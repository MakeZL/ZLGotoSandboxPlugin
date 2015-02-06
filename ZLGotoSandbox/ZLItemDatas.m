//
//  ZLItemDatas.m
//  ZLGotoSandbox
//
//  Created by 张磊 on 15-2-6.
//  Copyright (c) 2015年 com.zixue101.www. All rights reserved.
//

#import "ZLItemDatas.h"

@interface ZLItemDatas ()

@end

static NSString * DevicePlist = @"device.plist";
static NSString * MCMMetadataIdentifier = @"MCMMetadataIdentifier";
static NSString * SimulatorPath = @"Library/Developer/CoreSimulator/Devices/";
static NSFileManager *_fileManager = nil;
static NSString *_homePath = nil;

@implementation ZLItemDatas

+ (NSFileManager *)fileManager{
    if (!_fileManager) {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

+ (NSString *)homePath{
    if (!_homePath) {
        _homePath = [NSHomeDirectory() stringByAppendingPathComponent:SimulatorPath];
    }
    return _homePath;
}


#pragma mark - getAllItems
+ (NSArray *)getAllItems{
    
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

#pragma mark - load all device plist info.
+ (NSArray *)getDeviceInfoPlists{
    NSMutableArray *plists = [NSMutableArray array];
    if([[self fileManager] fileExistsAtPath:self.homePath]){
        NSArray *files = [_fileManager contentsOfDirectoryAtPath:self.homePath error:nil];
        
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


+ (NSArray *)projectsWithBox:(ZLSandBox *)box{
    
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

#pragma mark - get Simulator List Path.
+ (NSString *)getDevicePath:(ZLSandBox *)sandbox{
    
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

+ (NSString *)getBundleImagePathWithFilePath:(NSString *)filePath{
    
    NSString *containersPath = [[[filePath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    
    NSString *bundleApplicationPath = [[containersPath stringByAppendingPathComponent:@"Bundle"] stringByAppendingPathComponent:@"Application"];
    
    // 获取iOS8 沙盒路径
    NSDictionary *dataDict = [self getDataDictWithFileName:filePath];
    NSString *dataName = [self getAppName:dataDict[MCMMetadataIdentifier]];
    
    if (!dataName) {
        // iOS7 的沙盒bundle路径
        NSString *appPath = filePath;
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

+ (NSString *)getDataApplicationPath:(NSString *)filePath{
    return [[[self.homePath stringByAppendingPathComponent:filePath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Applications"];
}

+ (NSString *)getDataDictPathWithFileName:(NSString *)fileName{
    return [fileName stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
}

+ (NSString *)getAppName:(NSString *)identifierName{
    NSArray *array = [identifierName componentsSeparatedByString:@"."];
    NSString *projectName = [array lastObject];
    projectName = [projectName stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    return projectName;
}

+ (NSDictionary *)getDataDictWithFileName:(NSString *)fileName{
    return [NSDictionary dictionaryWithContentsOfFile:[self getDataDictPathWithFileName:fileName]];
}

+ (NSString *)getDataPath:(NSString *)filePath{
    return [[[[[self.homePath stringByAppendingPathComponent:filePath] stringByAppendingPathComponent:@"data"] stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:@"Data"] stringByAppendingPathComponent:@"Application"];
}

+ (NSString *)getHomePath{
    return self.homePath;
}
@end
