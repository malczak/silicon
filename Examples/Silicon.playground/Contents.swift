//: Playground - noun: a place where people can play

import Foundation
import UIKit

srand(0)

protocol TestProto {
  func name() -> String;
}

enum Services: String, TestProto {
  case Super = "Super";
  
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
s.set("Obj1", closure: { (si) in
    print("fetch 1")
    let o = Obj1()
    o.a = (si.resolve("Obj2")) as? Obj2
    return o
})

s.set("Obj2", closure: { (si) in
    print("fetch 2")
    let o = Obj2()
    o.b = (si.resolve("Obj3")) as? Obj3
    return o
});

s.set("Obj3", closure: { (si) in
    print("fetch 3")
    let o = Obj3()
    o.c =  (si.resolve("Obj1")) as? Obj1
    return o
});

Silicon.set("Obj4", shared:true, count: 2) { (si) in
    print("fetch 2")
    let o = Obj3()
    o.i = Int(rand())
    return o
};

let o = [
    s.get("Obj1"),
    s.get("Obj4"),
    s.get("Obj4"),
    s.get("Obj4"),
    s.get("services")
]

print("Done .... ")
for itm in o {
    print("\t \(itm) ~ \((itm != nil) ? Unmanaged<Obj>.passUnretained(itm as! Obj).toOpaque() : nil)")
}


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
