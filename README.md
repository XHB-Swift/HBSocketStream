# HBSocketStream
基于NSStream，NSRunLoop+NSThread封装的一个轻量Socket库
## Usage
``` Objective-C
#import "HBSocketStream.h"
```
## Example
创建Socket网络对象
``` Objective-C
HBSocketStream *socketStream = [[HBSocketStream alloc] init];
socketStream.socketStreamDelegate = self; 
```
发起连接
``` Objective-C
NSString *host = @"www.apple.com";
uint16_t port = 443;
[socketStream connectToHost:host port:port];
```
回调处理
``` Objective-C
//当前对象可进行写操作
- (void)socketStreamHasSpaceAvailable:(HBSocketStream *)socketStream {
    [socketStream readData];
}

//当前对象可进行读操作
- (void)socketStreamHasBytesAvailable:(HBSocketStream *)socketStream {
    NSData *data = ...; //需要发送的数据流
    [socketStream writeData:data];
}

//触发写操作，可能出错
- (void)socketStream:(HBSocketStream *)socketStream didWriteData:(NSData *_Nullable)data withError:(NSError *_Nullable)error {
    //发送完成可关闭写入流
    if (data == nil) { //data为nil表示无剩余数据
        [socketStream closeWrite];
    }
}

//触发读操作，可能出错
- (void)socketStream:(HBSocketStream *)socketStream didReadData:(NSData *_Nullable)data withError:(NSError *_Nullable)error {
    if (data) { //读取到数据
    }
}

//触发连接行为，可能出错
- (void)socketStream:(HBSocketStream *)socketStream didConnectWithError:(NSError *_Nullable)error {
    //可选实现方法
    if (error) { //表示连接失败
    }
} 
```
## Additional
Demo中有一个基于以上Socket网络层实现的HTTP请求库，可以参考其中源码，理解Socket网络层如何工作
## Author
1021580211@qq.com
