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

@class Silicon;
@class Higgs;
@class Task;

@protocol SiliconInjectable
@end;


@interface Silicon : NSObject

+(instancetype) si;
+(instancetype) sharedInstance;

// simple tasks
-(void) task:(NSString*) taskName withBlock:(void(^)(Task *t)) taskBlock count:(NSUInteger)count;
-(void) removeTask:(NSString*) taskName;
-(void) run:(NSString*) taskName completion:(void(^)()) completionBlock;
-(void) run:(NSString*) taskName;

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

@end


@interface Task: NSObject

-(void) exec:(void(^)(Task *t)) block;

@end;


typedef NS_ENUM(NSUInteger, HiggsType);

@interface Higgs : NSObject
{
    dispatch_semaphore_t initSema;

    HiggsType type;
    
    BOOL shared;
    
    NSInteger count;
    
    id definition;
    id object;
}

@property (nonatomic, weak) Silicon *si;

@property (nonatomic, readonly) BOOL available;

@property (nonatomic, readonly) BOOL resolved;

@property (nonatomic, readonly) NSString *className;

-(id) resolve;

+(id) higgsWithObject:(NSObject*) object shared:(BOOL) shared count:(NSInteger) count;

+(id) higgsWithClass:(Class) objectClass shared:(BOOL) shared count:(NSInteger) count;

+(id) higgsWithBlock:(NSObject*(^)(Silicon *si)) objectBlock shared:(BOOL) shared count:(NSInteger) count;

@end