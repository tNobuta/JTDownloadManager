//
//  JTDownloadItem.m
//  JapanDrama
//
//  Created by tmy on 14-8-19.
//  Copyright (c) 2014年 nobuta. All rights reserved.
//

#import "JTDownloadItem.h"

@implementation JTDownloadItem
{
    long long  _downloadedSize;
}

+ (instancetype)itemWithURL:(NSString *)URL {
    JTDownloadItem *item = [JTDownloadItem itemWithMultipleURLs:@[URL]];
    return item;
}

+ (instancetype)itemWithURL:(NSString *)URL savePath:(NSString *)savePath {
    JTDownloadItem *item = [JTDownloadItem itemWithURL:URL];
    item.savePath = savePath;
    return item;
}

+ (instancetype)itemWithMultipleURLs:(NSArray *)URLs {
    JTDownloadItem *item = [[JTDownloadItem alloc] init];
    item.URLs = URLs;
    return item;
}

+ (instancetype)itemWithMultipleURLs:(NSArray *)URLs savePath:(NSString *)savePath {
    JTDownloadItem *item = [JTDownloadItem itemWithMultipleURLs:URLs];
    item.savePath = savePath;
    return item;
}

- (long long)totalDownloadedSize {
    return _downloadedSize + self.downloadedSizeForCurrentURL;
}

- (id)init {
    if (self = [super init]) {
        self.actualPaths = [NSMutableArray array];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.URLs forKey:@"URLs"];
    [encoder encodeObject:self.savePath forKey:@"savePath"];
    [encoder encodeObject:self.actualPaths forKey:@"actualPaths"];
    [encoder encodeInteger:self.downloadingURLIndex forKey:@"downloadingURLIndex"];
    [encoder encodeObject:[NSNumber numberWithLongLong:self.totalSize] forKey:@"totalSize"];
    [encoder encodeObject:[NSNumber numberWithLongLong:_downloadedSize] forKey:@"downloadedSize"];
    [encoder encodeObject:[NSNumber numberWithLongLong:self.downloadedSizeForCurrentURL] forKey:@"downloadedSizeForCurrentURL"];
    [encoder encodeFloat:self.progress forKey:@"progress"];
    [encoder encodeInt:self.state forKey:@"state"];
    [encoder encodeInteger:self.tag forKey:@"tag"];
    [encoder encodeObject:self.context forKey:@"context"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.URLs = [decoder decodeObjectForKey:@"URLs"];
        self.savePath = [decoder decodeObjectForKey:@"savePath"];
        self.actualPaths = [decoder decodeObjectForKey:@"actualPaths"];
        self.downloadingURLIndex = [decoder decodeIntegerForKey:@"downloadingURLIndex"];
        [self setTotalSize:[[decoder decodeObjectForKey:@"totalSize"] longLongValue]];
        _downloadedSize = [[decoder decodeObjectForKey:@"downloadedSize"] longLongValue];
        self.downloadedSizeForCurrentURL = [[decoder decodeObjectForKey:@"downloadedSizeForCurrentURL"] longLongValue];
        self.progress = [decoder decodeFloatForKey:@"progress"];
        self.state = [decoder decodeIntForKey:@"state"];
        self.tag = [decoder decodeIntegerForKey:@"tag"];
        self.context = [decoder decodeObjectForKey:@"context"];
    }
    return self;
}

- (void)didFinishDownloadingForCurrentURL {
    _downloadedSize += self.downloadedSizeForCurrentURL;
    self.downloadedSizeForCurrentURL = 0;
}

@end
