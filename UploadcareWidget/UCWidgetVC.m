//
//  UCWidgetVC.m
//  ExampleProject
//
//  Created by Yury Nechaev on 05.04.16.
//  Copyright © 2016 Uploadcare. All rights reserved.
//

#import "UCWidgetVC.h"
#import "UCClient+Social.h"
#import "UCSocialSourcesRequest.h"
#import "UCSocialMacroses.h"
#import "UCSocialSource.h"
#import "UCSocialChunk.h"
#import "UCSocialEntriesRequest.h"
#import "UCWebViewController.h"
#import <SafariServices/SafariServices.h>
#import "UCSocialConstantsHeader.h"
#import "UCSocialEntriesCollection.h"
#import "UCGalleryVC.h"

@interface UCWidgetVC () <SFSafariViewControllerDelegate>
@property (nonatomic, strong) NSArray<UCSocialSource *> *tableData;
@property (nonatomic, strong) UCWebViewController *webVC;
@end

@implementation UCWidgetVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self fetchSocialSources];
}

- (void)fetchSocialSources {
    [[UCClient defaultClient] performUCSocialRequest:[UCSocialSourcesRequest new] completion:^(id response, NSError *error) {
        if (!error) {
            NSArray *sources = response[@"sources"];
            NSMutableArray *result = @[].mutableCopy;
            for (id source in sources) {
                UCSocialSource *socialSource = [[UCSocialSource alloc] initWithSerializedObject:source];
                if (socialSource) [result addObject:socialSource];
            }
            self.tableData = result.copy;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
            NSLog(@"Response: %@", response);
        } else {
            [self handleError:error];
        }
    }];
}

- (void)loginUsingAddress:(NSString *)loginAddress {
    
//    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_4) {
//        SFSafariViewController *svc = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:loginAddress]];
//        svc.delegate = self;
//        [self.navigationController pushViewController:svc animated:YES];
//    } else {
        self.webVC = [[UCWebViewController alloc] initWithURL:[NSURL URLWithString:loginAddress] loadingBlock:^(NSURL *url) {
            NSLog(@"URL: %@", url);
            if ([url.host isEqual:[[NSURL URLWithString:UCSocialAPIRoot] host]] && [url.lastPathComponent isEqual:@"endpoint"]) {
                [self.webVC dismissViewControllerAnimated:YES completion:nil];
            }
        }];
        [self.navigationController pushViewController:self.webVC animated:YES];
//    }
}

- (void)queryObjectOrLoginAddressForSource:(UCSocialSource *)source rootChunk:(UCSocialChunk *)rootChunk path:(id)path {
    
    __weak __typeof(self) weakSelf = self;
    [[UCClient defaultClient] performUCSocialRequest:[UCSocialEntriesRequest requestWithSource:source chunk:rootChunk] completion:^(id response, NSError *error) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (!error) {
            NSLog(@"Response: %@", response);
            NSString *loginAddress = [response objectForKey:@"login_link"];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (loginAddress) {
                    [strongSelf loginUsingAddress:loginAddress];
                } else if ([response[@"obj_type"] isEqualToString:@"error"]) {
                    
                } else {
                    [self processData:response];
                }
            });

        } else {
            [self handleError:error];
        }
    }];
}

- (void)processData:(id)responseData {
    UCSocialEntriesCollection *collection = [[UCSocialEntriesCollection alloc] initWithSerializedObject:responseData];
    [self showGalleryWithCollection:collection];
}

- (void)showGalleryWithCollection:(UCSocialEntriesCollection *)collection {
    UCGalleryVC *vc = [[UCGalleryVC alloc] initWitSocialEntriesCollection:collection];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)handleError:(NSError *)error {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tableData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    UCSocialSource *social = self.tableData[indexPath.row];
    cell.textLabel.text = social.sourceName;
    return cell;
}

#pragma mark - <UITableViewDelegate>

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UCSocialSource *social = self.tableData[indexPath.row];
    UCSocialChunk *chunk = social.rootChunks.firstObject;
    [self queryObjectOrLoginAddressForSource:social rootChunk:chunk path:nil];
}

#pragma mark - <SFSafariViewControllerDelegate>

- (NSArray<UIActivity *> *)safariViewController:(SFSafariViewController *)controller activityItemsForURL:(NSURL *)URL title:(nullable NSString *)title {
    NSLog(@"SF URL: %@", URL.absoluteString);
    return nil;
}

/*! @abstract Delegate callback called when the user taps the Done button. Upon this call, the view controller is dismissed modally. */
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    NSLog(@"SF DID FINISH");
}

/*! @abstract Invoked when the initial URL load is complete.
 @param success YES if loading completed successfully, NO if loading failed.
 @discussion This method is invoked when SFSafariViewController completes the loading of the URL that you pass
 to its initializer. It is not invoked for any subsequent page loads in the same SFSafariViewController instance.
 */
- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
    NSLog(@"SF DID COMPLETE INITIAL: %@", didLoadSuccessfully ? @"YES" : @"NO");
}

@end
