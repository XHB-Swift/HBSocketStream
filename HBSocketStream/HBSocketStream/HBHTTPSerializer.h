//
//  HBHTTPSerializer.h
//  HBSocketStream
//
//  Created by 谢鸿标 on 2019/7/16.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const HOST;
FOUNDATION_EXPORT NSString *const LOCATION;
FOUNDATION_EXPORT NSString *const USER_AGENT;
FOUNDATION_EXPORT NSString *const CONTENT_LENGTH;
FOUNDATION_EXPORT NSString *const TRANSFER_ENCODING;

@interface HBHTTPSerializer : NSObject

/**
 请求URL
 */
@property (nonatomic, copy, nullable, readonly) NSURL *requestURL;

/**
 Socket可发送数据流
 */
@property (nonatomic, copy, nullable, readonly) NSData *requestData;

/**
 Socket读取的数据流解析出来的HTTP响应对象，为nil则未完整接收HTTP响应报文
 */
@property (nonatomic, strong, nullable, readonly) NSHTTPURLResponse *response;

/**
 Socket读取数据流解析出来的HTTP响应体，为nil则未完整接收HTTP响应体
 */
@property (nonatomic, copy, nullable, readonly) NSData *responseBody;

/**
 利用一个request生成序列化器

 @param request 请求
 @return 实例对象
 */
+ (instancetype)httpSerializerWithRequest:(NSURLRequest *)request;

/**
 拼接来自Socket读取的数据流

 @param socketData 数据流
 */
- (void)appendSocketData:(NSData *_Nullable)socketData;

@end

NS_ASSUME_NONNULL_END
