//
//  SICoreDataInterface.h
//  WodRandomizer
//
//  Created by malczak on 31/08/14.
//  Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import <CoreData/CoreData.h>

@protocol SICoreDataInterface <NSObject>


@required

// CoreData main context connected to persisten store
@property (nonatomic, readonly, strong) NSManagedObjectContext * managedObjectContext;

// CoreData main storage coordinator
@property (nonatomic, readonly, strong) NSPersistentStoreCoordinator * persistentStoreCoordinator;

// Data model
@property (nonatomic, readonly, strong) NSManagedObjectModel * managedObjectModel;

// Persistent store
@property (nonatomic, readonly, strong) NSPersistentStore * persistentStore;


@optional

// CoreData context connected to persistent store
@property (nonatomic, readonly, strong) NSManagedObjectContext * storeContext;

// CoreData context intended to be used on main thread for data read
@property (nonatomic, readonly, strong) NSManagedObjectContext * mainContext;

// CoreData CRUD context
@property (nonatomic, readonly, strong) NSManagedObjectContext * savingContext;


@end
