//
// Created by malczak on 22/06/14.
// Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Property : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *serviceName;
@property (nonatomic, readonly) NSString *attributes;
@property (nonatomic, readonly) NSString *ivar;
@property (nonatomic, readonly) NSString *setter;
@property (nonatomic, readonly) NSString *getter;

-(id) initWithProperty:(objc_property_t)property_t;

-(BOOL) isGeneric;

-(BOOL) isClass;

-(BOOL) isCopy;

-(BOOL) isReadonly;

-(BOOL) isNonatomic;

-(BOOL) isDynamic;

-(BOOL) isWeak;

-(BOOL) hasSetter;

-(BOOL) hasGetter;

-(BOOL) hasPrefix;

-(id) resolve; // resolve Class Name - nil for non object properties

-(NSString*) resolveServiceName; // resolve potential class type

-(NSString*) nameRemovingPrefix;

@end

@interface Reflection : NSObject

@property (nonatomic, readonly) NSString *className;
@property (nonatomic, assign) Class class;

+ (id)reflectionFor:(NSObject*)object;
+ (id)reflectionForClass:(Class)objectClass;

- (id)initWithClass:(Class)aClass;

- (void)enumeratePropertiesUsingBlock:(void(^)(Property *aProperty, Reflection *reflection)) block;

@end