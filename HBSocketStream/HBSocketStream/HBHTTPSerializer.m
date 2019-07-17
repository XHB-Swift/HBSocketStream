//
//  HBHTTPSerializer.m
//  HBSocketStream
//
//  Created by 谢鸿标 on 2019/7/16.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import "HBHTTPSerializer.h"

#pragma mark - HTTP RFC

NSString *const CR = @"\r";
NSString *const LF = @"\n";
NSString *const CRLF = @"\r\n";
NSString *const CRLFCRLF = @"\r\n\r\n";

NSString *const HOST = @"Host";
NSString *const LOCATION = @"Location";
NSString *const USER_AGENT = @"User-Agent";
NSString *const CONTENT_LENGTH = @"Content-Length";
NSString *const TRANSFER_ENCODING = @"Transfer-Encoding";

@interface HBHTTPSerializer ()

@property (nonatomic) CFHTTPMessageRef responseMsg;

@end

@implementation HBHTTPSerializer

+ (instancetype)httpSerializerWithRequest:(NSURLRequest *)request {
    return [[HBHTTPSerializer alloc] initWithRequest:request];
}

- (instancetype)init {
    
    if (self = [super init]) {
        _responseMsg = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, NO);
    }
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request {
    
    if (self = [self init]) {
        if (request) {
            _requestURL = [request.URL copy];
            NSData *reqData = [self.class requestDataWithRequest:request];
            if (reqData) {
                _requestData = [NSData dataWithData:reqData];
            }
        }
    }
    return self;
}

- (void)appendSocketData:(NSData *_Nullable)socketData {
    if (self.responseMsg != NULL) {
        const UInt8 *bytes = socketData.bytes;
        NSUInteger length = socketData.length;
        CFHTTPMessageAppendBytes(self.responseMsg, bytes, length);
        BOOL completeHeader = CFHTTPMessageIsHeaderComplete(self.responseMsg);
        if (completeHeader) {
            if (_response == nil) {
                _response = [self.class responseWithMessage:self.responseMsg requestURL:self.requestURL];
            }
            NSData *HTTPBody = [self.class responseBodyWithMessage:self.responseMsg];
            if (HTTPBody) {
                _responseBody = [NSData dataWithData:HTTPBody];
            }
        }
    }
}

//生成Socket可发送的数据流
+ (NSData *_Nullable)requestDataWithRequest:(NSURLRequest *)request {
    NSURL *URL = request.URL;
    NSString *host = URL.host;
    NSString *method = request.HTTPMethod ?: @"GET";
    CFURLRef cf_http_url = (__bridge CFURLRef)URL;
    CFStringRef cf_http_method = (__bridge CFStringRef)method;
    CFHTTPMessageRef requestMessage = NULL;
    if (cf_http_url && cf_http_method) {
        requestMessage = CFHTTPMessageCreateRequest(kCFAllocatorDefault, cf_http_method, cf_http_url, kCFHTTPVersion1_1);
        UIDevice *currentDevice = UIDevice.currentDevice;
        NSString *userAgent = [NSString stringWithFormat:@"Mozila/5.0 (CFStream %@ iOS %@)", currentDevice.model, currentDevice.systemVersion];
        CFHTTPMessageSetHeaderFieldValue(requestMessage, (__bridge CFStringRef)HOST, (__bridge CFStringRef)host);
        CFHTTPMessageSetHeaderFieldValue(requestMessage, (__bridge CFStringRef)USER_AGENT, (__bridge CFStringRef)userAgent);
        //    @"Accept-Language":@"zh-cn",
        //    @"Connection":@"keep-alive"
        CFHTTPMessageSetHeaderFieldValue(requestMessage, (__bridge CFStringRef)@"Connection", (__bridge CFStringRef)@"keep-alive");
    }else {
        return nil;
    }
    NSDictionary<NSString *, NSString *> *allHeaderFields = request.allHTTPHeaderFields;
    if (allHeaderFields.count) {
        [allHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            CFStringRef cf_http_header = (__bridge CFStringRef)key;
            CFStringRef cf_http_value = (__bridge CFStringRef)obj;
            CFHTTPMessageSetHeaderFieldValue(requestMessage, cf_http_header, cf_http_value);
        }];
    }
    NSData *body = request.HTTPBody;
    if (body) {
        NSUInteger contentLength = body.length;
        CFHTTPMessageSetHeaderFieldValue(requestMessage, (__bridge CFStringRef)CONTENT_LENGTH, (__bridge CFStringRef)@(contentLength).stringValue);
        CFHTTPMessageSetBody(requestMessage, (__bridge CFDataRef)body);
    }
    NSData *sendedData = (__bridge_transfer NSData *)CFHTTPMessageCopySerializedMessage(requestMessage);
    CFRelease(requestMessage);
    requestMessage = NULL;
    return sendedData;
}

//生成响应对象

+ (NSHTTPURLResponse *)responseWithMessage:(CFHTTPMessageRef)message requestURL:(NSURL *)requestURL {
    NSHTTPURLResponse *response = nil;
    if (message != NULL && requestURL != nil) {
        //获取头部
        NSDictionary *headerFields = (__bridge_transfer NSDictionary *)CFHTTPMessageCopyAllHeaderFields(message);
        //获取响应码
        NSInteger statusCode = (NSInteger)CFHTTPMessageGetResponseStatusCode(message);
        //获取HTTP版本
        NSString *HTTPVersion = (__bridge_transfer NSString *)kCFHTTPVersion1_1;
        //构建响应对象
        response = [[NSHTTPURLResponse alloc] initWithURL:requestURL statusCode:statusCode HTTPVersion:HTTPVersion headerFields:headerFields];
    }
    return response;
}

//生成可序列化的响应数据
+ (NSData *_Nullable)responseBodyWithMessage:(CFHTTPMessageRef)message {
    NSDictionary *headerFields = (__bridge_transfer NSDictionary *)CFHTTPMessageCopyAllHeaderFields(message);
    NSData *body = (__bridge_transfer NSData *)CFHTTPMessageCopyBody(message);
    NSUInteger bodyLength = body.length;
    NSString *tf_encoding = headerFields[TRANSFER_ENCODING];
    NSString *contentLen = headerFields[CONTENT_LENGTH];
    BOOL isChunked = [tf_encoding isEqualToString:@"chunked"];
    BOOL isComplete = NO;
    NSData *HTTPBody = nil;
    if (isChunked) {
        NSData *chunkedEndData = [[NSString stringWithFormat:@"%@0%@", CRLF, CRLFCRLF] dataUsingEncoding:NSUTF8StringEncoding];
        if (chunkedEndData.length < bodyLength) {
            NSRange chunkedEndRange = [body rangeOfData:chunkedEndData options:0 range:(NSRange){0, bodyLength}];
            //未检测到chunked结束块，需要继续获取数据
            isComplete = (chunkedEndRange.length > 0);
            if (isComplete) { //不需要继续获取，解析Chunked块
                NSData *dechunked = [self dechunkedWithData:body];
                if (dechunked && (message != NULL)) {
                    HTTPBody = [NSData dataWithData:dechunked];
                }
            }
        }
    }else if (contentLen) {
        NSUInteger contentLength = (NSUInteger)[contentLen integerValue];
        isComplete = !(contentLength > bodyLength);
        if (isComplete) {
            HTTPBody = [NSData dataWithData:body];
        }
    }
    return HTTPBody;
}

//格式化chunked编码的字节流
+ (NSData *_Nullable)dechunkedWithData:(NSData *)data {
    
    char *pChunked = (char *)data.bytes;
    char *pBody = pChunked;
    char *pTemp = NULL;
    const char *crlf = CRLF.UTF8String;
    NSMutableData *rs = [NSMutableData data];
    long chunkedIntLength = 0;
    char chunkedStrLength[10];
    
    while (YES) {
        chunkedIntLength = 0;
        memset(chunkedStrLength, 0, 10);
        pTemp = strstr(pBody, crlf);
        long chunkedByteLength = pTemp - pBody;
        for (long i = 0; i < chunkedByteLength; i += 1) {
            chunkedStrLength[i] = pBody[i];
        }
        pBody = pTemp + 2;
        sscanf(chunkedStrLength, "%lx", &chunkedIntLength);
        if (chunkedIntLength > 0) {
            char pNewData[chunkedIntLength];
            memcpy(pNewData, pBody, chunkedIntLength);
            pBody = pBody + chunkedIntLength + 2;
            [rs appendBytes:pNewData length:chunkedIntLength];
        }else {
            break;
        }
    }
    
    return [rs copy];
}

@end
