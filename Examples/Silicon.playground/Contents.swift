//: Playground - noun: a place where people can play

import Foundation
import UIKit

srand(0)

enum Services: String, Silicon.Services {
  
  case OBJ_1 = "obj1"
  
  case OBJ_2 = "obj2"
  
  case OBJ_3 = "obj3"

  case OBJ_4 = "obj4"
  
  func name() -> String {
    return rawValue;
  }
}

class Obj {
    
}

class Obj1: Obj {
    var a: Obj2?
}

class Obj2: Obj {
    var b: Obj3?
}

class Obj3: Obj {
    var i: Int = 1
    var c: Obj1?
}


Silicon.sharedInstance.errorBlock = { error in
    print("WOW! AN ERROR - \(error)")
}


var s = Silicon.sharedInstance
s.set(Services.OBJ_1, closure: { (si) in
    print("fetch 1")
    let o = Obj1()
    o.a = (si.resolve(Services.OBJ_2)) as? Obj2
    return o
})

s.set(Services.OBJ_2, closure: { (si) in
    print("fetch 2")
    let o = Obj2()
    o.b = (si.resolve(Services.OBJ_3)) as? Obj3
    return o
});

s.set(Services.OBJ_3) { (si) in
    print("fetch 3")
    let o = Obj3()
    o.c =  (si.resolve(Services.OBJ_1)) as? Obj1
    return o
};

Silicon.set(Services.OBJ_4, shared:true, count: 2) { (si) in
    print("fetch 2")
    let o = Obj3()
    o.i = Int(rand())
    return o
};

let o = [
    s.get(Services.OBJ_1),
    s.get(Services.OBJ_2),
    s.get(Services.OBJ_3),
    s.get(Services.OBJ_4),
    s.get("services")
]

func ptr(itm:Any?) -> COpaquePointer {
  if let obj = itm as? AnyObject {
    return Unmanaged<AnyObject>.passUnretained(obj).toOpaque()
  }
  return nil
}

print("Done .... ")
for itm in o {
    print("\t \(itm) ~ \(ptr(itm))")
}

print("Last service? \(Services.OBJ_4.name()) : \(ptr(s.get(Services.OBJ_4)))")
print("Last service? \(Services.OBJ_4.name()) : \(ptr(s.get(Services.OBJ_4)))")
print("Last service? \(Services.OBJ_4.name()) : \(ptr(s.get(Services.OBJ_4)))")

/*
class PriorityQueue<T> {
    
}


class Event {
    
}

class EventDispatcher {
    
    class Listener {
        var type: String;
        
        unowned var handler: (Event) -> Void
        
        init(type: String, handler: (Event) -> Void) {
            self.type = type;
            self.handler = handler;
        }

    }
    
    private var _dispatch_queue = dispatch_queue_create("cat.thepirate.", DISPATCH_QUEUE_SERIAL);
    
    private var _listeners = [String:Listener]
    
    func dispatch(event: Event, async: Bool) {
        
    }
    
    func dispatch(event: Event) {
        self.dispatch(event, async: false)
    }
    
}
 */
