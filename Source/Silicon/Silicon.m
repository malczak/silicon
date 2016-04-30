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

@interface SIHashMap : NSObject

@property (nonatomic, strong) dispatch_queue_t accessQueue;

@property (nonatomic, strong) NSMutableDictionary *map;

-(instancetype) init;

-(void) setItem:(NSObject*) item forKey:(NSString*) key;

-(NSObject*) itemForKey:(NSString*) key;

-(void) removeItemForKey:(NSString*) key;

-(void) removeAllItems;

-(void) enumerateItemsWithBlock:(void(^)(NSString *key, NSObject *object, BOOL *stop)) block;

@end

@implementation SIHashMap

-(instancetype) init
{
    self = [super init];
    if(self)
    {
        self.map = [NSMutableDictionary dictionaryWithCapacity:5];
        self.accessQueue = dispatch_queue_create("cat.thepirate.silicon.hashMap.access", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void) setItem:(NSObject*) item forKey:(NSString*) key
{
    weakify(self, weakSelf);
    dispatch_async(self.accessQueue, ^(){
        strongify(weakSelf, strongSelf);
        if(strongSelf)
        {
            [strongSelf.map setObject:item forKey:key];
        }
    });
}

-(void) removeItemForKey:(NSString*) key
{
    weakify(self, weakSelf);
    dispatch_async(self.accessQueue, ^(){
        strongify(weakSelf, strongSelf);
        if(strongSelf)
        {
            [strongSelf.map removeObjectForKey:key];
        }
    });
}

-(void) removeAllItems
{
    weakify(self, weakSelf);
    dispatch_async(self.accessQueue, ^(){
        strongify(weakSelf, strongSelf);
        if(strongSelf)
        {
            [strongSelf.map removeAllObjects];
        }
    });
}

-(NSObject*) itemForKey:(NSString*) key
{
    __block NSObject *item = nil;
    weakify(self, weakSelf);
    dispatch_sync(self.accessQueue, ^(){
        strongify(weakSelf, strongSelf);
        if(strongSelf)
        {
            item = [strongSelf.map objectForKey:key];
        }
    });
    return item;
}
                                 
-(void) enumerateItemsWithBlock:(void(^)(NSString *key, NSObject *object, BOOL *stop)) block
{
    __strong void (^copiedBlock)(NSString*, NSObject*, BOOL*) = [block copy];

    weakify(self, weakSelf);
    dispatch_sync(self.accessQueue, ^(){
        strongify(weakSelf, strongSelf);
        if(strongSelf)
        {
            [strongSelf.map enumerateKeysAndObjectsUsingBlock:copiedBlock];
        }
    });
}

-(void)dealloc
{
    [self removeAllItems];
    dispatch_sync(self.accessQueue, ^(){ });
    self.accessQueue = nil;
}
                                 
@end

typedef NS_ENUM(NSUInteger, HiggsType){
    HIGGS_TYPE_UNDEF,
    HIGGS_TYPE_DIRECT,
    HIGGS_TYPE_CLASS,
    HIGGS_TYPE_BLOCK
};


@interface Silicon()
{
    SIHashMap *services;
    SIHashMap *tasks;
}
@end

@implementation Silicon

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
        services = [[SIHashMap alloc] init];
        tasks = [[SIHashMap alloc] init];
//        void *key = (__bridge void *)self;
//        void *nonNullValue = (__bridge void *)self;
//        dispatch_queue_set_specific(accessQueue, key, nonNullValue, NULL);
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


-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithBlock:serviceBlock shared:shared count:-1]];
}

-(void) service:(NSString*) serviceName withObject:(id) serviceObject shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithObject:serviceObject shared:shared count:-1]];
}

-(void) service:(NSString*) serviceName withClass:(Class) serviceClass shared:(BOOL)shared
{
    [self service:serviceName withHiggs:[Higgs higgsWithClass:serviceClass shared:shared count:-1]];
}


-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock count:(NSUInteger)count
{
    [self service:serviceName withHiggs:[Higgs higgsWithBlock:serviceBlock shared:NO count:MAX(-1, count)]];
}

-(void) service:(NSString*) serviceName withObject:(id) serviceObject count:(NSUInteger)count
{
    [self service:serviceName withHiggs:[Higgs higgsWithObject:serviceObject shared:NO count:MAX(-1, count)]];
}

-(void) service:(NSString*) serviceName withClass:(Class) serviceClass count:(NSUInteger)count
{
    [self service:serviceName withHiggs:[Higgs higgsWithClass:serviceClass shared:NO count:MAX(-1, count)]];
}


-(void) service:(NSString*) serviceName withHiggs:(Higgs *)higgs
{
    BOOL serviceNameExists = ([services itemForKey:serviceName] != nil);

    NSAssert(!serviceNameExists, @"Service '%@' already in use", serviceName);

    id<SILoggerInterface> logger =  [self getService:SI_LOGGER];
    [logger debug:[NSString stringWithFormat:@"Add '%@' service", serviceName]];
    
    higgs.si = self;
    [services setItem:higgs forKey:serviceName];
}

+(void) removeService:(NSString*) serviceName
{
    [[self si] removeService:serviceName];
}

-(void) removeService:(NSString*) serviceName
{
    [services removeItemForKey:serviceName];
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
        if(![higgs available])
        {
            [self removeService:serviceName];
        }
    }
    return object;
}

-(Higgs *)getServiceHiggs:(NSString *)serviceName {
    return (Higgs*)[services itemForKey:serviceName];
}

- (void)wire:(NSObject*)object
{
    if(![object conformsToProtocol:@protocol(SiliconInjectable)])
    {
        return;
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
            
            if( [aProperty isReadonly] )
            {
                [logger error:[NSString stringWithFormat:@"Cannot wire readonly property '%@'", aProperty.name]];
                return;
            }
            
            if( ![aProperty isWeak] )
            {
                [logger warning:[NSString stringWithFormat:@"Use weak autowired property '%@'", aProperty.name]];
            }

            // this will return nil for not fully resolved services
            NSString *serviceName = [aProperty resolveServiceName];
            if(!serviceName)
            {
                return ;
            }
            
            NSObject *service = [self getService:serviceName];
//            if(![higgs.className isEqualToString:className])
//            {
//                return ;
//            }
            
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
                        Ivar ivar = class_getInstanceVariable(aReflection.class, [aProperty.ivar UTF8String]);
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
    [services removeAllItems];
    [tasks removeAllItems];
    services = nil;
    tasks = nil;
}


@end

@implementation Higgs

+ (id)higgsWithType:(HiggsType) type andDefinition:(id) definition shared:(BOOL) shared count:(NSInteger) count
{
    return [[Higgs alloc] initWithType:type andDefinition:definition shared:shared count:count];
}

+ (id)higgsWithObject:(NSObject *)object shared:(BOOL) shared count:(NSInteger) count
{
    return [Higgs higgsWithType:HIGGS_TYPE_DIRECT andDefinition:object shared:shared count:count];
}

+ (id)higgsWithClass:(Class)objectClass shared:(BOOL) shared count:(NSInteger) count
{
    return [Higgs higgsWithType:HIGGS_TYPE_CLASS andDefinition:objectClass shared:shared count:count];
}

+ (id)higgsWithBlock:(NSObject*(^)(Silicon *si))objectBlock shared:(BOOL) shared count:(NSInteger) count
{
    return [Higgs higgsWithType:HIGGS_TYPE_BLOCK andDefinition:[objectBlock copy] shared:shared count:count];
}

-(id) initWithType:(HiggsType) higgsType andDefinition:(id) higgsDefinition shared:(BOOL) higgsShared count:(NSInteger) higgsCount
{
    NSAssert(higgsDefinition != nil, @"Higgs it not defined");

    self = [self init];
    if(self) {
        shared = higgsShared;
        count = MAX(-1,higgsCount);
        type = higgsType;
        definition = higgsDefinition;
        object = nil;
        initSema = dispatch_semaphore_create(1);
    }
    return self;
}

-(BOOL)available
{
    return (count > 0) || (count == -1);
}

-(BOOL)resolved
{
    return (object != nil);
}

-(id) resolve {

    if(object)
    {
        return object;
    }

    NSAssert(self.si != nil, @"Higgs cannot exist without Silicon");

    dispatch_semaphore_wait(initSema, DISPATCH_TIME_FOREVER);
    
    count = MAX(-1, count - 1);

    id instance = [self doResolveService];
    
    dispatch_semaphore_signal(initSema);

    return instance;
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
    [self.si wire:serviceObject];
}

- (void)dealloc
{
    self.si = nil;
    _className = nil;
    object = nil;
    definition = nil;
}

@end