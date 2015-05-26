//
// Created by malczak on 01/04/14.
// Copyright (c) 2014 segfaultsoft. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "UIViewController+Silicon.h"

// todo move it
#import "SILogger.h"
#import "SIPGCoreData.h"

#define weakify(id,weak_id) __weak typeof(id) weak_id = id

#define strongify(id,strong_id) __strong typeof(id) strong_id = id

// todo move it
extern NSString * const SI_SILICON;
extern NSString * const SI_LOGGER;
extern NSString * const SI_COREDATA;

@class Higgs;
@class Silicon;

@protocol SiliconInjectable
@end;

@interface Commands : NSObject

-(void) add:(void(^)(Silicon *)) commandBlock named:(NSString*) name;

-(void) remove:(NSString*) name;

-(void) execute:(NSString*) name;

-(void) execute:(NSString*) name completion:(void(^)()) completionBlock;

@end

@interface Silicon : NSObject

+(instancetype) si;
+(instancetype) sharedInstance;

// define shared services
-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock;
-(void) service:(NSString*) serviceName withObject:(id) serviceObject;
-(void) service:(NSString*) serviceName withClass:(Class) serviceClass;

// define services
-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock shared:(BOOL)shared;
-(void) service:(NSString*) serviceName withObject:(id) serviceObject shared:(BOOL)shared;
-(void) service:(NSString*) serviceName withClass:(Class) serviceClass shared:(BOOL)shared;

// define limited instance services
-(void) service:(NSString*) serviceName withBlock:(NSObject*(^)(Silicon *)) serviceBlock count:(NSUInteger)count;
-(void) service:(NSString*) serviceName withObject:(id) serviceObject count:(NSUInteger)count;
-(void) service:(NSString*) serviceName withClass:(Class) serviceClass count:(NSUInteger)count;

// service removal
+(void) removeService:(NSString*) serviceName;
-(void) removeService:(NSString*) serviceName;

// access services
+(id) getService:(NSString*) serviceName;
+(id) service:(NSString*) serviceName;
+(id) get:(NSString*) serviceName;
-(id) getService:(NSString*) serviceName;
-(id) service:(NSString*) serviceName;
-(id) get:(NSString*) serviceName;

// wire object with silicon services
-(void)wire:(NSObject*)object;

@property (nonatomic, readonly) Commands *commands;

// store all wired objects in weak table (default NO)
@property (nonatomic, assign) BOOL trackAllWiredObjects;

// force service resolving while performing object wiring (default NO)
@property (nonatomic, assign) BOOL resolveServicesOnWire;

@end


typedef NS_ENUM(NSUInteger, HiggsType);

@interface Higgs : NSObject {
    dispatch_semaphore_t initSem;
    dispatch_once_t setupToken;
    HiggsType type;
    BOOL shared;
    id definition;
    id object;
}

@property (nonatomic, weak) Silicon *si;
@property (nonatomic, readonly) NSString *className;

-(id) resolve;

+(id) higgsWithObject:(NSObject*) object shared:(BOOL) shared;

+(id) higgsWithClass:(Class) objectClass shared:(BOOL) shared;

+(id) higgsWithBlock:(NSObject*(^)(Silicon *si)) objectBlock shared:(BOOL) shared;

@end