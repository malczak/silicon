//
//  Services.swift
//  Simple
//
//  Created by Mateusz Malczak on 16/04/16.
//  Copyright © 2016 ThePirateCat. All rights reserved.
//

import Silicon

enum Services: String, Silicon.Services {
    
    case LOG = "si:log"
    
    case CONSOLE = "si:console"
    
    case NUMBER = "si:number"
    
    
    case OBJ_1 = "obj1"
    
    case OBJ_2 = "obj2"
    
    case OBJ_3 = "obj3"
    
    case OBJ_4 = "obj4"
    
    
    func name() -> String {
        return rawValue;
    }
    
}
