//
//  ZLGotoSandbox.m
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-1-4.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import "ZLGotoSandbox.h"
#import "ZLSandBox.h"
#import "ZLItemDatas.h"

@interface ZLGotoSandbox ()

@property (strong,nonatomic) NSArray *items;
@property (copy,nonatomic) NSString *path;
@property (strong,nonatomic) NSMutableArray *sources;
@property (assign,nonatomic) NSInteger currentIndex;
@property (copy,nonatomic) NSString *currentPath;

@end

@implementation ZLGotoSandbox

static NSString * ZLChangeSandboxRefreshItems = @"ZLChangeSandboxRefreshItems";
static NSString * MenuTitle = @"Go to Sandbox!";
static NSString * PrefixMenuTitle = @"当前项目 - ";
static NSString * PrefixFile = @"Add Files to “";
static NSString * MCMMetadataIdentifier = @"MCMMetadataIdentifier";

#pragma mark - lazy getter datas.
- (NSArray *)items{
    if (!_items) {
        NSArray *items = [ZLItemDatas getAllItems];
        
        items = [items sortedArrayUsingComparator:^NSComparisonResult(ZLSandBox *obj1, ZLSandBox *obj2) {
            return [obj1.version compare:obj2.version];
        }];
        
        self.items = [items sortedArrayUsingComparator:^NSComparisonResult(ZLSandBox *obj1, ZLSandBox *obj2) {
            if ([obj1.device compare:obj2.device] == NSOrderedAscending){
                return NSOrderedDescending;
            }else{
                return NSOrderedAscending;                
            }
        }];
        
        items = nil;
    }
    return _items;
}

- (NSMutableArray *)sources{
    if (!_sources) {
        _sources = [NSMutableArray array];
    }
    return _sources;
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationUnderMouseProjectName:) name:@"DVTSourceExpressionUnderMouseDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidAddNowCurrentProjectName:) name:@"IDEIndexDidChangeStateNotification" object:nil];
}

#pragma mark - addObserver change xcode project.
#pragma mark change window.
- (void)applicationUnderMouseProjectName:(NSNotification *)noti{
    NSMutableArray *paths = [NSMutableArray arrayWithArray:[[noti.object description] componentsSeparatedByString:@"/"]];
    NSString *workspacePath = nil;
    if (paths.count) {
        [paths removeLastObject];
        workspacePath = [[paths lastObject] stringByDeletingPathExtension];
    }
    if (workspacePath.length) {
        self.path = [workspacePath stringByDeletingPathExtension];
    }
}

#pragma mark change add Xcode project.
- (void)applicationDidAddNowCurrentProjectName:(NSNotification *)noti{
    NSRange range = [[noti.object description] rangeOfString:@"> "];
    NSString *path = [[noti.object description] substringFromIndex:range.location + range.length];
    if (![self.path isEqualToString:path] || !self.path.length) {
        self.path = path;
        [self applicationDidFinishLaunching:nil];
    }
}

#pragma mark change item.
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
    
    NSInteger index = -1;
    if ([noti.name isEqualToString:NSApplicationDidFinishLaunchingNotification]) {
        // 第一次监听文件改变
        [self addObserverFileChange];
    }else if ([noti.name isEqualToString:ZLChangeSandboxRefreshItems]){
        index = 0;
        for (NSMenuItem *item in [[AppMenuItem submenu] itemArray]) {
            if ([item.title isEqualToString:MenuTitle]) {
                [[AppMenuItem submenu] removeItemAtIndex:index-1];
                [[AppMenuItem submenu] removeItem:item];
                break;
            }
            index++;
        }
    }
    
    // 如果没有切换过项目/Xcode
    if (noti) {
        startMenuItem = [[NSMenuItem alloc] init];
        startMenuItem.title = MenuTitle;
        startMenuItem.state = NSOnState;
        
        startSubMenu  = [[NSMenu alloc] init];
        startMenuItem.submenu = startSubMenu;

        [[AppMenuItem submenu] addItem:[NSMenuItem separatorItem]];
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
    
    [startMenuItem setKeyEquivalentModifierMask: NSShiftKeyMask | NSCommandKeyMask];
    [startMenuItem setKeyEquivalent:@"w"];
    startMenuItem.target = self;
    startMenuItem.action = @selector(goNowCurrentSandbox:);
    
    for (NSInteger i = 0; i < self.items.count; i++) {
        ZLSandBox *sandbox = [self.items objectAtIndex:i];
        NSMenu *versionSubMenu = nil;
        NSInteger index = 0;
        if (noti) {
            versionSubMenu = [[NSMenu alloc] init];
        }else{
            if (i < [startSubMenu itemArray].count){
                versionSubMenu = [[startSubMenu itemAtIndex:i] submenu];
            }
        }
    
        for (NSInteger j = 0; j < sandbox.items.count; j++) {
            if (self.path.length && [sandbox.items[j] isEqualToString:self.path]){
                index = j;
            }
            if (noti){
                NSString *imagePath = [ZLItemDatas getBundleImagePathWithFilePath:sandbox.projectSandBoxPath[j]];
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
        
        if (!sandbox.items.count) {
            if (noti) {
                ZLMenuItem *versionSubMenuItem = [[ZLMenuItem alloc] init];
                versionSubMenuItem.state = NSOffState;
                versionSubMenuItem.title = @"您没有运行程序到这个模拟器.";
                [versionSubMenu addItem:versionSubMenuItem];
            }
        }else{
            
            if ((self.path.length && [sandbox.items[index] rangeOfString:self.path].location != NSNotFound )) {
                ZLMenuItem *versionSubMenuItem = [[versionSubMenu itemArray] firstObject];
                
                NSString *title = [versionSubMenuItem.title stringByReplacingOccurrencesOfString:PrefixMenuTitle withString:@""];
                
                if (![title isEqualToString:self.path] && versionSubMenuItem.tag != 101) {
                    versionSubMenuItem = [[ZLMenuItem alloc] init];
                    versionSubMenuItem.tag = 101;
                    [versionSubMenuItem setTarget:self];
                    [versionSubMenuItem setAction:@selector(gotoProjectSandBox:)];
                    [versionSubMenu insertItem:versionSubMenuItem atIndex:0];
                    [versionSubMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
                    
                    NSString *imagePath = [ZLItemDatas getBundleImagePathWithFilePath:sandbox.projectSandBoxPath[index]];
                    NSData *data = [NSData dataWithContentsOfFile:imagePath];
                    NSImage *image = [[NSImage alloc] initWithData:data];
                    [image setSize:NSSizeFromCGSize(CGSizeMake(18, 18))];
                    versionSubMenuItem.image = image;
                }
                
                if (versionSubMenuItem.tag == 101) {
                    versionSubMenuItem.index = index;
                    versionSubMenuItem.sandbox = sandbox;
                    versionSubMenuItem.title = [NSString stringWithFormat:@"%@%@",PrefixMenuTitle,sandbox.items[index]];
                }
                
                
                NSAttributedString *attr = [[NSAttributedString alloc] initWithString:versionSubMenuItem.title attributes:@{NSFontAttributeName: [NSFont userFontOfSize:16] , NSForegroundColorAttributeName:[NSColor redColor]}];
                versionSubMenuItem.attributedTitle = attr;

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

#pragma mark - 跳转到当前沙盒
- (void)goNowCurrentSandbox:(ZLMenuItem *)item{
    if (!self.currentPath.length) {
        [self showMessageText:@"MakeZL温馨提示：运行应用的时候,才会跳转到沙盒,中文的话可能是不行的哦~ (去菜单栏File -> go to sandbox)"];
    }
    [self openFinderWithFilePath:self.currentPath];
}

- (void)gotoProjectSandBox:(ZLMenuItem *)item{
    NSString *path = item.sandbox.projectSandBoxPath[item.index];
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
    NSString *path = [ZLItemDatas getDevicePath:item.sandbox];
    // open Finder
    if (!path.length) {
        path = [ZLItemDatas getHomePath];
        [self showMessageText:[NSString stringWithFormat:@"%@版本的模拟器还没有任何的程序\n给您跳转到根目录 (*^__^*)", item.sandbox.boxName]];
    }
    [self openFinderWithFilePath:path];
    
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

#pragma mark - addObserverFileChange
- (void)addObserverFileChange{
    
    NSUInteger count = self.items.count;
    for (NSInteger i = 0;i < count; i++) {
        
        ZLSandBox *sandbox = self.items[i];
        NSString *path = [ZLItemDatas getDevicePath:sandbox];
        if (path == nil) {
            continue;
        }
        
        NSURL *directoryURL = [NSURL fileURLWithPath:path]; // assume this is set to a directory
        int const fd = open([[directoryURL path] fileSystemRepresentation], O_EVTONLY);
        if (fd < 0) {
            char buffer[80];
            strerror_r(errno, buffer, sizeof(buffer));
            NSLog(@"Unable to open \"%@\": %s (%d)", [directoryURL path], buffer, errno);
            return;
        }
        
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
                                                          DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE, DISPATCH_TARGET_QUEUE_DEFAULT);
        
        dispatch_source_set_event_handler(source, ^(){
            unsigned long const data = dispatch_source_get_data(source);
            
            // 监听到改变了就去刷新Items
            self.currentPath = [ZLItemDatas getAppName:self.path withSandbox:sandbox];
            if (data & DISPATCH_VNODE_WRITE || data & DISPATCH_VNODE_DELETE) {
                sandbox.items = [ZLItemDatas projectsWithBox:sandbox];
                [self applicationDidFinishLaunching:[[NSNotification alloc] initWithName:ZLChangeSandboxRefreshItems object:nil userInfo:nil]];
            }
            
        });
        dispatch_source_set_cancel_handler(source, ^(){
            close(fd);
        });
        dispatch_resume(source);
    }
    
}

#pragma mark - alert Message with text
- (void)showMessageText:(NSString *)msgText{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msgText];
    [alert runModal];
}

@end
