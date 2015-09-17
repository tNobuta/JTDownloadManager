//
//  JTDownloadManager.m
//  JapanDrama
//
//  Created by tmy on 14-8-19.
//  Copyright (c) 2014年 nobuta. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JTDownloadManager.h"
#import "NSString+MD5.h"

#define CACHE_DIR @"JTDownload"
#define DEFAULT_SAVE_PATH @"Downloaded"
#define CACHE_NAME @"DownloadItems.dat"

@implementation JTDownloadManager
{
    JTURLSessionManager     *_sessionManager;
    NSString                *_cacheDir;
    NSString                *_defaultSaveDir;
    NSMutableArray          *_downloadItems;
    NSMutableArray          *_downloadingQueue;
    NSMutableArray          *_waitingQueue;
    NSMutableArray          *_downloadedItems;
    
    NSMutableDictionary     *_urlItemMapping;
    
    JTDownloadCallback      *_downloadCallback;
}

+ (instancetype)sharedManager {
    static JTDownloadManager *SharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SharedManager = [[self alloc] init];
    });
    
    return SharedManager;
}

- (JTURLSessionManager *)sessionManager {
    return _sessionManager;
}

- (id)init {
    if(self = [super init]) {
        _downloadItems = [[NSMutableArray alloc] init];
        _downloadingQueue = [[NSMutableArray alloc] init];
        _waitingQueue = [[NSMutableArray alloc] init];
        _downloadedItems = [[NSMutableArray alloc] init];
        _urlItemMapping = [[NSMutableDictionary alloc] init];
        
        _cacheDir = [NSString stringWithFormat:@"%@/Library/Caches/%@",NSHomeDirectory(), CACHE_DIR];
        _defaultSaveDir = [NSString stringWithFormat:@"%@/%@", _cacheDir, DEFAULT_SAVE_PATH];
        
        BOOL isDir = YES;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_cacheDir isDirectory:&isDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        

        if (![[NSFileManager defaultManager] fileExistsAtPath:_defaultSaveDir isDirectory:&isDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_defaultSaveDir withIntermediateDirectories:YES attributes:nil error:nil];
        }

        NSDictionary *cache = [NSKeyedUnarchiver unarchiveObjectWithFile:[NSString stringWithFormat:@"%@/%@", _cacheDir, CACHE_NAME]];
        if (cache) {
            NSArray *cachedItems = cache[@"items"];
            if (cachedItems && cachedItems.count > 0) {
                [_downloadItems addObjectsFromArray:cachedItems];
            }
            
            NSDictionary *urlMapping = cache[@"urlMapping"];
            if (urlMapping) {
                [_urlItemMapping addEntriesFromDictionary:urlMapping];
            }
        }
        
        
        for (JTDownloadItem *item in _downloadItems) {
            if (item.state == JTDownloadItemStateDownloaded) {
                [_downloadedItems addObject:item];
            }else if(item.state == JTDownloadItemStateWait) {
                [_waitingQueue addObject:item];
            }else {
                [_downloadingQueue addObject:item];
            }
        }
        
        _sessionManager = [[JTURLSessionManager alloc] init];
        _sessionManager.sessionManagerDelegate = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(save) name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(save) name:UIApplicationWillTerminateNotification object:[UIApplication sharedApplication]];
        
        
        _downloadCallback = DownloadCallback(^(JTDownloadTask *task, long long bytesReceived, long long totalBytesReceived, long long bytesExceptedToReceive) {
            JTDownloadItem *item = _urlItemMapping[task.URL];
            if (item) {
                if (item.state == JTDownloadItemStateWait) {
                    item.state = JTDownloadItemStateDownloading;
                    [_downloadingQueue addObject:item];
                    [_waitingQueue removeObject:item];
                    
                    if (item.totalDownloadedSize == 0 && self.delegate && [self.delegate respondsToSelector:@selector(downloadManager:didBeginToDownloadItem:)]) {
                        [self.delegate downloadManager:self didBeginToDownloadItem:item];
                    }else if(item.totalDownloadedSize > 0 && self.delegate && [self.delegate respondsToSelector:@selector(downloadManager:didResumeDownloadItem:)]) {
                        [self.delegate downloadManager:self didResumeDownloadItem:item];
                    }
                }
                
                item.downloadedSizeForCurrentURL = totalBytesReceived;
                float progress = (double)item.totalDownloadedSize / (double)item.totalSize;
                item.progress = progress;
                if (self.delegate) {
                    [self.delegate downloadManager:self didUpdateProgress:progress forItem:item];
                }
            }
        }, ^(JTDownloadTask *task) {
            JTDownloadItem *item = _urlItemMapping[task.URL];
            if (item) {
                [_urlItemMapping removeObjectForKey:[self currentURLForDownloadItem:item]];
                [item didFinishDownloadingForCurrentURL];
                item.downloadingURLIndex ++;
                if (item.downloadingURLIndex <= item.URLs.count - 1) {
                    NSString *savePath = [self savePathFromDownloadItem:item];
                    item.actualPaths[item.downloadingURLIndex] = savePath;
                    _urlItemMapping[[self currentURLForDownloadItem:item]] = item;
                    [_sessionManager downloadWithUrl:[self currentURLForDownloadItem:item] savePath:item.actualPaths[item.downloadingURLIndex] callback:_downloadCallback];
                }else {
                    item.state = JTDownloadItemStateDownloaded;
                    [_downloadingQueue removeObject:item];
                    [_downloadedItems addObject:item];
                    if (self.delegate && [self.delegate respondsToSelector:@selector(downloadManager:didFinishDownloadingItem:)]) {
                        [self.delegate downloadManager:self didFinishDownloadingItem:item];
                    }
                }
                
                [self save];
            }
            
        }, ^(JTDownloadTask *task) {
            JTDownloadItem *item = _urlItemMapping[task.URL];
            if (item) {
                item.state = JTDownloadItemStateFailed;
                if (self.delegate && [self.delegate respondsToSelector:@selector(downloadManager:failedToDownloadItem:)]) {
                    [self.delegate downloadManager:self failedToDownloadItem:item];
                }
                
                [self save];
            }
        });
    }
    
    return self;
}

- (void)downloadItem:(JTDownloadItem *)newItem {
    if (newItem.URLs.count == 0 || newItem.state == JTDownloadItemStateWait || newItem.state == JTDownloadItemStateDownloading || newItem.state == JTDownloadItemStateDownloaded) {
        return;
    }else if(newItem.state == JTDownloadItemStatePause || newItem.state == JTDownloadItemStateFailed) {
        [self resumeItem:newItem];
    }else {
        [self downloadItemInternal:newItem];
    }
}

- (void)downloadItemInternal:(JTDownloadItem *)newItem {
    NSString *savePath = [self savePathFromDownloadItem:newItem];
    newItem.actualPaths[newItem.downloadingURLIndex] = savePath;
    newItem.state = JTDownloadItemStateWait;
    _urlItemMapping[[self currentURLForDownloadItem:newItem]] = newItem;
    if (![_downloadItems containsObject:newItem]) {
        [_downloadItems addObject:newItem];
    }else {
        [_downloadingQueue removeObject:newItem];
    }
    
    [_waitingQueue addObject:newItem];
    
    dispatch_group_t group = dispatch_group_create();
    for(int i = 0; i < newItem.URLs.count ; i++) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:newItem.URLs[i]]];
            [request setHTTPMethod:@"HEAD"];
            NSHTTPURLResponse *response = nil;
            NSError *error = nil;
            [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            if (!error && response) {
                long long contentLength = response.expectedContentLength;
                @synchronized(self) {
                    newItem.totalSize += contentLength;
                }
            }
        });
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self save];
        [_sessionManager downloadWithUrl:newItem.URLs[newItem.downloadingURLIndex] savePath:savePath callback: _downloadCallback];
    });
    
    [self save];
}

- (void)pauseItem:(JTDownloadItem *)item {
    if ([_downloadItems containsObject:item] && item.state == JTDownloadItemStateDownloading) {
        item.state = JTDownloadItemStatePause;
        [_sessionManager pauseDownloadForURL: [self currentURLForDownloadItem:item]];
        
        [self save];
    }
}

- (void)resumeItem:(JTDownloadItem *)item {
    if ([_downloadItems containsObject:item] && item.state == JTDownloadItemStatePause) {
        item.state = JTDownloadItemStateWait;
        JTDownloadTask *task = [_sessionManager resumeDownloadForURL:[self currentURLForDownloadItem:item] savePath:item.actualPaths[item.downloadingURLIndex] callback:_downloadCallback];
        if (!task) {
            item.state = JTDownloadItemStateResumeError;
            if (self.delegate && [self.delegate respondsToSelector:@selector(downloadManager:failedToDownloadItem:)]) {
                [self.delegate downloadManager:self failedToDownloadItem:item];
            }
        }
        [self save];
    }
}

- (void)cancelItem:(JTDownloadItem *)item {
    if ([_downloadItems containsObject:item]) {
        if(item.state != JTDownloadItemStateDownloaded) {
            [_waitingQueue removeObject:item];
            [_downloadingQueue removeObject:item];
        }
        
        [_sessionManager cancelDownloadForURL:[self currentURLForDownloadItem:item]];
        [_urlItemMapping removeObjectForKey:[self currentURLForDownloadItem:item]];
        
        for (NSString *savePath in item.actualPaths) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
                [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
            }
        }
        
        [_downloadItems removeObject:item];
        
        [self save];
    }
}

- (void)cancelAllItems {
    [_sessionManager cancelAllDownloadTask];
    
    for (JTDownloadItem *item in _downloadingQueue) {
        for (NSString *savePath in item.actualPaths) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
                [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
            }
        }
    }
    
    [_urlItemMapping removeAllObjects];
    [_downloadItems removeObjectsInArray:_downloadingQueue];
    [_downloadItems removeObjectsInArray:_waitingQueue];
    
    [_downloadingQueue removeAllObjects];
    [_waitingQueue removeAllObjects];
    [self save];
}

- (void)removeDownloadedItem:(JTDownloadItem *)item {
    if ([_downloadItems containsObject:item] && item.state == JTDownloadItemStateDownloaded) {
        for (NSString *actualPath in item.actualPaths) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:actualPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:actualPath error:nil];
            }
        }
        
        [_downloadItems removeObject:item];
        [_downloadedItems removeObject:item];
    }
}

- (void)save {
    if (_downloadItems) {
        [NSKeyedArchiver archiveRootObject:@{@"items": _downloadItems, @"urlMapping": _urlItemMapping} toFile:[NSString stringWithFormat:@"%@/%@", _cacheDir, CACHE_NAME]];
    }
}

- (NSString *)currentURLForDownloadItem:(JTDownloadItem *)item {
    return item.URLs[item.downloadingURLIndex];
}

- (NSString *)savePathFromDownloadItem:(JTDownloadItem *)item {
    NSString *url = item.URLs[item.downloadingURLIndex];
    NSString *basePath = @"";
    NSString *savePath = @"";
    if (!item.savePath || item.savePath.length == 0) {
        basePath = [NSString stringWithFormat:@"%@/%@", _defaultSaveDir, [url md5Value]];
    }else {
        basePath = item.savePath;
    }
    
    if (item.URLs.count == 1 || !item.savePath) {
        savePath = basePath;
    }else {
        savePath = [NSString stringWithFormat:@"%@_%d", basePath, (int)item.downloadingURLIndex];
    }
    
    return savePath;
}

- (void)JTURLSessionManager:(JTURLSessionManager *)manager didSaveResumeDataForLastDownloadingTask:(NSString *)url {
    JTDownloadItem *item = _urlItemMapping[url];
    if (item) {
        item.state = JTDownloadItemStatePause;
    }
}

@end
