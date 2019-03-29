//
//  WYKSocketManager.h
//  CocoaSyncSocket
//
//  Created by 王永康 on 18/03/28.
//  Copyright © 2018年 王永康. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WYKSocketManagerDelegate <NSObject>

- (void)showMessage:(NSString *)message;

@end

@interface WYKSocketManager : NSObject

@property (nonatomic, weak) id <WYKSocketManagerDelegate> delegate;   //!<

+ (instancetype)share;

- (BOOL)connect;

- (void)disConnect;

- (void)sendMsg:(NSString *)msg;

- (void)pullTheMsg;


@end
