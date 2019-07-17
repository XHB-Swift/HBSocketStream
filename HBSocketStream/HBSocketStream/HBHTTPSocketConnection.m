//
//  HBHTTPSocketConnection.m
//  HBSocketStream
//
//  Created by 谢鸿标 on 2019/7/17.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import "HBHTTPSocketConnection.h"
#import "HBHTTPSerializer.h"
#import "HBSocketStream.h"

#pragma mark - 单个任务

@class HBHTTPSocketConnectionTask;

@protocol HBHTTPSocketConnectionTaskDelegate <NSObject>

- (void)socketConnectionTask:(HBHTTPSocketConnectionTask *)connectionTask didReceiveData:(NSData *)data;

- (void)socketConnectionTask:(HBHTTPSocketConnectionTask *)connectionTask didDetectRedirectionResponse:(NSHTTPURLResponse *)redirectionResponse;

- (void)socketConnectionTask:(HBHTTPSocketConnectionTask *)connectionTask didCompleteWithError:(NSError *_Nullable)error;

@end

@interface HBHTTPSocketConnectionTask : NSObject <HBSocketStreamDelegate>

@property (nonatomic, weak) id<HBHTTPSocketConnectionTaskDelegate> connectionTaskDelegate;
@property (nonatomic, strong) HBSocketStream *socketStream;
@property (nonatomic, strong) HBHTTPSerializer *httpSerializer;
@property (nonatomic, strong) NSSet<NSNumber *> *redirectionCodes;

- (instancetype _Nullable)initWithRequest:(NSURLRequest *)request;

- (void)startTask;

@end

@implementation HBHTTPSocketConnectionTask

- (instancetype _Nullable)initWithRequest:(NSURLRequest *)request {
    if (request) {
        if (self = [super init]) {
            _socketStream = [[HBSocketStream alloc] init];
            _socketStream.socketStreamDelegate = self;
            _httpSerializer = [HBHTTPSerializer httpSerializerWithRequest:request];
            NSNumber *codes[4] = {@301,@302,@303,@304};
            _redirectionCodes = [NSSet setWithObjects:codes count:4];
        }
        return self;
    }
    return nil;
}

- (void)startTask {
    NSURL *URL = self.httpSerializer.requestURL;
    NSString *scheme = URL.scheme;
    NSString *host = URL.host;
    uint16_t port = (URL.port ?: @(80)).intValue;
    if ([scheme isEqualToString:@"https"]) {
        port = 443;
        self.socketStream.sslSetting = @{};
    }
    [self.socketStream connectToHost:host port:port];
}

- (void)socketStream:(HBSocketStream *)socketStream didConnectWithError:(NSError *)error {
    if (error) {
        if (self.connectionTaskDelegate && [self.connectionTaskDelegate respondsToSelector:@selector(socketConnectionTask:didCompleteWithError:)]) {
            [self.connectionTaskDelegate socketConnectionTask:self didCompleteWithError:error];
        }
    }
}

- (void)socketStreamHasBytesAvailable:(HBSocketStream *)socketStream {
    [socketStream readData];
}

- (void)socketStreamHasSpaceAvailable:(HBSocketStream *)socketStream {
    [socketStream writeData:self.httpSerializer.requestData];
}

- (void)socketStream:(HBSocketStream *)socketStream didWriteData:(NSData *_Nullable)data withError:(NSError *)error {
    //发送完数据，关闭写操作
    if (!data) {
        [socketStream closeWrite];
    }
    if (error) {
        if (self.connectionTaskDelegate && [self.connectionTaskDelegate respondsToSelector:@selector(socketConnectionTask:didCompleteWithError:)]) {
            [self.connectionTaskDelegate socketConnectionTask:self didCompleteWithError:error];
        }
    }
}

- (void)socketStream:(HBSocketStream *)socketStream didReadData:(NSData *)data withError:(NSError *)error {
    if (!error) {
        if (self.connectionTaskDelegate && [self.connectionTaskDelegate respondsToSelector:@selector(socketConnectionTask:didReceiveData:)]) {
            [self.connectionTaskDelegate socketConnectionTask:self didReceiveData:data];
        }
        [self.httpSerializer appendSocketData:data];
        NSHTTPURLResponse *response = self.httpSerializer.response;
        NSData *body = self.httpSerializer.responseBody;
        if (response && body) {
            //接收完成，关闭读操作
            [socketStream closeRead];
            //判断重定向
            NSNumber *code = @(response.statusCode);
            if ([self.redirectionCodes containsObject:code]) {
                if (self.connectionTaskDelegate && [self.connectionTaskDelegate respondsToSelector:@selector(socketConnectionTask:didDetectRedirectionResponse:)]) {
                    [self.connectionTaskDelegate socketConnectionTask:self didDetectRedirectionResponse:response];
                }
            }else {
                if (self.connectionTaskDelegate && [self.connectionTaskDelegate respondsToSelector:@selector(socketConnectionTask:didCompleteWithError:)]) {
                    [self.connectionTaskDelegate socketConnectionTask:self didCompleteWithError:error];
                }
            }
        }
    }else {
        if (self.connectionTaskDelegate && [self.connectionTaskDelegate respondsToSelector:@selector(socketConnectionTask:didCompleteWithError:)]) {
            [self.connectionTaskDelegate socketConnectionTask:self didCompleteWithError:error];
        }
    }
}

@end

#pragma mark - 网络请求

@interface HBHTTPSocketConnection () <HBHTTPSocketConnectionTaskDelegate>

@property (nonatomic, strong) NSMutableArray<HBHTTPSocketConnectionTask *> *tasks;

@end

@implementation HBHTTPSocketConnection

- (instancetype)init {
    
    if (self = [super init]) {
        _tasks = [NSMutableArray array];
    }
    return self;
}

- (void)setSocketConnectionRequests:(NSArray<NSURLRequest *> *)requests {
    if (requests.count) {
        NSArray<NSURLRequest *> *internalRequests = [NSArray arrayWithArray:requests];
        [internalRequests enumerateObjectsUsingBlock:^(NSURLRequest * _Nonnull request, NSUInteger idx, BOOL * _Nonnull stop) {
            @synchronized (self.tasks) {
                HBHTTPSocketConnectionTask *task = [[HBHTTPSocketConnectionTask alloc] initWithRequest:request];
                task.connectionTaskDelegate = self;
                [self.tasks addObject:task];
            }
        }];
    }
}

- (void)start {
    NSArray<HBHTTPSocketConnectionTask *> *startedTasks = [NSArray arrayWithArray:self.tasks];
    [startedTasks enumerateObjectsUsingBlock:^(HBHTTPSocketConnectionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        [task startTask];
    }];
}

- (void)startAtRequestIndex:(NSUInteger)requestIndex {
    NSUInteger taskCount = self.tasks.count;
    if (taskCount > requestIndex) {
        HBHTTPSocketConnectionTask *task = [self.tasks objectAtIndex:requestIndex];
        [task startTask];
    }
}

- (void)addNewRequestsAndStart:(NSArray<NSURLRequest *> *)requests {
    if (requests.count) {
        NSArray<NSURLRequest *> *newRequests = [NSArray arrayWithArray:requests];
        [newRequests enumerateObjectsUsingBlock:^(NSURLRequest * _Nonnull newRequest, NSUInteger idx, BOOL * _Nonnull stop) {
            @synchronized (self.tasks) {
                HBHTTPSocketConnectionTask *task = [[HBHTTPSocketConnectionTask alloc] initWithRequest:newRequest];
                task.connectionTaskDelegate = self;
                [self.tasks addObject:task];
                [task startTask];
            }
        }];
    }
}

- (HBHTTPSerializer *)httpSerializerAtRequestIndex:(NSUInteger)requestIndex {
    NSUInteger taskCount = self.tasks.count;
    if (taskCount > requestIndex) {
        HBHTTPSocketConnectionTask *task = [self.tasks objectAtIndex:requestIndex];
        return task.httpSerializer;
    }
    return nil;
}

#pragma mark - 代理方法

- (void)socketConnectionTask:(HBHTTPSocketConnectionTask *)connectionTask didReceiveData:(NSData *)data {
    if (self.connectionDelegate && [self.connectionDelegate respondsToSelector:@selector(socketConnection:didReceiveData:atRequestIndex:)]) {
        [self.connectionDelegate socketConnection:self didReceiveData:data atRequestIndex:[self.tasks indexOfObject:connectionTask]];
    }
}

- (void)socketConnectionTask:(HBHTTPSocketConnectionTask *)connectionTask didDetectRedirectionResponse:(NSHTTPURLResponse *)redirectionResponse {
    if (self.connectionDelegate && [self.connectionDelegate respondsToSelector:@selector(socketConnection:didDetectRedirectionResponse:atRequestIndex:)]) {
        [self.connectionDelegate socketConnection:self didDetectRedirectionResponse:redirectionResponse atRequestIndex:[self.tasks indexOfObject:connectionTask]];
    }
}

- (void)socketConnectionTask:(HBHTTPSocketConnectionTask *)connectionTask didCompleteWithError:(NSError *_Nullable)error {
    if (self.connectionDelegate && [self.connectionDelegate respondsToSelector:@selector(socketConnection:didCompleteWithError:atRequestIndex:)]) {
        [self.connectionDelegate socketConnection:self didCompleteWithError:error atRequestIndex:[self.tasks indexOfObject:connectionTask]];
    }
}

@end
