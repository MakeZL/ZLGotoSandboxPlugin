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

/**
 *  获取所有的Item
 */
+ (NSArray *)getAllItems;

/**
 *  根据sandbox获取sandbox底下所有的Items
 */
+ (NSArray *)projectsWithBox:(ZLSandBox *)sandbox;

/**
 *  根据sandbox获取路径
 */
+ (NSString *)getDevicePath:(ZLSandBox *)sandbox;

/**
 *  根据filePath获取App图标路径
 */
+ (NSString *)getBundleImagePathWithFilePath:(NSString *)filePath;

/**
 *  根据identifierName获取App的名字
 */
+ (NSString *)getAppName:(NSString *)identifierName;

/**
 *  获取沙盒的根路径
 */
+ (NSString *)getHomePath;
@end
