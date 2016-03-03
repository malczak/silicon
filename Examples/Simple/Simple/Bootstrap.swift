//
//  Bootstrap.swift
//  Simple
//
//  Created by Mateusz Malczak on 02/03/16.
//  Copyright © 2016 ThePirateCat. All rights reserved.
//

import Foundation
import Silicon

class Bootstrap {
    
    class func setup() {
        let silicon = Silicon.sharedInstance;
        
        silicon.set("log") { si in
            let logBlock = { (info: String) in
                NSLog(info)
            }
            return logBlock
        }
    }
    
}