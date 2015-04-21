//  github: https://github.com/MakeZL/ZLGotoSandboxPlugin
//  Author: @email <120886865@qq.com> @weibo <weibo.com/makezl>
//
//  ZLItemDatas.h
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-2-6.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZLSandBox.h"

@interface ZLItemDatas : NSObject


+ (NSArray *)getAllItems;
/**
 *  According to the sandbox to get the sandbox under all Items
 */
+ (NSArray *)projectsWithBox:(ZLSandBox *)sandbox;

/**
 *  According to the sandbox access path
 */
+ (NSString *)getDevicePath:(ZLSandBox *)sandbox;

/**
 *  According to the filePath App icon path
 */
+ (NSString *)getBundleImagePathWithFilePath:(NSString *)filePath;

/**
 *  According to the identifierName App name
 */
+ (NSString *)getAppName:(NSString *)identifierName;

/**
 *  Under the name of App and sandbox,
    to obtain the specific path
 */
+ (NSString *)getAppName:(NSString *)appName withSandbox:(ZLSandBox *)sandbox;

/**
 *  Get Sandbox Home Path.
 */
+ (NSString *)getHomePath;
@end
