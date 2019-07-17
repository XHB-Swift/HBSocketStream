//
//  HBRunLoopThread.m
//  HBRunLoopThread
//
//  Created by 谢鸿标 on 2019/7/11.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import "HBRunLoopThread.h"

@interface HBRunLoopThread ()

@property (nonatomic, getter=canRespondDelegate) BOOL respondDelegate;
@property (nonatomic, strong) NSRunLoop *currentRunLoop;

@end

@implementation HBRunLoopThread

- (void)setRunLoopThreadDelegate:(id<HBRunLoopThreadDelegate>)runLoopThreadDelegate {
    _runLoopThreadDelegate = runLoopThreadDelegate;
    _respondDelegate = (runLoopThreadDelegate != nil);
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

- (void)main {
    [super main];
    self.currentRunLoop = [NSRunLoop currentRunLoop];
    if (self.canRespondDelegate && [self.runLoopThreadDelegate respondsToSelector:@selector(runLoopThread:willEnterRunLoop:)]) {
        [self.runLoopThreadDelegate runLoopThread:self willEnterRunLoop:self.currentRunLoop];
    }
    BOOL running = YES;
    while (running) {
        running = [self.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    if (self.canRespondDelegate && [self.runLoopThreadDelegate respondsToSelector:@selector(runLoopThread:didExitRunLoop:)]) {
        [self.runLoopThreadDelegate runLoopThread:self didExitRunLoop:self.currentRunLoop];
    }
}

@end
