//
//  ViewController.swift
//  HandsAlert
//
//  Created by Denis Mikaya on 20.03.20.
//  Copyright © 2020 Denis Mikaya. All rights reserved.
//

import UIKit
import WatchConnectivity
import os.log

class ViewController: UIViewController, WCSessionDelegate {


    @IBOutlet weak var progressAX: UIProgressView!
    @IBOutlet weak var progressAY: UIProgressView!
    @IBOutlet weak var progressAZ: UIProgressView!
    @IBOutlet weak var progressRX: UIProgressView!
    @IBOutlet weak var progressRY: UIProgressView!
    @IBOutlet weak var progressRZ: UIProgressView!
    @IBOutlet weak var testLabel: UILabel!
    @IBOutlet weak var anumberLabel: UILabel!
    @IBOutlet weak var anumberStepper: UIStepper!

    var connectivitySession : WCSession?
      
    var currentActivity = "0"
    let accGain : Double = 1.0
    let rotGain : Double = 0.1
    let wrWindow : Int = 500
    
    var msgsBuffer:[( x: Double,y: Double,z: Double,rx: Double,ry: Double,rz: Double)] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
         os_log("viewDidLoad")
              if WCSession.isSupported() {
                  connectivitySession = WCSession.default
                  connectivitySession?.delegate = self
                  connectivitySession?.activate()
              }
              else {
              }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        let cursession : Int = message["StopSession"] as? Int ?? -1
        
        if cursession != -1 {
            writeCSV(sess: cursession,from: msgsBuffer)
            msgsBuffer=[]
            return
        }
        
        let session : Double = message["S"] as? Double ?? 0.0
        
        let accX : Double = message["X"] as? Double ?? 0.0
        let accY : Double = message["Y"] as? Double ?? 0.0
        let accZ : Double = message["Z"] as? Double ?? 0.0
        let rotX : Double = message["RX"] as? Double ?? 0.0
        let rotY : Double = message["RY"] as? Double ?? 0.0
        let rotZ : Double = message["RZ"] as? Double ?? 0.0
        
        
        msgsBuffer += [(x: accX,y: accY,z: accZ,rx: rotX,ry:rotY,rz: rotZ)]
        
        if msgsBuffer.count == wrWindow {
            writeCSV(sess:  Int(session),from: msgsBuffer)
            msgsBuffer=[]
        }
        
        DispatchQueue.main.async {
            self.testLabel.text = (String(self.msgsBuffer.count))
            self.progressAX.progress = Float(abs(accX * self.accGain))
            self.progressAY.progress = Float(abs(accY * self.accGain))
            self.progressAZ.progress = Float(abs(accZ * self.accGain))
            self.progressRX.progress = Float(abs(rotX * self.rotGain))
            self.progressRY.progress = Float(abs(rotY * self.rotGain))
            self.progressRZ.progress = Float(abs(rotZ * self.rotGain))
        }
    }
        
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    
    
    func writeCSV(sess:Int,from list:[(x: Double,y: Double,z: Double,rx: Double,ry: Double,rz: Double)]) {
        var csvString = ""
        for r in list {
            csvString = csvString.appending("\(String(describing: r.x)),\(String(describing: r.y)) , \(String(describing: r.z))")
            csvString = csvString.appending(",\(String(describing: r.rx)),\(String(describing: r.ry)) , \(String(describing: r.rz))")
            csvString = csvString.appending(",\(String(describing: sess)),\(String(describing: currentActivity))\n") 
        }
        
        do {
            let fileManager = FileManager.default
            let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: true)
            let fileURL = path.appendingPathComponent("motion_\(String(sess)).csv")
            
            if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
                fileHandle.seekToEndOfFile()
                guard let data = csvString.data(using: .utf8) else {
                    return
                }
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try csvString.write(to: fileURL, atomically: false, encoding: .utf8)
            }
        } catch {
        }
        
    }
    
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        anumberLabel.text = Int(sender.value).description
        currentActivity = Int(sender.value).description
    }
    
}


