//
//  ViewController.swift
//  Simple
//
//  Created by Mateusz Malczak on 02/03/16.
//  Copyright © 2016 ThePirateCat. All rights reserved.
//

import UIKit
import Silicon


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



class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
    
        var s = Silicon.sharedInstance
        s.set(Services.OBJ_1, closure: { (si) in
            print("fetch 1")
            let o = Obj1()
            o.a = (si.resolve(Services.OBJ_2)) as? Obj2
            return o
        })
        
        s.set(Services.OBJ_2, shared: true, closure: { (si) in
            print("fetch 2")
            let o = Obj2()
            for i in 0...30000 {
                DispatchQueue.main.sync{ print("Setting \(i)") }
            }
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
            o.i = Int(arc4random())
            return o
        };
        
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async{ print("q1") }
            s.get(Services.OBJ_1)
            DispatchQueue.main.async{ print("q1 -> DONE") }

        }
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async{ print("q2") }
            s.get(Services.OBJ_1)
            DispatchQueue.main.async{ print("q2 -> DONE") }
        }
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async{ print("q3") }
            s.get(Services.OBJ_1)
            DispatchQueue.main.async{ print("q3 -> DONE") }
        }
        
//        let o = [
//            s.get(Services.OBJ_1),
//            s.get(Services.OBJ_2),
//            s.get(Services.OBJ_3),
//            s.get(Services.OBJ_4),
//            s.get("services")
//        ]

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

