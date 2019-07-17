//
//  HBSocketStream.h
//  HBSocketStream
//
//  Created by 谢鸿标 on 2019/7/16.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HBSocketStream;
@protocol HBSocketStreamDelegate <NSObject>

//当前对象可进行写操作
- (void)socketStreamHasSpaceAvailable:(HBSocketStream *)socketStream;

//当前对象可进行读操作
- (void)socketStreamHasBytesAvailable:(HBSocketStream *)socketStream;

//触发写操作，可能出错
- (void)socketStream:(HBSocketStream *)socketStream didWriteData:(NSData *_Nullable)data withError:(NSError *_Nullable)error;

//触发读操作，可能出错
- (void)socketStream:(HBSocketStream *)socketStream didReadData:(NSData *_Nullable)data withError:(NSError *_Nullable)error;

@optional

//触发连接行为，可能出错
- (void)socketStream:(HBSocketStream *)socketStream didConnectWithError:(NSError *_Nullable)error;

@end

@interface HBSocketStream : NSObject

//Socket是否通过蜂窝连接
@property (nonatomic) BOOL useCellularTunnel;

//代理方法处理Socket事件
@property (nonatomic, weak) id<HBSocketStreamDelegate> socketStreamDelegate;

//SSL配置，要开启SSL设置一个非空字典即可
@property (nonatomic, nullable, copy) NSDictionary *sslSetting;

//发起连接
- (void)connectToHost:(NSString *)host port:(uint16_t)port;

//发起写操作
- (void)writeData:(NSData *_Nullable)data;

//当发送完数据，关闭写操作
- (void)closeWrite;

//发起读操作
- (void)readData;

//当接收完成，关闭读操作
- (void)closeRead;

@end

NS_ASSUME_NONNULL_END
