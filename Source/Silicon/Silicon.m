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
    HIGGS_TYPE_CLASSREF,
    HIGGS_TYPE_BLOCK
};

@interface Silicon (SiliconPrivate)

-(void)wire:(NSObject *)object withTracking:(BOOL)trackObject;

@end

@implementation Silicon {
    dispatch_queue_t wiredObjectsQueue;
    NSHashTable *wiredObjects;
    dispatch_queue_t servicesQueue;
    NSMutableDictionary *services;
}

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
        servicesQueue = dispatch_queue_create("pl.printu.silicon.servicesQueue", DISPATCH_QUEUE_SERIAL);
        services = [NSMutableDictionary dictionary];
        
        wiredObjectsQueue = dispatch_queue_create("pl.printu.silicon.wiredObjectsQueue", DISPATCH_QUEUE_CONCURRENT);
        wiredObjects = [NSHashTable weakObjectsHashTable];
        
        self.trackAllWiredObjects = NO;
    }
    return self;
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

-(void) service:(NSString*) serviceName withClassName:(NSString*) serviceClassName
{
    [self service:serviceName withClassName:serviceClassName shared:YES];
}


-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithBlock:serviceBlock shared:YES]];
}

-(void) service:(NSString*) serviceName withObject:(id) serviceObject shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithObject:serviceObject shared:YES]];
}

-(void) service:(NSString*) serviceName withClass:(Class) serviceClass shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithClass:serviceClass shared:YES]];
}

-(void) service:(NSString*) serviceName withClassName:(NSString*) serviceClassName shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithClassName:serviceClassName shared:YES]];
}


-(void) service:(NSString*) serviceName withHiggs:(Higgs *)higgs
{
    __block BOOL serviceNameExists = NO;
    __weak typeof(self) weakSelf = self;
    __weak NSMutableDictionary* weakServices = services;

    dispatch_barrier_sync(servicesQueue, ^(){
        serviceNameExists = ([weakServices objectForKey:serviceName] != nil);
    });

    NSAssert(!serviceNameExists, @"Service '%@' already in use", serviceName);

    id<SILoggerInterface> logger =  [self getService:SI_LOGGER];
    [logger debug:[NSString stringWithFormat:@"Add '%@' service", serviceName]];
    
    dispatch_barrier_async(servicesQueue, ^(){
        if(weakServices && weakSelf) {
            [weakServices setObject:higgs forKey:serviceName];
            if([weakServices objectForKey:serviceName] == higgs) {
                higgs.si = weakSelf;
            }
        }
    });
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
    Higgs *higgs = [self getServiceHiggs:serviceName];
    return higgs ? [higgs resolve] : nil;
}

-(Higgs *)getServiceHiggs:(NSString *)serviceName {
    __block Higgs *higgs = nil;

    dispatch_barrier_sync(servicesQueue, ^(){
        higgs = [services objectForKey:serviceName];
    });

//    if(higgs) {
//        [higgs resolve];
//    }

    return higgs;
}

-(Higgs *)getServiceHiggsByClass:(NSString*) serviceClassName {
    __block Higgs *higgs = nil;

    if(serviceClassName) {
    
        BOOL doResolve = self.resolveServicesOnWire;
        
        dispatch_barrier_sync(servicesQueue, ^(){
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

- (void)wire:(NSObject*)object
{
    [self wire:object withTracking:self.trackAllWiredObjects];
}

-(void)wire:(NSObject *)object withTracking:(BOOL)trackObject
{
    if(![object conformsToProtocol:@protocol(SiliconInjectable)]){
        return;
    }
    
    // keep track of wired objects, this prevents from multiple wire passes
    if(trackObject) {
        __block BOOL alreadyWired = NO;
        __weak NSObject* weakObject = object;
        dispatch_barrier_sync(wiredObjectsQueue, ^(){
            alreadyWired = weakObject && [wiredObjects containsObject:weakObject];
        });
        
        if(alreadyWired) {
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
    
    if(reflection) {
        [reflection enumeratePropertiesUsingBlock:^(Property *aProperty, Reflection *aReflection){
            if(![aProperty isClass]) {
                return;
            }
            
            NSString *className = [aProperty resolve];
            if(!className) {
                return;
            }
            
            Higgs *higgs = nil;
            
            higgs = [self getServiceHiggsByClass:className];
            
            if(!higgs) { // this will return nil for not fully resolved services
                
                NSString *serviceName = [aProperty resolveServiceName];
                higgs = [self getServiceHiggs:serviceName];
                if(!higgs) {
                    return ;
                }
                
            }
            
            NSObject *service = [higgs resolve];
            if(![higgs.className isEqualToString:className]) {
                return ;
            }
            
            if( [aProperty isReadonly] ) {
                [logger error:[NSString stringWithFormat:@"Cannot wire readonly property '%@'", aProperty.name]];
                return;
            }
            
            if( ![aProperty isWeak] ) {
                [logger warning:[NSString stringWithFormat:@"Use weak autowired property '%@'", aProperty.name]];
            }
            
            [logger debug:[NSString stringWithFormat:@"SET %@ > - %@(%@)", aReflection.className, aProperty.name, aProperty.attributes]];
            
            /*
             1. if setter is defined - call it
             2. try key-value to set property
             3. try to set iVar
             */
            
            if([aProperty hasSetter]) {
                SEL setterSelector = NSSelectorFromString(aProperty.setter);
                if([object respondsToSelector:setterSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [object performSelector:setterSelector withObject:service];
#pragma clang diagnostic pop
                }
            } else
                if([object respondsToSelector:@selector(setValue:forKey:)]) {
                    [object setValue:service forKey:aProperty.name];
                } else
                    if(aProperty.ivar) {
                        Ivar ivar = class_getInstanceVariable(aReflection.class, aProperty.ivar.UTF8String);
                        if(ivar) {
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
    services = nil;
}


@end


@implementation Higgs

-(id) initWithType:(HiggsType) higgsType andDefinition:(id) higgsDefinition shared:(BOOL) higgsShared {

    NSAssert(higgsDefinition != nil, @"Higgs it not defined");

    self = [self init];
    if(self) {
        initToken = 0l;
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

    if(object) {
        return object;
    }

    NSAssert(self.si != nil, @"Higgs cannot exist without Silicon");

    dispatch_semaphore_wait(initSem, DISPATCH_TIME_FOREVER);

    __weak typeof(self) weakSelf = self;

    dispatch_once(&initToken, ^(){
        if(weakSelf) {
            [weakSelf doResolveService];
            [weakSelf setupService];
        }
    });

    dispatch_semaphore_signal(initSem);

    return object;
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

+ (id)higgsWithClassName:(NSObject *)objectClassName shared:(BOOL) shared; {
    return [Higgs higgsWithType:HIGGS_TYPE_CLASSREF andDefinition:objectClassName shared:shared];
}

+ (id)higgsWithBlock:(NSObject*(^)(Silicon *si))objectBlock shared:(BOOL) shared; {
    return [Higgs higgsWithType:HIGGS_TYPE_BLOCK andDefinition:[objectBlock copy] shared:shared];
}

- (void)doResolveService {
    if(object) {
        return;
    }
    
    NSObject* (^classConstructor)(Class) = ^NSObject*(Class objectClass) {
        SEL initSelector = NSSelectorFromString(@"initWithSi:");
        Method initWithSiMethod = class_getInstanceMethod(objectClass, initSelector);
        if(initWithSiMethod) {
            return method_invoke([objectClass alloc], initWithSiMethod, self.si);
        }
        return [[objectClass alloc] init];
    };

    if(type == HIGGS_TYPE_CLASSREF) {
        NSString *className = [definition isKindOfClass:[NSString class]] ? (NSString *) definition : nil;
        NSAssert(className != nil, @"Higgs class reference should be a valid NSString instance");

        const char *classNameCStr = [className UTF8String];
        Class objectClass = objc_getClass(classNameCStr);
        NSAssert(className != nil, ([NSString stringWithFormat:@"Higgs class reference '%@' not fount", className]));

        object = classConstructor(objectClass);
    } else
    if(type == HIGGS_TYPE_CLASS) {
        Class objectClass = (Class) definition;
        object = classConstructor(objectClass);
    } else
    if(type == HIGGS_TYPE_BLOCK) {
        NSObject*(^definitionBlock)(Silicon *) = (NSObject*(^)(Silicon *)) definition;
        object = definitionBlock(self.si); // todo ? any extra test
    } else
    if(type == HIGGS_TYPE_DIRECT) {
        object = definition;
    }
    
    if(shared) {
        type = HIGGS_TYPE_DIRECT;
        definition = nil;
    }
}

- (void)setupService {
    NSAssert(object != nil, @"Service not resolved");
    char const *classNameCStr = object_getClassName(object);
    _className = [NSString stringWithCString:classNameCStr encoding:NSUTF8StringEncoding];
    [self.si wire:object withTracking:YES];
}

- (void)dealloc {
    self.si = nil;
    _className = nil;
    object = nil;
    definition = nil;
}


@end