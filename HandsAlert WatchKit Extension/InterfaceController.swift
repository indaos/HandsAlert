//
//  InterfaceController.swift
//  HandsAlert WatchKit Extension
//
//  Created by Denis Mikaya on 20.03.20.
//  Copyright © 2020 Denis Mikaya. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit
import CoreMotion
import WatchConnectivity
import os.log
import CoreML
import simd

class InterfaceController: WKInterfaceController,WCSessionDelegate {
    
    @IBOutlet var  sessionButton:WKInterfaceButton?
    @IBOutlet var  testButton:WKInterfaceButton?
    @IBOutlet var  sessionLabel:WKInterfaceLabel?
    @IBOutlet var  movingLabel:WKInterfaceLabel?

    var session : HKWorkoutSession?
    let motionManager = CMMotionManager()
    let healthStore = HKHealthStore()
    var connectivitySession : WCSession?

    var currentSession : Int = 0
    var  isPrediction = false
    
    static let pWindowSize = 50
    static let updateInterval = 0.02
    static let stateInLength = 400
    
    var currentIndxPWindow = 0
    
    let aX = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let aY = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let aZ = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let gX = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gY = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gZ = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    var stateOutput = try! MLMultiArray(shape:[stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
    let modelBuffer = AccTupleBuffer(size: 50)
    
    var classifier: HandsAlertActivityClassifier = HandsAlertActivityClassifier()

    let activityMinSession = 20000.0
    let inactivityInterval = 2000.0
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        self.motionManager.accelerometerUpdateInterval = InterfaceController.updateInterval
        self.motionManager.gyroUpdateInterval = InterfaceController.updateInterval
        self.motionManager.deviceMotionUpdateInterval = InterfaceController.updateInterval
        
        if WCSession.isSupported() {
            connectivitySession = WCSession.default
            connectivitySession?.delegate = self
            connectivitySession?.activate()
        }
        
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
    
    func currentTimeInMiliseconds() -> Double {
        return Double(Date().timeIntervalSince1970 * 1000)
    }
    
    var beginningOfCurrSession = 0.0
    
    func performModelPrediction ()  {
        DispatchQueue.main.async {
            let modelPrediction = try! self.classifier.prediction(acc_x: self.aX,acc_y: self.aY,acc_z: self.aZ,
                                                             gyro_x: self.gX,gyro_y: self.gY, gyro_z: self.gZ,
                                                             stateIn: self.stateOutput)
            self.stateOutput = modelPrediction.stateOut
            let a0 = modelPrediction.activityProbability["0"] ?? 0
            let a1 = modelPrediction.activityProbability["1"] ?? 0
            let a2 = modelPrediction.activityProbability["2"] ?? 0
            print(">>"+modelPrediction.activity+","+String(a0)+","+String(a1)+","+String(a2))
   
            if  modelPrediction.activity == "2"  && (!a2.isNaN && a2 > 0.6 ) {
                if self.beginningOfCurrSession == 0 {
                    WKInterfaceDevice().play(.notification)
                    self.beginningOfCurrSession=self.currentTimeInMiliseconds()
                } else if self.currentTimeInMiliseconds() - self.beginningOfCurrSession > self.activityMinSession {
                    WKInterfaceDevice().play(.notification)
                    self.beginningOfCurrSession=0
                }
            } else if self.beginningOfCurrSession > 0 {
                let inactivity = self.currentTimeInMiliseconds() - self.beginningOfCurrSession
                if inactivity > self.inactivityInterval {
                    WKInterfaceDevice().play(.failure)
                    self.beginningOfCurrSession+=inactivity
                }
            }
        }
    }
    
    var movingDirection=false
    
    func addAccelSampleToDataArray (accelSample: CMDeviceMotion) {
        
        let acceleration : CMAcceleration = accelSample.userAcceleration
        let rotationRate : CMRotationRate = accelSample.rotationRate
        aX[[currentIndxPWindow] as [NSNumber]] = acceleration.x as NSNumber
        aY[[currentIndxPWindow] as [NSNumber]] = acceleration.y as NSNumber
        aZ[[currentIndxPWindow] as [NSNumber]] = acceleration.z as NSNumber
        gX[[currentIndxPWindow] as [NSNumber]] = rotationRate.x as NSNumber
        gY[[currentIndxPWindow] as [NSNumber]] = rotationRate.y as NSNumber
        gZ[[currentIndxPWindow] as [NSNumber]] = rotationRate.z as NSNumber
        currentIndxPWindow += 1
        
        if ( currentIndxPWindow == InterfaceController.pWindowSize) {
            performModelPrediction()
            currentIndxPWindow = 0
        }
        
    }
    
    private func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            
            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak self] (data, error) in
                
                guard let acceleration : CMAcceleration = data?.userAcceleration else { return }
                guard let rotationRate : CMRotationRate = data?.rotationRate else {  return }
                
                if self?.isPrediction ?? false {
                    self?.addAccelSampleToDataArray(accelSample: data! )
                    return
                }
                
                if self?.modelBuffer.isFull() ?? false {
                    self!.modelBuffer.buffer.forEach { e in
                        let messageDict : [String : Double] = [
                            "S" : Double(self?.currentSession ?? 0),
                            "X" : e.x,
                            "Y" : e.y,
                            "Z" : e.z,
                            "RX" : e.rx,
                            "RY" : e.ry,
                            "RZ" : e.rz
                        ]
                        self?.connectivitySession?.sendMessage(messageDict, replyHandler: nil , errorHandler: { (error) in
                            print("message error \(error)")
                        })
                    }
                    self?.modelBuffer.reset();
                } else {
                    self?.modelBuffer.addSample((x: acceleration.x, y: acceleration.y, z: acceleration.z,
                                                 rx: rotationRate.x, ry: rotationRate.y, rz: rotationRate.z))
                }
                
            }
        }
    }
   
    
    @IBAction func starttest() {
        isPrediction.toggle()
        if !isPrediction {
            startstop()
            self.testButton?.setTitle("Start Prediction")
        } else {
            startstop()
            self.testButton?.setTitle("Stop Prediction")
        }
    }
    
    @IBAction func startstop() {
        
        if self.session != nil {
            self.testButton?.setEnabled(false)
            
            let messageDict : [String : Int] = [
                "StopSession" : self.currentSession
            ]
            self.connectivitySession?.sendMessage(messageDict, replyHandler: nil , errorHandler: { (error) in
                print("message error \(error)")
            })
            
            self.motionManager.stopDeviceMotionUpdates()
            self.session?.end()
            self.session = nil
            self.sessionButton?.setTitle("Start L-Session")
            WKInterfaceDevice().play(.notification)
            
        } else {
            var p=readProp()
            currentSession=p["Session"] ?? 1
            p["Session"]=currentSession+1
            saveProps(prop: p)
            
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .mixedCardio
            configuration.locationType = .indoor
            do {
                self.session = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
            } catch {
                dismiss()
                return
            }
            
            self.sessionButton?.setTitle("Stop Session")
            WKInterfaceDevice().play(.notification)
            self.session?.startActivity(with: Date())
            self.testButton?.setEnabled(true)
            
            startMotionUpdates()
            
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func saveProps(prop: [String:Int]) {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let url = urls.first else {
            return
        }
        if let data = try? PropertyListSerialization.data(fromPropertyList: prop, format: .xml, options: 1) {
            do {
                try data.write(to: url.appendingPathComponent("props.plist"))
            } catch {
            }
        }
    }
    
    func readProp() -> [String:Int] {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let url = urls.first else {
            return ["Session":0]
        }
        if let input = try? Data(contentsOf: url.appendingPathComponent("props.plist")),
            let dictionary = try? PropertyListSerialization.propertyList(from: input, options: .mutableContainersAndLeaves, format: nil),
            let d = dictionary as? [String : Int] {
            return d
        }
        return ["Session":0]
    }
    
    
}



