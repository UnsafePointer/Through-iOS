//
//  THRFeedsViewController.m
//  Through
//
//  Created by Renzo Crisóstomo on 01/06/14.
//  Copyright (c) 2014 Renzo Crisóstomo. All rights reserved.
//

#import "THRFeedViewController.h"
#import "THRMediaCollectionViewCell.h"

@interface THRFeedViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, assign) BOOL shouldRefreshOlder;

- (void)refresh:(id)sender;
- (void)quickDetails:(id)sender;
- (void)refreshOlder;

@end

@implementation THRFeedViewController

static NSString *cellIdentifier = @"THRMediaCollectionViewCell";

#pragma mark - Controller Life Cycle

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];
    if (self) {
        self.title = @"Feed";
        self.feed = [NSMutableArray array];
        self.shouldRefreshOlder = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    @weakify(self);
    
    UIBarButtonItem *btnDone = [[UIBarButtonItem alloc]
                                initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                target:self
                                action:@selector(refresh:)];
    self.navigationItem.rightBarButtonItem = btnDone;
    [self.collectionView registerClass:[THRMediaCollectionViewCell class]
            forCellWithReuseIdentifier:cellIdentifier];
    self.collectionView.delegate = self;
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self.collectionView setContentInset:UIEdgeInsetsMake(20 + 44.0f, 0, 20 + 20 + 44.0f, 0)];
    UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                        action:@selector(quickDetails:)];
    [gestureRecognizer setDirection:UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight];
    [self.collectionView addGestureRecognizer:gestureRecognizer];
    if ([self.feed count] == 0) {
        PFQuery *query = [PFQuery queryWithClassName:@"TwitterMedia"];
        [query whereKey:@"user" equalTo:[PFUser currentUser]];
        [query orderByDescending:@"mediaDate"];
        [query setLimit:50];
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            
            @strongify(self);
            
            if (error) {
                //TODO: Handle error.
            } else {
                [self.feed insertObjects:objects
                               atIndexes:[NSIndexSet
                                          indexSetWithIndexesInRange:
                                          NSMakeRange(0, [objects count])]];
                [[self collectionView] reloadData];
                [[self collectionView]
                 scrollToItemAtIndexPath:[NSIndexPath
                                          indexPathForItem:0
                                          inSection:0]
                 atScrollPosition:UICollectionViewScrollPositionTop
                 animated:YES];
            }
        }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Private Methods

- (void)refresh:(id)sender
{
    @weakify(self);
    
    PFQuery *query = [PFQuery queryWithClassName:@"TwitterMedia"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    if ([self.feed count] != 0) {
        PFObject *lastFeed = self.feed[0];
        [query whereKey:@"mediaDate" greaterThan:[lastFeed objectForKey:@"mediaDate"]];
    }
    [query orderByDescending:@"mediaDate"];
    [query setLimit:50];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        @strongify(self);
        
        if (error) {
            //TODO: Handle error.
        } else if ([objects count] == 0) {
            [PFCloud
             callFunctionInBackground:@"generateFeedsForUser"
             withParameters:@{@"username": [[PFUser currentUser] objectForKey:@"username"]}
             block:^(NSArray *results, NSError *error) {
                 if (error) {
                     //TODO: Handle error.
                 } else {
                     [self.feed insertObjects:results
                                    atIndexes:[NSIndexSet
                                               indexSetWithIndexesInRange:
                                               NSMakeRange(0, [results count])]];
                     [[self collectionView] reloadData];
                 }
             }];
        } else {
            [self.feed insertObjects:objects
                           atIndexes:[NSIndexSet
                                      indexSetWithIndexesInRange:
                                      NSMakeRange(0, [objects count])]];
            [[self collectionView] reloadData];
        }
    }];
}

- (void)quickDetails:(id)sender
{
    UIGestureRecognizer *gestureRecognizer = (UIGestureRecognizer *)sender;
    if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    CGPoint point = [gestureRecognizer locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
    if (indexPath == nil){
        NSLog(@"couldn't find index path");
    } else {
        THRMediaCollectionViewCell *cell = (THRMediaCollectionViewCell *)[self.collectionView
                                                                          cellForItemAtIndexPath:indexPath];
        [cell toggleDetails];
    }
}

- (void)refreshOlder
{
    @weakify(self);
    
    PFQuery *query = [PFQuery queryWithClassName:@"TwitterMedia"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    PFObject *oldestFeed = self.feed.lastObject;
    [query whereKey:@"mediaDate" lessThan:[oldestFeed objectForKey:@"mediaDate"]];
    [query orderByDescending:@"mediaDate"];
    [query setLimit:50];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        @strongify(self);
        
        if (error) {
            //TODO: Handle error.
        } else if ([objects count] == 0) {
            [SVProgressHUD showErrorWithStatus:@"Can't find more items."];
            self.shouldRefreshOlder = NO;
        } else {
            [self.feed addObjectsFromArray:objects];
            [[self collectionView] reloadData];
        }
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.feed.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    THRMediaCollectionViewCell *cell = [collectionView
                                        dequeueReusableCellWithReuseIdentifier:cellIdentifier
                                        forIndexPath:indexPath];
    PFObject *media = self.feed[indexPath.row];
    cell.imageURL = [NSURL URLWithString:[media objectForKey:@"url"]];
    NSDate *date = [media objectForKey:@"mediaDate"];
    cell.details = [NSString stringWithFormat:@"%@ on Twitter (%@): %@", [media objectForKey:@"userName"], [date shortTimeAgoSinceNow], [media objectForKey:@"text"]];
    CGFloat yOffset = ((self.collectionView.contentOffset.y - cell.frame.origin.y) / IMAGE_HEIGHT) * IMAGE_OFFSET_SPEED;
    cell.imageOffset = CGPointMake(0.0f, yOffset);
    if (indexPath.row == self.feed.count - 1 && self.shouldRefreshOlder) {
        [self refreshOlder];
    }
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    for(THRMediaCollectionViewCell *view in self.collectionView.visibleCells) {
        CGFloat yOffset = ((self.collectionView.contentOffset.y - view.frame.origin.y) / IMAGE_HEIGHT) * IMAGE_OFFSET_SPEED;
        view.imageOffset = CGPointMake(0.0f, yOffset);
    }
}

@end
