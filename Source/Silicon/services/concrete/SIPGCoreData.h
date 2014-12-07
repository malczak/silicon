//
//  SIPGCoreData.h
//  WodRandomizer
//
//  Created by malczak on 31/08/14.
//  Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import "SICoreDataInterface.h"
#import "MLActiveRecord.h"

@interface SIPGCoreData : NSObject <SICoreDataInterface>

// MLDataStack
@property (nonatomic, readonly, strong) MLCoreDataStack *stack;

// CoreData main context connected to persistent store
@property (nonatomic, readonly, strong) NSManagedObjectContext * managedObjectContext;

// CoreData main storage coordinator
@property (nonatomic, readonly, strong) NSPersistentStoreCoordinator * persistentStoreCoordinator;

// Data model
@property (nonatomic, readonly, strong) NSManagedObjectModel * managedObjectModel;

// Persistent store
@property (nonatomic, readonly, strong) NSPersistentStore * persistentStore;

// CoreData context connected to persistent store
@property (nonatomic, readonly, strong) NSManagedObjectContext * storeContext;

// CoreData context intended to be used on main thread for data read
@property (nonatomic, readonly, strong) NSManagedObjectContext * mainContext;

// CoreData CRUD context
@property (nonatomic, readonly, strong) NSManagedObjectContext * savingContext;

-(id) initWithStack:(MLCoreDataStack*) stack;

@end
