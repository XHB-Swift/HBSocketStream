//
//  HBHTTPSocketConnection.h
//  HBSocketStream
//
//  Created by 谢鸿标 on 2019/7/17.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HBHTTPSocketConnection, HBHTTPSerializer;

@protocol HBHTTPSocketConnectionDelegate <NSObject>

@optional

- (void)socketConnection:(HBHTTPSocketConnection *)socketConnection
          didReceiveData:(NSData *)data
          atRequestIndex:(NSUInteger)requestIndex;

- (void)socketConnection:(HBHTTPSocketConnection *)socketConnection
didDetectRedirectionResponse:(NSHTTPURLResponse *)redirectionResponse
          atRequestIndex:(NSUInteger)requestIndex;

- (void)socketConnection:(HBHTTPSocketConnection *)socketConnection
    didCompleteWithError:(NSError *_Nullable)error
          atRequestIndex:(NSUInteger)requestIndex;

@end

@interface HBHTTPSocketConnection : NSObject

@property (nonatomic, weak) id<HBHTTPSocketConnectionDelegate> connectionDelegate;

- (void)setSocketConnectionRequests:(NSArray<NSURLRequest *> *)requests;

- (void)start;

- (void)startAtRequestIndex:(NSUInteger)requestIndex;

- (void)addNewRequestsAndStart:(NSArray<NSURLRequest *> *)requests;

- (HBHTTPSerializer *_Nullable)httpSerializerAtRequestIndex:(NSUInteger)requestIndex;

@end

NS_ASSUME_NONNULL_END
