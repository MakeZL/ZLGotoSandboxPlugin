//
//  ZLSandBox.h
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-5.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZLSandBox : NSObject

@property (copy,nonatomic) NSString *version;
@property (copy,nonatomic) NSString *device;
@property (copy,nonatomic) NSString *boxName;

@property (strong,nonatomic) NSArray *items;
/**
 *  沙盒的路径
 */
@property (strong,nonatomic) NSArray *projectSandBoxPath;

@end
