//
//  JTDownloadItem.h
//  JapanDrama
//
//  Created by tmy on 14-8-19.
//  Copyright (c) 2014年 nobuta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSUInteger, JTDownloadItemState) {
    JTDownloadItemStateNone = 0,
    JTDownloadItemStateWait,
    JTDownloadItemStateDownloading,
    JTDownloadItemStatePause,
    JTDownloadItemStateFailed,
    JTDownloadItemStateResumeError,
    JTDownloadItemStateDownloaded
};

@interface JTDownloadItem : NSObject<NSCoding>

+ (instancetype)itemWithURL:(NSString *)URL;
+ (instancetype)itemWithURL:(NSString *)URL savePath:(NSString *)savePath;
+ (instancetype)itemWithMultipleURLs:(NSArray *)URLs;
+ (instancetype)itemWithMultipleURLs:(NSArray *)URLs savePath:(NSString *)savePath;

- (void)didFinishDownloadingForCurrentURL;

@property (nonatomic, strong) NSArray *URLs;
@property (nonatomic, strong) NSString *savePath;
@property (nonatomic, strong) NSMutableArray *actualPaths;
@property (nonatomic) NSInteger downloadingURLIndex;
@property (nonatomic) long long totalSize;  
@property (nonatomic,readonly) long long totalDownloadedSize;
@property (nonatomic) long long downloadedSizeForCurrentURL;
@property (nonatomic) CGFloat progress;
@property (nonatomic) JTDownloadItemState state;
@property (nonatomic) NSInteger tag;
@property (nonatomic, strong) NSDictionary *context;

@end
