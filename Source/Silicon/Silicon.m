//
// Created by malczak on 01/04/14.
// Copyright (c) 2014 segfaultsoft. All rights reserved.
//


#import <objc/runtime.h>
#import <objc/message.h>
#import "Silicon.h"
#import "Reflection.h"

typedef NS_ENUM(NSUInteger, HiggsType){
    HIGGS_TYPE_UNDEF,
    HIGGS_TYPE_DIRECT,
    HIGGS_TYPE_CLASS,
    HIGGS_TYPE_CLASSREF,
    HIGGS_TYPE_BLOCK
};

@implementation Silicon {
    dispatch_queue_t servicesQueue;
    NSMutableDictionary *services;
}

+(instancetype) si {
    return [self sharedInstance];
}

+(instancetype)sharedInstance{
    static Silicon *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(){
        instance = [[Silicon alloc] init];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if(self) {
        servicesQueue = dispatch_queue_create("pl.printu.silicon.servicesQueue", DISPATCH_QUEUE_SERIAL);
        services = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock
{
    [self service:serviceName withHiggs:[Higgs higgsWithBlock:serviceBlock]];
}

-(void) service:(NSString *)serviceName withObject:(id) serviceObject
{
    [self service:serviceName withHiggs:[Higgs higgsWithObject:serviceObject]];
}

-(void) service:(NSString*) serviceName withClass:(Class) serviceClass
{
    [self service:serviceName withHiggs:[Higgs higgsWithClass:serviceClass]];
}

-(void) service:(NSString*) serviceName withClassName:(NSString*) serviceClassName
{
    [self service:serviceName withHiggs:[Higgs higgsWithClassName:serviceClassName]];
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

    if(higgs) {
        [higgs resolve];
    }

    return higgs;
}

- (void)wire:(NSObject*)object
{
    if(![object conformsToProtocol:@protocol(SiliconInjectable)]){
        return;
    }

    Reflection *reflection = [Reflection reflectionFor:object];

    if(reflection) {
        [reflection enumeratePropertiesUsingBlock:^(Property *aProperty, Reflection *aReflection){
            if(![aProperty isClass]) {
                return;
            }

            NSString *className = [aProperty resolve];
            if(!className) {
                return;
            }

            Higgs *higgs = [self getServiceHiggs:aProperty.name];
            if(!higgs) {
                return ;
            }

            NSObject *service = [higgs resolve];
            if(![higgs.className isEqualToString:[aProperty resolve]]) {
                return ;
            }

            if( [aProperty isReadonly] ) {
                NSLog(@"Cannot wire readonly property '%@'", aProperty.name);
                return;
            }

            if( ![aProperty isWeak] ) {
                NSLog(@"Warning - its better to use weak to autowired property '%@'", aProperty.name);
            }

            NSLog(@"SET %@ > - %@(%@)", aReflection.className, aProperty.name, aProperty.attributes);

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

-(id) initWithType:(HiggsType) higgsType andDefinition:(id) higgsDefinition {

    NSAssert(higgsDefinition != nil, @"Higgs it not defined");

    self = [super init];
    if(self) {
        initToken = 0l;
        setupToken = 0l;
        initSem = dispatch_semaphore_create(1);
        object = nil;
        type = higgsType;
        definition = higgsDefinition;
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

+ (id) higgsWithType:(HiggsType) type andDefinition:(id) definition  {
    return [[Higgs alloc] initWithType:type andDefinition:definition];
}

+ (id)higgsWithObject:(NSObject *)object {
    return [Higgs higgsWithType:HIGGS_TYPE_DIRECT andDefinition:object];
}

+ (id)higgsWithClass:(Class)objectClass {
    return [Higgs higgsWithType:HIGGS_TYPE_CLASS andDefinition:objectClass];
}

+ (id)higgsWithClassName:(NSObject *)objectClassName {
    return [Higgs higgsWithType:HIGGS_TYPE_CLASSREF andDefinition:objectClassName];
}

+ (id)higgsWithBlock:(NSObject*(^)(Silicon *si))objectBlock {
    return [Higgs higgsWithType:HIGGS_TYPE_BLOCK andDefinition:[objectBlock copy]];
}

- (void)doResolveService {
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

    type = HIGGS_TYPE_DIRECT;
    definition = nil;
}

- (void)setupService {
    NSAssert(object != nil, @"Service not resolved");
    char const *classNameCStr = object_getClassName(object);
    _className = [NSString stringWithCString:classNameCStr encoding:NSUTF8StringEncoding];
    [self.si wire:object];
}

- (void)dealloc {
    self.si = nil;
    _className = nil;
    object = nil;
    definition = nil;
}


@end