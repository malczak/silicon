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
  
  func name() -> String {
    return rawValue;
  }
  
}