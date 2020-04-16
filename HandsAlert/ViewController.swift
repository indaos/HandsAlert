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
    @IBOutlet weak var secsLabel: UILabel!
    @IBOutlet weak var anumberLabel: UILabel!
    @IBOutlet weak var anumberStepper: UIStepper!

    var connectivitySession : WCSession?
      
    var currentActivity = "0"
    let accGain : Double = 1.0
    let rotGain : Double = 0.1
    let wrWindow : Int = 500
    var seconds = 0
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
        let session : Double = message["S"] as? Double ?? 0.0

        let today = Date()
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "HH:mm:ss:SS"
        print(formatter1.string(from: today)+"  message:"+String(cursession)+","+String(session))
        
        DispatchQueue.main.async {
              self.progressAX.progress = Float(abs(0))
              self.progressAY.progress = Float(0)
          }
        
        if cursession != -1 {
          //  writeCSV(sess: cursession,from: msgsBuffer)
            seconds = 0
            msgsBuffer=[]
            return
        }
        
       // let session : Double = message["S"] as? Double ?? 0.0
        for index in 0...49 {
            let accX : Double = message["X"+String(index)] as? Double ?? 0.0
            let accY : Double = message["Y"+String(index)] as? Double ?? 0.0
            let accZ : Double = message["Z"+String(index)] as? Double ?? 0.0
            let rotX : Double = message["RX"+String(index)] as? Double ?? 0.0
            let rotY : Double = message["RY"+String(index)] as? Double ?? 0.0
            let rotZ : Double = message["RZ"+String(index)] as? Double ?? 0.0
            msgsBuffer += [(x: accX,y: accY,z: accZ,rx: rotX,ry:rotY,rz: rotZ)]
        }
        seconds+=1
        DispatchQueue.main.async {
            self.progressAX.progress = Float(self.msgsBuffer.count)/500
            self.secsLabel.text = ""+String(self.seconds)+" seconds"
        }
        
        if msgsBuffer.count == wrWindow {
            writeCSV(sess:  Int(session),from: msgsBuffer)
            msgsBuffer=[]
            DispatchQueue.main.async {
                self.progressAY.progress = Float(100)
                self.progressAX.progress = Float(0)
            }
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
        switch Int(sender.value) {
        case 0:  anumberLabel.text="None"
        case 1:  anumberLabel.text="Touching Face"
        case 2:  anumberLabel.text="Washing Hands"
        default:
            anumberLabel.text="?"
        }
        currentActivity = Int(sender.value).description
    }
    
}


