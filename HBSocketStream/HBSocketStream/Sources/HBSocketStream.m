//
//  HBSocketStream.m
//  HBSocketStream
//
//  Created by 谢鸿标 on 2019/7/16.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import "HBSocketStream.h"
#import "HBRunLoopThread.h"
#import <sys/socket.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/sysctl.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <netinet/in.h>

#pragma mark - Socket

CFSocketNativeHandle const HBSOCKNULL = -1;

NSString *const HBTCPAddressFamily = @"tcp-family";
NSString *const HBTCPAddressData = @"tcp-data";

@interface HBSocketStream () <HBRunLoopThreadDelegate, NSStreamDelegate>

@property (nonatomic) CFSocketNativeHandle socketFD;
@property (nonatomic, strong) NSMutableDictionary *defaultSSLSetting;
//管理RunLoop线程池
@property (nonatomic, strong) NSMutableArray<HBRunLoopThread *> *threadsPool;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;

@end

@implementation HBSocketStream

- (instancetype)init {
    
    if (self = [super init]) {
        _socketFD = HBSOCKNULL;
        _threadsPool = [NSMutableArray array];
        _defaultSSLSetting = [NSMutableDictionary dictionary];
    }
    return self;
}

//设置SSL
- (void)setSslSetting:(NSDictionary *)sslSetting {
    _sslSetting = [sslSetting copy];
    if (_defaultSSLSetting.count == 0) {
        _defaultSSLSetting[(__bridge id)kCFStreamSSLIsServer] = (__bridge id)kCFBooleanFalse;
        _defaultSSLSetting[(__bridge id)kCFStreamPropertySocketSecurityLevel] = (__bridge id)kCFStreamSocketSecurityLevelTLSv1;
    }
    if (_sslSetting) {
        [_defaultSSLSetting addEntriesFromDictionary:_sslSetting];
    }
}

//连接远程主机
- (void)connectToHost:(NSString *)host port:(uint16_t)port {
    
    if (self.sslSetting) {
        self.defaultSSLSetting[(__bridge id)kCFStreamSSLPeerName] = host;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSDictionary<NSString *, id> *addrInfo = [self.class HBSocketResolveHost:host port:port error:&error];
        CFSocketNativeHandle sock = HBSOCKNULL;
        if (!error) {
            int family = [addrInfo[HBTCPAddressFamily] intValue];
            sock = [self.class HBSocketInitWithFamily:family cellular:self.useCellularTunnel error:&error];
            if (!error) {
                NSData *address = addrInfo[HBTCPAddressData];
                error = [self.class HBSocket:sock connectToAddress:address];
            }
        }
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!error) {
            strongSelf.socketFD = sock;
            [strongSelf initializeStreams];
        }
        if (strongSelf.socketStreamDelegate && [strongSelf.socketStreamDelegate respondsToSelector:@selector(socketStream:didConnectWithError:)]) {
            [strongSelf.socketStreamDelegate socketStream:strongSelf didConnectWithError:error];
        }
    });
}

//创建流
- (void)initializeStreams {
    CFReadStreamRef readStreamRef = NULL;
    CFWriteStreamRef writeStreamRef = NULL;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, self.socketFD, &readStreamRef, &writeStreamRef);
    CFReadStreamSetProperty(readStreamRef, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse);
    CFWriteStreamSetProperty(writeStreamRef, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse);
    if (self.sslSetting) {
        CFWriteStreamSetProperty(writeStreamRef, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)self.defaultSSLSetting);
        CFReadStreamSetProperty(readStreamRef, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)self.defaultSSLSetting);
    }
    self.inputStream = (__bridge_transfer NSInputStream *)readStreamRef;
    self.outputStream = (__bridge_transfer NSOutputStream *)writeStreamRef;
    self.inputStream.delegate = self;
    self.outputStream.delegate = self;
    [self.inputStream open];
    [self.outputStream open];
    @synchronized (self.threadsPool) {
        //线程池达到6个RunLoop线程对象时，清空线程池的线程对象
        if (self.threadsPool.count > 5) {
            [self.threadsPool removeAllObjects];
        }
        HBRunLoopThread *thread = [[HBRunLoopThread alloc] init];
        thread.name = [NSString stringWithFormat:@"HBSocketStreamThread-%@",self];
        thread.runLoopThreadDelegate = self;
        [thread start];
        [self.threadsPool addObject:thread];
    }
}

- (void)writeData:(NSData *_Nullable)data {
    if (data) {
        const uint8_t *bytes = data.bytes;
        NSUInteger length = data.length;
        NSInteger res = [self.outputStream write:bytes maxLength:length];
        NSError *writeError = nil;
        NSData *leftData = data;
        if (res < 0) {
            writeError = self.outputStream.streamError;
        }else {
            const uint8_t *leftBytes = bytes + res;
            NSUInteger leftLength = length - res;
            if (leftLength > 0) {
                leftData = [NSData dataWithBytes:leftBytes length:leftLength];
            }else {
                leftData = nil;
            }
        }
        if (self.socketStreamDelegate && [self.socketStreamDelegate respondsToSelector:@selector(socketStream:didWriteData:withError:)]) {
            [self.socketStreamDelegate socketStream:self didWriteData:leftData withError:writeError];
        }
    }
}

- (void)closeWrite {
    [self.outputStream close];
}

- (void)readData {
    NSUInteger maxBufferLength = 16*1024;
    uint8_t buffer[maxBufferLength];
    memset(buffer, 0, maxBufferLength);
    NSInteger res = [self.inputStream read:buffer maxLength:maxBufferLength];
    NSError *readError = nil;
    NSData *data = nil;
    if (res < 0) {
        readError = self.inputStream.streamError;
    }else {
        data = [NSData dataWithBytes:buffer length:res];
    }
    if (self.socketStreamDelegate && [self.socketStreamDelegate respondsToSelector:@selector(socketStream:didReadData:withError:)]) {
        [self.socketStreamDelegate socketStream:self didReadData:data withError:readError];
    }
}

- (void)closeRead {
    [self.inputStream close];
}

#pragma mark - Stream代理方法

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable:
        {
            if (self.socketStreamDelegate && [self.socketStreamDelegate respondsToSelector:@selector(socketStreamHasBytesAvailable:)]) {
                [self.socketStreamDelegate socketStreamHasBytesAvailable:self];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
            if (self.socketStreamDelegate && [self.socketStreamDelegate respondsToSelector:@selector(socketStreamHasSpaceAvailable:)]) {
                [self.socketStreamDelegate socketStreamHasSpaceAvailable:self];
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - RunLoop线程代理方法

- (void)runLoopThread:(HBRunLoopThread *)thread willEnterRunLoop:(NSRunLoop *)runLoop {
    [self.inputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
//    NSLog(@"%s",__func__);
}

- (void)runLoopThread:(HBRunLoopThread *)thread didExitRunLoop:(NSRunLoop *)runLoop {
    [self.inputStream removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
//    NSLog(@"%s",__func__);
}

#pragma mark - 错误

+ (NSError *)HBSocketStreamErrorWithCode:(NSInteger)code reason:(NSString *_Nullable)reason {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = reason;
    return [NSError errorWithDomain:@"HBSocketStreamErrorDomain" code:code userInfo:userInfo];
}

#pragma mark - Socket工具方法

//DNS解析
+ (NSDictionary<NSString *, id> *)HBSocketResolveHost:(NSString *)host port:(uint16_t)port error:(NSError **_Nullable)error {
    
    NSString *strPort = [NSString stringWithFormat:@"%d",port];
    struct addrinfo *res1 = NULL, *res2 = NULL;
    NSMutableDictionary<NSString *, id> *addrInfo = nil;
    int gai_error = getaddrinfo([host UTF8String], [strPort UTF8String], NULL, &res1);
    
    if (!gai_error) {
        
        addrInfo = [NSMutableDictionary dictionary];
        
        for (res2 = res1; res2 != NULL; res2 = res2->ai_next) {
            
            if (res2->ai_family == AF_INET && addrInfo.count == 0) {
                NSData *ipv4 = [NSData dataWithBytes:res2->ai_addr length:res2->ai_addrlen];
                addrInfo[HBTCPAddressFamily] = @(AF_INET);
                addrInfo[HBTCPAddressData] = ipv4;
            }
            if (res2->ai_family == AF_INET6 && addrInfo.count == 0) {
                
                struct sockaddr_in6 *sockaddr = (struct sockaddr_in6 *)res2->ai_addr;
                in_port_t *portPtr = &sockaddr->sin6_port;
                if ((portPtr != NULL) && (*portPtr == 0)) {
                    *portPtr = htons(port);
                }
                NSData *ipv6 = [NSData dataWithBytes:res2->ai_addr length:res2->ai_addrlen];
                addrInfo[HBTCPAddressFamily] = @(AF_INET6);
                addrInfo[HBTCPAddressData] = ipv6;
            }
        }
    }else {
        
        NSString *gaiErrorDesc = [NSString stringWithFormat:@"getaddrinfo function error reason: %s", gai_strerror(gai_error)];
        if (error) {
            *error = [self HBSocketStreamErrorWithCode:gai_error reason:gaiErrorDesc];
        }
    }
    
    if (res1) {
        freeaddrinfo(res1);
        res1 = NULL;
    }
    
    if (res2) {
        freeaddrinfo(res2);
        res2 = NULL;
    }
    return addrInfo;
}

//创建Socket套接字
+ (CFSocketNativeHandle)HBSocketInitWithFamily:(int)family cellular:(BOOL)cellular error:(NSError **_Nullable)error {
    CFSocketNativeHandle socketFd = socket(family, SOCK_STREAM, IPPROTO_TCP);
    if (socketFd == HBSOCKNULL) {
        int err = errno;
        if (error) {
            *error = [self HBSocketStreamErrorWithCode:err reason:[NSString stringWithFormat:@"Error in socket(): %s", strerror(err)]];
        }
        return HBSOCKNULL;
    }
    if (cellular) {
        __unused int index = if_nametoindex("pdp_ip0");
        if (index == 0) {
            if (error) {
                *error = [self HBSocketStreamErrorWithCode:-1 reason:@"Not found <pdp_ip0>"];
            }
            return HBSOCKNULL;
        }
        __unused int sockopt = setsockopt(socketFd, IPPROTO_IP, IP_BOUND_IF, &index, sizeof(index));
    }
    return socketFd;
}

//Socket连接
+ (NSError *_Nullable)HBSocket:(CFSocketNativeHandle)socketFD connectToAddress:(NSData *)address {
    
    const struct sockaddr *sock_addr = (const struct sockaddr *)address.bytes;
    socklen_t sock_addr_len = (socklen_t)address.length;
    int result = connect(socketFD, sock_addr, sock_addr_len);
    NSError *connError = nil;
    if (result) {
        int err = errno;
        connError = [self HBSocketStreamErrorWithCode:err reason:[NSString stringWithFormat:@"Error in connect(): %s", strerror(err)]];
    }
    return connError;
}

//Socket断开
+ (NSError *_Nullable)HBSocketDisconnect:(CFSocketNativeHandle)socketFD {
    NSError *error = nil;
    if (socketFD != HBSOCKNULL) {
        int closeErr = close(socketFD);
        int err = errno;
        if (closeErr != 0) {
            error = [self HBSocketStreamErrorWithCode:err reason:[NSString stringWithFormat:@"%s",strerror(err)]];
        }
    }
    return error;
}

@end
