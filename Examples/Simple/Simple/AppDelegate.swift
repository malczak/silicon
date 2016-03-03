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

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Bootstrap.setup()
        
        if let log = Silicon.get("log") as? ((String) -> Void) {
            log("Super")
        }
        
        return true
    }

}

