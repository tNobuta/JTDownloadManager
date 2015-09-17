//
//  JTDownloadManager.h
//  JapanDrama
//
//  Created by tmy on 14-8-19.
//  Copyright (c) 2014年 nobuta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "JTNetworking.h"
#import "JTDownloadItem.h"

@protocol JTDownloadManagerDelegate;
@class JTURLSessionManager;

@interface JTDownloadManager : NSObject <JTURLSessionManagerDelegate>

@property (nonatomic, weak) id<JTDownloadManagerDelegate> delegate;
@property (nonatomic, readonly) JTURLSessionManager *sessionManager;
@property (nonatomic, readonly) NSArray *downloadItems; //items with state none, wait, downloading, pause, failed, donwloaded
@property (nonatomic, readonly) NSArray *downloadingQueue; //items with state downloading, pause, failed
@property (nonatomic, readonly) NSArray *waitingQueue;
@property (nonatomic, readonly) NSArray *downloadedItems;

+ (instancetype)sharedManager;

- (void)downloadItem:(JTDownloadItem *)newItem;
- (void)pauseItem:(JTDownloadItem *)item;
- (void)resumeItem:(JTDownloadItem *)item;
- (void)cancelItem:(JTDownloadItem *)item;
- (void)removeDownloadedItem:(JTDownloadItem *)item;
- (void)cancelAllItems;

@end


@protocol JTDownloadManagerDelegate <NSObject>

@optional
- (void)downloadManager:(JTDownloadManager *)manager didBeginToDownloadItem:(JTDownloadItem *)item;
- (void)downloadManager:(JTDownloadManager *)manager didResumeDownloadItem:(JTDownloadItem *)item;
- (void)downloadManager:(JTDownloadManager *)manager didFinishDownloadingItem:(JTDownloadItem *)item;
- (void)downloadManager:(JTDownloadManager *)manager failedToDownloadItem:(JTDownloadItem *)item;

@required
- (void)downloadManager:(JTDownloadManager *)manager didUpdateProgress:(CGFloat)progress forItem:(JTDownloadItem *)item;


@end