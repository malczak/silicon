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

@property (nonatomic, readonly, strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic, readonly, strong) NSPersistentStoreCoordinator * persistentStoreCoordinator;
@property (nonatomic, readonly, strong) NSManagedObjectModel * managedObjectModel;
@property (nonatomic, readonly, strong) NSPersistentStore * persistentStore;

- (NSManagedObjectContext *)newConfinementContext;

@end
