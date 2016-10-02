/*
 The MIT License (MIT)
 Copyright (c) 2016, Mateusz Malczak
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the Software
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
 OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/* http://github.com/malczak/silicon */

import Foundation
import Dispatch

public protocol SiInjectable {
    
}

public protocol SiService {
    func name() -> String
}

public protocol Si {
}

open class Silicon {
    
    public typealias Services = SiService;
    
    public enum ResolveError: Error {
        case serviceAlreadyExists(service: String)
        
        case circularDependency(service: String?, resolvingTree:Set<String>)
        
        case missingDefinition(service: String?)
        
        case serviceNotFound(service: String)
        
        case missingInstance(service: String)
    }
    
    class Context {
        static let ContextKey = DispatchSpecificKey<UnsafeMutableRawPointer?>()
        
        weak var higgs:Higgs?
        
        let group: DispatchGroup = DispatchGroup()
        
        let queue: DispatchQueue
        
        var error: ResolveError? = nil
        
        var resolveTrace = Set<String>()
        
        lazy var uid: DispatchSpecificKey<UnsafeMutableRawPointer?> = {
            return ContextKey
        }()
        
        init(withHiggs: Higgs) {
            higgs = withHiggs
            queue = DispatchQueue(label: Context.queueName(), attributes: []);
            let selfPtr = Unmanaged<Silicon.Context>.passUnretained(self).toOpaque()
            let queueKey = UnsafeMutableRawPointer(selfPtr)
            queue.setSpecific(key: uid, value: queueKey);
        }
        
        func contains(_ name: String) -> Bool {
            return resolveTrace.contains(name)
        }
        
        func insert(_ name: String) {
            resolveTrace.insert(name);
        }
        
        func wait() {
            group.wait(timeout: DispatchTime.distantFuture)
            queue.setSpecific(key: uid, value: nil);
            resolveTrace.removeAll()
        }
        
        deinit {
            print("\t\t\t\t>>>> CONTEXT DEINIT")
        }
        
        class func queueName() -> String {
            return "cat.thepirate.silicon.higgs.context" + String(time(nil))
        }
    }
    
    class Higgs {
        
        class Definition {
            fileprivate var instance: Any? = nil
            
            fileprivate var closure: (_ si: Silicon) -> Any?
            
            fileprivate var sema = DispatchSemaphore(value: 1)
            
            
            init(_ closure: @escaping (_ si: Silicon) -> Any? ) {
                self.closure = closure
            }
            
            func get(_ si: Silicon) -> Any? {
                sema.wait(timeout: DispatchTime.distantFuture)
                if instance == nil {
                    instance = closure(si)
                }
                sema.signal()
                return instance
            }
            
            deinit {
                print("\t\t\t\t>>>> DEFINITION DEINIT")
            }
            
        }
        
        
        static let INF = -1
        
        var name: String
        
        var instance: Any? = nil
        
        var definition: Definition? = nil
        
        var shared: Bool = true
        
        var count: Int = INF
        
        var resolved: Bool {
            return instance != nil
        }
        
        init (name: String, shared: Bool, count: Int) {
            self.name = name
            self.shared = shared
            self.count = count
        }
        
        convenience init(name: String, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) {
            self.init(name: name, shared: shared, count: count)
            self.definition = Definition(closure)
        }
        
        convenience init(name: String, shared: Bool, count: Int, instance: Any) {
            self.init(name: name, shared: shared, count: count)
            self.instance = instance
        }
        
        deinit {
            definition = nil
            instance = nil
            print("\t\t\t\t\t>>>> HIGGS DEINIT")
        }
        
    }
    
    open static let sharedInstance = Silicon()
    
    open var errorBlock: ((Silicon.ResolveError) -> Void)? = nil
    
    var services: [String:Higgs] = [String:Higgs]()
    
    let servicesQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.services", attributes: [])
    
    let errorsQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.errors", attributes: [])
    
    fileprivate init() {
        services = [String:Higgs]()
    }
    
    
    // MARK: Static versions
    
    class open func set(_ name: String, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(name, shared: false, closure: closure);
    }
    
    class open func set(_ name: String, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(name, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    class open func set(_ name: String, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.sharedInstance.set(name, shared: shared, count: count, closure: closure)
    }
    
    class open func set(_ name: String, instance: Any) -> Void {
        Silicon.set(name, shared: false, instance: instance);
    }
    
    class open func set(_ name: String, shared: Bool, instance: Any) -> Void {
        Silicon.set(name, shared: shared, count: Higgs.INF, instance: instance)
    }
    
    class open func set(_ name: String, shared: Bool, count: Int, instance: Any) -> Void {
        Silicon.sharedInstance.set(name, shared: shared, count: count, instance: instance)
    }
    
    // MARK: resolve higgs object
    
    class open func get(_ name: String) -> Any? {
        return Silicon.sharedInstance.get(name)
    }
    
    class open func resolve(_ name: String) -> Any? {
        return Silicon.sharedInstance.resolve(name)
    }
    
    // MARK: Instance Create block definition based higgs
    
    open func set(_ name: String, closure:@escaping (_ si: Silicon) -> Any?) -> Void {
        self.set(name, shared: false, closure: closure);
    }
    
    open func set(_ name: String, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.set(name, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    open func set(_ name: String, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.add(Higgs: Higgs(name: name, shared: shared, count: count, closure: closure))
    }
    
    // MARK: Create instance based higgs
    
    open func set(_ name: String, instance: Any) -> Void {
        self.set(name, shared: false, instance: instance);
    }
    
    open func set(_ name: String, shared: Bool, instance: Any) -> Void {
        self.set(name, shared: shared, count: Higgs.INF, instance: instance)
    }
    
    open func set(_ name: String, shared: Bool, count: Int, instance: Any) -> Void {
        self.add(Higgs: Higgs(name: name, shared: shared, count: count, instance: instance))
    }
    
    // MARK: resolve higgs object
    
    open func get(_ name: String) -> Any? {
        return resolve(name);
    }
    
    open func resolve(_ name: String) -> Any? {
        guard let higgs = self.get(HiggsName: name) else {
            handle(Error: .serviceNotFound(service: name))
            return nil;
        }
        
        print("\nResolving \(name)")
        
        if higgs.resolved {
            self.update(Higgs: higgs)
            return higgs.instance
        }
        
        print("\tMissing")
        
        var object: Any? = nil
        
        let key = Context.ContextKey
        // MARK: Check if method called on private queue
        // --
        // Using static key allows us to test if we are running on private queue -
        // if we are, then we are using queue context to run all service resolving 
        // on that private queue
        if let queue_data = DispatchQueue.getSpecific(key: key) {
            if queue_data != nil {
                if let unsafeData = queue_data {
                    let ctx = Unmanaged<Silicon.Context>.fromOpaque(unsafeData).takeUnretainedValue()
                    return self.resolve(Higgs: higgs, onContext: ctx)
                }
            }
        }
        
        // new resolver
        // MARK: non thread safe - shouldnt be run once per service ?
        let ctx = Context(withHiggs: higgs)
        
        ctx.group.enter()
        ctx.queue.async(execute: { [unowned silicon = self, unowned higgs, unowned ctx, unowned group = ctx.group] in
            object = silicon.resolve(Higgs: higgs, onContext: ctx)
            group.leave()
            })
        
        ctx.wait()
        
        if let error = ctx.error {
            self.handle(Error: error)
            return nil
        }
        
        print("\t<- \(object)")
        return object
    }
    
    fileprivate func resolve(Higgs higgs: Higgs, onContext context: Context) -> Any? {
        var instance = higgs.instance
        
        if instance == nil {
            
            // MARK: dont resolve on poluted stack
            if context.error != nil {
                return nil
            }
            
            if context.contains(higgs.name) {
                print("Circularity!!!");
                context.error = .circularDependency(service: context.higgs?.name, resolvingTree: context.resolveTrace)
                return nil;
            }
            context.insert(higgs.name)
            
            if let definition = higgs.definition {
                if higgs.shared {
                    instance = definition.get(self)
                    if instance == nil {
                        context.error = .missingInstance(service: higgs.name)
                    }
                    higgs.instance = instance
                    higgs.definition = nil
                } else {
                    instance = definition.closure(self)
                }
            } else {
                context.error = .missingDefinition(service: context.higgs?.name)
            }
        }
        
        self.update(Higgs: higgs)
        
        return instance
    }
    
    fileprivate func update(Higgs higgs: Higgs) {
        // MARK: non thread safe
        if higgs.count > 0 {
            higgs.count -= 1
        }
        
        print("count \(higgs.count)")
        
        if higgs.count == 0 {
            self.remove(Higgs: higgs)
        }
    }
    
    fileprivate func add(Higgs higgs: Higgs) -> Bool {
        var exists = false
        servicesQueue.sync(flags: .barrier, execute: { [unowned self] in
            exists = (self.services[higgs.name] != nil)
            if !exists {
                self.services[higgs.name] = higgs;
            } else {
                self.handle(Error: .serviceAlreadyExists(service: higgs.name))
            }
            })
        return !exists;
    }
    
    fileprivate func get(HiggsName name: String) -> Higgs? {
        var higgs:Higgs? = nil
        servicesQueue.sync(flags: .barrier, execute: { [unowned self] in
            higgs = self.services[name]
            })
        return higgs
    }
    
    fileprivate func remove(Higgs higgs: Higgs) {
        servicesQueue.async(flags: .barrier, execute: { [unowned self] in
            self.services.removeValue(forKey: higgs.name)
            })
    }
    
    fileprivate func handle(Error error: Silicon.ResolveError) {
        if let _block = self.errorBlock {
            errorsQueue.async(execute: {
                _block(error)
            })
        } else {
            #if DEBUG
                print("Error \(error)");
            #endif
        }
    }
}

// MARK: Protocol for accessing Silicon in custom classes

extension Si where Self: AnyObject {
    func silicon() -> Silicon {
        return Silicon.sharedInstance
    }
    
    func inject(_ service: SiService) -> Any? {
        return silicon().get(service)
    }
}


// MARK: Service management using SiService protocol

extension Silicon {
    
    class public func set(_ service: SiService, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(service, shared: false, closure: closure);
    }
    
    class public func set(_ service: SiService, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(service, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    class public func set(_ service: SiService, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(service.name(), shared: shared, count: count, closure: closure)
    }
    
    class public func set(_ service: SiService, instance: Any) -> Void {
        Silicon.set(service, shared: false, instance: instance);
    }
    
    class public func set(_ service: SiService, shared: Bool, instance: Any) -> Void {
        Silicon.set(service, shared: shared, count: Higgs.INF, instance: instance)
    }
    
    class public func set(_ service: SiService, shared: Bool, count: Int, instance: Any) -> Void {
        Silicon.set(service.name(), shared: shared, count: count, instance: instance)
    }
    
    public func set(_ service: SiService, closure:@escaping (_ si: Silicon) -> Any?) -> Void {
        self.set(service, shared: false, closure: closure);
    }
    
    public func set(_ service: SiService, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.set(service, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    public func set(_ service: SiService, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.set(service.name(), shared:  shared, count:  count, closure: closure);
    }
    
    public func set(_ service: SiService, instance: Any) -> Void {
        self.set(service, shared: false, instance: instance);
    }
    
    public func set(_ service: SiService, shared: Bool, instance: Any) -> Void {
        self.set(service, shared: shared, count: Higgs.INF, instance: instance)
    }
    
    public func set(_ service: SiService, shared: Bool, count: Int, instance: Any) -> Void {
        self.set(service.name(), shared: shared, count: count, instance: instance);
    }
    
    class public func get(_ service: SiService) -> Any? {
        return Silicon.sharedInstance.get(service)
    }
    
    class public func resolve(_ service: SiService) -> Any? {
        return Silicon.sharedInstance.resolve(service)
    }
    
    public func get(_ service: SiService) -> Any? {
        return get(service.name())
    }
    
    public func resolve(_ service: SiService) -> Any? {
        return resolve(service.name())
    }
    
}
