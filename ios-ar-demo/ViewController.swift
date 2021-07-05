//
//  ViewController.swift
//  ios-ar-demo
//
//  Created by Jonathan Zbick on 30.06.21.
//

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!

    @IBOutlet weak var blurView: UIVisualEffectView!
    
    lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController}).first!
    }()
    
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".serialSceneKitQueue")
    
    var session: ARSession {
        return sceneView.session
    }
    
    var currentImage = 0
    
    var referenceImage: ARReferenceImage? = nil
    
    var images: [UIImage?] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        sceneView.rendersContinuously = true
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(onSwipe))
        swipeLeft.direction = UISwipeGestureRecognizer.Direction.left
        sceneView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(onSwipe))
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        sceneView.addGestureRecognizer(swipeRight)
        
        statusViewController.restartExperienceHandler = {[unowned self] in
            self.restartExperience()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        session.pause()
    }
    
    var isRestartAvailable = true
    
    func resetTracking() {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing assets")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        
        self.referenceImage = imageAnchor.referenceImage
        
        updateQueue.async {
            
            let directoryEnumerator: FileManager.DirectoryEnumerator = FileManager.default.enumerator(atPath: "\(Bundle.main.resourcePath!)/Images")!
            
            var imageNames: [String] = []
            
            while let obj = directoryEnumerator.nextObject() as? String {
                if obj.hasSuffix("jpg") {
                    imageNames.append(obj)
                }
            }
            
            imageNames.sort()
            
            self.images = imageNames.map { obj in
                UIImage.init(contentsOfFile: "\(Bundle.main.resourcePath!)/Images/\(obj)")
            }
            
            let image = self.images[self.currentImage]!

            let planeNode = SCNNode()
            
            planeNode.eulerAngles.x = -.pi / 2
            
            planeNode.geometry = self.createGeometry(image: image)

            node.addChildNode(planeNode)
        }
        
        DispatchQueue.main.async {
            let imageName = self.referenceImage!.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image '\(imageName)'")
        }
    }
    
    @objc private func onSwipe(recognizer: UISwipeGestureRecognizer) {
        
        switch recognizer.direction {
        case UISwipeGestureRecognizer.Direction.left:
            currentImage = (currentImage + 1) % images.count
        case UISwipeGestureRecognizer.Direction.right:
            let number = (currentImage - 1) % images.count
            currentImage = number < 0 ? number + images.count : number
        default:
            return
        }
        
        let image = images[currentImage]!
        
        let location = recognizer.location(in: recognizer.view as? ARSCNView)
        
        let hitTestResult = self.sceneView.hitTest(location)
        
        if let node = hitTestResult.first?.node {
            node.geometry = createGeometry(image: image)
        }
    }
    
    private func createGeometry(image: UIImage) -> SCNGeometry {
        let plane = SCNPlane(width: self.referenceImage!.physicalSize.height * image.size.width / image.size.height,
                             height: self.referenceImage!.physicalSize.height)
        
        plane.firstMaterial?.diffuse.contents = image
        
        return plane
    }
}
