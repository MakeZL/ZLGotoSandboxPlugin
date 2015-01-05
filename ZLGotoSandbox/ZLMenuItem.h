//
//  ZLMenuItem.h
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-5.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ZLMenuItem : NSMenuItem
/**
 *  沙盒的路径
 */
@property (copy,nonatomic) NSString *projectSandBoxPath;
@end
