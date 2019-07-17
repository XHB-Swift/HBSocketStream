//
//  ViewController.m
//  HBSocketStream
//
//  Created by 谢鸿标 on 2019/7/16.
//  Copyright © 2019 谢鸿标. All rights reserved.
//

#import "ViewController.h"
#import "HBHTTPSerializer.h"
#import "HBHTTPSocketConnection.h"

@interface ViewController () <HBHTTPSocketConnectionDelegate>

@property (nonatomic, strong) HBHTTPSocketConnection *socketConnection;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.socketConnection = [[HBHTTPSocketConnection alloc] init];
    self.socketConnection.connectionDelegate = self;
    UIButton *button = [UIButton buttonWithType:(UIButtonTypeCustom)];
    [button setTitle:@"请求" forState:(UIControlStateNormal)];
    [button setTitleColor:[UIColor blackColor] forState:(UIControlStateNormal)];
    button.frame = (CGRect){80,80};
    [button sizeToFit];
    [button addTarget:self action:@selector(requestAction:) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:button];
}

- (void)requestAction:(UIButton *)sender {
    NSArray<NSString *> *urlStrings = @[@"http://www.apple.com/cn/",@"http://www.baidu.com/",
                                        @"https://cn.bing.com",@"https://github.com"];
    NSMutableArray<NSURLRequest *> *requests = [NSMutableArray array];
    for (NSString *urlString in urlStrings) {
        NSURL *URL = [NSURL URLWithString:urlString];
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        [requests addObject:request];
    }
    [self.socketConnection setSocketConnectionRequests:requests];
    [self.socketConnection start];
}

- (void)socketConnection:(HBHTTPSocketConnection *)socketConnection
          didReceiveData:(NSData *)data
          atRequestIndex:(NSUInteger)requestIndex {
//    NSLog(@"%s: requestIndex = %@", __func__, @(requestIndex));
}

- (void)socketConnection:(HBHTTPSocketConnection *)socketConnection
didDetectRedirectionResponse:(NSHTTPURLResponse *)redirectionResponse
          atRequestIndex:(NSUInteger)requestIndex {
    NSLog(@"%s: requestIndex = %@", __func__, @(requestIndex));
    NSDictionary *allHeaderFields = redirectionResponse.allHeaderFields;
    NSString *location = allHeaderFields[LOCATION];
    if (location) {
        NSURL *URL = [NSURL URLWithString:location];
        if (URL) {
            NSURLRequest *request = [NSURLRequest requestWithURL:URL];
            [socketConnection addNewRequestsAndStart:@[request]];
        }
    }
}

- (void)socketConnection:(HBHTTPSocketConnection *)socketConnection
    didCompleteWithError:(NSError *_Nullable)error
          atRequestIndex:(NSUInteger)requestIndex {
    NSLog(@"%s: requestIndex = %@", __func__, @(requestIndex));
    if (error == nil) {
        HBHTTPSerializer *httpSerializer = [socketConnection httpSerializerAtRequestIndex:requestIndex];
        NSLog(@"requestURL = %@", httpSerializer.requestURL);
        NSLog(@"response = %@", httpSerializer.response);
        NSLog(@"responseBody = %@", @(httpSerializer.responseBody.length));
    }
}


@end
