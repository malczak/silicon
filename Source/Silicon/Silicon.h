//
// Created by malczak on 01/04/14.
// Copyright (c) 2014 segfaultsoft. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "UIViewController+Silicon.h"

@class Higgs;
@class Silicon;

@protocol SiliconInjectable
@end;

@interface Silicon : NSObject

+(instancetype) si;
+(instancetype) sharedInstance;

// define services
-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock;
-(void) service:(NSString*) serviceName withObject:(id) serviceObject;
-(void) service:(NSString*) serviceName withClass:(Class) serviceClass;
-(void) service:(NSString*) serviceName withClassName:(NSString*) serviceClassName;

// access services
+(id) getService:(NSString*) serviceName;
+(id) service:(NSString*) serviceName;
+(id) get:(NSString*) serviceName;
-(id) getService:(NSString*) serviceName;
-(id) service:(NSString*) serviceName;
-(id) get:(NSString*) serviceName;

// wire object with silicon services
-(void)wire:(NSObject*)object;

@end


typedef NS_ENUM(NSUInteger, HiggsType);

@interface Higgs : NSObject {
    dispatch_semaphore_t initSem;
    dispatch_once_t initToken;
    dispatch_once_t setupToken;
    HiggsType type;
    id definition;
    id object;
}

@property (nonatomic, weak) Silicon *si;
@property (nonatomic, readonly) NSString *className;

-(id)resolve;

+(id) higgsWithObject:(NSObject*) object;

+(id) higgsWithClass:(Class) objectClass;

+(id) higgsWithClassName:(NSObject*) objectClassName;

+(id) higgsWithBlock:(NSObject*(^)(Silicon *si)) objectBlock;

@end