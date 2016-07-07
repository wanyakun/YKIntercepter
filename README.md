## Objective-C防止数组越界

最近项目中多次出现因为数组越界导致的app crash，因为总有人对数据进行读取、插入、删除和替换的过程中出现数组越界的情况。

#### Crash原因

- 读取：index超出array的索引范围
- 插入：index大于count、插入的object为nil或者Null
- 删除：index超出array的索引范围
- 替换：index超出array的索引范围、替换的object为nil或者Null

#### 解决思路

由于项目中存在有拦截器，在runtime中使用Aspects对UIViewController生命周期进行method swizzle。所以，首先想到的是是否可以对NSArray和NSMutableArray的这些方法进行替换，在替换的方法中对条件进行判断，来解决crash问题。

#### 解决方法

由于Objective-C方法调用是通过runtime进行objc_msgSend来决定具体调用哪个SEL，所以要想实现method swizzle，其实就是对SEL进行替换。对于Method Swizzling请参考这篇文章：http://nshipster.com/method-swizzling/

- 首先要对NSObject进行扩充，增加swizzleMethod方法，用于对系统方法进行替换

```objc
#import <Foundation/Foundation.h>

@interface NSObject (Swizzle)
/**
 *  对系统方法进行替换
 *
 *  @param originalSelector 被替换的方法
 *  @param swizzledSelector 实际使用的方法
 *  @param error            替换过程中出现的错误，如果没有错误则为nil
 *
 *  @return 是否替换成功
 */
+ (BOOL)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector error:(NSError **)error;

@end
  
#import "NSObject+Swizzle.h"
#import <objc/runtime.h>

@implementation NSObject (Swizzle)

@implementation NSObject (Swizzle)

+ (BOOL)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector error:(NSError **)error {
    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    if (!originalMethod) {
        NSString *string = [NSString stringWithFormat:@"%@ 类没有找到 %@ 方法", NSStringFromClass([self class]), NSStringFromSelector(originalSelector)];
        *error = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:-1 userInfo:[NSDictionary dictionaryWithObject:string forKey:NSLocalizedDescriptionKey]];
        return NO;
    }
    
    Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
    if (!swizzledMethod) {
        NSString *string = [NSString stringWithFormat:@"%@ 类没有找到 %@ 方法", NSStringFromClass([self class]), NSStringFromSelector(swizzledSelector)];
        *error = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:-1 userInfo:[NSDictionary dictionaryWithObject:string forKey:NSLocalizedDescriptionKey]];
        return NO;
    }
    
    if (class_addMethod([self class], originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod([self class], swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    return YES;
}
```

- 书写拦截器，对NSArray和NSMutableArray的方法进行替换，主要替换的方法包括：objectAtIndex：，addObject:，insertObject:atIndex:，removeObjectAtIndex:和replaceObjectAtIndex:withObject:。

```objc
#import <Foundation/Foundation.h>

@interface YKIntercepter : NSObject

@end

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
```

对于YKIntercepter：

 +(void)load方法：上方的文章中提到，所有类的该方法在Objective-C runtime中会自动被调用。大名鼎鼎的IQKeyboardManager之所以不用写一行代码就可以引入，其实用的也是这种方法。

dispatch_once_t：保证方法swizzling只被执行一次

yk开头方法：yk开头的方法为替换方法，方法内部调用yk开头的方法并不会形成递归，因为方法被替换后，调用yk开头的方法实际上执行的是系统的方法。

#### 使用方法

使用方法不需要做任何改变，还是直接使用系统方法，对现有代码0入侵。