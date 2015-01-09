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
@property (copy,nonatomic) NSString *path;
@end

@implementation ZLGotoSandbox

static NSString * SimulatorPath = @"Library/Developer/CoreSimulator/Devices/";
static NSString * DevicePlist = @"device.plist";

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
        self.items = [self setupItems];
    }
    return _items;
}

#pragma mark - setupItems
- (NSArray *)setupItems{
    
    NSMutableArray *items = [NSMutableArray array];
    NSArray *plists = [self getDeviceInfoPlists];
    
    for (NSDictionary *dict in plists) {
        NSString *version = [[[dict valueForKeyPath:@"runtime"]   componentsSeparatedByString:@"."] lastObject] ;
        NSString *device = [dict valueForKeyPath:@"name"];
        
        NSString *boxName = [NSString stringWithFormat:@"%@ (%@)",device, version];
        
        ZLSandBox *box = [[ZLSandBox alloc] init];
        box.boxName = boxName;
        box.version = version;
        box.device = device;
        box.items = [self projectsWithBox:box];
        
        [items addObject:box];
    }
    return items;
}


#pragma mark - init
- (instancetype)init{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowProjectNotification:) name:@"IDEWorkspaceIndexRegistrationBatchNotification" object:nil];
        
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
        NSInteger pathIndex = 0;
        NSMenu *versionSubMenu = [[NSMenu alloc] init];
        for (NSInteger j = 0; j < sandbox.items.count; j++) {
            if (self.path.length && [sandbox.items[j] isEqualToString:self.path]){
                pathIndex = j;
            }else{
                ZLMenuItem *versionSubMenuItem = [[ZLMenuItem alloc] init];
                versionSubMenuItem.index = j;
                versionSubMenuItem.sandbox = sandbox;
                [versionSubMenuItem setTarget:self];
                [versionSubMenuItem setAction:@selector(gotoProjectSandBox:)];
                versionSubMenuItem.title = sandbox.items[j];
                [versionSubMenu addItem:versionSubMenuItem];
            }
        }
        
        if (!sandbox.items.count) {
            ZLMenuItem *versionSubMenuItem = [[ZLMenuItem alloc] init];
            versionSubMenuItem.state = NSOffState;
            versionSubMenuItem.title = @"您没有运行程序到这个模拟器.";
            [versionSubMenu addItem:versionSubMenuItem];
        }else{
            if (self.path.length && [sandbox.items[pathIndex] isEqualToString:self.path]) {
                ZLMenuItem *versionSubMenuItem = [[ZLMenuItem alloc] init];
                versionSubMenuItem.index = pathIndex;
                versionSubMenuItem.sandbox = sandbox;
                [versionSubMenuItem setTarget:self];
                [versionSubMenuItem setAction:@selector(gotoProjectSandBox:)];
                versionSubMenuItem.title = [NSString stringWithFormat:@"当前项目 - %@",sandbox.items[pathIndex]];
                [versionSubMenu insertItem:versionSubMenuItem atIndex:0];
                
                
                [versionSubMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
            }
        }
        
        
        ZLMenuItem *versionMenuItem = [[ZLMenuItem alloc] init];
        versionMenuItem.sandbox = sandbox;
        [versionMenuItem setImage:[NSImage imageNamed:@"EOEntity"]];
        versionMenuItem.title = [self.items[i] boxName];
        versionMenuItem.submenu = versionSubMenu;
        
        
        [versionMenuItem setTarget:self];
        [versionMenuItem setAction:@selector(gotoSandBox:)];
        [startSubMenu addItem:versionMenuItem];
        
    }
}

#pragma mark - get Current Directory
- (void)nowProjectNotification:(NSNotification *)noti{
    if (self.path.length) {
        return ;
    }
    
    NSString *path = [[[noti.object description] componentsSeparatedByString:@"path:"] lastObject];
    path = [path stringByReplacingOccurrencesOfString:@">" withString:@""];
    
    NSArray *paths = [path componentsSeparatedByString:@"/"];
    
    
    for (NSString *pathName in paths) {
        NSRange range = [pathName rangeOfString:@".xcodeproj"];
        if (range.location != NSNotFound) {
            path = [pathName stringByReplacingOccurrencesOfString:@".xcodeproj" withString:@""];
            self.path = path;
            break;
        }
    }
    
    [self applicationDidFinishLaunching:nil];
}

#pragma mark - show Projects all aplications.
- (NSArray *)projectsWithBox:(ZLSandBox *)box{
    
    NSString *path = [self getDevicePath:box];

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
                     [[str stringByReplacingOccurrencesOfString:@".app" withString:@""] stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
                    
                    [projectSandBoxPath addObject:fileName];
                }
            }
        }else{
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:fileUrl];
            if ([dict valueForKeyPath:@"MCMMetadataIdentifier"]) {
                NSArray *array = [dict[@"MCMMetadataIdentifier"] componentsSeparatedByString:@"."];
                NSString *projectName = [array lastObject];
                projectName = [projectName stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
                [names addObject:projectName];
                [projectSandBoxPath addObject:fileName];

            }
        }
    }
    
    box.projectSandBoxPath = projectSandBoxPath;
    
    return names;
}

- (void)gotoProjectSandBox:(ZLMenuItem *)item{
    [self openFinderWithFilePath:item.sandbox.projectSandBoxPath[item.index]];
}

#pragma mark - go to sandbox list.
- (void)gotoSandBox:(ZLMenuItem *)item{
    
    if (!item.title.length) {
        return ;
    }
    
    // 0.Get Click Version. (获取版本号)
    // 1.look directionary has Device.plist (查看文件夹底下是否有device.plist文件)。
    // 2.find runtime field. (找到runtime的字段) rangeOfString 查看是否有相应的信息
    // 3.also is have runtime field . It jump To data/Containers/Data/Application. (如果有就跳转到，当前文件夹底下的 data/Containers/Data/Application)
    NSString *path = [self getDevicePath:item.sandbox];
    // open Finder
    if (!path.length) {
        path = self.homePath;
        [self showMessageText:[NSString stringWithFormat:@"%@版本的模拟器还没有任何的程序\n给您跳转到根目录 (*^__^*)", item.sandbox.boxName]];
    }
    [self openFinderWithFilePath:path];
    
}


#pragma mark - Open Finder
- (void)openFinderWithFilePath:(NSString *)path{
    NSString *open = [NSString stringWithFormat:@"open %@",path];
    const char *str = [open UTF8String];
    system(str);
}

#pragma mark - get Simulator List Path.
- (NSString *)getDevicePath:(ZLSandBox *)sandbox{
    
    NSString *filePath = self.homePath;
    if(![self.fileManager fileExistsAtPath:filePath]){
        return nil;
    }
    
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:filePath error:nil];
    
    for (NSString *filesPath in files) {
        NSString *devicePath =  [[filePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:DevicePlist];

        NSString *ApplicationPath = [self getBundlePath:filesPath];
        
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:devicePath];
        if (dict.allKeys.count) {
            NSRange range = [[dict valueForKey:@"name"] rangeOfString:sandbox.device];
            if (range.location != NSNotFound) {
                if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                    ApplicationPath = [self getBundleApllcationPath:filesPath];
                    if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                        return nil;
                        //return [self.homePath stringByAppendingPathComponent:filesPath];
                    }
                }
                ApplicationPath = [self getBundleApllcationPath:filesPath];
                if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                    ApplicationPath = [self getBundlePath:filesPath];
                }
                
                return ApplicationPath;
                
            }
        }
    }
    return nil;
}
    
- (NSString *)getBundlePath:(NSString *)filePath{
    return [[[[[self.homePath stringByAppendingPathComponent:filePath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:@"Application"];
}

- (NSString *)getBundleApllcationPath:(NSString *)filePath{
   return [[[filePath stringByAppendingPathComponent:filePath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Applications"];
}

#pragma mark - load all device plist info.
- (NSArray *)getDeviceInfoPlists{
    NSMutableArray *plists = [NSMutableArray array];
    if([self.fileManager fileExistsAtPath:self.homePath]){
        NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.homePath error:nil];
        
        for (NSString *filesPath in files) {
            
            NSString *devicePath =  [[self.homePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:DevicePlist];
            if (![self.fileManager fileExistsAtPath:devicePath]) {
                continue;
            }
            
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:devicePath];
            if (dict.allKeys.count) {
                [plists addObject:dict];
            }
        }
    }
    return plists;
}

#pragma mark - alert Message with text
- (void)showMessageText:(NSString *)msgText{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msgText];
    [alert runModal];
}

@end
