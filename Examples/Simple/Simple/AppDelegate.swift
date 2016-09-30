//
//  AppDelegate.swift
//  Simple
//
//  Created by Mateusz Malczak on 02/03/16.
//  Copyright © 2016 ThePirateCat. All rights reserved.
//

import UIKit
import Silicon

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Bootstrap.setup()
        
        self.log(text: "On Boostrap done")
        let sem = DispatchSemaphore(value: 0)
        
        let queue = DispatchQueue(label: "testy1")
        let queue2 = DispatchQueue(label: "testy2")
        let key = DispatchSpecificKey<Int>()
        queue.setSpecific(key: key, value: 1001)
        queue2.async {
            print("\t\ttrying t1")
            if let t1 = DispatchQueue.getSpecific(key: DispatchSpecificKey<Int>()) {
                print("Got t1 = \(t1)")
            }
            print("\t\ttrying t2 \(key)")
            if let t2 = DispatchQueue.getSpecific(key: key) {
                print("Got t2 = \(t2)")
            }
        }
        
        return true
    }

}


