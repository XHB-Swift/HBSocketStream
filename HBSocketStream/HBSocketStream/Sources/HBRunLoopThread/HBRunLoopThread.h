//
//  HBRunLoopThread.h
//  HBRunLoopThread
//
//  Created by 谢鸿标 on 2019/7/11.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HBRunLoopThread;

@protocol HBRunLoopThreadDelegate <NSObject>

/**
 即将进入RunLoop，该时机用于添加RunLoop的资源，使RunLoop运行

 @param thread 线程
 @param runLoop 当前线程RunLoop
 */
- (void)runLoopThread:(HBRunLoopThread *)thread willEnterRunLoop:(NSRunLoop *)runLoop;

/**
 已经退出RunLoop，该时机用于移除RunLoop的资源，终止RunLoop运行
 
 注：如果RunLoop的资源一直没有事件到来（例如：NSPort对象不被处理），该方法永远不会被执行（原因：RunLoop没有事做，线程进入休眠），需要手动将RunLoop的资源在合适时机释放（例如：[runLoop removePort:port forMode:NSDefaultRunLoopMode];）且调用CFRunLoopStop(r1)方法强制关闭RunLoop，以下方法才会被执行

 @param thread 线程
 @param runLoop 当前线程RunLoop
 */
- (void)runLoopThread:(HBRunLoopThread *)thread didExitRunLoop:(NSRunLoop *)runLoop;

@end

@interface HBRunLoopThread : NSThread

@property (nonatomic, weak) id<HBRunLoopThreadDelegate> runLoopThreadDelegate;

@property (nonatomic, strong, readonly) NSRunLoop *currentRunLoop;

@end

NS_ASSUME_NONNULL_END
