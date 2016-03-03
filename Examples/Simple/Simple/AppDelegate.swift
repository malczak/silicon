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

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Bootstrap.setup()
        
        self.log("On Boostrap done")
        
        return true
    }

}


