//
//  YKIntercepter.m
//  CrashDemo
//
//  Created by wanyakun on 16/7/5.
//  Copyright © 2016年 com.ucaiyuan. All rights reserved.
//

#import "YKIntercepter.h"
#import <objc/runtime.h>
#import "NSObject+Swizzle.h"

#pragma mark Private Swizzle
#pragma mark - NSArray Method Swizzle
@interface NSArray (Swizzle)

- (id)yk_objectAtIndex:(NSUInteger)index;

@end

@implementation NSArray (Swizzle)

- (id)yk_objectAtIndex:(NSUInteger)index {
    if (index < self.count) {
        return [self yk_objectAtIndex:index];
    }
    
    return nil;
}

@end

#pragma mark - NSMutableArray Method Swizzle
@interface NSMutableArray (Swizzle)

- (id)yk_objectAtIndex:(NSUInteger)index;
- (void)yk_addObject:(id)anObject;
- (void)yk_insertObject:(id)anObject atIndex:(NSUInteger)index;
- (void)yk_removeObjectAtIndex:(NSUInteger)index;
- (void)yk_replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject;

@end

@implementation NSMutableArray (Swizzle)

- (id)yk_objectAtIndex:(NSUInteger)index {
    if (index < self.count) {
        return [self yk_objectAtIndex:index];
    }
    
    return nil;
}

- (void)yk_addObject:(id)anObject {
    if (anObject != nil && [anObject isKindOfClass:[NSNull class]] == NO) {
        [self yk_addObject:anObject];
    }
}

- (void)yk_insertObject:(id)anObject atIndex:(NSUInteger)index {
    if (index <= self.count && anObject != nil && [anObject isKindOfClass:[NSNull class]] == NO) {
        [self yk_insertObject:anObject atIndex:index];
    }
}

- (void)yk_removeObjectAtIndex:(NSUInteger)index {
    if (index < self.count) {
        [self yk_removeObjectAtIndex:index];
    }
}

- (void)yk_replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject {
    if (index < self.count && anObject != nil && [anObject isKindOfClass:[NSNull class]] == NO) {
        [self yk_replaceObjectAtIndex:index withObject:anObject];
    }
}

@end

#pragma mark YKIntercepter
#pragma mark - Implementation YKIntercepter
@implementation YKIntercepter

+ (void)load {
    [super load];
    [YKIntercepter sharedInstance];
}

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static YKIntercepter *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YKIntercepter alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //替换NSArray方法
        [objc_getClass("__NSArrayI") swizzleMethod:@selector(objectAtIndex:) withMethod:@selector(yk_objectAtIndex:) error:nil];
        //替换NSMutableArray方法
        [objc_getClass("__NSArrayM") swizzleMethod:@selector(objectAtIndex:) withMethod:@selector(yk_objectAtIndex:) error:nil];
        [objc_getClass("__NSArrayM") swizzleMethod:@selector(addObject:) withMethod:@selector(yk_addObject:) error:nil];
        [objc_getClass("__NSArrayM") swizzleMethod:@selector(insertObject:atIndex:) withMethod:@selector(yk_insertObject:atIndex:) error:nil];
        [objc_getClass("__NSArrayM") swizzleMethod:@selector(removeObjectAtIndex:) withMethod:@selector(yk_removeObjectAtIndex:) error:nil];
        [objc_getClass("__NSArrayM") swizzleMethod:@selector(replaceObjectAtIndex:withObject:) withMethod:@selector(yk_replaceObjectAtIndex:withObject:) error:nil];
    }
    return self;
}

@end




