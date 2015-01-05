//
//  ZLGotoSandbox.m
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-4.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import "ZLGotoSandbox.h"
#import "ZLSandBox.h"
#import "ZLMenuItem.h"

@interface ZLGotoSandbox ()
@property (copy,nonatomic) NSString *homePath;
@property (strong,nonatomic) NSArray *items;
@property (strong,nonatomic) NSFileManager *fileManager;
@end

@implementation ZLGotoSandbox

static NSString * SimulatorPath = @"Library/Developer/CoreSimulator/Devices/";

#pragma mark - lazy getter datas.
- (NSFileManager *)fileManager{
    if (!_fileManager) {
        self.fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (NSString *)homePath{
    if (!_homePath) {
        _homePath = [NSHomeDirectory() stringByAppendingPathComponent:SimulatorPath];
    }
    return _homePath;
}

- (NSArray *)items{
    if (!_items) {
        
        ZLSandBox *box81 = [[ZLSandBox alloc] init];
        box81.boxName = @"Go,iOS8.1 Simulator!";
        box81.items = [self projectsWithBox:box81];
        
        ZLSandBox *box80 = [[ZLSandBox alloc] init];
        box80.boxName = @"Go,iOS8.0 Simulator!";
        box80.items = [self projectsWithBox:box80];
        
        ZLSandBox *box71 = [[ZLSandBox alloc] init];
        box71.boxName = @"Go,iOS7.1 Simulator!";
        box71.items = [self projectsWithBox:box71];
        
        ZLSandBox *box70 = [[ZLSandBox alloc] init];
        box70.boxName = @"Go,iOS7.0 Simulator!";
        box70.items = [self projectsWithBox:box70];
        
        _items = @[
                   box81,box80,box71,box70
                 ];
    }
    return _items;
}


#pragma mark - init
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

#pragma mark - initMenu
- (void)applicationDidFinishLaunching:(NSNotification *)noti{
    
    NSMenuItem *AppMenuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
    [[AppMenuItem submenu] addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *startMenuItem = [[NSMenuItem alloc] init];
    startMenuItem.title = @"Go to Sandbox!";
    startMenuItem.state = NSOnState;
    
    NSMenu *startSubMenu = [[NSMenu alloc] init];
    startMenuItem.submenu = startSubMenu;
    [startMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
    [[AppMenuItem submenu] addItem:startMenuItem];
    
    for (NSInteger i = 0; i < self.items.count; i++) {
        
        ZLSandBox *sandbox = [self.items objectAtIndex:i];
        
        NSMenu *versionSubMenu = [[NSMenu alloc] init];
        for (NSInteger j = 0; j < sandbox.items.count; j++) {
            ZLMenuItem *versionSubMenuItem = [[ZLMenuItem alloc] init];
            [versionSubMenuItem setTarget:self];
            [versionSubMenuItem setAction:@selector(gotoProjectSandBox:)];
            versionSubMenuItem.projectSandBoxPath = sandbox.projectSandBoxPath[j];
            versionSubMenuItem.title = sandbox.items[j];
            [versionSubMenu addItem:versionSubMenuItem];
        }
        
        
        NSMenuItem *versionMenu = [[NSMenuItem alloc] init];
        versionMenu.title = [self.items[i] boxName];
        versionMenu.submenu = versionSubMenu;
        
        [versionMenu setTarget:self];
        [versionMenu setAction:@selector(gotoSandBox:)];
        [versionMenu setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [startSubMenu addItem:versionMenu];
        
    }
}


#pragma mark - show Projects all aplications.
- (NSArray *)projectsWithBox:(ZLSandBox *)box{
    
    NSString *version = [self getVersionWithTitle:box.boxName];
    NSString *path = [self getDevicePath:self.homePath version:version];

    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *projectSandBoxPath = [NSMutableArray array];
    
    NSArray *paths = [self.fileManager contentsOfDirectoryAtPath:path error:nil];
    for (NSString *pathName in paths) {
        NSString *fileName = [path stringByAppendingPathComponent:pathName];
        NSString *fileUrl = [fileName stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        
        if(![self.fileManager fileExistsAtPath:fileUrl]){
            NSArray *arr = [self.fileManager contentsOfDirectoryAtPath:fileName error:nil];
            for (NSString *str in arr) {
                NSRange range = [str rangeOfString:@".app"];
                if (range.location != NSNotFound) {
                    [names addObject:
                     [str stringByReplacingOccurrencesOfString:@".app" withString:@""]];
                    [projectSandBoxPath addObject:fileName];
                }
            }
        }else{
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:fileUrl];
            if ([dict valueForKeyPath:@"MCMMetadataIdentifier"]) {
                NSArray *array = [dict[@"MCMMetadataIdentifier"] componentsSeparatedByString:@"."];
                NSString *projectName = [array lastObject];
                [names addObject:projectName];
                [projectSandBoxPath addObject:fileName];

            }
        }
    }
    
    box.projectSandBoxPath = projectSandBoxPath;
    
    return names;
}

- (void)gotoProjectSandBox:(ZLMenuItem *)item{
    [self openFinderWithFilePath:item.projectSandBoxPath];
}

#pragma mark - go to sandbox list.
- (void)gotoSandBox:(NSMenuItem *)item{
    
    if (!item.title.length) {
        return ;
    }
    
    // 0.Get Click Version. (获取版本号)
    // 1.look directionary has Device.plist (查看文件夹底下是否有device.plist文件)。
    // 2.find runtime field. (找到runtime的字段) rangeOfString 查看是否有相应的信息
    // 3.also is have runtime field . It jump To data/Containers/Data/Application. (如果有就跳转到，当前文件夹底下的 data/Containers/Data/Application)
    
    NSString *version = [self getVersionWithTitle:item.title];

    NSString *path = [self getDevicePath:self.homePath version:version];
    if (!path.length) {
        path = self.homePath;
        NSString *msgText = [NSString stringWithFormat:@"您没有%@版本的目录.\n给您跳转到模拟器的根目录.",version];
        [self showMessageText:msgText];
    }
    
    // open Finder
    [self openFinderWithFilePath:path];
}


#pragma mark - Open Finder
- (void)openFinderWithFilePath:(NSString *)path{
    NSString *open = [NSString stringWithFormat:@"open %@",path];
    const char *str = [open UTF8String];
    system(str);
}

#pragma mark - This is Version Make.
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

#pragma mark - get Simulator List Path.
- (NSString *)getDevicePath:(NSString *)filePath version:(NSString *)version{
    
    NSString *applicationPath = nil;
    if([self.fileManager fileExistsAtPath:filePath]){
        
        NSArray *files = [self.fileManager contentsOfDirectoryAtPath:filePath error:nil];
        
        for (NSString *filesPath in files) {
            
            NSString *devicePath =  [[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"device.plist"];
            
            NSString *ApplicationPath = [[[[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:@"Application"];
            
            if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                ApplicationPath = [[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Applications"];
                if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                    continue;
                }
            }
            
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:devicePath];
            if (dict.allKeys.count) {
                NSRange range = [[dict valueForKey:@"runtime"] rangeOfString:version];
                if (range.location != NSNotFound) {
                    NSString *ApplicationPath = [[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Applications"];
                    if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                        ApplicationPath = [[[[[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:@"Application"];
                    }
                    
                    return ApplicationPath;
                    
                }
            }
        }
    }
    return applicationPath;
}

#pragma mark - alert Message with text
- (void)showMessageText:(NSString *)msgText{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msgText];
    [alert runModal];
}

@end
