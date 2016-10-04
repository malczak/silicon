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
        
        case failedToCreateContext(service: String)
        
        case contextResolveError
    }
    
    internal class Context {
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
        
        func dispose() {
            higgs = nil
            queue.setSpecific(key: uid, value: nil);
            resolveTrace.removeAll()
        }
        
        deinit {
            syncedPrint("\t\t\t\t>>>> CONTEXT DEINIT")
        }
        
        class func queueName() -> String {
            return "cat.thepirate.silicon.higgs.context" + String(time(nil))
        }
    }
    
    internal class Higgs: Hashable {
        
        class Definition {
            
            var closure: (_ si: Silicon) -> Any?
            
            init(closure: @escaping (_ si: Silicon) -> Any? ) {
                self.closure = closure
            }
            
            func get(_ si: Silicon) -> Any? {
                return closure(si)
            }
            
            deinit {
                syncedPrint("\t\t\t\t>>>> DEFINITION DEINIT")
            }
        }
        
        class SingletonDefinition: Definition {

            weak var higgs: Higgs?

            var instance: Any? = nil

            var sema = DispatchSemaphore(value: 1)

            init(withHiggs higgs:Higgs, closure: @escaping (_ si: Silicon) -> Any? ) {
                self.higgs = higgs
                super.init(closure: closure)
            }
            
            override func get(_ si: Silicon) -> Any? {
                sema.wait(timeout: DispatchTime.distantFuture)
                if instance == nil {
                    instance = closure(si)
                    if let higgs = higgs {
                        higgs.instance = instance
                        higgs.definition = nil
                    }
                    higgs = nil
                }
                sema.signal()
                return instance
            }
            
            deinit {
                instance = nil
                higgs = nil
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
        
        var hashValue: Int {
            return name.hash
        }
        
        init (name: String, shared: Bool, count: Int) {
            self.name = name
            self.shared = shared
            self.count = count
        }
        
        convenience init(name: String, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) {
            self.init(name: name, shared: shared, count: count)
            self.definition = shared ? Definition(closure: closure) : SingletonDefinition(withHiggs: self, closure: closure)
        }
        
        convenience init(name: String, shared: Bool, count: Int, instance: Any) {
            self.init(name: name, shared: shared, count: count)
            self.instance = instance
        }
        
        deinit {
            definition = nil
            instance = nil
            syncedPrint("\t\t\t\t\t>>>> HIGGS DEINIT")
        }
        
        static func == (lhs: Higgs, rhs: Higgs) -> Bool {
            return lhs.name == rhs.name
        }
        
    }
    
    open static let sharedInstance = Silicon()
    
    open var errorBlock: ((Silicon.ResolveError) -> Void)? = nil
    
    private var services = [String:Higgs]()
    
    private var contexts = [Higgs:Context]()
    
    private let contextsQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.contexts", attributes: [])
    
    private let servicesQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.services", attributes: [])
    
    private let errorsQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.errors", attributes: [])
    
    final public func set(_ name: String, shared: Bool, count: Int, instance: Any) -> Void {
        self.add(Higgs: Higgs(name: name, shared: shared, count: count, instance: instance))
    }
    
    final public func set(_ name: String, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.add(Higgs: Higgs(name: name, shared: shared, count: count, closure: closure))
    }
    
    final public func get(_ name: String) -> Any? {
        return resolve(name);
    }

    final public func resolve(_ name: String) -> Any? {
        guard let higgs = self.get(HiggsName: name) else {
            handle(Error: .serviceNotFound(service: name))
            return nil;
        }
        
        syncedPrint("\nResolving \(name)")
        
        // Already resolved? use it!
        if higgs.resolved {
            return use(Higgs: higgs)
        }
        
        syncedPrint("\tMissing")
        
        var object: Any? = nil
        
        // Handle service dependencies (Step#2)
        // All nested resolve(_:) calls are handled on private queue.
        // When method is called on private queue get context 
        // If context is found method call was done on private queue 
        // as a result of method call in Step#1
        let key = Context.ContextKey
        if let queue_data = DispatchQueue.getSpecific(key: key) {
            if queue_data != nil {
                if let unsafeData = queue_data {
                    let ctx = Unmanaged<Silicon.Context>.fromOpaque(unsafeData).takeUnretainedValue()
                    return self.resolve(Higgs: higgs, onContext: ctx)
                }
            }
        }
        
        // new resolver
        var ctx: Context? = nil
        
        if higgs.shared {
            // sync contexts
            
        } else {
            // run on cotext
        }
        
//        servicesQueue.sync { [unowned self] in
//            ctx = self.contexts[higgs]
//        }
//        
//        if let context = ctx {
//            context.group.wait(timeout: DispatchTime.distantFuture)
        // if resolved ? (should be always resolved!)
//            return context.higgs?.instance
//        }
//        
        if ctx == nil {
            ctx = Context(withHiggs: higgs)
//            servicesQueue.sync { [unowned self] in
//                self.contexts[higgs] = ctx
//            }
        }

        var error: ResolveError? = nil
        
        if let context = ctx {
            // Service instance resolution (Step#1)
            // Service instances are resolved if not yet resolved 
            // (or service is shared) service. Create a context
            // and run all resolving on a separation private queue identified by specific key
            context.group.enter()
            context.queue.async(execute: { [unowned silicon = self] in
                if let higgs = context.higgs {
                    object = silicon.resolve(Higgs: higgs, onContext: context)
                } else {
                    context.error = .contextResolveError
                }
                context.group.leave()
                })
            context.group.wait(timeout: DispatchTime.distantFuture)
            context.dispose()
            
            error = context.error
        } else {
            error = .failedToCreateContext(service: higgs.name)
        }
        
        if let error = error {
            self.handle(Error: error)
            return nil
        }
        
        syncedPrint("\t<- \(object)")
        return object
    }
    
    fileprivate func resolve(Higgs higgs: Higgs, onContext context: Context) -> Any? {
        var instance = higgs.instance
        
        if instance == nil {
            // Don't resolve on poluted stack
            if context.error != nil {
                return nil
            }
            
            if context.contains(higgs.name) {
                // Circular serivces dependency.
                // Further resolution will result in dead lock
                // on context queue.
                syncedPrint("Circularity!!!");
                context.error = .circularDependency(service: context.higgs?.name, resolvingTree: context.resolveTrace)
                return nil;
            }
            context.insert(higgs.name)
            
            if let definition = higgs.definition {
                // Fetch service instance from definition. For non-shared services
                // definition closure call is synchronized. In other
                // services closure is called on context queue
                instance = definition.get(self)
                if instance == nil {
                    context.error = .missingInstance(service: higgs.name)
                }
            } else {
                context.error = .missingDefinition(service: context.higgs?.name)
            }
        }
        
        return use(Higgs: higgs)
    }
    
    fileprivate func use(Higgs higgs: Higgs) -> Any? {
        let instance = higgs.instance
        update(Higgs: higgs)
        return instance
    }
    
    fileprivate func update(Higgs higgs: Higgs) {
        // MARK: non thread safe
        if higgs.count > 0 {
            higgs.count -= 1
        }
        
        syncedPrint("count \(higgs.count)")
        
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
                syncedPrint("Error \(error)");
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

// MARK: Service management by name

extension Silicon {
    
    class final public func set(_ name: String, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(name, shared: false, closure: closure);
    }
    
    class final public func set(_ name: String, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(name, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    class final public func set(_ name: String, instance: Any) -> Void {
        Silicon.set(name, shared: false, instance: instance);
    }
    
    class final public func set(_ name: String, shared: Bool, instance: Any) -> Void {
        Silicon.set(name, shared: shared, count: Higgs.INF, instance: instance)
    }
    
    class final public func set(_ name: String, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.sharedInstance.set(name, shared: shared, count: count, closure: closure)
    }
    
    class final public func set(_ name: String, shared: Bool, count: Int, instance: Any) -> Void {
        Silicon.sharedInstance.set(name, shared: shared, count: count, instance: instance)
    }
    
    class open func get(_ name: String) -> Any? {
        return Silicon.sharedInstance.get(name)
    }
    
    class open func resolve(_ name: String) -> Any? {
        return Silicon.sharedInstance.resolve(name)
    }
    
    final public func set(_ name: String, closure:@escaping (_ si: Silicon) -> Any?) -> Void {
        self.set(name, shared: false, closure: closure);
    }
    
    final public func set(_ name: String, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.set(name, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    final public func set(_ name: String, instance: Any) -> Void {
        self.set(name, shared: false, instance: instance);
    }
    
    final public func set(_ name: String, shared: Bool, instance: Any) -> Void {
        self.set(name, shared: shared, count: Higgs.INF, instance: instance)
    }
}

// MARK: Service management by SiService protocol

extension Silicon {
    
    class final public func set(_ service: SiService, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(service, shared: false, closure: closure);
    }
    
    class final public func set(_ service: SiService, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(service, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    class final public func set(_ service: SiService, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        Silicon.set(service.name(), shared: shared, count: count, closure: closure)
    }
    
    class final public func set(_ service: SiService, instance: Any) -> Void {
        Silicon.set(service, shared: false, instance: instance);
    }
    
    class final public func set(_ service: SiService, shared: Bool, instance: Any) -> Void {
        Silicon.set(service, shared: shared, count: Higgs.INF, instance: instance)
    }
    
    class final public func set(_ service: SiService, shared: Bool, count: Int, instance: Any) -> Void {
        Silicon.set(service.name(), shared: shared, count: count, instance: instance)
    }
    
    final public func set(_ service: SiService, closure:@escaping (_ si: Silicon) -> Any?) -> Void {
        self.set(service, shared: false, closure: closure);
    }
    
    final public func set(_ service: SiService, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.set(service, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    final public func set(_ service: SiService, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Void {
        self.set(service.name(), shared:  shared, count:  count, closure: closure);
    }
    
    final public func set(_ service: SiService, instance: Any) -> Void {
        self.set(service, shared: false, instance: instance);
    }
    
    final public func set(_ service: SiService, shared: Bool, instance: Any) -> Void {
        self.set(service, shared: shared, count: Higgs.INF, instance: instance)
    }
    
    final public func set(_ service: SiService, shared: Bool, count: Int, instance: Any) -> Void {
        self.set(service.name(), shared: shared, count: count, instance: instance);
    }
    
    class final public func get(_ service: SiService) -> Any? {
        return Silicon.sharedInstance.get(service)
    }
    
    class final public func resolve(_ service: SiService) -> Any? {
        return Silicon.sharedInstance.resolve(service)
    }
    
    final public func get(_ service: SiService) -> Any? {
        return get(service.name())
    }
    
    final public func resolve(_ service: SiService) -> Any? {
        return resolve(service.name())
    }
    
}

func syncedPrint(_ items: Any...) {
    DispatchQueue.main.async {
        print(items)
    }
}
