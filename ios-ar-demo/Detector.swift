//
//  Detector.swift
//  ios-ar-demo
//
//  Created by Jonathan Zbick on 30.06.21.
//

import UIKit
import Vision
import CoreImage

class Detector {
    
    private var currentCameraImage: CVPixelBuffer!
    
    private var updateTimer: Timer?
    
    private var updateInterval: TimeInterval = 0.1
    
    weak var delegate: DetectorDelegate?
    
    init() {
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            if let capturedImage = ViewController.instance?.sceneView.session.currentFrame?.caputuredImage {
                self.search(in: capturedImage)
            }
        }
    }
}

protocol DetectorDelegate: class {
    func rectangleFound(rectangleContent: CIImage)
}
