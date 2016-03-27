//  github: https://github.com/MakeZL/ZLGotoSandboxPlugin
//  Author: @email <120886865@qq.com> @weibo <weibo.com/makezl>
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
// leave in Simpulator items;
@property (strong,nonatomic) NSArray *items;
// current `Project` path
@property (copy,nonatomic) NSString *path;
// `shortcut keys` Jump need.
@property (copy,nonatomic) NSString *currentPath;
// recoder startMenuItem.
@property (strong,nonatomic) NSMenuItem *startMenuItem;
@end

@implementation ZLGotoSandbox

static NSString * ZLChangeSandboxRefreshItems = @"ZLChangeSandboxRefreshItems";
static NSString * MenuTitle = @"Go to Sandbox!";
static NSString * PrefixMenuTitle = @"NowApp - ";
static NSString * PrefixFile = @"Add Files to “";
static NSInteger VersionSubMenuItemTag = 101;

#pragma mark - lazy getter datas.
- (NSArray *)items{
    if (!_items) {
        self.items = [[ZLItemDatas getAllItems] sortedArrayUsingComparator:^NSComparisonResult(ZLSandBox *obj1, ZLSandBox *obj2) {
            return [obj1.version compare:obj2.version];
        }];
        
        // sort
        self.items = [self.items sortedArrayUsingComparator:^NSComparisonResult(ZLSandBox *obj1, ZLSandBox *obj2) {
            if ([obj1.device compare:obj2.device] == NSOrderedAscending){
                return NSOrderedDescending;
            }else{
                return NSOrderedAscending;                
            }
        }];
    }
    return _items;
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
    
    if (![self.path isEqualToString:workspacePath] && workspacePath.length) {
        self.path = [workspacePath stringByDeletingPathExtension];
        [self applicationDidFinishLaunching:nil];
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
    
    // No change XCode.
    if (noti) {
        startMenuItem = [[NSMenuItem alloc] init];
        startMenuItem.title = MenuTitle;
        startMenuItem.state = NSOnState;
        
        startSubMenu  = [[NSMenu alloc] init];
        startMenuItem.submenu = startSubMenu;
        
        if (index != -1){
            [[AppMenuItem submenu] insertItem:[NSMenuItem separatorItem] atIndex:index-1];
            [[AppMenuItem submenu] insertItem:startMenuItem atIndex:index];
        }else{
            [[AppMenuItem submenu] addItem:[NSMenuItem separatorItem]];
            [[AppMenuItem submenu] addItem:startMenuItem];
        }
    }else{
        // Change XCode , `Recycling` items.
        for (NSMenuItem *item in [[AppMenuItem submenu] itemArray]) {
            if ([item.title isEqualToString:MenuTitle]) {
                startMenuItem = item;
                startSubMenu = item.submenu;
                break;
            }
        }
    }
    
    self.startMenuItem = startMenuItem;
    // Add ShortcutKey
    [self addStartMenuItemShortcutKeys];
    
    NSUInteger itemCount = self.items.count;
    
    for (NSInteger i = 0; i < itemCount; i++) {
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
                versionSubMenuItem.title = @"No run Application In the simulator.";
                [versionSubMenu addItem:versionSubMenuItem];
            }
        }else{
            
            if ((self.path.length && [sandbox.items[index] rangeOfString:self.path].location != NSNotFound )) {
                ZLMenuItem *versionSubMenuItem = [[versionSubMenu itemArray] firstObject];
                
                NSString *title = [versionSubMenuItem.title stringByReplacingOccurrencesOfString:PrefixMenuTitle withString:@""];
                
                if (![title isEqualToString:self.path] && versionSubMenuItem.tag != VersionSubMenuItemTag) {
                    versionSubMenuItem = [[ZLMenuItem alloc] init];
                    versionSubMenuItem.tag = VersionSubMenuItemTag;
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
                
                if (versionSubMenuItem.tag == VersionSubMenuItemTag) {
                    versionSubMenuItem.index = index;
                    versionSubMenuItem.sandbox = sandbox;
                    versionSubMenuItem.title = [NSString stringWithFormat:@"%@%@",PrefixMenuTitle,sandbox.items[index]];
                }
                
                NSAttributedString *attr = [[NSAttributedString alloc] initWithString:versionSubMenuItem.title attributes:@{NSFontAttributeName: [NSFont userFontOfSize:16] , NSForegroundColorAttributeName:[NSColor greenColor]}];
                versionSubMenuItem.attributedTitle = attr;
                
            }else{
                // clear Items
                ZLMenuItem *versionSubMenuItem = [[versionSubMenu itemArray] firstObject];
                if (versionSubMenuItem.tag == VersionSubMenuItemTag) {
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
        
        if (index != -1 && ([noti.name isEqualToString:ZLChangeSandboxRefreshItems])) {
            [startSubMenu cancelTracking];
        }
    }
}

- (void)addStartMenuItemShortcutKeys{
    [self.startMenuItem setKeyEquivalentModifierMask: NSShiftKeyMask | NSCommandKeyMask];
    [self.startMenuItem setKeyEquivalent:@"w"];
    self.startMenuItem.target = self;
    self.startMenuItem.action = @selector(goNowCurrentSandbox:);
}

#pragma mark - Jump Current Sandbox.
- (void)goNowCurrentSandbox:(ZLMenuItem *)item{
    if (!self.currentPath.length) {
        [self showMessageText:[NSString stringWithFormat:@"%@:%@ > %@",self.currentPath,self.path,@"MakeZL : In the Run Simulation. Must be App info.plist Identifier is EqualTo Project Name."]];
    }
    [self openFinderWithFilePath:self.currentPath];
}

- (void)gotoProjectSandBox:(ZLMenuItem *)item{
    NSString *path = item.sandbox.projectSandBoxPath[item.index];
    [self openFinderWithFilePath:path];
}

#pragma mark - go to sandbox list.
- (void)gotoSandBox:(ZLMenuItem *)item{
    if (!item.title.length) return ;
    
    NSString *path = [ZLItemDatas getDevicePath:item.sandbox];
    // open Finder
    if (!path.length) {
        path = [ZLItemDatas getHomePath];
        [self showMessageText:[NSString stringWithFormat:@"%@ Simualtor no Apps . Give you a Jump to root Directory. (*^__^*)", item.sandbox.boxName]];
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
        if (path == nil) continue;
        NSURL *directoryURL = [NSURL fileURLWithPath:path]; // assume this is set to a directory
        int const fd = open([[directoryURL path] fileSystemRepresentation], O_EVTONLY);
        if (fd < 0) {
            char buffer[80];
            strerror_r(errno, buffer, sizeof(buffer));
            NSLog(@"Unable to open \"%@\": %s (%d)", [directoryURL path], buffer, errno);
            return;
        }
        
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
                                                        DISPATCH_VNODE_LINK |
                                                          DISPATCH_VNODE_EXTEND |
                                                          DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE, DISPATCH_TARGET_QUEUE_DEFAULT);
        
        dispatch_source_set_event_handler(source, ^(){
            unsigned long const data = dispatch_source_get_data(source);
            // change refresh items.
            self.currentPath = [ZLItemDatas getAppName:self.path withSandbox:sandbox];
            if (data & DISPATCH_VNODE_WRITE || data & DISPATCH_VNODE_DELETE) {
                sandbox.items = [ZLItemDatas projectsWithBox:sandbox];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self applicationDidFinishLaunching:[[NSNotification alloc] initWithName:ZLChangeSandboxRefreshItems object:nil userInfo:nil]];
                });
            }
            
        });
        dispatch_source_set_cancel_handler(source, ^(){
            close(fd);
        });
        dispatch_resume(source);
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - alert Message with text
- (void)showMessageText:(NSString *)msgText{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msgText];
    [alert runModal];
}

@end
