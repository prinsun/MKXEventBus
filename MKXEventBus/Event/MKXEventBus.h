//
//  MKXEventBus.h
//  MKXEventBus
//
//  Created by MK on 16/3/2.
//  Copyright © 2016年 makeex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MKXEventBus/MKXEvent.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  全局的事件分发总线
 */
@interface MKXEventBus : NSObject

/**
 *  全局共享的事件总线
 *
 *  @return 事件分发总线
 */
+ (instancetype)sharedBus;

/**
 *  发布一个事件
 *
 *  @param event 要发布的事件
 */
- (void)publish:(__kindof MKXEvent *)event;

/**
 *  延时发布一个事件
 *
 *  @param event 要发布的事件
 *  @param delay 延时值
 */
- (void)publish:(__kindof MKXEvent *)event after:(NSTimeInterval)delay;

/**
 *  发布一个 GeneralEvent
 *
 *  @param eventName 事件名称
 */
- (void)publishGeneralEventWithName:(NSString *)eventName;

/**
 *  发布一个 GeneralEvent
 *
 *  @param eventName 事件名称
 *  @param tag       事件标记
 */
- (void)publishGeneralEventWithName:(NSString *)eventName tag:(NSUInteger)tag;

/*
 *  指定时间订阅者在什么队列触发，默认是 diaptch_queue_main
 */
+ (void)beginSubscribe:(dispatch_queue_t)handleQueue;
+ (void)endSubscribe;

/**
 *  订阅是个事件
 *
 *  @param eventClass 事件类型
 *  @param target     处理该事件的对象
 *  @param block      具体处理块
 */
- (void)subscribe:(Class)eventClass for:(NSObject *)target with:(void (^)(__kindof MKXEvent *))block;

/**
 *  订阅一个事件，并指定过滤
 *
 *  @param eventClass 事件类型
 *  @param target     处理该事件的对象
 *  @param filter     事件过滤器
 *  @param block      具体处理块
 */
- (void)subscribe:(Class)eventClass for:(NSObject *)target
           filter:(BOOL (^)(__kindof MKXEvent *))filter
             with:(void (^)(__kindof MKXEvent *))block;

/*
 *  通过 selector 来订阅事件，与 block 订阅类似，但不用关心循环引用问题
 */
- (void)subscribe:(Class)eventClass for:(NSObject *)target action:(SEL)action;
- (void)subscribe:(Class)eventClass for:(NSObject *)target
           filter:(BOOL (^)(__kindof MKXEvent *))filter
           action:(SEL)action;

/**
 *  订阅 GeneralEvent
 */
- (void)subscribeGeneralEventWithName:(NSString *)eventName
                                  for:(NSObject *)target
                                block:(void(^)(void))block;
- (void)subscribeGeneralEventWithName:(NSString *)eventName
                                  for:(NSObject *)target
                               action:(SEL)action;

/**
 *  取消某个对象对特定事件的订阅
 *
 *  @param eventClass 要取消的事件类型
 *  @param target     处理该事件的对象
 */
- (void)unsubscribe:(Class)eventClass for:(NSObject *)target;

/**
 *  取消一个对象所订阅的所有事件
 *
 *  @param target 要取消订阅事件的对象
 */
- (void)unsubscribe:(NSObject *)target;

@end

NS_ASSUME_NONNULL_END
