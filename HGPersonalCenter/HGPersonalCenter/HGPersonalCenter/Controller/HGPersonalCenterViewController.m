//
//  HGPersonalCenterViewController.m
//  HGPersonalCenter
//
//  Created by Arch on 2017/6/16.
//  Copyright © 2017年 mint_bin. All rights reserved.
//

#import "HGPersonalCenterViewController.h"
#import "HGFirstViewController.h"
#import "HGSecondViewController.h"
#import "HGThirdViewController.h"
#import "HGCenterBaseTableView.h"
#import "HGMessageViewController.h"
#import "HGSegmentedPageViewController.h"

static CGFloat const HeaderImageViewHeight = 240;

@interface HGPersonalCenterViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, HGSegmentedPageViewControllerDelegate, HGPageViewControllerDelegate>
@property (nonatomic, strong) HGCenterBaseTableView *tableView;
@property (nonatomic, strong) UIView *footerView;
@property (nonatomic, strong) UIButton *messageButton;
@property (nonatomic, strong) UIImageView *headerImageView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nickNameLabel;
@property (nonatomic, strong) HGSegmentedPageViewController *segmentedPageViewController;
@property (nonatomic) BOOL cannotScroll;
@end

@implementation HGPersonalCenterViewController

#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 11.0, *)) {
        [[UIScrollView appearance] setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
    }else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    //如果使用自定义的按钮去替换系统默认返回按钮，会出现滑动返回手势失效的情况
    self.navigationController.interactivePopGestureRecognizer.delegate = self;
    [self setupSubViews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateNavigationBarBackgroundColor];
}

#pragma mark - Private Methods
- (void)setupSubViews {
    [self.view insertSubview:self.tableView belowSubview:self.navigationBar];
    [self.navigationBar addSubview:self.messageButton];
    [self.tableView addSubview:self.headerImageView];
    [self.headerImageView addSubview:self.avatarImageView];
    [self.headerImageView addSubview:self.nickNameLabel];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.messageButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.mas_equalTo(-10);
        make.right.mas_equalTo(-15);
        make.size.mas_equalTo(CGSizeMake(25, 25));
    }];
    [self.avatarImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.headerImageView);
        make.size.mas_equalTo(CGSizeMake(80, 80));
        make.bottom.mas_equalTo(-70);
    }];
    [self.nickNameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.headerImageView);
        make.width.mas_lessThanOrEqualTo(200);
        make.bottom.mas_equalTo(-40);
    }];
}

- (void)gotoMessagePage {
    HGMessageViewController *vc = [[HGMessageViewController alloc]init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)updateNavigationBarBackgroundColor {
    CGFloat alpha = 0;
    CGFloat currentOffsetY = self.tableView.contentOffset.y;
    if (-currentOffsetY <= NAVIGATION_BAR_HEIGHT) {
        alpha = 1;
    } else if ((-currentOffsetY > NAVIGATION_BAR_HEIGHT) && -currentOffsetY < HeaderImageViewHeight) {
        alpha = (HeaderImageViewHeight + currentOffsetY) / (HeaderImageViewHeight - NAVIGATION_BAR_HEIGHT);
    } else {
        alpha = 0;
    }
    self.navigationBar.backgroundColor = kRGBA(28, 162, 223, alpha);
}

#pragma mark - UIScrollViewDelegate
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    [self.segmentedPageViewController.currentPageViewController makePageViewControllerScrollToTop];
    return YES;
}

/**
 * 处理联动
 * 因为要实现下拉头部放大的问题，tableView设置了contentInset，所以试图刚加载的时候会调用一遍这个方法，所以要做一些特殊处理，
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    //第一部分：处理导航栏
    [self updateNavigationBarBackgroundColor];
    
    //第二部分：处理手势冲突
    CGFloat contentOffsetY = scrollView.contentOffset.y;
    //吸顶临界点(此时的临界点不是视觉感官上导航栏的底部，而是当前屏幕的顶部相对scrollViewContentView的位置)
    CGFloat criticalPointOffsetY = [self.tableView rectForSection:0].origin.y - NAVIGATION_BAR_HEIGHT;
    
    //利用contentOffset处理内外层scrollView的滑动冲突问题
    if (contentOffsetY >= criticalPointOffsetY) {
        /*
         * 到达临界点：
         * 1.未吸顶状态 -> 吸顶状态
         * 2.维持吸顶状态(pageViewController.scrollView.contentOffsetY > 0)
         */
        //“进入吸顶状态”以及“维持吸顶状态”
        self.cannotScroll = YES;
        scrollView.contentOffset = CGPointMake(0, criticalPointOffsetY);
        [self.segmentedPageViewController.currentPageViewController makePageViewControllerScroll:YES];
    } else {
        /*
         * 未达到临界点：
         * 1.吸顶状态 -> 不吸顶状态
         * 2.维持吸顶状态(pageViewController.scrollView.contentOffsetY > 0)
         */
        if (self.cannotScroll) {
            //“维持吸顶状态”
            scrollView.contentOffset = CGPointMake(0, criticalPointOffsetY);
        } else {
            /* 吸顶状态 -> 不吸顶状态
             * pageViewController.scrollView.contentOffsetY <= 0时，会通过代理HGPageViewControllerDelegate来改变当前控制器self.cannotScroll的值；
             */
        }
    }
    
    //第三部分：
    /**
     * 处理头部自定义背景视图 (如: 下拉放大)
     * 图片会被拉伸多出状态栏的高度
     */
    if(contentOffsetY <= -HeaderImageViewHeight) {
        if (self.isEnlarge) {
            CGRect f = self.headerImageView.frame;
            //改变HeadImageView的frame
            //上下放大
            f.origin.y = contentOffsetY;
            f.size.height = -contentOffsetY;
            //左右放大
            f.origin.x = (contentOffsetY * SCREEN_WIDTH / HeaderImageViewHeight + SCREEN_WIDTH) / 2;
            f.size.width = -contentOffsetY * SCREEN_WIDTH / HeaderImageViewHeight;
            //改变头部视图的frame
            self.headerImageView.frame = f;
        }else{
            scrollView.bounces = NO;
        }
    }else {
        scrollView.bounces = YES;
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [self addChildViewController:self.segmentedPageViewController];
    [cell.contentView addSubview:self.segmentedPageViewController.view];
    [self.segmentedPageViewController didMoveToParentViewController:self];
    [self.segmentedPageViewController.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(cell.contentView);
    }];
    return cell;
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return SCREEN_HEIGHT - NAVIGATION_BAR_HEIGHT;
}

#pragma mark - HGSegmentedPageViewControllerDelegate
- (void)segmentedPageViewControllerWillBeginDragging {
    self.tableView.scrollEnabled = NO;
}

- (void)segmentedPageViewControllerDidEndDragging {
    self.tableView.scrollEnabled = YES;
}

#pragma mark - HGPageViewControllerDelegate
- (void)pageViewControllerLeaveTop {
    self.cannotScroll = NO;
}

#pragma mark - Lazy
- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[HGCenterBaseTableView alloc] init];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.contentInset = UIEdgeInsetsMake(HeaderImageViewHeight, 0, 0, 0);//内容视图开始正常显示的坐标为(0, HeaderImageViewHeight)
        _tableView.showsVerticalScrollIndicator = NO;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _tableView;
}

- (UIButton *)messageButton {
    if (!_messageButton) {
        _messageButton = [UIButton buttonWithType:(UIButtonTypeCustom)];
        [_messageButton setImage:[UIImage imageNamed:@"message"] forState:(UIControlStateNormal)];
        _messageButton.adjustsImageWhenHighlighted = NO;
        [_messageButton addTarget:self action:@selector(gotoMessagePage) forControlEvents:(UIControlEventTouchUpInside)];
    }
    return _messageButton;
}

- (UIImageView *)avatarImageView {
    if (!_avatarImageView) {
        _avatarImageView = [[UIImageView alloc] init];
        _avatarImageView.image = [UIImage imageNamed:@"center_avatar.jpeg"];
        _avatarImageView.userInteractionEnabled = YES;
        _avatarImageView.layer.masksToBounds = YES;
        _avatarImageView.layer.borderWidth = 1;
        _avatarImageView.layer.borderColor = kRGBA(255, 253, 253, 1).CGColor;
        _avatarImageView.layer.cornerRadius = 40;
    }
    return _avatarImageView;
}

- (UILabel *)nickNameLabel {
    if (!_nickNameLabel) {
        _nickNameLabel = [[UILabel alloc] init];
        _nickNameLabel.font = [UIFont systemFontOfSize:16];
        _nickNameLabel.textColor = [UIColor whiteColor];
        _nickNameLabel.textAlignment = NSTextAlignmentCenter;
        _nickNameLabel.text = @"下雪天";
    }
    return _nickNameLabel;
}

- (UIImageView *)headerImageView {
    if (!_headerImageView) {
        _headerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, -HeaderImageViewHeight, SCREEN_WIDTH, HeaderImageViewHeight)];
        _headerImageView.image = [UIImage imageNamed:@"center_bg.jpg"];
    }
    return _headerImageView;
}

- (HGSegmentedPageViewController *)segmentedPageViewController {
    if (!_segmentedPageViewController) {
        NSArray *titles = @[@"华盛顿", @"夏威夷", @"拉斯维加斯", @"纽约", @"西雅图", @"底特律", @"费城", @"旧金山", @"芝加哥"];
        NSMutableArray *controllers = [NSMutableArray array];
        for (int i = 0; i < titles.count; i ++) {
            HGPageViewController *controller;
            if (i % 3 == 0) {
                 controller = [[HGThirdViewController alloc] init];
            } else if (i % 2 == 0) {
                 controller = [[HGSecondViewController alloc] init];
            } else {
                 controller = [[HGFirstViewController alloc] init];
            }
            controller.delegate = self;
            [controllers addObject:controller];
        }
        _segmentedPageViewController = [[HGSegmentedPageViewController alloc] init];
        _segmentedPageViewController.pageViewControllers = controllers.copy;
        _segmentedPageViewController.categoryView.titles = titles;
        _segmentedPageViewController.categoryView.originalIndex = self.selectedIndex;
        _segmentedPageViewController.delegate = self;
    }
    return _segmentedPageViewController;
}

- (UIView *)footerView {
    if (!_footerView) {
        _footerView = [[UIView alloc] init];
        _footerView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, SCREEN_HEIGHT - NAVIGATION_BAR_HEIGHT);
    }
    return _footerView;
}

@end

