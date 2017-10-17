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

internal protocol Definition {
    func get(_ si: Silicon) -> Any?
}

open class Silicon {
    public class Bag {
        private class BagData {
            var storage = [String:Any]()
            
            public subscript(name: String) -> Any? {
                get {
                    return storage[name]
                }
                set(newValue) {
                    if newValue != nil {
                        storage[name] = newValue
                    } else {
                        storage.removeValue(forKey: name)
                    }
                }
            }

            deinit {
                storage.removeAll()
            }
        }
        
        private var id: String? = nil
        
        private weak var data: BagData? = nil
        
        public init(_ id: String) {
            let id = "cat.thepirate.silicon.bag.\(id)"

            let si = Silicon.shared
            var bagData: BagData? = nil
            if let existingData = si.get(id) as? BagData{
                bagData = existingData
            } else {
                bagData = BagData()
                si.set(id, instance: bagData!)
                self.id = id
            }
            data = bagData
        }
        
        public subscript(name: String) -> Any? {
            get {
                return data?[name]
            }
            set(newValue) {
                data?[name] = newValue
            }
        }
        
        deinit {
            if let id = id {
                Silicon.shared.remove(id)
            }
        }
    }
    
    public typealias Services = SiService;
    
    public enum ResolveError: Error {
        case serviceAlreadyExists(service: String)
        
        case circularDependency(service: String?, resolvingTree:Set<String>)
        
        case missingDefinition(service: String?)
        
        case serviceNotFound(service: String)
        
        case missingInstance(service: String)
        
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
            return Context.ContextKey
        }()
        
        init(withHiggs: Higgs) {
            higgs = withHiggs
            queue = DispatchQueue(label: Context.queueName(), qos: DispatchQoS.userInteractive)
            let selfPtr = Unmanaged<Silicon.Context>.passUnretained(self).toOpaque()
            let queueKey = UnsafeMutableRawPointer(selfPtr)
            queue.setSpecific(key: uid, value: queueKey)
            SiLog("> init `\(higgs?.name ?? "(undef)")` context")
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
            SiLog("< deinit `\(higgs?.name ?? "(undef)")` context")
        }
        
        class func queueName() -> String {
            return "cat.thepirate.silicon.higgs.context" + String(time(nil))
        }
    }
    
    internal class Higgs: Hashable {
        
        class ReusableDefinition: Definition {
            
            var closure: (_ si: Silicon) -> Any?
            
            init(closure: @escaping (_ si: Silicon) -> Any? ) {
                self.closure = closure
            }
            
            func wired() {
                
            }
            
            func get(_ si: Silicon) -> Any? {
                return closure(si)
            }
            
            deinit {
                SiLog("< deinit definition")
            }
        }
        
        class SingletonDefinition: ReusableDefinition {

            weak var higgs: Higgs?

            var instance: Any? = nil

            var sema = DispatchSemaphore(value: 1)

            init(withHiggs higgs:Higgs, closure: @escaping (_ si: Silicon) -> Any? ) {
                self.higgs = higgs
                super.init(closure: closure)
            }
            
            override func get(_ si: Silicon) -> Any? {
                _ = sema.wait(timeout: DispatchTime.distantFuture)
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
            self.definition = shared ? SingletonDefinition(withHiggs: self, closure: closure) : ReusableDefinition(closure: closure)
        }
        
        convenience init(name: String, shared: Bool, count: Int, instance: Any) {
            self.init(name: name, shared: shared, count: count)
            self.instance = instance
        }
        
        deinit {
            definition = nil
            instance = nil
            SiLog("< deinit higgs")
        }
        
        static func == (lhs: Higgs, rhs: Higgs) -> Bool {
            return lhs.name == rhs.name
        }
        
    }
    
    open static let shared = Silicon()
    
    open var errorBlock: ((Silicon.ResolveError) -> Void)? = nil
    
    private var services = [String:Higgs]()
    
    private var contexts = [Higgs:Context]()
    
    private let contextsQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.contexts")
    
    private let servicesQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.services", attributes: [DispatchQueue.Attributes.concurrent])
    
    private let errorsQueue: DispatchQueue = DispatchQueue(label: "cat.thepirate.silicon.errors", attributes: [DispatchQueue.Attributes.concurrent])
    
    @discardableResult
    final public func set(_ name: String, shared: Bool = true, count: Int, instance: Any, initializer: ((_: Any) -> ())? = nil) -> Bool {
        return self.add(Higgs: Higgs(name: name, shared: shared, count: count, instance: instance))
    }
    
    @discardableResult
    final public func set(_ name: String, shared: Bool, count: Int, closure: @escaping (_: Silicon) -> Any?) -> Bool {
        return self.add(Higgs: Higgs(name: name, shared: shared, count: count, closure: closure))
    }
    
    @discardableResult
    final public func remove(_ name: String) -> Bool {
        guard let higgs = get(HiggsName: name) else {
            return false
        }
        remove(Higgs: higgs)
        return true
    }
    
    final public func get(_ name: String) -> Any? {
        return resolve(name);
    }

    final public func resolve(_ name: String) -> Any? {
        guard let higgs = self.get(HiggsName: name) else {
            handle(Error: .serviceNotFound(service: name))
            return nil;
        }
        
        SiLog("~ resolving `\(name)` service")
        
        // Already resolved? use it!
        if higgs.resolved {
            return use(Higgs: higgs)
        }
        
        SiLog("~ missing `\(name) service")
        
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
        
        var ctx: Context? = nil
        var activeContext: Context? = nil
        
        if higgs.shared {
            // Shared services are resolved on private synchronized queue
            contextsQueue.sync { [unowned self] in
                activeContext = self.contexts[higgs]
                if activeContext == nil {
                    ctx = Context(withHiggs: higgs)
                    self.contexts[higgs] = ctx!
                }
            }

        } else {
            ctx = Context(withHiggs: higgs)
        }
        
        var error: ResolveError? = nil
        var object: Any? = nil
        
        if let context = ctx {
            // Service instance resolution (Step#1)
            // Service instances are resolved if not yet resolved
            // (or service is shared) service. Create a context
            // and run all resolving on a separation private queue identified by specific key
            //
            // We are not using `queue.async(group: ..., execute:...)` as this can result in
            // `wait` being signaled to early
            context.group.enter()
            context.queue.async(execute: { [unowned silicon = self] in
                if let higgs = context.higgs {
                    object = silicon.resolve(Higgs: higgs, onContext: context)
                } else {
                    context.error = .contextResolveError
                }
                context.group.leave()
                })
            _ = context.group.wait(timeout: DispatchTime.distantFuture)
            SiLog("~ primary synced")
            _ = contextsQueue.sync { [unowned self] in
                self.contexts.removeValue(forKey: higgs)
            }
            context.dispose()
            error = context.error
        } else
            if let context = activeContext {
                // Service is already being resolved (Step#3)
                // wait on its queue to get instance
                // --
                // @check: Is it possible to signal `wait` in Step#1
                // before we block a group again
                context.group.enter()
                context.queue.sync { [unowned self, unowned context] in
                    SiLog("~ secondary synced")
                    object = self.use(Higgs: higgs)
                    context.group.leave()
                }
                error = context.error
            } else {
                error = ResolveError.contextResolveError
        }
        
        if let error = error {
            self.handle(Error: error)
            return nil
        }
        
        SiLog("<- resolved `\(object ?? "null")`")
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
                SiLog("~ circular dependency");
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
        
        return use(Higgs: higgs) ?? instance
    }
    
    fileprivate func use(Higgs higgs: Higgs) -> Any? {
        var instance:Any? = nil
        if higgs.count != 0 {
            instance = higgs.instance
            update(Higgs: higgs)
        }
        return instance
    }
    
    fileprivate func update(Higgs higgs: Higgs) {
        servicesQueue.sync(flags: .barrier, execute: { [unowned self] in
            if higgs.count > 0 {
                higgs.count -= 1
            }
            
            if higgs.count == 0 {
                self.remove(Higgs: higgs)
            }
        })
    }
    
    fileprivate func add(Higgs higgs: Higgs) -> Bool {
        var exists = false
        servicesQueue.sync(flags: .barrier, execute: { [unowned self] in
            exists = (self.services[higgs.name] != nil)
            if !exists {
                self.services[higgs.name] = higgs
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
                SiLog("Internal error \(error)");
            #endif
        }
    }
}

// MARK: Protocol for accessing Silicon in custom classes

extension Si where Self: AnyObject {
    func silicon() -> Silicon {
        return Silicon.shared
    }
    
    func inject(_ service: SiService) -> Any? {
        return silicon().get(service)
    }
    
    func inject<T>(_ service: SiService) -> T? {
        return silicon().get(service)
    }
}

// MARK: Service management by name

extension Silicon {
    
    @discardableResult
    class final public func set(_ name: String, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return Silicon.set(name, shared: false, closure: closure);
    }
    
    @discardableResult
    class final public func set(_ name: String, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return Silicon.set(name, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    @discardableResult
    class final public func set(_ name: String, instance: Any) -> Bool {
        return Silicon.set(name, count: Higgs.INF, instance: instance)
    }
    
    @discardableResult
    class final public func set(_ name: String, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return Silicon.shared.set(name, shared: shared, count: count, closure: closure)
    }
    
    @discardableResult
    class final public func set(_ name: String, count: Int, instance: Any) -> Bool {
        return Silicon.shared.set(name, shared: true, count: count, instance: instance)
    }
    
    class open func get(_ name: String) -> Any? {
        return Silicon.shared.get(name)
    }
    
    class open func resolve(_ name: String) -> Any? {
        return Silicon.shared.resolve(name)
    }
        
    @discardableResult
    final public func set(_ name: String, closure:@escaping (_ si: Silicon) -> Any?) -> Bool {
        return self.set(name, shared: false, closure: closure);
    }
    
    @discardableResult
    final public func set(_ name: String, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return self.set(name, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    @discardableResult
    final public func set(_ name: String, instance: Any) -> Bool {
        return self.set(name, count: Higgs.INF, instance: instance)
    }
}

// MARK: Service management by SiService protocol

extension Silicon {
    
    @discardableResult
    class final public func set(_ service: SiService, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return Silicon.set(service, shared: false, closure: closure);
    }
    
    @discardableResult
    class final public func set(_ service: SiService, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return Silicon.set(service, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    @discardableResult
    class final public func set(_ service: SiService, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return Silicon.set(service.name(), shared: shared, count: count, closure: closure)
    }
    
    @discardableResult
    class final public func set(_ service: SiService, instance: Any) -> Bool {
        return Silicon.shared.set(service.name(), shared: true, count: Higgs.INF, instance: instance)
    }
    
    @discardableResult
    class final public func set(_ service: SiService, count: Int, instance: Any) -> Bool {
        return Silicon.shared.set(service.name(), shared: true, count: count, instance: instance)
    }
    
    @discardableResult
    final public func set(_ service: SiService, closure:@escaping (_ si: Silicon) -> Any?) -> Bool {
        return self.set(service, shared: false, closure: closure);
    }
    
    @discardableResult
    final public func set(_ service: SiService, shared: Bool, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return self.set(service, shared: shared, count: Higgs.INF, closure: closure)
    }
    
    @discardableResult
    final public func set(_ service: SiService, shared: Bool, count: Int, closure: @escaping (_ si:Silicon) -> Any?) -> Bool {
        return self.set(service.name(), shared:  shared, count:  count, closure: closure);
    }
    
    @discardableResult
    final public func set(_ service: SiService, instance: Any) -> Bool {
        return self.set(service, count: Higgs.INF, instance: instance)
    }
    
    @discardableResult
    final public func set(_ service: SiService, count: Int, instance: Any) -> Bool {
        return self.set(service.name(), shared: true, count: count, instance: instance);
    }
    
    @discardableResult
    final public func remove(_ service: SiService) -> Bool {
        return self.remove(service.name())
    }

    class final public func get<T>(_ service: SiService) -> T? {
        return get(service.name()) as? T
    }
    
    class final public func get(_ service: SiService) -> Any? {
        return Silicon.shared.get(service)
    }
    
    class final public func resolve(_ service: SiService) -> Any? {
        return Silicon.shared.resolve(service)
    }
    
    final public func get(_ service: SiService) -> Any? {
        return get(service.name())
    }
    
    final public func resolve(_ service: SiService) -> Any? {
        return resolve(service.name())
    }
    
    final public func get<T>(_ service: SiService) -> T? {
        return get(service.name()) as? T
    }
    
    final public func resolve<T>(_ service: SiService) -> T? {
        return resolve(service.name()) as? T
    }
}

public func inject<T>(_ service: SiService) -> T? {
    return Silicon.shared.get(service)
}

precedencegroup Inject {
    associativity: right
}

infix operator <~ : Inject

public func <~<T>(lhs: inout T?, rhs: SiService) {
    lhs = Silicon.shared.get(rhs)
}

#if DEBUG
    func SiLogPrint(_ message: String) {
        print(message)
    }
    public var SiliconLogger: ((_: String) -> ())? = nil
#else
    public var SiliconLogger: ((_: String) -> ())? = nil
    
#endif

func SiLog(_ message: String) {
    if let logger = SiliconLogger {
        DispatchQueue.main.async {
            logger("[Silicon] \(message)")
        }
    }
}
