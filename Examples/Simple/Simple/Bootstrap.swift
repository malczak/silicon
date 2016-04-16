//
//  Bootstrap.swift
//  Simple
//
//  Created by Mateusz Malczak on 02/03/16.
//  Copyright © 2016 ThePirateCat. All rights reserved.
//

import Foundation
import Silicon

class Holder {
  var value:Int
  init(widthValue value:Int) {
    self.value = value
  }
  deinit {
    print("Removed Holder")
  }
}

class Text {
  let value = "SUPER"
  deinit {
    print("KILLED")
  }
}

class Bootstrap {
  
  class func setup() {
    let silicon = Silicon.sharedInstance;
    let t = Text()
    
    silicon.set(Services.CONSOLE) { si in
      let consoleBlock = { (info: String) in
        NSLog(info)
      }
      return consoleBlock
    }
    
    let h = Holder(widthValue: 5)
    silicon.set(Services.NUMBER, shared: true, count: 4, instance: h);
    
    silicon.set(Services.LOG) { [t] si in
      NSLog(t.value)
      let console = si.get(Services.CONSOLE) as? ((String) -> Void)
      var cnt = 0
      while let i = si.get(Services.NUMBER) as? Holder {
        console?("Index \(cnt) value \(i.value)")
        i.value -= 2;
        cnt += 1
      }
      return console
    }
    
  }
  
}

extension NSObject {
  
  public func log(text: String)
  {
    if let log = Silicon.get(Services.LOG) as? ((String) -> Void) {
      log(text)
    }
  }
  
}