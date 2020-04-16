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
    @IBOutlet var  movingLabel:WKInterfaceLabel?

    var session : HKWorkoutSession?
    let motionManager = CMMotionManager()
    let healthStore = HKHealthStore()
    var connectivitySession : WCSession?

    var currentSession : Int = 0
    var  isPrediction = false
    
    static let pWindowSize = 80
    static let updateInterval = 0.0125
    static let stateInLength = 400
    
    var currentIndxPWindow = 0
    
    let aX = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let aY = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let aZ = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let gX = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gY = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gZ = try! MLMultiArray(shape: [pWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    var stateOutput = try! MLMultiArray(shape:[stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
    let modelBuffer = AccTupleBuffer(size: pWindowSize)

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
        
    
    func performModelPrediction ()  {
        DispatchQueue.main.async {
            let modelPrediction = try! self.classifier.prediction(ax: self.aX,ay: self.aY,az: self.aZ,
                                                                  gx: self.gX,gy: self.gY, gz: self.gZ,
                                                             stateIn: self.stateOutput)
            let a0 = modelPrediction.actProbability["0"] ?? 0
            let a1 = modelPrediction.actProbability["1"] ?? 0
            let a2 = modelPrediction.actProbability["2"] ?? 0
            self.stateOutput = modelPrediction.stateOut
            var debStr=""
            switch(modelPrediction.act) {
            case "0":debStr=modelPrediction.act+","+String(a0)
            case "1":debStr=modelPrediction.act+","+String(a1)
            case "2":debStr=modelPrediction.act+","+String(a2)
            default:
                debStr="?"
            }
            print(debStr)
            self.movingLabel?.setText(debStr)
        }
    }
    
    
    func shiftData() {
        for i in 1..<InterfaceController.pWindowSize {
            aX[i-1]=aX[i]
            aY[i-1]=aY[i]
            aZ[i-1]=aZ[i]
            gX[i-1]=gX[i]
            gY[i-1]=gY[i]
            gZ[i-1]=gZ[i]
        }
    }
    
    var counter=0
    
    func addAccelSampleToDataArray (accelSample: CMDeviceMotion) {
        
        let acceleration : CMAcceleration = accelSample.userAcceleration
        let rotationRate : CMRotationRate = accelSample.rotationRate
        
        if  currentIndxPWindow == InterfaceController.pWindowSize {
            shiftData()
            aX[[currentIndxPWindow-1] as [NSNumber]] = acceleration.x as NSNumber
            aY[[currentIndxPWindow-1] as [NSNumber]] = acceleration.y as NSNumber
            aZ[[currentIndxPWindow-1] as [NSNumber]] = acceleration.z as NSNumber
            gX[[currentIndxPWindow-1] as [NSNumber]] = rotationRate.x as NSNumber
            gY[[currentIndxPWindow-1] as [NSNumber]] = rotationRate.y as NSNumber
            gZ[[currentIndxPWindow-1] as [NSNumber]] = rotationRate.z as NSNumber
        } else {
            aX[[currentIndxPWindow] as [NSNumber]] = acceleration.x as NSNumber
            aY[[currentIndxPWindow] as [NSNumber]] = acceleration.y as NSNumber
            aZ[[currentIndxPWindow] as [NSNumber]] = acceleration.z as NSNumber
            gX[[currentIndxPWindow] as [NSNumber]] = rotationRate.x as NSNumber
            gY[[currentIndxPWindow] as [NSNumber]] = rotationRate.y as NSNumber
            gZ[[currentIndxPWindow] as [NSNumber]] = rotationRate.z as NSNumber
        }
        
        if ( currentIndxPWindow == InterfaceController.pWindowSize) {
            if counter == 20 {
                performModelPrediction()
                counter=0
            } else {
                counter+=1
            }
        } else {
            currentIndxPWindow += 1
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
                    var c=0
                    var messageDict:[String:Any]=[:]
                    messageDict["S"] = Double(self?.currentSession ?? 0)
                    self!.modelBuffer.buffer.forEach { e in
                        messageDict["X"+String(c)] = e.x
                        messageDict["Y"+String(c)] = e.y
                        messageDict["Z"+String(c)] = e.z
                        messageDict["RX"+String(c)] = e.rx
                        messageDict["RY"+String(c)] = e.ry
                        messageDict["RZ"+String(c)] = e.rz
                        c+=1
                    }
                    self?.connectivitySession?.sendMessage(messageDict, replyHandler: nil , errorHandler: { (error) in
                        print("message error \(error)")
                    })
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
            self.motionManager.stopDeviceMotionUpdates()
            self.session?.end()
            self.session = nil
            self.sessionButton?.setTitle("Start L-Session")
            self.modelBuffer.reset();
            WKInterfaceDevice().play(.notification)
            let messageDict : [String : Int] = [
                     "StopSession" : self.currentSession
                 ]
             self.connectivitySession?.sendMessage(messageDict, replyHandler: nil , errorHandler: { (error) in
                 print("message error \(error)")
             })
        } else {
            var p=readProp()
            currentSession=p["Session"] ?? 1
            p["Session"]=currentSession+1
            saveProps(prop: p)
            
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .other
            configuration.locationType = .unknown
            do {
                self.session = try HKWorkoutSession( healthStore: self.healthStore,configuration: configuration)
            } catch {
                dismiss()
                return
            }
  
            self.session?.startActivity(with: Date())
            
            self.testButton?.setEnabled(true)
            self.sessionButton?.setTitle("Stop Session")
            WKInterfaceDevice().play(.notification)
            
            startMotionUpdates()
            
            self.session?.pause()

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



