//
//  SIPGCoreData.m
//  WodRandomizer
//
//  Created by malczak on 31/08/14.
//  Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import "SIPGCoreData.h"
#import "WRSQLiteCoreDataStack.h"

@implementation SIPGCoreData

@synthesize storeContext = _storeContext;
@synthesize mainContext = _mainContext;
@synthesize savingContext = _savingContext;

-(id) initWithStack:(MLCoreDataStack*) stack
{
    self = [super init];
    if(self) {
        _stack = stack;
        [_stack loadStack];
        
        [MLCoreDataStack setDefaultStack:_stack];
    }
    return self;
}

-(BOOL) seedingRequired
{
    return ((WRSQLiteCoreDataStack*)self.stack).seedingRequired;
}

- (NSManagedObjectContext *)managedObjectContext {
    NSDictionary * threadDictionary = [[NSThread currentThread] threadDictionary];
    NSManagedObjectContext * threadContext = threadDictionary[MLActiveRecordManagedObjectContextKey];
    
    if (threadContext) {
        return threadContext;
    }
    else if ([NSThread isMainThread]) {
        return self.mainContext;
    }
    else {
        return self.savingContext;
    }
}

-(NSPersistentStoreCoordinator *) persistentStoreCoordinator
{
    return [self.stack persistentStoreCoordinator];
}

-(NSManagedObjectModel *) managedObjectModel
{
    return [self.stack managedObjectModel];
}

-(NSPersistentStore *) persistentStore
{
    return [self.stack persistentStore];
}

- (NSManagedObjectContext *)storeContext {
    if (!_storeContext) {
        _storeContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _storeContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
    }
    
    return _storeContext;
}

- (NSManagedObjectContext *)mainContext {
    if (!_mainContext) {
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _mainContext.parentContext = self.storeContext;
    }
    
    return _mainContext;
}

- (NSManagedObjectContext *)savingContext {
    if (!_savingContext) {
        _savingContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _savingContext.parentContext = self.mainContext;
    }
    
    return _savingContext;
}

@end
