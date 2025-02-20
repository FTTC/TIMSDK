//
//  TUIProfileController.m
//  TUIKit
//
//  Created by annidyfeng on 2019/3/11.
//  Copyright © 2019年 kennethmiao. All rights reserved.
//

#import "TUIUserProfileController.h"
#import "TUICommonContactProfileCardCell.h"
#import "TUIFriendRequestViewController.h"
#import "TUICommonContactTextCell.h"
#import "TUICommonModel.h"
#import "TUICommonPendencyCellData.h"
#import "TUIContactAvatarViewController.h"
#import "TUIContactConversationCellData.h"
#import "TUIThemeManager.h"


@interface TUIUserProfileController ()<TUIContactProfileCardDelegate>
@property NSMutableArray<NSArray *> *dataList;
@property (nonatomic, strong) TUINaviBarIndicatorView *titleView;
@end

@implementation TUIUserProfileController

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];

    return self;
}

- (void)willMoveToParentViewController:(nullable UIViewController *)parent
{
    [super willMoveToParentViewController:parent];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _titleView = [[TUINaviBarIndicatorView alloc] init];
    [_titleView setTitle:TUIKitLocalizableString(ProfileDetails)];
    self.navigationItem.titleView = _titleView;
    self.navigationItem.title = @"";
    self.clearsSelectionOnViewWillAppear = YES;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    [self.tableView registerClass:[TUICommonContactTextCell class] forCellReuseIdentifier:@"TextCell"];
    [self.tableView registerClass:[TUICommonContactProfileCardCell class] forCellReuseIdentifier:@"CardCell"];
    [self.tableView registerClass:[TUIButtonCell class] forCellReuseIdentifier:@"ButtonCell"];

    //如果不加这一行代码，依然可以实现点击反馈，但反馈会有轻微延迟，体验不好。
    self.tableView.delaysContentTouches = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self loadData];
}


/**
 * 加载视图信息
 */
- (void)loadData
{
    NSMutableArray *list = @[].mutableCopy;
    [list addObject:({
        NSMutableArray *inlist = @[].mutableCopy;
        [inlist addObject:({
            TUICommonContactProfileCardCellData *personal = [[TUICommonContactProfileCardCellData alloc] init];
            personal.identifier = self.userFullInfo.userID;
            personal.avatarImage = DefaultAvatarImage;
            personal.avatarUrl = [NSURL URLWithString:self.userFullInfo.faceURL];
            personal.name = [self.userFullInfo showName];
            personal.genderString = [self.userFullInfo showGender];
            personal.signature = [self.userFullInfo showSignature];
            personal.reuseId = @"CardCell";
            personal;
        })];
        inlist;
    })];

    //当用户状态为请求添加好友/请求添加群组时，视图加载出验证消息模块
    if (self.pendency || self.groupPendency) {
        [list addObject:({
            NSMutableArray *inlist = @[].mutableCopy;
            [inlist addObject:({
                TUICommonContactTextCellData *data = TUICommonContactTextCellData.new;
                data.key = TUIKitLocalizableString(FriendAddVerificationMessage); // @"验证消息";
                data.keyColor = [UIColor colorWithRed:136/255.0 green:136/255.0 blue:136/255.0 alpha:1/1.0];
                data.valueColor = [UIColor colorWithRed:68/255.0 green:68/255.0 blue:68/255.0 alpha:1/1.0];
                if (self.pendency) {
                    data.value = self.pendency.addWording;
                } else if (self.groupPendency) {
                    data.value = self.groupPendency.requestMsg;
                }
                data.reuseId = @"TextCell";
                data.enableMultiLineValue = YES;
                data;
            })];
            inlist;
        })];
    }


    self.dataList = list;

    //当用户为陌生人时，在当前视图给出"加好友"按钮
    if (self.actionType == PCA_ADD_FRIEND) {
        [[V2TIMManager sharedInstance] checkFriend:@[self.userFullInfo.userID] checkType:V2TIM_FRIEND_TYPE_BOTH succ:^(NSArray<V2TIMFriendCheckResult *> *resultList) {
            if (resultList.count == 0) {
                return;
            }
            V2TIMFriendCheckResult *result = resultList.firstObject;
            if (result.relationType == V2TIM_FRIEND_RELATION_TYPE_IN_MY_FRIEND_LIST || result.relationType == V2TIM_FRIEND_RELATION_TYPE_BOTH_WAY) {
                return;
            }
            
            [self.dataList addObject:({
                NSMutableArray *inlist = @[].mutableCopy;
                [inlist addObject:({
                    TUIButtonCellData *data = TUIButtonCellData.new;
                    data.title = TUIKitLocalizableString(FriendAddTitle); // @"加好友";
                    data.style = ButtonWhite;
                    data.cbuttonSelector = @selector(onAddFriend);
                    data.reuseId = @"ButtonCell";
                    data.hideSeparatorLine = YES;
                    data;
                })];
                inlist;
            })];
            
            [self.tableView reloadData];
                    
        } fail:^(int code, NSString *desc) {
            NSLog(@"");
        }];
    }

    //当用户请求添加使用者为好友时，在当前视图给出"同意"、"拒绝"，使当前用户进行选择
    if (self.actionType == PCA_PENDENDY_CONFIRM) {
        [self.dataList addObject:({
            NSMutableArray *inlist = @[].mutableCopy;
            [inlist addObject:({
                TUIButtonCellData *data = TUIButtonCellData.new;
                data.title = TUIKitLocalizableString(Accept);
                data.style = ButtonWhite;
                data.textColor = [UIColor colorWithRed:20/255.0 green:122/255.0 blue:255/255.0 alpha:1/1.0];
                data.cbuttonSelector = @selector(onAgreeFriend);
                data.reuseId = @"ButtonCell";
                data;
            })];
            [inlist addObject:({
                TUIButtonCellData *data = TUIButtonCellData.new;
                data.title = TUIKitLocalizableString(Decline);
                data.style = ButtonRedText;
                data.cbuttonSelector =  @selector(onRejectFriend);
                data.reuseId = @"ButtonCell";
                data;
            })];
            inlist;
        })];
    }

    //当用户请求加入群组时，在当前视图给出"同意"、"拒绝"，使当前群组管理员进行选择
    if (self.actionType == PCA_GROUP_CONFIRM) {
        [self.dataList addObject:({
            NSMutableArray *inlist = @[].mutableCopy;
            [inlist addObject:({
                TUIButtonCellData *data = TUIButtonCellData.new;
                data.title = TUIKitLocalizableString(Accept);// @"同意";
                data.style = ButtonWhite;
                data.textColor = TUICoreDynamicColor(@"primary_theme_color", @"#147AFF");
                data.cbuttonSelector = @selector(onAgreeGroup);
                data.reuseId = @"ButtonCell";
                data;
            })];
            [inlist addObject:({
                TUIButtonCellData *data = TUIButtonCellData.new;
                data.title = TUIKitLocalizableString(Decline);//@"拒绝";
                data.style = ButtonRedText;
                data.cbuttonSelector =  @selector(onRejectGroup);
                data.reuseId = @"ButtonCell";
                data;
            })];
            inlist;
        })];
    }

    [self.tableView reloadData];
}

#pragma mark - Table view data source
/**
 *  tableView数据源函数
 */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataList.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataList[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    TUICommonCellData *data = self.dataList[indexPath.section][indexPath.row];
    TUICommonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:data.reuseId forIndexPath:indexPath];
    //如果是 profileCard 的话，添加委托。
    if ([cell isKindOfClass:[TUICommonContactProfileCardCell class]]) {
        TUICommonContactProfileCardCell *cardCell = (TUICommonContactProfileCardCell *)cell;
        cardCell.delegate = self;
        cell = cardCell;
    }
    [cell fillWithData:data];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    TUICommonCellData *data = self.dataList[indexPath.section][indexPath.row];
    return [data heightOfWidth:Screen_Width];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return section == 0 ? 0 : 10;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    return view;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    return view;
}

/**
 *  点击 发送信息 按钮后执行的函数
 */
- (void)onSendMessage
{
//    TUIChatConversationModel *data = [[TUIChatConversationModel alloc] init];
//    data.conversationID = [NSString stringWithFormat:@"c2c_%@",self.userFullInfo.userID];
//    data.userID = self.userFullInfo.userID;
//    data.title = [self.userFullInfo showName];
//    ChatViewController *chat = [[ChatViewController alloc] init];
//    chat.conversationData = data;
//    [self.navigationController pushViewController:chat animated:YES];
}

/**
 *  点击 加好友 按钮后执行的函数
 */
- (void)onAddFriend
{
    TUIFriendRequestViewController *vc = [TUIFriendRequestViewController new];
    vc.profile = self.userFullInfo;
    [self.navigationController pushViewController:vc animated:YES];
}

/**
 *  点击 同意(好友) 按钮后执行的函数
 */
- (void)onAgreeFriend
{
    [self.pendency agree];
}

- (void)onRejectFriend
{
    [self.pendency reject];
}

- (void)onAgreeGroup
{
    [self.groupPendency accept];
}

- (void)onRejectGroup
{
    [self.groupPendency reject];
}

- (UIView *)toastView
{
    return [UIApplication sharedApplication].keyWindow;
}

- (void)didSelectAvatar {
    TUIContactAvatarViewController *image = [[TUIContactAvatarViewController alloc] init];
    image.avatarData.avatarUrl = [NSURL URLWithString:self.userFullInfo.faceURL];
    NSArray *list = self.dataList;
    NSLog(@"%@",list);

    [self.navigationController pushViewController:image animated:YES];
}

/**
 *  点击头像查看大图的委托实现
 */
- (void)didTapOnAvatar:(TUICommonContactProfileCardCell *)cell {
    TUIContactAvatarViewController *image = [[TUIContactAvatarViewController alloc] init];
    image.avatarData = cell.cardData;
    [self.navigationController pushViewController:image animated:YES];
}

@end
