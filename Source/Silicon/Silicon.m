    //
// Created by malczak on 01/04/14.
// Copyright (c) 2014 segfaultsoft. All rights reserved.
//


#import <objc/runtime.h>
#import <objc/message.h>
#import "Silicon.h"
#import "Reflection.h"


NSString * const SI_SILICON = @"Silicon";
NSString * const SI_LOGGER = @"Logger";
NSString * const SI_COREDATA = @"CoreData";

typedef NS_ENUM(NSUInteger, HiggsType){
    HIGGS_TYPE_UNDEF,
    HIGGS_TYPE_DIRECT,
    HIGGS_TYPE_CLASS,
    HIGGS_TYPE_BLOCK
};

@interface Higgs ()

@property (nonatomic, assign) NSInteger count;

@end


@interface Commands ()
{
    dispatch_queue_t commandsAccessQueue;
    dispatch_queue_t commandsQueue;
}

@property (nonatomic, strong) NSMutableDictionary *commands;

@end

@implementation Commands

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        commandsQueue = dispatch_queue_create("cat.thepirate.silicon.commands.execute", DISPATCH_QUEUE_SERIAL);
        commandsAccessQueue = dispatch_queue_create("cat.thepirate.silicon.commands.access", DISPATCH_QUEUE_SERIAL);
        self.commands = [NSMutableDictionary dictionary];
    }
    return self;
}
    
-(void) add:(void(^)(Silicon *)) commandBlock named:(NSString*) name
{
    weakify(self, weakSelf);
    dispatch_async(commandsAccessQueue, ^(){
        [weakSelf.commands setObject:commandBlock forKey:name];
    });
}

-(void) remove:(NSString*) name
{
    weakify(self, weakSelf);
    dispatch_async(commandsAccessQueue, ^(){
        [weakSelf.commands removeObjectForKey:name];
    });
}

-(void) execute:(NSString*) name
{
    [self execute:name
       completion:nil];
}

-(void) execute:(NSString*) name completion:(void(^)()) completionBlock
{
    weakify(self, weakSelf);
    dispatch_async(commandsAccessQueue, ^(){
        strongify(weakSelf, strongSelf);
        if(strongSelf)
        {
            void(^commandBlock)(Silicon *si) = [strongSelf.commands objectForKey:name];
            if(commandBlock)
            {
                [strongSelf remove:name];
                [strongSelf executeCommand:commandBlock
                                completion:completionBlock];
            }
        }
    });
}

-(void) executeCommand:(void(^)(Silicon *)) commandBlock completion:(void(^)()) completionBlock
{
    dispatch_async(commandsQueue, ^(){
        commandBlock([Silicon sharedInstance]);
        if(completionBlock)
        {
            completionBlock();
        }
    });
}

-(void)dealloc
{
    [self.commands removeAllObjects];
    commandsQueue = nil;
    commandsAccessQueue = nil;
}

@end


@interface Silicon()
{
    Commands *commands;
    NSHashTable *wiredObjects;
    dispatch_queue_t wiredObjectsQueue;
    dispatch_queue_t serviceAccessQueue;
    NSMutableDictionary *services;
}

-(void)wire:(NSObject *)object withTracking:(BOOL)trackObject;

@end

@implementation Silicon

@synthesize commands = _commands;

+(instancetype) si {
    return [self sharedInstance];
}

+(instancetype)sharedInstance{
    static Silicon *silicon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(){
        silicon = [[Silicon alloc] init];
        [silicon service:SI_SILICON withObject:silicon];
    });
    return silicon;
}

- (id)init {
    self = [super init];
    if(self) {
        serviceAccessQueue = dispatch_queue_create("pl.printu.silicon.serviceAccessQueue", DISPATCH_QUEUE_SERIAL);
        wiredObjectsQueue = dispatch_queue_create("pl.printu.silicon.wiredObjectsQueue", DISPATCH_QUEUE_CONCURRENT);
        services = [NSMutableDictionary dictionary];
        wiredObjects = [NSHashTable weakObjectsHashTable];
        
        self.trackAllWiredObjects = NO;
    }
    return self;
}
-(Commands *)commands
{
    if(!_commands)
    {
        _commands = [[Commands alloc] init];
    }
    return _commands;
}

-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock
{
    [self service:serviceName withBlock:serviceBlock shared:YES];
}

-(void) service:(NSString *)serviceName withObject:(id) serviceObject
{
    [self service:serviceName withObject:serviceObject shared:YES];
}

-(void) service:(NSString*) serviceName withClass:(Class) serviceClass
{
    [self service:serviceName withClass:serviceClass shared:YES];
}


-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithBlock:serviceBlock shared:shared]];
}

-(void) service:(NSString*) serviceName withObject:(id) serviceObject shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithObject:serviceObject shared:YES]];
}

-(void) service:(NSString*) serviceName withClass:(Class) serviceClass shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithClass:serviceClass shared:YES]];
}


-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock count:(NSUInteger)count
{
    Higgs *higgs = [Higgs higgsWithBlock:serviceBlock shared:NO];
    higgs.count = MAX(1, count);
    [self service:serviceName withHiggs:higgs];
}

-(void) service:(NSString*) serviceName withObject:(id) serviceObject count:(NSUInteger)count
{
    Higgs *higgs = [Higgs higgsWithObject:serviceObject shared:NO];
    higgs.count = MAX(1, count);
    [self service:serviceName withHiggs:higgs];
}

-(void) service:(NSString*) serviceName withClass:(Class) serviceClass count:(NSUInteger)count
{
    Higgs *higgs = [Higgs higgsWithClass:serviceClass shared:NO];
    higgs.count = MAX(1, count);
    [self service:serviceName withHiggs:higgs];
}


-(void) service:(NSString*) serviceName withHiggs:(Higgs *)higgs
{
    __block BOOL serviceNameExists = NO;
    __weak typeof(self) weakSelf = self;
    __weak NSMutableDictionary* weakServices = services;

    dispatch_barrier_sync(serviceAccessQueue, ^(){ // todo cyclic barrier is not required on seriall queues
        serviceNameExists = ([weakServices objectForKey:serviceName] != nil);
    });

    NSAssert(!serviceNameExists, @"Service '%@' already in use", serviceName);

    id<SILoggerInterface> logger =  [self getService:SI_LOGGER];
    [logger debug:[NSString stringWithFormat:@"Add '%@' service", serviceName]];
    
    dispatch_barrier_async(serviceAccessQueue, ^(){
        if(weakServices && weakSelf) {
            [weakServices setObject:higgs forKey:serviceName];
            if([weakServices objectForKey:serviceName] == higgs) {
                higgs.si = weakSelf;
            }
        }
    });
}

+(void) removeService:(NSString*) serviceName
{
    [[self si] removeService:serviceName];
}

-(void) removeService:(NSString*) serviceName
{
    Higgs *higgs = [self getServiceHiggs:serviceName];
    if(higgs != nil)
    {
        [self removeHiggs:higgs];
    }
}

+(id) service:(NSString*) serviceName {
    return [[self si] service:serviceName];
}

+(id) get:(NSString*) serviceName {
    return [[self si] get:serviceName];
}

+(id) getService:(NSString*) serviceName {
    return [[self si] getService:serviceName];
}

- (id)service:(NSString *)serviceName {
    return [self getService:serviceName];
}

- (id)get:(NSString *)serviceName {
    return [self getService:serviceName];
}

- (id)getService:(NSString *)serviceName {
    id object = nil;
    Higgs *higgs = [self getServiceHiggs:serviceName];
    if(higgs != nil)
    {
        object = [higgs resolve];
        if(higgs.count == 0)
        {
            [self removeHiggs:higgs];
        }
    }
    return object;
}

-(Higgs *)getServiceHiggs:(NSString *)serviceName {
    __block Higgs *higgs = nil;

    dispatch_barrier_sync(serviceAccessQueue, ^(){
        higgs = [services objectForKey:serviceName];
    });

    return higgs;
}

-(Higgs *)getServiceHiggsByClass:(NSString*) serviceClassName {
    __block Higgs *higgs = nil;

    if(serviceClassName) {
    
        BOOL doResolve = self.resolveServicesOnWire;
        
        dispatch_barrier_sync(serviceAccessQueue, ^(){
            [services enumerateKeysAndObjectsUsingBlock:^(NSString *service, Higgs *item, BOOL *stop){
                
                if( doResolve ) {
                    [item resolve];
                }
                
                if( [serviceClassName isEqualToString:item.className] ) {
                    higgs = item;
                    *stop = YES;
                }
                
            }];
        });
        
    }
    
    return higgs;
}

-(void) removeHiggs:(Higgs*) higgsToDelete
{
    __weak NSMutableDictionary* weakServices = services;
    
    dispatch_barrier_sync(serviceAccessQueue, ^(){
        __block NSString *serviceName = nil;
        
        [weakServices enumerateKeysAndObjectsUsingBlock:^(NSString *name, Higgs* higgs, BOOL *stop){
            if([higgsToDelete isEqual:higgs])
            {
                higgsToDelete.si = nil;
                serviceName = name;
                *stop = YES;
            }
        }];
        
        if(serviceName != nil)
        {
            [weakServices removeObjectForKey:serviceName];
        }
    });
}

- (void)wire:(NSObject*)object
{
    [self wire:object withTracking:self.trackAllWiredObjects];
}

-(void)wire:(NSObject *)object withTracking:(BOOL)trackObject
{
    if(![object conformsToProtocol:@protocol(SiliconInjectable)])
    {
        return;
    }
    
    // keep track of wired objects, this prevents from multiple wire passes
    if(trackObject)
    {
        __block BOOL alreadyWired = NO;
        __weak NSObject* weakObject = object;
        dispatch_barrier_sync(wiredObjectsQueue, ^(){
            alreadyWired = weakObject && [wiredObjects containsObject:weakObject];
        });
        
        if(alreadyWired)
        {
            return;
        }
        
        dispatch_barrier_async(wiredObjectsQueue, ^(){
            if(weakObject) {
                [wiredObjects addObject:weakObject];
            }
        });
    }
    
    Reflection *reflection = [Reflection reflectionFor:object];
    id<SILoggerInterface> logger = [self getService:SI_LOGGER];
    
    [logger debug:[NSString stringWithFormat:@"Wire object %@", reflection.className]];
    
    if(reflection)
    {
        [reflection enumeratePropertiesUsingBlock:^(Property *aProperty, Reflection *aReflection)
        {
            if(![aProperty isClass])
            {
                return;
            }
            
            NSString *className = [aProperty resolve];
            if(!className)
            {
                return;
            }
            
            // this will return nil for not fully resolved services
            Higgs *higgs = [self getServiceHiggsByClass:className];
            
            if(!higgs)
            {
                NSString *serviceName = [aProperty resolveServiceName];
                higgs = [self getServiceHiggs:serviceName];
                if(!higgs)
                {
                    return /* die silently */;
                }
                
            }
            
            NSObject *service = [higgs resolve];
            if(![higgs.className isEqualToString:className])
            {
                return ;
            }
            
            if( [aProperty isReadonly] )
            {
                [logger error:[NSString stringWithFormat:@"Cannot wire readonly property '%@'", aProperty.name]];
                return;
            }
            
            if( ![aProperty isWeak] )
            {
                [logger warning:[NSString stringWithFormat:@"Use weak autowired property '%@'", aProperty.name]];
            }
            
            [logger debug:[NSString stringWithFormat:@"SET %@ > - %@(%@)", aReflection.className, aProperty.name, aProperty.attributes]];
            
            /*
             1. if setter is defined - call it
             2. try key-value to set property
             3. try to set iVar
             */
            
            if([aProperty hasSetter])
            {
                SEL setterSelector = NSSelectorFromString(aProperty.setter);
                if([object respondsToSelector:setterSelector])
                {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [object performSelector:setterSelector withObject:service];
#pragma clang diagnostic pop
                }
            } else
                if([object respondsToSelector:@selector(setValue:forKey:)])
                {
                    [object setValue:service forKey:aProperty.name];
                } else
                    if(aProperty.ivar)
                    {
                        Ivar ivar = class_getInstanceVariable(aReflection.class, aProperty.ivar.UTF8String);
                        if(ivar)
                        {
                            object_setIvar(object, ivar, service);
                        }
                    } else {
                        // todo show warning
                        [logger warning:@"Unable to set property"];
                    }
            
        }];
    }
}

- (void)dealloc {
    [services removeAllObjects];
    [wiredObjects removeAllObjects];
    _commands = nil;
    services = nil;
}


@end

@implementation Higgs

-(id) initWithType:(HiggsType) higgsType andDefinition:(id) higgsDefinition shared:(BOOL) higgsShared {

    NSAssert(higgsDefinition != nil, @"Higgs it not defined");

    self = [self init];
    if(self) {
        self.count = -1;
        setupToken = 0l;
        initSem = dispatch_semaphore_create(1);
        object = nil;
        type = higgsType;
        definition = higgsDefinition;
        shared = higgsShared;
    }
    return self;
}

-(id) resolve {

    if(object)
    {
        return object;
    }

    NSAssert(self.si != nil, @"Higgs cannot exist without Silicon");

    dispatch_semaphore_wait(initSem, DISPATCH_TIME_FOREVER);
    
    // decrement
    if(self.count > 0)
    {
        self.count -= 1;
    }

    id instance = [self doResolveService];
    
    dispatch_semaphore_signal(initSem);

    return instance;
}

+ (id)higgsWithType:(HiggsType) type andDefinition:(id) definition shared:(BOOL) shared;  {
    return [[Higgs alloc] initWithType:type andDefinition:definition shared:shared];
}

+ (id)higgsWithObject:(NSObject *)object shared:(BOOL) shared; {
    return [Higgs higgsWithType:HIGGS_TYPE_DIRECT andDefinition:object shared:shared];
}

+ (id)higgsWithClass:(Class)objectClass shared:(BOOL) shared; {
    return [Higgs higgsWithType:HIGGS_TYPE_CLASS andDefinition:objectClass shared:shared];
}

+ (id)higgsWithBlock:(NSObject*(^)(Silicon *si))objectBlock shared:(BOOL) shared; {
    return [Higgs higgsWithType:HIGGS_TYPE_BLOCK andDefinition:[objectBlock copy] shared:shared];
}

- (id)doResolveService
{
    if(object)
    {
        return object;
    }

    id instance = object;

    @autoreleasepool
    {
        if(type == HIGGS_TYPE_CLASS)
        {
            Class objectClass = (Class) definition;
            instance = [[objectClass alloc] init];
        } else
            if(type == HIGGS_TYPE_BLOCK)
            {
                NSObject*(^definitionBlock)(Silicon *) = (NSObject*(^)(Silicon *)) definition;
                instance = definitionBlock(self.si);
            } else
                if(type == HIGGS_TYPE_DIRECT)
                {
                    instance = definition;
                }
    }

    NSAssert(instance != nil, @"Service not resolved");
    
    [self setSharedInstance:instance];
    
    [self setServiceName:instance];
    
    [self setupService:instance];;
    
    return instance;
}

-(void) setSharedInstance:(id) serviceObject
{
    if(!shared)
    {
        return;
    }

    object = serviceObject;
    type = HIGGS_TYPE_DIRECT;
    definition = nil;
}

-(void) setServiceName:(id) serviceObject
{
    char const *classNameCStr = object_getClassName(serviceObject);
    _className = [NSString stringWithCString:classNameCStr encoding:NSUTF8StringEncoding];
}

- (void)setupService:(id) serviceObject
{
    [self.si wire:serviceObject withTracking:YES];
}

- (void)dealloc {
    self.si = nil;
    _className = nil;
    object = nil;
    definition = nil;
}


@end