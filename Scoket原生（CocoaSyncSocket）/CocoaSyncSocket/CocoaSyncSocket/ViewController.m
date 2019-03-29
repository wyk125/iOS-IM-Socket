//
//  ViewController.m
//  CocoaSyncSocket
//
//  Created by 王永康 on 18/03/26.
//  Copyright © 2018年 王永康. All rights reserved.
//

#import "ViewController.h"
#import "WYKSocketManager.h"

@interface ViewController () <WYKSocketManagerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *sendFiled;
@property (weak, nonatomic) IBOutlet UIButton *sendBtn;
@property (weak, nonatomic) IBOutlet UIButton *connectBtn;
@property (weak, nonatomic) IBOutlet UIButton *disConnectBtn;
@property (weak, nonatomic) IBOutlet UITextView *reciveTextView;

@end

@implementation ViewController

- (void)dealloc
{
    [WYKSocketManager share].delegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [WYKSocketManager share].delegate = self;
    
    [_connectBtn addTarget:self action:@selector(connectAction) forControlEvents:UIControlEventTouchUpInside];
    
    [_disConnectBtn addTarget:self action:@selector(disConnectAction) forControlEvents:UIControlEventTouchUpInside];
    
    [_sendBtn addTarget:self action:@selector(sendAction) forControlEvents:UIControlEventTouchUpInside];
}

//连接
- (void)connectAction
{
    [[WYKSocketManager share] connect];
}

//断开连接
- (void)disConnectAction
{
    [[WYKSocketManager share] disConnect];
    [self showNewMessage:@"主动断开连接"];
}

//发送消息
- (void)sendAction
{
    if (_sendFiled.text.length == 0) {
        return;
    }
    [[WYKSocketManager share] sendMsg:_sendFiled.text];
    NSString *message = [NSString stringWithFormat:@"发送：%@",_sendFiled.text];
    [self showNewMessage:message];
}

//接收消息
- (void)showMessage:(NSString *)message
{
    [self showNewMessage:message];
}

- (void)showNewMessage:(NSString *)message
{
    NSString *text = [NSString stringWithFormat:@"%@\n%@\n",self.reciveTextView.text,message];
    self.reciveTextView.text = text;
}

@end
