//
//  DrawingView.swift
//  Lama-Cleaner-iOS
//
//  Created by 間嶋大輔 on 2023/12/27.
//

import Foundation
import UIKit

struct Line {
    var points: [CGPoint]
    var lineWidth: CGFloat
}

protocol DrawingViewDelegate: AnyObject {
    func drawingViewDidFinishDrawing(_ drawingView: DrawingView)
}

class DrawingView: UIView {
    weak var delegate: DrawingViewDelegate?
    private var mode:InpaintingMode = .wholeImage
    private var lines: [Line] = []
    private var currentLine: Line?
    private var lineWidth:CGFloat = 10

    func setLineWidth(_ width: CGFloat) {
        lineWidth = width
    }
    
    func setInpaintMode(mode: InpaintingMode) {
        self.mode = mode
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let startPoint = touch.location(in: self)
        currentLine = Line(points: [startPoint], lineWidth: lineWidth)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let newPoint = touch.location(in: self)
        currentLine?.points.append(newPoint)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let completedLine = currentLine {
            lines.append(completedLine)
        }
        currentLine = nil
        setNeedsDisplay()
       delegate?.drawingViewDidFinishDrawing(self)
    }

    func getImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: bounds.size))

        for line in lines {
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(line.lineWidth)
            context.setLineCap(.round)

            guard let firstPoint = line.points.first else { continue }
            context.move(to: firstPoint)

            for point in line.points.dropFirst() {
                context.addLine(to: point)
            }

            context.strokePath()
        }

        if let currentLine = currentLine {
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(currentLine.lineWidth)
            context.setLineCap(.round)

            guard let firstPoint = currentLine.points.first else { return nil }
            context.move(to: firstPoint)

            for point in currentLine.points.dropFirst() {
                context.addLine(to: point)
            }

            context.strokePath()
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return image
    }
    
    func getNormalizedDrawingArea() -> CGRect {
        let drawingArea = calculateBoundingRect()
        let normalizeRect = CGRect(x: drawingArea.minX / bounds.width, y: drawingArea.minY / bounds.height, width: drawingArea.width / bounds.width, height: drawingArea.height / bounds.height)
        return normalizeRect
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        backgroundColor = .clear
        for line in lines {
            context.setStrokeColor(UIColor.yellow.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(line.lineWidth)
            context.setLineCap(.round)

            guard let firstPoint = line.points.first else { continue }
            context.move(to: firstPoint)

            for point in line.points.dropFirst() {
                context.addLine(to: point)
            }

            context.strokePath()
        }

        if let currentLine = currentLine {
            context.setStrokeColor(UIColor.yellow.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(currentLine.lineWidth)
            context.setLineCap(.round)

            guard let firstPoint = currentLine.points.first else { return }
            context.move(to: firstPoint)

            for point in currentLine.points.dropFirst() {
                context.addLine(to: point)
            }

            context.strokePath()
        }
        
        if mode == .cropROI {
            let boundingRect = calculateBoundingRect()
            context.setStrokeColor(UIColor.yellow.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(2.0)
            context.addRect(boundingRect)
            context.strokePath()
        }
    }
    
    private func calculateBoundingRect() -> CGRect {
        guard var minX = lines.flatMap({ $0.points.map({ $0.x }) }).min(),
              var maxX = lines.flatMap({ $0.points.map({ $0.x }) }).max(),
              var minY = lines.flatMap({ $0.points.map({ $0.y }) }).min(),
              var maxY = lines.flatMap({ $0.points.map({ $0.y }) }).max()
        else { return CGRect.zero }
        var boundingRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let margin:CGFloat = lineWidth * 1.5
        boundingRect = CGRect(x: minX - margin, y: minY - margin, width: maxX - minX + margin * 2, height: maxY - minY + margin * 2)
        if boundingRect.minX < 0 {
            boundingRect.origin.x = 0
        }
        
        if boundingRect.minY < 0 {
            boundingRect.origin.y = 0
        }
        if boundingRect.maxX > bounds.maxX {
            boundingRect.size.width = bounds.maxX - boundingRect.minX
        }
        if boundingRect.maxY > bounds.maxY {
            boundingRect.size.height = bounds.maxY - boundingRect.minY
        }
        return boundingRect
    }

    func clearDrawing() {
        lines.removeAll()
        currentLine = nil
        setNeedsDisplay()
    }
}
