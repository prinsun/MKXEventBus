//
//  MKXEventBus.m
//  MKXEventBus
//
//  Created by MK on 16/3/2.
//  Copyright © 2016年 makeex. All rights reserved.
//

#import "MKXEventBus.h"
#import "MKXMergeableEvent.h"
#import "MKXGeneralEvent.h"

/**
 *  事件订阅者
 */
@interface MKXEventSubscriber : NSObject

@property (nonatomic, weak) NSObject *target;
@property (nonatomic, copy) BOOL (^filter)(__kindof MKXEvent *);
@property (nonatomic, copy) void (^action)(__kindof MKXEvent *);
@property (nonatomic, strong) dispatch_queue_t handleQueue;

@end

@implementation MKXEventSubscriber
@end

//////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Subscriber Context
//////////////////////////////////////////////////////////////////////////////////////

#define kMKXCurrentSubscriberContext @"MKXCurrentSubscriberContext"

/**
 *  订阅者上下文，用于管理调度队列切换
 */
@interface MKXSubscriberContext : NSObject

+ (instancetype)contextWithQueue:(dispatch_queue_t)queue
                          parent:(MKXSubscriberContext *)parent;

+ (MKXSubscriberContext *)current;

+ (void)setCurrent:(MKXSubscriberContext *)context;

@property (nonatomic, strong, readonly) dispatch_queue_t queue;
@property (nonatomic, strong, readonly) MKXSubscriberContext *parent;

@end

@implementation MKXSubscriberContext

+ (instancetype)contextWithQueue:(dispatch_queue_t)queue
                          parent:(MKXSubscriberContext *)parent {
    MKXSubscriberContext *context = [MKXSubscriberContext new];
    context->_queue = queue;
    context->_parent = parent;
    return context;
}

+ (MKXSubscriberContext *)current {
    MKXSubscriberContext *context = [NSThread currentThread].threadDictionary[kMKXCurrentSubscriberContext];
    if (context == nil) {
        context = [self contextWithQueue:dispatch_get_main_queue() parent:nil];
        [self setCurrent:context];
    }
    return context;
}

+ (void)setCurrent:(MKXSubscriberContext *)context {
    if (context == nil) {
        [[NSThread currentThread].threadDictionary removeObjectForKey:kMKXCurrentSubscriberContext];
    } else {
        [NSThread currentThread].threadDictionary[kMKXCurrentSubscriberContext] = context;
    }
}

@end

//////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Event Bus
//////////////////////////////////////////////////////////////////////////////////////

@interface MKXEventBus ()

@property (nonatomic, strong, readonly) dispatch_queue_t operateQueue;
@property (nonatomic, strong, readonly) NSMutableDictionary *pendingMergeableEvents;
@property (nonatomic, strong, readonly) NSMutableDictionary *subscribers;

@end

@implementation MKXEventBus

+ (instancetype)sharedBus {
    static MKXEventBus *instance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

+ (void)beginSubscribe:(dispatch_queue_t)handleQueue {
    MKXSubscriberContext *context = [MKXSubscriberContext contextWithQueue:handleQueue
                                                          parent:MKXSubscriberContext.current];
    [MKXSubscriberContext setCurrent:context];
}

+ (void)endSubscribe {
    MKXSubscriberContext *context = [MKXSubscriberContext current].parent;
    [MKXSubscriberContext setCurrent:context];
}

- (instancetype)init {
    if (self = [super init]) {
        _operateQueue = dispatch_queue_create("com.makeex.eventbus.queue", NULL);
        _pendingMergeableEvents = [[NSMutableDictionary alloc] initWithCapacity:10];
        _subscribers = [[NSMutableDictionary alloc] initWithCapacity:10];
    }
    return self;
}

- (void)publish:(__kindof MKXEvent *)event {
    static NSMutableDictionary<NSString *, NSNumber *> *publishTimes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        publishTimes = [NSMutableDictionary new];
    });
    
    NSString *subscriberKey = NSStringFromClass(event.class);
    
    dispatch_async(self.observationInfo, ^{
        NSNumber *times = publishTimes[subscriberKey];
        if (times == nil) { times = @0; }
        times = @(times.unsignedLongValue + 1);
        publishTimes[subscriberKey] = times;
        
        // 可合并的事件
        if ([event conformsToProtocol:@protocol(MKXMergeableEvent)]) {
            [self __merge:event withKey:subscriberKey];
        } else {
            [self __publish:event withKey:subscriberKey];
        }
        
        // 每个事件发布 20 次进行一次回收处理
        if (times.unsignedLongValue > 20) {
            publishTimes[subscriberKey] = @0;
            [self __recycleSubscriber:subscriberKey];
        }
    });
}

- (void)publish:(__kindof MKXEvent *)event after:(NSTimeInterval)delay {
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(time, self.operateQueue, ^{
        [self publish:event];
    });
}

- (void)publishGeneralEventWithName:(NSString *)eventName {
    [self publishGeneralEventWithName:eventName tag:0];
}

- (void)publishGeneralEventWithName:(NSString *)eventName tag:(NSUInteger)tag {
    MKXGeneralEvent *event = [MKXGeneralEvent new];
    event.name = eventName;
    event.tag = tag;
    [self publish:event];
}

- (void)__merge:(__kindof MKXEvent *)event withKey:(NSString *)subscriberKey {
    __block NSMutableArray *mergeableEvents = self.pendingMergeableEvents[subscriberKey];
    if (mergeableEvents == nil) {
        mergeableEvents = [NSMutableArray new];
        self.pendingMergeableEvents[subscriberKey] = mergeableEvents;
    }
    
    BOOL merged = NO;
    for (NSUInteger i = 0; i < mergeableEvents.count; i++) {
        id mergeableInfo = mergeableEvents[i];
        id<MKXMergeableEvent> mergeableEvent = mergeableInfo[@"event"];
        merged = [mergeableEvent merge:event];
        if (merged) {
            mergeableInfo[@"event_id"] = @(event.eventId);
            break;
        }
    }
    
    NSTimeInterval mergeTimeout = 1.0;
    NSTimeInterval mergeInterval = 0.25;
    if ([event.class respondsToSelector:@selector(mergeTimeout)]) {
        mergeTimeout = [event.class mergeTimeout];
    }
    if ([event.class respondsToSelector:@selector(mergeInterval)]) {
        mergeInterval = [event.class mergeInterval];
    }
    
    if (!merged) {
        [mergeableEvents addObject:@{@"event_id": @(event.eventId), @"event": event}];
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(mergeTimeout * NSEC_PER_SEC));
        dispatch_after(time, self.operateQueue, ^{
            for (id mergeableInfo in mergeableEvents) {
                if (mergeableInfo[@"event"] == event) {
                    [self __publish:event withKey:subscriberKey];
                    [mergeableEvents removeObject:event];
                    
                    if (mergeableEvents.count == 0) {
                        [self.pendingMergeableEvents removeObjectForKey:subscriberKey];
                    }
                    return;
                }
            }
        });
    }
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(mergeInterval * NSEC_PER_SEC));
    dispatch_after(time, self.operateQueue, ^{
        for (id mergeableInfo in mergeableEvents) {
            if ([mergeableInfo[@"event_id"] unsignedLongValue] == event.eventId) {
                [self __publish:event withKey:subscriberKey];
                [mergeableEvents removeObject:event];
                
                if (mergeableEvents.count == 0) {
                    [self.pendingMergeableEvents removeObjectForKey:subscriberKey];
                }
                return;
            }
        }
    });
}

- (void)__publish:(__kindof MKXEvent *)event withKey:(NSString *)subscriberKey {
    NSMutableArray *subscribers = self.subscribers[subscriberKey];
    for (MKXEventSubscriber *subscriber in subscribers) {
        if (subscriber.target == nil) {
            continue;
        }
        if (subscriber.filter != nil && !subscriber.filter(event)) {
            continue;
        }
        
        dispatch_async(subscriber.handleQueue, ^{
            subscriber.action(event);
        });
    }
}

/**
 *  回收无效的订阅者
 *
 *  @param event 要回收的订阅事件
 */
- (void)__recycleSubscriber:(NSString *)subscriberKey {
    NSMutableArray *subscribers = self.subscribers[subscriberKey];
    if (subscribers == nil) return;
    
    for (NSInteger i = subscribers.count - 1; i >= 0; i--) {
        MKXEventSubscriber *subscriber = subscribers[i];
        if (subscriber.target == nil) {
            [subscribers removeObjectAtIndex:i];
        }
    }
    
    if (subscribers.count == 0) {
        [self.subscribers removeObjectForKey:subscriberKey];
    }
}

//////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Subscribes
//////////////////////////////////////////////////////////////////////////////////////

static id MKXEventFilterTrue()  { return nil; }

- (void)subscribe:(Class)eventClass for:(NSObject *)target with:(void (^)(__kindof MKXEvent *))block {
    [self subscribe:eventClass for:target filter:MKXEventFilterTrue() with:block];
}

- (void)subscribe:(Class)eventClass for:(NSObject *)target action:(SEL)action {
    [self subscribe:eventClass for:target filter:MKXEventFilterTrue() action:action];
}

- (void)subscribe:(Class)eventClass for:(NSObject *)target
           filter:(BOOL (^)(__kindof MKXEvent *))filter
           action:(SEL)action {
    __weak __typeof(target) weakTarget = target;
    void (^handleBlock)(__kindof MKXEvent *) = ^(__kindof MKXEvent *event) {
        __strong __typeof(weakTarget) strongTarget = weakTarget;
        if (strongTarget == nil) return;
        
        NSMethodSignature *methodSignature = [strongTarget methodSignatureForSelector:action];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        invocation.target = strongTarget;
        invocation.selector = action;
        
        NSUInteger argCount = [methodSignature numberOfArguments];
        NSAssert(argCount <= 3, @"event handle method arguments must less than 2");
        
        if (argCount == 3) {
            void *value = (__bridge void *)(event);
            [invocation setArgument:&value atIndex:2];
        }
        
        [invocation retainArguments];
        [invocation invoke];
    };
    
    [self subscribe:eventClass for:target filter:filter with:handleBlock];
}

- (void)subscribe:(Class)eventClass for:(NSObject *)target
           filter:(BOOL (^)(__kindof MKXEvent *))filter
             with:(void (^)(__kindof MKXEvent *))block {
    dispatch_queue_t handleQueue = [MKXSubscriberContext current].queue;
    NSString *subscriberKey = NSStringFromClass(eventClass);
   
    dispatch_sync(self.operateQueue, ^{
        MKXEventSubscriber *subscriber = [[MKXEventSubscriber alloc] init];
        subscriber.target = target;
        subscriber.filter = filter;
        subscriber.action = block;
        subscriber.handleQueue = handleQueue;
        
        NSMutableArray *subscribers = self.subscribers[subscriberKey];
        if (subscribers == nil) {
            subscribers = [NSMutableArray new];
            self.subscribers[subscriberKey] = subscribers;
        }
        
        [subscribers addObject:subscriber];
    });
}

- (void)subscribeGeneralEventWithName:(NSString *)eventName
                                  for:(NSObject *)target
                                block:(void(^)(void))block {
    [self subscribe:MKXGeneralEvent.class for:target filter:^BOOL(MKXGeneralEvent *event) {
        return [event.name isEqualToString:eventName];
    } with:^(__unused MKXEvent *_) {
        block();
    }];
}

- (void)subscribeGeneralEventWithName:(NSString *)eventName
                                  for:(NSObject *)target
                               action:(SEL)action {
    [self subscribe:MKXGeneralEvent.class for:target filter:^BOOL(MKXGeneralEvent *event) {
        return [event.name isEqualToString:eventName];
    } action:action];
}

- (void)unsubscribe:(Class)eventClass for:(NSObject *)target {
    NSString *subscriberKey = NSStringFromClass(eventClass);
   
    dispatch_sync(self.operateQueue, ^{
        NSMutableArray *subscribers = self.subscribers[subscriberKey];
        if (subscribers == nil) return;
        
        for (NSInteger i = subscribers.count - 1; i >= 0; i--) {
            MKXEventSubscriber *subscriber = subscribers[i];
            if (subscriber.target == target) {
                [subscribers removeObjectAtIndex:i];
            }
        }
        
        if (subscribers.count == 0) {
            [self.subscribers removeObjectForKey:subscriberKey];
        }
    });
}

- (void)unsubscribe:(NSObject *)target {
    dispatch_sync(self.operateQueue, ^{
        for (NSMutableArray *subscribers in self.subscribers.allValues) {
            for (NSInteger i = subscribers.count - 1; i >= 0; i--) {
                MKXEventSubscriber *subscriber = subscribers[i];
                if (subscriber.target == target) {
                    [subscribers removeObjectAtIndex:i];
                }
            }
        }
    });
}

@end
