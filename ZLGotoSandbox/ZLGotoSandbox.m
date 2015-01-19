//
//  ZLGotoSandbox.m
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-4.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import "ZLGotoSandbox.h"
#import "ZLSandBox.h"

@interface ZLGotoSandbox ()
@property (copy,nonatomic) NSString *homePath;
@property (strong,nonatomic) NSArray *items;
@property (strong,nonatomic) NSFileManager *fileManager;
@property (copy,nonatomic) NSString *path;
@end

@implementation ZLGotoSandbox

static NSString * SimulatorPath = @"Library/Developer/CoreSimulator/Devices/";
static NSString * DevicePlist = @"device.plist";
static NSString * MenuTitle = @"Go to Sandbox!";
static NSString * PrefixMenuTitle = @"当前项目 - ";
static NSString * PrefixFile = @"Add Files to “";
static NSString * MCMMetadataIdentifier = @"MCMMetadataIdentifier";

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
        box.udid = dict[@"UDID"];
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
        [self addNotification];
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

- (void)addNotification{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidAddCurrentMenu:) name:NSMenuDidChangeItemNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidAddNowCurrentProjectName:) name:@"IDEIndexDidChangeStateNotification" object:nil];
}

- (void)applicationDidAddNowCurrentProjectName:(NSNotification *)noti{
    NSRange range = [[noti.object description] rangeOfString:@"> "];
    NSString *path = [[noti.object description] substringFromIndex:range.location + range.length];
    if (![self.path isEqualToString:path] || !self.path.length) {
        self.path = path;
        [self applicationDidFinishLaunching:nil];
    }
}

#pragma mark - addObserver change xcode project.
- (void)applicationDidAddCurrentMenu:(NSNotification *)noti{
    NSMenu *menu = noti.object;
    if ([menu.title isEqualToString:@"File"]) {
        for (NSMenuItem *item in [menu itemArray]) {
        NSRange r = [item.title rangeOfString:PrefixFile];
        if (r.location != NSNotFound) {
            NSString *path = [item.title stringByReplacingOccurrencesOfString:PrefixFile withString:@""];
            
            NSRange range = [path rangeOfString:@"”"];
            path = [path substringToIndex:range.location];
            
                if (![self.path isEqualToString:path] || !self.path.length) {
                    self.path = path;
                    [self applicationDidFinishLaunching:nil];
                }
            }
        }
    }
}

#pragma mark - initMenu
- (void)applicationDidFinishLaunching:(NSNotification *)noti{
    NSMenuItem *AppMenuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
    NSMenuItem *startMenuItem = nil;
    NSMenu *startSubMenu = nil;
    
    // 如果没有切换过项目/Xcode
    if (noti) {
        [[AppMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        startMenuItem = [[NSMenuItem alloc] init];
        startMenuItem.title = MenuTitle;
        startMenuItem.state = NSOnState;
        
        startSubMenu  = [[NSMenu alloc] init];
        startMenuItem.submenu = startSubMenu;
        [startMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [[AppMenuItem submenu] addItem:startMenuItem];
    }else{
        // 如果切换了项目/Xcode,就从列表取,不需要再次创建,节省内存
        for (NSMenuItem *item in [[AppMenuItem submenu] itemArray]) {
            if ([item.title isEqualToString:MenuTitle]) {
                startMenuItem = item;
                startSubMenu = item.submenu;
                break;
            }
        }
    }
    
    for (NSInteger i = 0; i < self.items.count; i++) {
        ZLSandBox *sandbox = [self.items objectAtIndex:i];
        NSInteger pathIndex = 0;
        NSMenu *versionSubMenu = nil;
        if (noti) {
            versionSubMenu = [[NSMenu alloc] init];
        }else{
            versionSubMenu = [[startSubMenu itemAtIndex:i] submenu];
        }
        
        for (NSInteger j = 0; j < sandbox.items.count; j++) {
            if (self.path.length && [sandbox.items[j] isEqualToString:self.path]){
                pathIndex = j;
            }else{
             if (noti) {
                 NSString *imagePath = [self getBundleImagePathWithFilePath:sandbox.projectSandBoxPath[j]];
                 NSData *data = [NSData dataWithContentsOfFile:imagePath];
                 NSImage *image = [[NSImage alloc] initWithData:data];
                 [image setSize:NSSizeFromCGSize(CGSizeMake(18, 18))];
                 
                ZLMenuItem *versionSubMenuItem = [[ZLMenuItem alloc] init];
                versionSubMenuItem.image = image;
                versionSubMenuItem.index = j;
                versionSubMenuItem.sandbox = sandbox;
                [versionSubMenuItem setTarget:self];
                [versionSubMenuItem setAction:@selector(gotoProjectSandBox:)];
                versionSubMenuItem.title = sandbox.items[j];
                [versionSubMenu addItem:versionSubMenuItem];
             }
           }
        }
        
        if (!sandbox.items.count) {
            if (noti) {
                ZLMenuItem *versionSubMenuItem = [[ZLMenuItem alloc] init];
                versionSubMenuItem.state = NSOffState;
                versionSubMenuItem.title = @"您没有运行程序到这个模拟器.";
                [versionSubMenu addItem:versionSubMenuItem];
            }
        }else{
            if (self.path.length && [sandbox.items[pathIndex] isEqualToString:self.path] ) {
                ZLMenuItem *versionSubMenuItem = [[versionSubMenu itemArray] firstObject];
                NSString *title = [versionSubMenuItem.title stringByReplacingOccurrencesOfString:PrefixMenuTitle withString:@""];
                if (!([title isEqualToString:self.path]) && versionSubMenuItem.tag != 101) {
                    versionSubMenuItem = [[ZLMenuItem alloc] init];
                    versionSubMenuItem.tag = 101;
                    [versionSubMenuItem setTarget:self];
                    [versionSubMenuItem setAction:@selector(gotoProjectSandBox:)];
                    [versionSubMenu insertItem:versionSubMenuItem atIndex:0];
                    [versionSubMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
                    
                    NSString *imagePath = [self getBundleImagePathWithFilePath:sandbox.projectSandBoxPath[pathIndex]];
                    NSData *data = [NSData dataWithContentsOfFile:imagePath];
                    NSImage *image = [[NSImage alloc] initWithData:data];
                    [image setSize:NSSizeFromCGSize(CGSizeMake(18, 18))];
                    versionSubMenuItem.image = image;
                }
                
                
                versionSubMenuItem.index = pathIndex;
                versionSubMenuItem.sandbox = sandbox;
                versionSubMenuItem.title = [NSString stringWithFormat:@"%@%@",PrefixMenuTitle,sandbox.items[pathIndex]];
            }else{
                // 清空
                ZLMenuItem *versionSubMenuItem = [[versionSubMenu itemArray] firstObject];
                if (versionSubMenuItem.tag == 101) {
                    [versionSubMenu removeItem:versionSubMenuItem];
                    [versionSubMenu removeItem:[[versionSubMenu itemArray] firstObject]];
                }
            }
        }
        
        if (noti) {
            ZLMenuItem *versionMenuItem = [[ZLMenuItem alloc] init];
            versionMenuItem.sandbox = sandbox;
            versionMenuItem.title = [self.items[i] boxName];
            versionMenuItem.submenu = versionSubMenu;
            
            [versionMenuItem setTarget:self];
            [versionMenuItem setAction:@selector(gotoSandBox:)];
            [startSubMenu addItem:versionMenuItem];
        }
    }
}

#pragma mark - show Projects all aplications.
- (NSArray *)projectsWithBox:(ZLSandBox *)box{
    
    NSString *path = [self getDevicePath:box];
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *projectSandBoxPath = [NSMutableArray array];
    
    NSArray *paths = [self.fileManager contentsOfDirectoryAtPath:path error:nil];
    for (NSString *pathName in paths) {
        NSString *fileName = [path stringByAppendingPathComponent:pathName];
        NSString *fileUrl = [self getDataDictPathWithFileName:fileName];
        
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
            if ([dict valueForKeyPath:MCMMetadataIdentifier]) {
                
                [names addObject:[self getAppName:dict[MCMMetadataIdentifier]]];
                [projectSandBoxPath addObject:fileName];

            }
        }
    }
    
    box.projectSandBoxPath = projectSandBoxPath;
    
    return names;
}

- (void)gotoProjectSandBox:(ZLMenuItem *)item{
    
    NSString *path = item.sandbox.projectSandBoxPath[item.index];
    if (![self.fileManager fileExistsAtPath:path]) {
        path = [path stringByDeletingLastPathComponent];
        [self showMessageText:@"您可能已经在模拟器删除了这个程序，给您跳转到它上一个目录。"];
    }
    [self openFinderWithFilePath:path];
}

#pragma mark - go to sandbox list.
- (void)gotoSandBox:(ZLMenuItem *)item{
    
    if (!item.title.length) {
        return ;
    }
    
    // Note:
    // 1.获取版本号
    // 2.查看文件夹底下是否有device.plist文件
    // 3.Device.plist (找到runtime的字段) rangeOfString 查看是否有相应的信息 。
    // 4.如果有就跳转到，当前文件夹底下的 data/Containers/Data/Application
    NSString *path = [self getDevicePath:item.sandbox];
    // open Finder
    if (!path.length) {
        path = self.homePath;
        [self showMessageText:[NSString stringWithFormat:@"%@版本的模拟器还没有任何的程序\n给您跳转到根目录 (*^__^*)", item.sandbox.boxName]];
    }
    [self openFinderWithFilePath:path];
    
}

- (NSString *)getDataDictPathWithFileName:(NSString *)fileName{
    return [fileName stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
}

- (NSDictionary *)getDataDictWithFileName:(NSString *)fileName{
    return [NSDictionary dictionaryWithContentsOfFile:[self getDataDictPathWithFileName:fileName]];
}

#pragma mark - Open Finder
- (void)openFinderWithFilePath:(NSString *)path{
    if (!path.length) {
        return ;
    }
    
    NSString *open = [NSString stringWithFormat:@"open %@",path];
    const char *str = [open UTF8String];
    system(str);
}

#pragma mark - get Simulator List Path.
- (NSString *)getDevicePath:(ZLSandBox *)sandbox{
    
    if(![self.fileManager fileExistsAtPath:self.homePath]){
        return nil;
    }
    
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.homePath error:nil];
    
    NSString *ApplicationPath = nil;
    
    for (NSString *filesPath in files) {
        NSString *devicePath =  [[self.homePath stringByAppendingPathComponent:filesPath] stringByAppendingPathComponent:DevicePlist];

        ApplicationPath = [self getDataPath:filesPath];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:devicePath];
        
        if (dict.allKeys.count) {
            NSRange range = [[dict valueForKey:@"UDID"] rangeOfString:sandbox.udid];
            
            if (range.location != NSNotFound) {
                
                if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                    ApplicationPath = [self getDataApplicationPath:filesPath];
                    
                    if (![self.fileManager fileExistsAtPath:ApplicationPath]) {
                        return nil;
                    }
                }
                
                if (!ApplicationPath.length) {
                    ApplicationPath = [self getDataApplicationPath:filesPath];
                }
                return ApplicationPath;
            }
        }
    }
    
    return ApplicationPath;
}

- (NSString *)getDataPath:(NSString *)filePath{
    return [[[[[self.homePath stringByAppendingPathComponent:filePath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:@"Application"];
}

- (NSString *)getDataApplicationPath:(NSString *)filePath{
   return [[[self.homePath stringByAppendingPathComponent:filePath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Applications"];
}

- (NSString *)getBundleImagePathWithFilePath:(NSString *)filePath{
    
    NSString *containersPath = [[[filePath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    
    NSString *bundleApplicationPath = [[containersPath stringByAppendingPathComponent:@"Bundle"] stringByAppendingPathComponent:@"Application"];
    
    NSDictionary *dataDict = [self getDataDictWithFileName:filePath];
    NSString *dataName = [self getAppName:dataDict[MCMMetadataIdentifier]];
    
    NSArray *applicationPaths = [self.fileManager contentsOfDirectoryAtPath:bundleApplicationPath error:nil];
    for (NSString *applicationPath in applicationPaths) {
        NSDictionary *dict = [self getDataDictWithFileName:[bundleApplicationPath stringByAppendingPathComponent:applicationPath]];
        NSString *appDictPath = [self getAppName:dict[MCMMetadataIdentifier]];
        if ([dataName isEqualToString:appDictPath]) {
            
            NSString *appPath = [bundleApplicationPath stringByAppendingPathComponent:applicationPath];
            NSArray *paths = [self.fileManager contentsOfDirectoryAtPath:appPath error:nil];
            NSString *appName = nil;
            for (NSString *pathName in paths) {
                if ([[pathName pathExtension] isEqualToString:@"app"]) {
                    appName = pathName;
                    break;
                }
            }
            
            if (appName) {
                NSArray *resources = [self.fileManager contentsOfDirectoryAtPath:[appPath stringByAppendingPathComponent:appName] error:nil];
                
                for (NSString *resource in resources) {
                    NSRange range = [resource rangeOfString:@"AppIcon"];
                    if (range.location != NSNotFound) {
                        return [[appPath stringByAppendingPathComponent:appName] stringByAppendingPathComponent:resource];
                    }
                }
                
            }
        }
    }
    return nil;
}

- (NSString *)getAppName:(NSString *)identifierName{
    NSArray *array = [identifierName componentsSeparatedByString:@"."];
    NSString *projectName = [array lastObject];
    projectName = [projectName stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    return projectName;
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
