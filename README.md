# 比赛周 · Tracktion

个人使用的原生 iPhone F1 赛历与积分 MVP。SwiftUI + WidgetKit，最低 iOS 17，无外部代码依赖、账号、广告或自建服务器。

## 运行

1. 用 Xcode 26.3 打开 `RaceWeek.xcodeproj`（不是 Package.swift）。
2. 顶部选择 `RaceWeek` 和已安装的 iPhone 模拟器，按 ⌘R。
3. 首次联网拉取赛历和积分。断网时显示已有缓存及同步时间。

本机命令行构建：

```sh
xcodebuild -project RaceWeek.xcodeproj -scheme RaceWeek -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/RaceWeekDerived CODE_SIGN_IDENTITY=- build
swift test --scratch-path build/core-tests
```

`Scripts/generate_project.py` 可重新生成工程和 plist。修改生成的工程配置后，应同步修改脚本，避免下次生成覆盖配置。

## 已实现

- 本周 / 下一站、全年赛历；支持上一年、本年、下一年。下一年仅显示数据源已公布内容。
- 练习、排位、正赛及存在时的冲刺排位 / 冲刺；没有时间的场次明确标记待定。
- 本地或赛道时区，简体中文 / 英文，浅色 / 深色。
- 最新已发布车手、车队积分，显示数据源轮次及获取时间；不计算比赛中预估积分。
- 赛历、车手积分、车队积分独立缓存。网络失败不会覆盖已有成功结果。
- 可选开赛前 30 分钟本地提醒。打开 App 成功同步时修正已设置提醒，不保证后台获知临时改期。
- 三种桌面小组件，小 / 中尺寸：下一场赛程、车手前三、车队前三。使用本年度数据。
- 主 App 15 分钟缓存；手动刷新最短间隔 15 秒。组件建议 30 分钟刷新一次，实际由 iOS 调度。

## 数据与限制

数据来源：[Jolpica F1](https://github.com/jolpica/jolpica-f1)，通过 HTTPS 的 Ergast 兼容接口。没有付费实时遥测或官方赛事直播数据。

请保留数据来源和 [Jolpica 使用条款](https://github.com/jolpica/jolpica-f1/blob/main/TERMS.md)、[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) 归属说明。界面中文人名和地名为显示层翻译，未知条目保留源文字。本项目为独立、非官方车迷应用，赛道地图采用官网原图；图标为用户提供的头盔插画，包含品牌标识。公开分发前仍需确认相应素材的使用权，详见 `SOURCES.md`。

接口可用性、完整性、发布延迟及大陆网络可达性依赖第三方；本机联网成功不代表所有地区均可访问。获取时间不是官方成绩发布时间。赛程倒计时不代表赛事实际运行状态。

## 真机与发布前待办

当前提供可运行的模拟器开发版，未上传 App Store / TestFlight。

- 真机需在两个 target 的 Signing & Capabilities 设置自己的 Team、唯一 Bundle ID 和共同 App Group，并同步修改 `SharedSettings.group` 与 entitlements。当前使用占位标识 `app.raceweek.personal` / `group.app.raceweek.personal`。
- 完成真机小组件刷新、后台行为、通知和弱网验收；模拟器不代替这些检查。
- 图标已加入；仍需准备上架截图、公开隐私政策与支持页面，按实际 API 使用填写隐私清单和 App Store 隐私申报。
- 发布前重新核实数据条款与分发范围；订阅、广告或其他商用不可直接沿用当前个人版的数据使用假设。

## 结构

`Sources/Core`：接口解码、模型、时区映射、缓存。
`Sources/App`：主 App、设置、提醒与页面。
`Sources/UI`：共享样式。
`Sources/Widget`：三个 WidgetKit 组件。
`Tests/Core`：不依赖网络的核心测试。

源码为本项目新写实现；未复制其他 F1 App 源码。第三方数据许可与本项目源码是不同事项。

## 本次验证记录

Xcode 26.3 构建主 App 与 Widget 扩展成功；5 项核心测试通过。iPhone 17 Pro / iOS 26.3 模拟器已验证联网赛历、积分页面、中英文设置切换，并添加赛历组件、看到真实接口返回的下一场时间。真机提醒及长期后台刷新尚未验证。命令行使用临时构建目录避免文稿目录的 Finder 扩展属性影响签名。

## 0.2 更新

- App 内显示名为 Tracktion / 比赛周；桌面名称通过 InfoPlist.strings 跟随系统的 App 语言。App 内语言切换控制内容，不直接改变系统桌面标签。
- 用户图标已转为无透明通道的 1024×1024 AppIcon，保留原图内容。
- 下一站卡片和全年赛历均进入详情页。26 条赛道资料包含官网参数、官网三计时段地图、简短中英文历史与地区介绍；地图支持双指缩放、双击放大和拖动。
- 地图有两种官方样式：带 SECTOR 字样的新版图，以及使用红 / 蓝 / 黄区分 S1 / S2 / S3 的图。未重新推算计时段边界。
- 资料按 circuitID 匹配：sepang 指向雪邦，bahrain 指向萨基尔。修复 Bahrain Grand Prix in Malaysia 的中文名称。
- 使用官网 2026 年资料，萨基尔、吉达、伊莫拉使用 2025 年资料；查看不同赛季时有年份提示。这些固定赛道档案需后续维护，不会自动套用到未来赛道改建。
- 按要求未补入 2027 赛历，赛历接口及赛季默认选择机制保持原状。
- 内部 Xcode 工程、scheme、应用标识及 widget kind 保留 RaceWeek，避免破坏既有安装、缓存及桌面组件；用户界面名称已更改。

赛道资料来源及地图地址见 [SOURCES.md](SOURCES.md)。直接上架流程见 [APP_STORE_GUIDE.md](APP_STORE_GUIDE.md)。

0.2 验证：主 App 与组件构建成功，8 项测试通过；模拟器实际验证了下一站详情、地图双击缩放、雪邦中文名称与参数、新图标和中文桌面名。26 张地图通过文字识别并对无文字标签的图人工查看，保留原图的计时段边界。
