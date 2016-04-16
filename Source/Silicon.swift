import Foundation

public protocol SiInjectable {
  
}

public protocol SiService {
  func name() -> String
}

public class Silicon {
  
  public typealias Services = SiService;
  
  public enum Error: ErrorType {
    case ServiceAlreadyExists(service: String)
    
    case CircularDependency(service: String?, resolvingTree:Set<String>)
    
    case MissingDefinition(service: String?)
    
    case ServiceNotFound(service: String)
    
    case MissingInstance(service: String)
  }
  
  class Context {
    weak var higgs:Higgs?
    
    let group: dispatch_group_t = dispatch_group_create()
    
    let queue: dispatch_queue_t
    
    var error: Error? = nil
    
    var resolveTrace = Set<String>()
    
    var uid: UnsafePointer<Int8> {
      return dispatch_queue_get_label(queue)
    }
    
    init(withHiggs: Higgs) {
      higgs = withHiggs
      queue = dispatch_queue_create(Context.queueName(), DISPATCH_QUEUE_SERIAL);
      let selfPtr = Unmanaged<Silicon.Context>.passUnretained(self).toOpaque()
      let queueKey = UnsafeMutablePointer<Void>(selfPtr)
      dispatch_queue_set_specific(queue, uid, queueKey, nil);
    }
    
    func contains(name: String) -> Bool {
      return resolveTrace.contains(name)
    }
    
    func insert(name: String) {
      resolveTrace.insert(name);
    }
    
    func wait() {
      dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
      dispatch_queue_set_specific(queue, uid, nil, nil);
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
      private var closure: (si: Silicon) -> Any?
      
      private var predicate: dispatch_once_t = 0
      
      init(_ closure: (si: Silicon) -> Any? ) {
        self.closure = closure
      }
      
      func get(si: Silicon) -> Any? {
        var value: Any? = nil
        dispatch_once(&predicate, { [unowned si, unowned self] in
          value = self.closure(si: si)
          })
        return value
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
    
    convenience init(name: String, shared: Bool, count: Int, closure: (si:Silicon) -> Any?) {
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
  public static let sharedInstance = Silicon()
  
  public var errorBlock: ((Silicon.Error) -> Void)? = nil
  
  var services: [String:Higgs] = [String:Higgs]()
  
  let servicesQueue: dispatch_queue_t = dispatch_queue_create("cat.thepirate.silicon.services", DISPATCH_QUEUE_SERIAL)
  
  let errorsQueue: dispatch_queue_t = dispatch_queue_create("cat.thepirate.silicon.errors", DISPATCH_QUEUE_SERIAL)
  
  private init() {
    services = [String:Higgs]()
  }
  
  
  // MARK: Static versions
  
  class public func set(name: String, closure: (si:Silicon) -> Any?) -> Void {
    Silicon.set(name, shared: false, closure: closure);
  }
  
  class public func set(name: String, shared: Bool, closure: (si:Silicon) -> Any?) -> Void {
    Silicon.set(name, shared: shared, count: Higgs.INF, closure: closure)
  }
  
  class public func set(name: String, shared: Bool, count: Int, closure: (si:Silicon) -> Any?) -> Void {
    Silicon.sharedInstance.set(name, shared: shared, count: count, closure: closure)
  }
  
  class public func set(name: String, instance: Any) -> Void {
    Silicon.set(name, shared: false, instance: instance);
  }
  
  class public func set(name: String, shared: Bool, instance: Any) -> Void {
    Silicon.set(name, shared: shared, count: Higgs.INF, instance: instance)
  }
  
  class public func set(name: String, shared: Bool, count: Int, instance: Any) -> Void {
    Silicon.sharedInstance.set(name, shared: shared, count: count, instance: instance)
  }
  
  // MARK: resolve higgs object
  
  class public func get(name: String) -> Any? {
    return Silicon.sharedInstance.get(name)
  }
  
  class public func resolve(name: String) -> Any? {
    return Silicon.sharedInstance.resolve(name)
  }
  
  // MARK: Instance Create block definition based higgs
  
  public func set(name: String, closure:(si: Silicon) -> Any?) -> Void {
    self.set(name, shared: false, closure: closure);
  }
  
  public func set(name: String, shared: Bool, closure: (si:Silicon) -> Any?) -> Void {
    self.set(name, shared: shared, count: Higgs.INF, closure: closure)
  }
  
  public func set(name: String, shared: Bool, count: Int, closure: (si:Silicon) -> Any?) -> Void {
    self.add(Higgs: Higgs(name: name, shared: shared, count: count, closure: closure))
  }
  
  // MARK: Create instance based higgs
  
  public func set(name: String, instance: Any) -> Void {
    self.set(name, shared: false, instance: instance);
  }
  
  public func set(name: String, shared: Bool, instance: Any) -> Void {
    self.set(name, shared: shared, count: Higgs.INF, instance: instance)
  }
  
  public func set(name: String, shared: Bool, count: Int, instance: Any) -> Void {
    self.add(Higgs: Higgs(name: name, shared: shared, count: count, instance: instance))
  }
  
  // MARK: resolve higgs object
  
  public func get(name: String) -> Any? {
    return resolve(name);
  }
  
  public func resolve(name: String) -> Any? {
    guard let higgs = self.get(HiggsName: name) else {
      handle(Error: .ServiceNotFound(service: name))
      return nil;
    }
    
    print("\nResolving \(name)")
    
    if higgs.resolved {
      self.update(Higgs: higgs)
      return higgs.instance
    }
    
    print("\tMissing")
    
    var object: Any? = nil
    
    let lbl = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)
    let queue_data = dispatch_get_specific(lbl)
    print("\tqueue \(queue_data)")
    if queue_data != nil {
      let opaque_data = COpaquePointer(queue_data)
      let ctx = Unmanaged<Silicon.Context>.fromOpaque(opaque_data).takeUnretainedValue()
      return self.resolve(Higgs: higgs, onContext: ctx)
    }
    
    // new resolver
    let ctx = Context(withHiggs: higgs)
    
    dispatch_group_enter(ctx.group)
    dispatch_async(ctx.queue, { [unowned silicon = self, unowned higgs, unowned ctx, unowned group = ctx.group] in
      object = silicon.resolve(Higgs: higgs, onContext: ctx)
      dispatch_group_leave(group)
      })
    
    ctx.wait()
    
    if let error = ctx.error {
      self.handle(Error: error)
      return nil
    }
    
    print("\t<- \(object)")
    return object
  }
  
  private func resolve(Higgs higgs: Higgs, onContext context: Context) -> Any? {
    var instance = higgs.instance
    
    if instance == nil {
      
      // MARK: dont resolve on poluted stack
      if context.error != nil {
        return nil
      }
      
      if context.contains(higgs.name) {
        print("Circularity!!!");
        context.error = .CircularDependency(service: context.higgs?.name, resolvingTree: context.resolveTrace)
        return nil;
      }
      context.insert(higgs.name)
      
      if let definition = higgs.definition {
        if higgs.shared {
          instance = definition.get(self)
          if instance == nil {
            context.error = .MissingInstance(service: higgs.name)
          }
          higgs.instance = instance
          higgs.definition = nil
        } else {
          instance = definition.closure(si: self)
        }
      } else {
        context.error = .MissingDefinition(service: context.higgs?.name)
      }
    }
    
    self.update(Higgs: higgs)
    
    return instance
  }
  
  private func update(Higgs higgs: Higgs) {
    if higgs.count > 0 {
      higgs.count -= 1
    }
    
    print("count \(higgs.count)")
    
    if higgs.count == 0 {
      self.remove(Higgs: higgs)
    }
  }
  
  private func add(Higgs higgs: Higgs) -> Bool {
    var exists = false
    dispatch_barrier_sync(servicesQueue, { [unowned self] in
      exists = (self.services[higgs.name] != nil)
      if !exists {
        self.services[higgs.name] = higgs;
      } else {
        self.handle(Error: .ServiceAlreadyExists(service: higgs.name))
      }
      })
    return !exists;
  }
  
  private func get(HiggsName name: String) -> Higgs? {
    var higgs:Higgs? = nil
    dispatch_barrier_sync(servicesQueue, { [unowned self] in
      higgs = self.services[name]
      })
    return higgs
  }
  
  private func remove(Higgs higgs: Higgs) {
    dispatch_barrier_async(servicesQueue, { [unowned self] in
      self.services.removeValueForKey(higgs.name)
      })
  }
  
  private func handle(Error error: Silicon.Error) {
    if let _block = self.errorBlock {
      dispatch_async(errorsQueue, {
        _block(error)
      })
    } else {
      #if DEBUG
        print("Error \(error)");
      #endif
    }
  }
}

// MARK: Service management using SiService protocol

extension Silicon {
  
  class public func get(service: SiService) -> Any? {
    return Silicon.sharedInstance.get(service)
  }
  
  class public func resolve(service: SiService) -> Any? {
    return Silicon.sharedInstance.resolve(service)
  }
  
  class public func set(service: SiService, closure: (si:Silicon) -> Any?) -> Void {
    Silicon.set(service, shared: false, closure: closure);
  }
  
  class public func set(service: SiService, shared: Bool, closure: (si:Silicon) -> Any?) -> Void {
    Silicon.set(service, shared: shared, count: Higgs.INF, closure: closure)
  }
  
  class public func set(service: SiService, shared: Bool, count: Int, closure: (si:Silicon) -> Any?) -> Void {
    Silicon.sharedInstance.set(service, shared: shared, count: count, closure: closure)
  }
  
  class public func set(service: SiService, instance: Any) -> Void {
    Silicon.set(service, shared: false, instance: instance);
  }
  
  class public func set(service: SiService, shared: Bool, instance: Any) -> Void {
    Silicon.set(service, shared: shared, count: Higgs.INF, instance: instance)
  }
  
  class public func set(service: SiService, shared: Bool, count: Int, instance: Any) -> Void {
    Silicon.set(service.name(), shared: shared, count: count, instance: instance)
  }
  
  public func set(service: SiService, closure:(si: Silicon) -> Any?) -> Void {
    self.set(service, shared: false, closure: closure);
  }
  
  public func set(service: SiService, shared: Bool, closure: (si:Silicon) -> Any?) -> Void {
    self.set(service, shared: shared, count: Higgs.INF, closure: closure)
  }
  
  public func set(service: SiService, shared: Bool, count: Int, closure: (si:Silicon) -> Any?) -> Void {
    self.set(service.name(), shared:  shared, count:  count, closure: closure);
  }
  
  public func set(service: SiService, instance: Any) -> Void {
    self.set(service, shared: false, instance: instance);
  }
  
  public func set(service: SiService, shared: Bool, instance: Any) -> Void {
    self.set(service, shared: shared, count: Higgs.INF, instance: instance)
  }
  
  public func set(service: SiService, shared: Bool, count: Int, instance: Any) -> Void {
    self.set(service.name(), shared: shared, count: count, instance: instance);
  }
  
  public func get(service: SiService) -> Any? {
    return get(service.name())
  }
  
  public func resolve(service: SiService) -> Any? {
    return resolve(service.name())
  }
  
}