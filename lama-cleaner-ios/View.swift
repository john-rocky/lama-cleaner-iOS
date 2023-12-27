//
//  View.swift
//  Lama-Cleaner-iOS
//
//  Created by 間嶋大輔 on 2023/12/27.
//

import Foundation
import UIKit

extension ViewController {
    
    
    func resetDrawingView() {
        drawingView.clearDrawing()
    }
    
    func setupView() {
        view.backgroundColor = .black
        imageView.backgroundColor = .clear
        imageView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height * 0.7)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        drawingView.backgroundColor = .clear
        drawingView.frame = imageView.frame
        view.addSubview(drawingView)
        let buttonAreaHeight = view.bounds.height * 0.3
        let buttonHeight = buttonAreaHeight/5
        let buttonWidth = buttonHeight
        
        undoButton.frame = CGRect(x: view.center.x - buttonWidth/2, y: view.bounds.maxY - buttonAreaHeight/2, width: buttonWidth, height: buttonHeight)
        selectPhotoButton.frame = CGRect(x: undoButton.frame.minX - buttonWidth - 20, y:  view.bounds.maxY - buttonAreaHeight/2, width: buttonWidth, height: buttonHeight)
        superResolutionButton.frame = CGRect(x: undoButton.frame.maxX+20, y: view.bounds.maxY - buttonAreaHeight/2, width: buttonWidth, height: buttonHeight)
        saveButton.frame = CGRect(x: superResolutionButton.frame.maxX + 20, y: view.bounds.maxY - buttonAreaHeight/2, width: buttonWidth, height: buttonHeight)
        let brushSliderWidth = view.bounds.width * 0.6
        brushLabel.frame = CGRect(x: view.bounds.width * 0.05, y: view.bounds.maxY - buttonAreaHeight/2 - buttonHeight - 20, width: view.bounds.width * 0.2, height: buttonHeight)
        brushSlider.frame = CGRect(x: brushLabel.frame.maxX, y: view.bounds.maxY - buttonAreaHeight/2 - buttonHeight - 20, width: brushSliderWidth, height: buttonHeight)
        segmentedControl.frame =  CGRect(x: brushLabel.frame.maxX, y: view.bounds.maxY - buttonAreaHeight/2 - buttonHeight * 2 - 20, width: brushSliderWidth, height: buttonHeight/2)
        inpaintModeLabel.frame = CGRect(x: view.bounds.width * 0.05, y: view.bounds.maxY - buttonAreaHeight/2 - buttonHeight * 2 - 30, width: view.bounds.width * 0.2, height: buttonHeight)
        segmentedControl.backgroundColor = .white
        undoButton.setImage(UIImage(systemName: "arrowshape.turn.up.left.fill"), for: .normal)
        selectPhotoButton.setImage(UIImage(systemName: "photo"), for: .normal)
        saveButton.setImage(UIImage(systemName: "tray.and.arrow.down.fill"), for: .normal)

        superResolutionButton.setTitle("SR", for: .normal)
        
        undoButton.tintColor = .white
        saveButton.tintColor = .white
        selectPhotoButton.tintColor = .white
        superResolutionButton.setTitleColor(.white, for: .normal)

        undoButton.backgroundColor = .clear
        selectPhotoButton.backgroundColor = .clear
        superResolutionButton.backgroundColor = .clear
        saveButton.backgroundColor = .clear

        view.addSubview(selectPhotoButton)
        view.addSubview(superResolutionButton)
        view.addSubview(undoButton)
        view.addSubview(saveButton)
        view.addSubview(segmentedControl)
        view.addSubview(inpaintModeLabel)

        view.addSubview(brushLabel)
        view.addSubview(brushSlider)
        segmentedControl.selectedSegmentTintColor = .yellow
        inpaintModeLabel.text = "Input"
        inpaintModeLabel.textAlignment = .center
        inpaintModeLabel.textColor = .white
        brushSlider.minimumTrackTintColor = UIColor.yellow
        brushSlider.minimumValue = 5
        brushSlider.maximumValue = 40
        brushSlider.value = 30
        brushLabel.text = "Brush"
        brushLabel.textColor = .white
        brushLabel.textAlignment = .center
        adjustDrawingViewSize()
    }

    func performPulsingAnimation() {
        pulsatingAnimation = CABasicAnimation(keyPath: "opacity")
        pulsatingAnimation?.duration = 0.5
        pulsatingAnimation?.fromValue = 1.0
        pulsatingAnimation?.toValue = 0.0
        pulsatingAnimation?.autoreverses = true
        pulsatingAnimation?.repeatCount = Float.infinity

        drawingView.layer.add(pulsatingAnimation!, forKey: "pulsating")
        
    }

    func stopPulsatingAnimation() {
        drawingView.layer.removeAnimation(forKey: "pulsating")
    }
    
    func presentAlert(_ title: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title,
                                                    message: "",
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK",
                                         style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}
