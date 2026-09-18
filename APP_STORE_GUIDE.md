# Tracktion / 比赛周：不经过 TestFlight 的上架流程

核对日期：2026-09-16。TestFlight 是可选的测试分发方式，不是 App Store 提交的必经步骤。可以直接上传正式候选构建并提交 App Review，但不能跳过苹果审核。

苹果说明：[上传 App](https://help.apple.com/xcode/mac/current/en.lproj/dev442d7f2ca.html)、[提交审核](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)。

## 1. 准备开发者账号

加入 [Apple Developer Program](https://developer.apple.com/programs/enroll/)。个人或组织均可；免费 Apple Account 不足以向 App Store 发布。由账号持有人完成身份验证、付款及协议接受。

## 2. 配置应用身份与签名

- 为主 App 和 Widget 扩展分别设置自己的唯一 Bundle ID。
- 在两个 target 的 Signing & Capabilities 中选择同一 Team，配置共同的 App Group。
- 同步修改 `Resources/Shared.entitlements` 与 `SharedSettings.group`，并更新工程生成脚本中的配置。
- 提交前使用当前苹果接受的 Xcode / SDK；要求可能变化，以 [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) 为准。
- 先用自己的 iPhone 验证启动、联网、断网缓存、提醒、组件与语言。这不要求 TestFlight，可直接用 Xcode 安装到登记的真机。

## 3. 完成当前项目的发布准备

当前版本仍是本地开发版，尚未提交审核。需要处理：

- 确认 Tracktion 名称、用户提供的头盔图标和图内品牌元素的使用权与名称可用性。
- 确认 F1 官网地图及相关赛道知识产权的公开分发许可。标明来源不等于取得授权；官网规则见 [F1 Guidelines](https://www.formula1.com/en/information/guidelines.4EOKE9RRqevL4niTK9kWyt)。
- 核实 Jolpica 数据条款允许的分发范围；未来广告或订阅属于新的商业模式，不能直接沿用个人使用假设。
- 准备可公开访问的隐私政策和支持页面；按实际数据流填写隐私申报。检查 UserDefaults 等 required-reason API 的隐私清单，不能因为没有登录或分析 SDK 就省略核对。
- 完成 Release / 真机验收，检查组件共享容器、通知权限拒绝时的提示、不同网络下的表现，以及来源链接。
- 地图及介绍目前是有年份标注的本地快照，后续赛道变化需维护。

## 4. 创建 App Store Connect 条目

登录 [App Store Connect](https://appstoreconnect.apple.com/)，进入“我的 App”→“+”→“新建 App”。选择 iOS，填写名称、主要语言、Bundle ID 和内部 SKU。

分别填写简体中文和英文的名称、描述、关键词；选择类别（例如体育）、年龄分级，并设置价格和分发地区。最终名称取决于系统可用性及审核。

准备实际运行截图、支持 URL、隐私政策 URL、内容版权声明、审核联系人与说明。当前 App 不要求登录，审核说明中可注明无需测试账号。

## 5. 用 Xcode 上传

1. 打开 `RaceWeek.xcodeproj`，选择主 App 的 `RaceWeek` scheme。
2. 设置正式版本号和递增的 build number。
3. 选择通用 iOS 真机目标，例如 `Any iOS Device (arm64)`，而非模拟器。
4. 菜单 `Product → Archive`。
5. 在 Organizer 选中归档，选择 `Distribute App → App Store Connect`，按向导验证签名并上传。
6. 不要选择 `TestFlight Internal Only`，这种构建不能用于正式 App Store 发布。见 [Apple 测试分发说明](https://developer.apple.com/tutorials/develop-in-swift/test-your-beta-app)。

## 6. 直接提交 App Review

等待构建处理完成，在 App Store Connect 的 App 版本页选择上传的 build，按实际情况完成加密出口合规和隐私等问卷。

填写完整后点击 `Add for Review`，再进入待提交项目点击 `Submit for Review`。仅点前一个按钮不会真正提交。整个流程无需创建 TestFlight 测试组或邀请测试员。

## 7. 审核与发布

审核通过后，按所选方式自动或手动发布；如收到问题，在 App Store Connect 回复或上传修正版。上传成功不等于审核通过，也不等于已经在商店可下载。不要预设固定审核时长。

## 中国大陆及海外

大陆上架需核对 App 备案 / ICP 备案信息与 App Store Connect 的要求，并确保填写的名称、主体等与备案一致。并非勾选中国大陆即可完成，也不能把非商用视为自动豁免。不同内容类别可能有额外许可要求。

欧盟分发需如实申报 DSA 下的 trader（交易商）状态；若属于 trader，需要提供相应验证与公开联系信息。其他地区按实际销售范围处理，不应盲目勾选全球。

苹果参考：[App 信息与各地区要求](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)。
