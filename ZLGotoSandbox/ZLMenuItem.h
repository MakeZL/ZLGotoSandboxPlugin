//
//  ZLMenuItem.h
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-5.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZLSandBox.h"

@interface ZLMenuItem : NSMenuItem

/**
 *  索引值
 */
@property (assign,nonatomic) NSInteger index;
@property (strong,nonatomic) ZLSandBox *sandbox;

@end
