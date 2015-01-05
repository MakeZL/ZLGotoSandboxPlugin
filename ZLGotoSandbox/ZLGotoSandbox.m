//
//  ZLGotoSandbox.m
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-4.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import "ZLGotoSandbox.h"

@interface ZLGotoSandbox ()
@property (strong,nonatomic) NSArray *items;
@end

@implementation ZLGotoSandbox

- (NSArray *)items{
    if (!_items) {
        _items = @[
                   @"Go,iOS8.1 Simulator!",
                   @"Go,iOS8.0 Simulator!",
                   @"Go,iOS7.1 Simulator!",
                   @"Go,iOS7.0 Simulator!"
                   
                 ];
    }
    return _items;
}

- (instancetype)init{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
    }
    return self;
}

+(void)pluginDidLoad:(NSBundle *)plugin {
    [self shared];
}

+ (instancetype)shared{
    static dispatch_once_t onceToken;
    static id instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)applicationDidFinishLaunching:(NSNotification *)noti{
    
    NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
    [[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *newMenuItem = [[NSMenuItem alloc] init];
    newMenuItem.title = @"Go to Sandbox!";
    newMenuItem.state = NSOnState;
    
    NSMenu *subMenu = [[NSMenu alloc] init];;
    newMenuItem.submenu = subMenu;
    [newMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
    [[editMenuItem submenu] addItem:newMenuItem];
    
    for (NSInteger i = 0; i < self.items.count; i++) {
        NSMenuItem *newMenuItem2 = [[NSMenuItem alloc] init];
        newMenuItem2.title = self.items[i];
        [newMenuItem2 setTarget:self];
        [newMenuItem2 setAction:@selector(gotoSandBox:)];
        [newMenuItem2 setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [subMenu addItem:newMenuItem2];
    }
}



- (void)gotoSandBox:(NSMenuItem *)item{
    
    if (!item.title.length) {
        return ;
    }
    
    NSString *version = [self getVersionWithTitle:item.title];
    // 0.获取版本号
    // 1.遍历每个文件夹底下是否有device.plist。
    // 2.找到runtime的字段。
    // 3.rangeOfString 查看是否有相应的信息
    // 4.如果有就跳转到，当前文件夹底下的 data/Containers/Data/Application
    
    NSString *homePath = NSHomeDirectory();
    NSString *filePath = [homePath stringByAppendingPathComponent:@"Library/Developer/CoreSimulator/Devices/"];
    NSString *path = [self getDevicePath:filePath version:version];
    if (!path.length) {
        path = filePath;
        
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *msgText = [NSString stringWithFormat:@"您没有%@版本的目录.\n给您跳转到模拟器的根目录.",version];
        [alert setMessageText:msgText];
        [alert runModal];
    }
    NSString *open = [NSString stringWithFormat:@"open %@",path];
    const char *str = [open UTF8String];
    system(str);
}

- (NSString *)getVersionWithTitle:(NSString *)title{
    
    NSString *version = nil;
    NSRange range = [title rangeOfString:@"iOS8.1"];
    if (range.location != NSNotFound) {
        version = @"iOS-8-1";
    }
    
    if (version == nil) {
        range = [title rangeOfString:@"iOS8.0"];
        if (range.location != NSNotFound) {
            version = @"iOS-8-0";
        }
    }
    
    if (version == nil) {
        range = [title rangeOfString:@"iOS7.1"];
        if (range.location != NSNotFound) {
            version = @"iOS-7-1";
        }
    }
    
    if (version == nil) {
        range = [title rangeOfString:@"iOS7.0"];
        if (range.location != NSNotFound) {
            version = @"iOS-7-0";
        }
    }
    
    
    return version;
}

- (NSString *)getDevicePath:(NSString *)filePath version:(NSString *)version{
    
    NSString *applicationPath = nil;
    NSFileManager *mgr = [NSFileManager defaultManager];
    if([mgr fileExistsAtPath:filePath]){
        
        NSArray *files = [mgr contentsOfDirectoryAtPath:filePath error:nil];
        
        for (NSString *filesPath in files) {
            
            NSString *devicePath =  [[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"device.plist"];
            
            NSString *ApplicationPath = [[[[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:@"Application"];
            
            if (![mgr fileExistsAtPath:ApplicationPath]) {
                ApplicationPath = [[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Applications"];
                if (![mgr fileExistsAtPath:ApplicationPath]) {
                    continue;
                }
            }
            
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:devicePath];
            if (dict.allKeys.count) {
                NSRange range = [[dict valueForKey:@"runtime"] rangeOfString:version];
                if (range.location != NSNotFound) {
                    NSString *ApplicationPath = [[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Applications"];
                    if (![mgr fileExistsAtPath:ApplicationPath]) {
                        ApplicationPath = [[[[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:@"Application"];
                    }
                    
                    
                    return ApplicationPath;
                    
                }
            }
        }
    }
    return applicationPath;
}


@end
