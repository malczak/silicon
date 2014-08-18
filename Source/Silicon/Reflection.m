//
// Created by malczak on 22/06/14.
// Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import <objc/runtime.h>
#import "Reflection.h"

@interface ReflectionCache : NSObject
    -(void) cacheReflection:(Reflection *)reflection;
    -(Reflection *) getReflectionByClass:(Class) objectClass;
    -(Reflection *) getReflectionByClassName:(NSString*) className;
@end


@implementation ReflectionCache {
    NSMutableDictionary *_cache;
    dispatch_queue_t cacheQueue;
}

- (id)init {
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary dictionary];
        cacheQueue = dispatch_queue_create("pl.printu.silicon.reflection.cacheQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)cacheReflection:(Reflection *)reflection {
    __weak NSMutableDictionary *weakCache = _cache;
    dispatch_barrier_async(cacheQueue, ^(){
        if(weakCache) {
            [weakCache setObject:reflection forKey:reflection.className];
        }
    });
}

- (Reflection *)getReflectionByClass:(Class)objectClass {
    __block Reflection *reflection = nil;
    __weak NSMutableDictionary *weakCache = _cache;
    dispatch_barrier_sync(cacheQueue, ^(){
        if(weakCache) {
            [weakCache enumerateKeysAndObjectsUsingBlock:^(NSString *key, Reflection *reflectionAt, BOOL *stop){
                if(objectClass == reflectionAt.class) {
                    reflection = reflectionAt;
                    *stop = YES;
                }
            }];
        }
    });
    return reflection;
}

- (Reflection *)getReflectionByClassName:(NSString *)className {
    __block Reflection *reflection = nil;
    __weak NSMutableDictionary *weakCache = _cache;
    dispatch_barrier_sync(cacheQueue, ^(){
        if(weakCache) {
            reflection = [weakCache objectForKey:className];
        }
    });
    return reflection;
}

@end;


char const * const PROPERTY_SI = "si";

@implementation Property {

    NS_OPTIONS(NSUInteger, type) {
        TYPE_UNDEF      =   0 << 0,
        TYPE_POINTER    =   1 << 0,
        TYPE_GENERIC    =   1 << 1,
        TYPE_STRUCT     =   1 << 2,
        TYPE_CLASS      =   1 << 3
    };

    struct {
        BOOL copy:1;
        BOOL readonly:1;
        BOOL retain:1;
        BOOL nonatomic:1;
        BOOL getter:1;
        BOOL setter:1;
        BOOL dynamic:1;
        BOOL weak:1;
        BOOL garbage:1;
        BOOL prefixed:1;
    } attrs;

    NSString *descriptor;
}

- (id)initWithProperty:(objc_property_t)property_t {
    self = [super init];
    if(self) {
        type = TYPE_UNDEF;

        char const *nameCStr = property_getName(property_t);
        _name = [NSString stringWithCString:nameCStr encoding:NSUTF8StringEncoding];
        _serviceName = _name;

        [self setDefaultAttrs];
        /*
            Allowed prefixes are siNameOfService, si_NameOfService
         */
        UInt8 prefixLength = 0;
        if((strlen(nameCStr) > strlen(PROPERTY_SI)) && ((*nameCStr == *PROPERTY_SI) && (*(nameCStr + 1) == *(PROPERTY_SI + 1)))) {
            prefixLength += 2;
            if(!isalnum(*(nameCStr + 2)) || isupper(*(nameCStr + 2))) {
                prefixLength += 1;
            }
            attrs.prefixed = YES;
            _serviceName = [[_name substringFromIndex:prefixLength] capitalizedString];
        }
        attrs.prefixed = (prefixLength > 0);


        char const *attributesCStr = property_getAttributes(property_t);
        _attributes = [NSString stringWithCString:attributesCStr encoding:NSUTF8StringEncoding];

        _ivar = nil;
        _setter = nil;
        _getter = nil;
        [self parse];
    }
    return self;
}

- (void)setDefaultAttrs {
    attrs.copy = NO;
    attrs.readonly = NO;
    attrs.retain = NO;
    attrs.nonatomic = YES;
    attrs.getter = NO;
    attrs.setter = NO;
    attrs.dynamic = NO;
    attrs.weak = NO;
    attrs.garbage = NO;
}

-(BOOL) isGeneric {
    return (type & TYPE_GENERIC) == TYPE_GENERIC;
}

-(BOOL) isClass {
    return (type & TYPE_CLASS) == TYPE_CLASS;
}

- (BOOL)isCopy {
    return attrs.copy;
}

- (BOOL)isReadonly {
    return attrs.readonly;
}

- (BOOL)isNonatomic {
    return attrs.nonatomic;
}

- (BOOL)isDynamic {
    return attrs.dynamic;
}

-(BOOL) isWeak {
    return attrs.weak;
}

- (BOOL)hasSetter {
    return attrs.setter && _setter && [_setter length];
}

- (BOOL)hasGetter {
    return attrs.getter && _getter && [_getter length];
}

- (BOOL)hasPrefix {
    return attrs.prefixed;
}

-(id)resolve {
    return descriptor;
}

- (NSString *)nameRemovingPrefix {
    if(!attrs.prefixed) {
        return self.name;
    }
    return self.serviceName;
}

-(void) parse
{
    if(!_attributes) {
        return ;
    }

    char const *attrsCstr = [_attributes UTF8String];
    char const *attrChr = attrsCstr;
    char const *lastChr = attrsCstr +[_attributes length];

    NSString*(^parseName)(char const **, char const *) = ^(char const **inPtr, char const *endPtr){
        NSString *name = nil;

        while( (**inPtr == '"') && (*inPtr < endPtr)) {
            *inPtr += 1;
        }

        if(*inPtr < endPtr){

            char const *beginPtr = *inPtr;

            while( (**inPtr != ',') && (**inPtr != '"') && (*inPtr < endPtr)) {
                *inPtr += 1;
            }

            NSUInteger length = (*inPtr - beginPtr);
            if(length>0) {
                name = [[NSString alloc] initWithBytes:beginPtr length:length encoding:NSUTF8StringEncoding];
            }

        }

        return name;
    };

    while(attrChr < lastChr) {
        char c = *attrChr;
        attrChr += 1;
        switch (c) {
            case 'T':
                if(*attrChr == '^') {
                    attrChr += 1;
                    type |= TYPE_POINTER;
                }
                if(*attrChr == '@'){
                    attrChr += 1;
                    type |= TYPE_CLASS;

                }

                if(*attrChr == '{'){
                    type |= TYPE_STRUCT;
                } else {
                    type |= TYPE_GENERIC;
                }

                descriptor = parseName(&attrChr, lastChr);
                NSLog(@"type %@",descriptor);
                break;
            case 'R':
                attrs.readonly = YES;
                break;
            case 'C':
                attrs.copy = YES;
                break;
            case '&':
                attrs.retain = YES;
                break;
            case 'N':
                attrs.nonatomic = YES;
                break;
            case 'G':
                attrs.getter = YES;
                _getter = parseName(&attrChr, lastChr);
                NSLog(@"getter %@",_getter);
                break;
            case 'S':
                attrs.setter = YES;
                _setter = parseName(&attrChr, lastChr);
                NSLog(@"setter %@",_setter);
                break;
            case 'D':
                attrs.dynamic = YES;
                break;
            case 'W':
                attrs.weak = YES;
                break;
            case 'P':
                attrs.garbage = YES;
                break;
            case 'V':
                _ivar = parseName(&attrChr, lastChr);
                NSLog(@"Property iVar %@",_ivar);
                break;
        }
    }
}

@end;



@interface Reflection(Private)
    -(NSMutableSet *) getProperties;
@end

@implementation Reflection {
    NSMutableSet *properties;
    NSMutableArray *superClasses;
}

+(ReflectionCache*)cache {
    static ReflectionCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(){
        instance = [[ReflectionCache alloc] init];

    });
    return instance;
}

+ (id)reflectionFor:(NSObject*)object
{
    if(!object) {
        return nil;
    }
    Class objectClass = [object class];
    return [Reflection reflectionForClass:objectClass];
}

+ (id)reflectionForClass:(Class)objectClass
{
    if(!objectClass) {
        return nil;
    }
    char const *classNameCStr = object_getClassName(objectClass);
    if(!classNameCStr) {
        return nil;
    }
    NSString *className = [NSString stringWithCString:classNameCStr encoding:NSUTF8StringEncoding];
    Reflection *reflection = [[Reflection cache] getReflectionByClassName:className];
    if(!reflection) {
        reflection = [[Reflection alloc] initWithClass:objectClass];
        [[Reflection cache] cacheReflection:reflection];
    }
    return reflection;
}

- (id)initWithClass:(Class)aClass {
    self = [super init];
    if (self) {
        _class = aClass;
        properties = [NSMutableSet set];
        superClasses = [NSMutableArray array];
        if(_class) {
            char const *classNameCStr = object_getClassName(_class);
            if(classNameCStr) {
                _className = [NSString stringWithCString:classNameCStr encoding:NSUTF8StringEncoding];
            }
            [self setup];
        }
    }

    return self;
}

- (void)enumeratePropertiesUsingBlock:(void(^)(Property *aProperty, Reflection *reflection)) block {
    if(!block){
        return;
    }
    [properties enumerateObjectsUsingBlock:^(Property *aProperty, BOOL *stop){
        block(aProperty, self);
    }];
    if(superClasses) {
        [superClasses enumerateObjectsUsingBlock:^(Reflection *reflection, NSUInteger index, BOOL *s1){
            if(reflection) {
                [[reflection getProperties] enumerateObjectsUsingBlock:^(Property *aProperty, BOOL *s2){
                    block(aProperty, reflection);
                }];
            }
        }];
    }
}

-(NSMutableSet *)getProperties {
    return properties;
}

-(void) setup
{
    unsigned int count = 0;
    objc_property_t *rawProperties = class_copyPropertyList(self.class, &count);

    if(!count || (rawProperties == NULL)) {
        return;
    }
    for (unsigned int propertyIdx=0; propertyIdx < count; propertyIdx+=1) {
        objc_property_t property_t = rawProperties[propertyIdx];
        Property *aProperty = [[Property alloc] initWithProperty:property_t];
        [properties addObject:aProperty];
    }
    free(rawProperties);

    [self setupSuperClasses];
}

-(void) setupSuperClasses
{
    Class rootClass = [NSObject class];
    Class objectClass = class_getSuperclass(self.class);

    while(objectClass != rootClass){
        [superClasses addObject:[Reflection reflectionForClass:objectClass]];
        objectClass = class_getSuperclass(objectClass);
    };
}

- (void)dealloc {
    [properties removeAllObjects];
    [superClasses removeAllObjects];
    properties = nil;
    superClasses = nil;
}


@end