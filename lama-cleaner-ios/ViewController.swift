//
//  ViewController.swift
//  Lama-iOS
//
//  Created by 間嶋大輔 on 2023/12/25.
//

import UIKit
import Vision
import CoreML
import PhotosUI

class ViewController: UIViewController,PHPickerViewControllerDelegate, UIPickerViewDelegate, DrawingViewDelegate {

    var imageView = UIImageView()
    let drawingView = DrawingView()
    let undoButton = UIButton()
    let compareButton = UIButton()
    let selectPhotoButton =  UIButton()
    let superResolutionButton = UIButton()
    let saveButton = UIButton()
    var brushSlider = UISlider()
    let brushLabel = UILabel()
    let segmentedControl = UISegmentedControl(items: ["Whole image", "Crop ROI"])
    let inpaintModeLabel = UILabel()
    let compareSlider = UISlider()
    var pulsatingAnimation: CABasicAnimation?
    let dummyKnobImageView = UIImageView()

    lazy var model: LaMa? = {
        do {
            let config = MLModelConfiguration()
//            config.computeUnits = .cpuAndGPU
            let model = try LaMa(configuration: config)
            return model
        } catch let error {
            print(error)
            fatalError("model initialize error")
        }
    }()
    
    lazy var srRequest: VNCoreMLRequest = {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            let model = try realesrgangeneral512(configuration: config).model
            let vnModel = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: vnModel)
            request.imageCropAndScaleOption = .scaleFill
            return request
        } catch let error {
            print(error)
            fatalError("model initialize error")
        }
    }()
    
    private var inpaintMode: InpaintingMode = .wholeImage
    private var inputImage: UIImage?
    private let ciContext = CIContext()
    private var imagesSoFar:[UIImage] = []
    private var compareMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        inputImage = UIImage(named: "input")
        imageView.image = inputImage
        imagesSoFar.append(inputImage!)
        setupView()
        drawingView.delegate = self
        drawingView.setLineWidth(40)
        selectPhotoButton.addTarget(self, action: #selector(presentPhPicker), for: .touchUpInside)
        compareButton.addTarget(self, action: #selector(compare), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveImage), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undoInpainting), for: .touchUpInside)
        brushSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged), for: .valueChanged)
        compareSlider.addTarget(self, action: #selector(comparesSliderValueDidChange), for: .valueChanged)
        compareSlider.minimumValue = 0.001
        compareSlider.maximumValue = 0.999
        compareSlider.value = 0.5
        segmentedControl.selectedSegmentIndex = 0
        compareSlider.isHidden = true
        dummyKnobImageView.isHidden = true
    }
    
    func inference(maskedImage inputImage:UIImage, maskImage mask:UIImage) {
        print(inputImage.size.width/inputImage.size.height)
        print(mask.size.width/mask.size.height)
        let normalizedDrawingRect = self.drawingView.getNormalizedDrawingArea()

        guard let model = model else { fatalError("Model initialize error.") }
        DispatchQueue.global(qos: .userInitiated).async {
            
            do {
                var input:LaMaInput?
                let originalSize = self.inputImage!.size
                let drawingRect = CGRect(x: normalizedDrawingRect.minX * originalSize.width, y: normalizedDrawingRect.minY * originalSize.height, width: normalizedDrawingRect.width * originalSize.width, height: normalizedDrawingRect.height * originalSize.height)
                
                if self.inpaintMode == .cropROI {
                    let maskDrawingRect = CGRect(x: normalizedDrawingRect.minX *  mask.size.width, y: normalizedDrawingRect.minY * mask.size.height, width: normalizedDrawingRect.width *  mask.size.width, height: normalizedDrawingRect.height *  mask.size.height)
                    guard let croppedMaskImage = self.cropImage(image: mask, rect:maskDrawingRect),
                          let croppedOriginalImage = self.cropImage(image: inputImage, rect: drawingRect)else { fatalError() }
                    input = try LaMaInput(imageWith: croppedOriginalImage.cgImage!, maskWith: croppedMaskImage.cgImage!)
                    
                } else {
                    
                    input = try LaMaInput(imageWith: inputImage.cgImage!, maskWith: mask.cgImage!)
                    
                }
                
                let start = Date()
                let out = try model.prediction(input: input!)
                let pixelBuffer = out.output
                let resultCIImage = CIImage(cvPixelBuffer: pixelBuffer)
                print(resultCIImage.extent.size)

                var image:UIImage!
                if self.inpaintMode == .cropROI {
                    guard let resultCGImage = self.ciContext.createCGImage(resultCIImage, from: resultCIImage.extent)?.resize(size: drawingRect.size) else { fatalError() }
                    
                    image = UIImage(cgImage: resultCGImage)

//                    image = image.resized(toSize: drawingRect.size)!
                    image = image.resize(size: drawingRect.size)
                    print(image.size)
                    print(inputImage.size)
                    image = self.mergeImageWithRect(image1: inputImage, image2: image, mergeRect: drawingRect)!
                } else {
                    guard let resultCGImage = self.ciContext.createCGImage(resultCIImage, from: resultCIImage.extent) else { fatalError() }
                    
                    let resultImage = UIImage(cgImage: resultCGImage).resize(size: originalSize)
                    guard let croppedResultImage = self.cropImage(image: resultImage!, rect: drawingRect)else { fatalError() }
                    image = self.mergeImageWithRect(image1: inputImage, image2: croppedResultImage, mergeRect: drawingRect)!

                    
                }
                print(originalSize)
                print(image.size)
                let timeElapsed = -start.timeIntervalSinceNow
                print(timeElapsed)
                
                self.inputImage = image
                self.imagesSoFar.append(image)
                DispatchQueue.main.async {
                    
                    self.resetDrawingView()
                    self.imageView.image = image
                    self.stopPulsatingAnimation()
                    print("Done")
                }
            } catch let error {
                print(error)
            }
        }
    }
    
    
    @objc func run() {
        performPulsingAnimation()
        guard let maskImage:UIImage = drawingView.getImage()
        else { fatalError("Mask overlap error") }
        inference(maskedImage: inputImage!, maskImage: maskImage)
    }
    
    @objc func saveImage(){
        UIImageWriteToSavedPhotosAlbum(self.inputImage!, self, #selector(imageSaved), nil)
    }
    
    @objc func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        presentAlert("saved in photo library!")
    }
    
    @objc func undoInpainting() {
        print(imagesSoFar.count)
        
        if imagesSoFar.count > 1 {
            imagesSoFar.removeLast()
            let recentImage = imagesSoFar.last!
            imageView.image = recentImage
            inputImage = recentImage
        }
        
        if compareMode {
            compareMode = false
            compareSlider.isHidden = true
            dummyKnobImageView.isHidden = true
            drawingView.isHidden = false
            compareButton.tintColor = .white
            imageView.image = inputImage
        }
    }
    
    @objc func presentPhPicker(){
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc func sr() {
        let handler = VNImageRequestHandler(ciImage: CIImage(image: inputImage!)!)
        do {
            try handler.perform([srRequest])
            guard let result = srRequest.results?.first as? VNPixelBufferObservation else {
                return
            }
            let srCIImage = CIImage(cvPixelBuffer: result.pixelBuffer)
            let resizedCGImage = ciContext.createCGImage(srCIImage, from: srCIImage.extent)?.resize(size: CGSize(width: inputImage!.size.width, height: inputImage!.size.height))
            let srUIImage = UIImage(cgImage: resizedCGImage!)
            inputImage = srUIImage
            DispatchQueue.main.async {
                self.imageView.image = srUIImage
                self.adjustDrawingViewSize()
            }
        } catch let error {
            print(error)
        }
    }
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        let selectedValue = sender.value
        drawingView.setLineWidth(CGFloat(selectedValue))
    }
    
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        let selectedIndex = sender.selectedSegmentIndex
        if selectedIndex == 0 {
            inpaintMode = .wholeImage
            drawingView.setInpaintMode(mode: .wholeImage)
        } else {
            inpaintMode = .cropROI
            drawingView.setInpaintMode(mode: .cropROI)
        }
    }
    
    @objc func compare(_ sender: UIButton) {
        if !compareMode {
            setCompareMode()
            comparesSliderValueDidChange(compareSlider)
        } else {
            resetCompareMode()
            imageView.image = inputImage

        }
    }
    
    func setCompareMode() {
        compareMode = true
        compareSlider.isHidden = false
        dummyKnobImageView.isHidden = false
        drawingView.isHidden = true
        compareButton.tintColor = .yellow
    }
    
    func resetCompareMode() {
        compareMode = false
        compareSlider.isHidden = true
        dummyKnobImageView.isHidden = true
        drawingView.isHidden = false
        compareButton.tintColor = .white
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error  in
                if let image = image as? UIImage,  let safeSelf = self {
                    let correctOrientImage = safeSelf.getCorrectOrientationUIImage(uiImage: image)
                    safeSelf.inputImage = correctOrientImage
                    safeSelf.imagesSoFar = [correctOrientImage]
                    
                    DispatchQueue.main.async {
                        safeSelf.resetDrawingView()
                        safeSelf.imageView.image = correctOrientImage
                        safeSelf.adjustDrawingViewSize()
                        safeSelf.resetCompareMode()
                    }
                }
            }
        }
    }
    
    func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
        var newImage = UIImage()
        let ciContext = CIContext()
        switch uiImage.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            newImage = UIImage(cgImage: cgImage)
        default:
            newImage = uiImage
        }
        return newImage
    }
    
    func adjustDrawingViewSize() {
        let displayAspect = imageView.frame.height / imageView.frame.width
        let imageSize = imageView.image!.size
        let imageAspect = imageSize.height / imageSize.width
        if imageAspect <= displayAspect {
            let minX = imageView.frame.minX
            let minY = imageView.center.y - (imageView.frame.width * imageAspect / 2)
            let width = imageView.frame.width
            let height = imageView.frame.width * imageAspect
            drawingView.frame = CGRect(x: minX, y: minY, width: width, height: height)

        } else {
            let aspect = imageSize.width / imageSize.height
            drawingView.frame = CGRect(x: imageView.center.x - (imageView.frame.height * aspect / 2), y: imageView.frame.minY, width: imageView.frame.height * aspect, height: imageView.frame.height)
        }
        compareSlider.center = imageView.center
        dummyKnobImageView.center.y = compareSlider.center.y
        dummyKnobImageView.center.x = imageView.frame.width * CGFloat(compareSlider.value)
    }
    
    func mergeImages(image1: UIImage, image2: UIImage, mergeRect: CGRect) -> UIImage? {
        if let croppedImage = cropImage(image: image1, rect: mergeRect) {
            if let mergedImage = mergeImageWithRect(image1: image2, image2: croppedImage, mergeRect: mergeRect) {
                return mergedImage
            }
        }
        return nil
    }

    func cropImage(image: UIImage, rect: CGRect) -> UIImage? {
        if let cgImage = image.cgImage {
            let toCGImageScale = CGFloat(cgImage.width) / image.size.width
            let cropRect = CGRect(x: rect.minX * toCGImageScale, y: rect.minY * toCGImageScale, width: rect.width * toCGImageScale, height: rect.height * toCGImageScale)
            let croppedCGImage = cgImage.cropping(to: cropRect)
            return UIImage(cgImage: croppedCGImage!)
        }
        return nil
    }

    func mergeImageWithRect(image1: UIImage, image2: UIImage, mergeRect: CGRect) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image1.size, false, image1.scale)
        
        image1.draw(in: CGRect(x: 0, y: 0, width: image1.size.width, height: image1.size.height))
        
        image2.draw(in: mergeRect)
        
        let mergedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return mergedImage
    }
    
    func drawingViewDidFinishDrawing(_ drawingView: DrawingView) {
        run()
    }
    
    @objc func comparesSliderValueDidChange(_ sender: UISlider) {
        let image1 = inputImage!
        let image2 = imagesSoFar.first!
        let value = sender.value
        let leftPercentage = CGFloat(value)
        let rightPercentage = CGFloat(1 - value)
        
        let image1Width = image1.size.width * leftPercentage
        let image2Width = image2.size.width * rightPercentage
        
        let image1Rect = CGRect(x: 0, y: 0, width: image1Width, height: image1.size.height)
        let croppedImage1 = cropImage(image: image1, rect: image1Rect)
        
        let image2Rect = CGRect(x: image1.size.width - image2Width, y: 0, width: image2Width, height: image1.size.height)
        let croppedImage2 = cropImage(image: image2, rect: image2Rect)
        let lineXPosition = CGFloat(value) * image1.size.width

        let renderer = UIGraphicsImageRenderer(size: image1.size)
        let combinedImage = renderer.image { context in
            croppedImage1!.draw(in: image1Rect)
            croppedImage2!.draw(in: image2Rect)
            let lineColor = UIColor.yellow.withAlphaComponent(0.5)
            lineColor.set()
            context.cgContext.move(to: CGPoint(x: lineXPosition, y: 0))
            context.cgContext.addLine(to: CGPoint(x: lineXPosition, y: image1.size.height))
            context.cgContext.setLineWidth(5)
            context.cgContext.strokePath()
        }
        dummyKnobImageView.center.x = imageView.frame.width * CGFloat(compareSlider.value)
        imageView.image = combinedImage
    }
}

enum InpaintingMode {
    case wholeImage
    case cropROI
}

//extension UIImage {
//    func resized(toSize newSize: CGSize) -> UIImage? {
//        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
//        defer { UIGraphicsEndImageContext() }
//        self.draw(in: CGRect(origin: .zero, size: newSize))
//        return UIGraphicsGetImageFromCurrentImageContext()
//    }
//
//
//}
extension UIImage {
    func resize(size _size: CGSize) -> UIImage? {
        let aspectWidth = _size.width / size.width
        let aspectHeight = _size.height / size.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let scaledWidth = size.width * aspectWidth
        let scaledHeight = size.height * aspectHeight

        UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 0.0)
        draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }
}

