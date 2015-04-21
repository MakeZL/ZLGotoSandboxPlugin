//  github: https://github.com/MakeZL/ZLGotoSandboxPlugin
//  Author: @email <120886865@qq.com> @weibo <weibo.com/makezl>
//
//  ZLSandBox.h
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-5.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface ZLSandBox : NSObject

@property (copy,nonatomic) NSString *udid;
@property (copy,nonatomic) NSString *version;
@property (copy,nonatomic) NSString *device;
// device+version
@property (copy,nonatomic) NSString *boxName;
// contains simulator items
@property (strong,nonatomic) NSArray *items;
// sanbox path
@property (strong,nonatomic) NSArray *projectSandBoxPath;

@end

@interface ZLMenuItem : NSMenuItem

@property (assign,nonatomic) NSInteger index;
@property (strong,nonatomic) ZLSandBox *sandbox;

@end

