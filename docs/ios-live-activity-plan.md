# iOS 实时活动（Live Activity）+ 灵动岛 方案

> 目标：在锁屏和灵动岛（Dynamic Island）上实时展示当前天气，天气刷新时同步更新。
> 本文档只覆盖方案设计，不含实现。

## 1. 目标与范围

### v1 范围
- 锁屏实时活动卡片：城市、当前温度、天气现象、最高/最低温、更新时间
- 灵动岛四种形态：compact（左右）、minimal、expanded
- 天气数据变化时更新活动；关闭开关 / 长时间无更新时结束
- 设置页新增开关（仅 iOS 16.1+ 显示）
- 所有数据由 App 本地驱动（不依赖服务端推送）

### v1 不做（列为 v2）
- APNs 远程推送更新实时活动（需要付费开发者账号 + 服务端）
- 交互按钮（刷新、切换城市，iOS 17 App Intents）
- 天气预警专属实时活动（如"40 分钟后降雨"倒计时）
- Apple Watch 扩展（iOS 18 `supplementalActivityFamilies`）

## 2. 平台约束（决定设计的硬条件）

| 项目 | 约束 |
|---|---|
| 系统版本 | ActivityKit 需要 **iOS 16.1+**；当前 Runner 部署目标为 15.0，保持不变，调用处用 `if #available(iOS 16.1, *)` 包住 |
| 灵动岛 | 仅 iPhone 14 Pro / 15 Pro / 16 Pro 等带灵动岛机型；其余机型只有锁屏卡片 |
| 生命周期 | 活动最长 **8 小时**活跃，结束后锁屏最多保留 **4 小时**；系统可随时提前结束 |
| 更新频率 | 本地 `Activity.update` 不受推送预算限制，但系统仍会限频 → 仅数据变化时更新 |
| 数据传递 | `ContentState` 随 `Activity.request/update` 直接传给扩展，**不需要 App Groups** |
| 构建 | Widget Extension（SwiftUI）由 `flutter build ios --no-codesign` 自动编译进 .app；无需签名配置 |
| 侧载 | 未签名 IPA → ESign 自签时扩展（.appex）会被一并重签；无特殊能力要求 |

## 3. 方案选型

### 方案 A：`live_activities` 插件（2.6.0）
- 优点：现成的 MethodChannel 封装，Dart 侧 API 完整（create/update/end/areActivitiesEnabled）
- 缺点：
  - **强制 App Groups**：数据经 `UserDefaults(suiteName:)` 传给扩展
  - **App Groups 需要付费开发者账号**，免费 Apple ID（Personal Team）不支持 → 与"未签名 IPA + ESign 自签"的分发方式冲突
  - `ActivityAttributes` 类名必须叫 `LiveActivitiesAppAttributes`，UI 自由度受限
  - 图片 ≤4KB 等额外限制

### 方案 B：自研 MethodChannel + ActivityKit（推荐）
- 优点：
  - `ContentState` 强类型直接携带全部数据 → **不需要 App Groups、不需要推送能力**，免费证书自签也能用
  - 扩展 UI 完全自定义，符合 Aurora 视觉
  - 无第三方包版本绑定
- 成本：多写约 300~400 行 Swift（桥接 + 扩展 UI）

### 结论
**采用方案 B**。现有工程（未签名 IPA + ESign 侧载）下方案 A 的 App Groups 依赖是硬伤；
若以后有付费开发者账号且想省代码，可再评估迁移到 A。

## 4. 详细设计（方案 B）

### 4.1 Flutter 侧

新增 `lib/services/live_activity_service.dart`：

```dart
class LiveActivityService {
  static const MethodChannel _channel =
      MethodChannel('com.sirandev.auroraweather/live_activity');

  Future<bool> isSupported();          // iOS 16.1+ 且用户未关闭实时活动
  Future<void> start(Map<String, dynamic> data);
  Future<void> update(Map<String, dynamic> data);
  Future<void> end();
  Future<String?> getState();          // active / dismissed / ended
}
```

数据模型（普通 Map 即可，避免新增 freezed 模型）：

```json
{
  "city": "杭州",
  "temp": "18",
  "feelsLike": "17",
  "text": "多云",
  "icon": "104",
  "tempMax": "22",
  "tempMin": "12",
  "updatedAt": 1732000000,
  "unit": "C"
}
```

接入点：
- `lib/providers/weather_provider.dart`：`loadWeather()` / `refresh()` 成功后调用
  `liveActivityService.update(data)`（比较关键字段 hash，无变化跳过）
- `lib/screens/main_screen.dart` 启动时：开关开启 → `start(data)`
- `lib/providers/settings_provider.dart`：新增 `iosLiveActivityEnabled`（key: `ios_live_activity_enabled`，默认 true）

设置项（`lib/screens/settings/settings_screen.dart`）：
- 仅在 `supportsLiveActivities` 为 true 时显示（`lib/core/platform/platform_capabilities.dart` 新增：
  `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && iOS >= 16.1`，运行时用 `Platform.isIOS`
  的版本判断可用 `MethodChannel` 的 `isSupported()` 结果代替）
- 标题「锁屏实时活动」，副标题说明"在锁屏和灵动岛上显示当前天气（iOS 16.1+）"
- 关闭开关 → `liveActivityService.end()`

### 4.2 iOS 侧

新增 Widget Extension target：`AuroraWeatherLiveActivity`

```
ios/
├── Runner/Info.plist                 # + NSSupportsLiveActivities = true
├── LiveActivity/
│   ├── AuroraWeatherLiveActivity.swift   # @main WidgetBundle
│   ├── AuroraWeatherActivityAttributes.swift
│   ├── LockScreenView.swift
│   ├── DynamicIslandView.swift
│   └── Info.plist                    # NSExtension: com.apple.widgetkit-extension
└── Runner/LiveActivityBridge.swift   # MethodChannel → ActivityKit
```

`ContentState` 定义：

```swift
struct AuroraWeatherActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var city: String
        var temp: String
        var feelsLike: String
        var text: String
        var symbol: String      // Swift 端由 QWeather icon code 映射
        var tempMax: String
        var tempMin: String
        var updatedAt: Date
    }
}
```

桥接策略（`LiveActivityBridge.swift`，在 AppDelegate 注册）：
- `start`：`Activity.request(attributes:contentState:pushType: nil)`
- `update`：`await activity.update(ActivityContent(state:staleDate: Date+15min))`
- `end`：`await activity.end(nil, dismissalPolicy: .immediate)`
- 保存 `Activity<AuroraWeatherActivityAttributes>?` 引用；冷启动时用
  `Activity<AuroraWeatherActivityAttributes>.activities` 取回活动
- 全部包 `if #available(iOS 16.1, *)`；`ActivityAuthorizationInfo().areActivitiesEnabled` 为 false 时返回不支持

UI：
- 锁屏：圆角 20 卡片，深色渐变底（按天气/昼夜），城市 + 大号温度 + 描述 + 高低温 + "更新于 HH:mm"
- 灵动岛：
  - compactLeading：SF Symbol 天气图标
  - compactTrailing：温度
  - minimal：温度（或图标，空间不足时只放温度）
  - expanded：左侧城市/描述，右侧大温度，底部高低温 + 更新时间
- QWeather icon code → SF Symbol 映射表（sun.max.fill / cloud.fill / cloud.rain.fill /
  cloud.bolt.rain.fill / snowflake / cloud.fog.fill / moon.stars.fill 等）

### 4.3 工程配置（project.pbxproj）

1. Xcode 新建 Widget Extension target（勾选 "Include Live Activity"），命名 `AuroraWeatherLiveActivity`
2. Bundle Identifier：`com.sirandev.auroraweather.LiveActivity`（必须是 Runner bundle id 的前缀）
3. 扩展部署目标：**iOS 16.1**（Runner 保持 15.0）
4. Runner 的 "Embed App Extensions" 构建阶段加入该扩展
5. 扩展 Build Settings：`SKIP_INSTALL = YES`、`APPLICATION_EXTENSION_API_ONLY = YES`
6. **不添加** App Groups / Push Notifications 能力（自签友好）
7. 两个 Info.plist 都加 `NSSupportsLiveActivities = true`

> ⚠️ pbxproj 手改易错。建议本机用 Xcode 生成 target 后提交；CI 只负责编译验证。

## 5. 更新与生命周期策略

| 场景 | 行为 |
|---|---|
| App 启动 | 开关开 + 有天气数据 → `start`（若已有活动则 `update`） |
| 手动/自动刷新成功 | 关键字段有变化才 `update`，`staleDate = now + 15min` |
| 刷新失败 | 不更新，等下次；活动超时后系统标记过期 |
| 关闭开关 | `end`（立即移除） |
| App 被杀 | 活动保留，staleDate 过后显示为过期，不主动结束 |
| 满 8 小时 | 系统自动结束；下次打开 App 重新创建 |

不做远程推送的前提下，锁屏的"实时感"依赖 App 前台刷新频率，方案中如实说明，避免预期偏差。

## 6. 设置与文案

- 设置项：`iosLiveActivityEnabled`，默认开启
- 中文：「锁屏实时活动」/ 副标题「在锁屏和灵动岛上显示当前天气（iOS 16.1+）」
- 英文：`Live Activity` / `Show current weather on the Lock Screen and Dynamic Island (iOS 16.1+)`
- 开关只在 `isSupported() == true` 时显示

## 7. 测试计划

1. **模拟器**：iPhone 16 Pro（灵动岛）验证 compact/minimal/expanded + 锁屏卡片；
   iPhone 16（无灵动岛）验证锁屏卡片 + 无灵动岛 UI
2. **iOS 15 模拟器**：设置项不显示、无崩溃、天气功能回归
3. **真机**：iOS 16.1+ 侧载 ESign 重签后验证活动能出现、数据正确、重签未破坏扩展
4. **CI**：现有 `ipa-dispatch.yml` 直接构建验证扩展编译通过（`flutter build ios --no-codesign`）
5. **边界**：关闭系统"实时活动"总开关时，App 内开关应提示或自动隐藏（依赖 areActivitiesEnabled）

## 8. 里程碑

| 阶段 | 内容 | 预估 |
|---|---|---|
| M1 | 扩展 target + 静态 UI（固定数据） | 0.5 天 |
| M2 | Dart 通道 + 天气刷新联动 + 设置开关 | 0.5 天 |
| M3 | 灵动岛四形态 + 图标映射 + 文案/本地化 | 0.5 天 |
| M4 | CI 构建 + 模拟器/真机/侧载验证 | 0.5 天 |

v2：交互按钮（App Intents）、预警实时活动、APNs 推送更新。

## 9. 风险清单

| 风险 | 影响 | 对策 |
|---|---|---|
| pbxproj 手改出错 | CI 构建失败 | 本机 Xcode 生成 target 后提交；CI 先跑通再合入 |
| 免费证书侧载不支持某些能力 | 活动不显示 | 方案 B 不依赖 App Groups/推送，理论上无此问题；需真机验证 |
| ESign 重签未正确处理 .appex | 扩展失效 | 验收项；若失败可尝试其他签名工具或保留扩展不签名 |
| 系统限频/省电策略 | 更新延迟 | 仅数据变化时更新；staleDate 让 UI 明确显示过期 |
| 用户关闭系统实时活动 | 开关无效 | `areActivitiesEnabled` 检查 + UI 说明 |
| 灵动岛仅 Pro 机型 | 普通机型无灵动岛 | 文档/设置文案说明"锁屏可用，灵动岛仅部分机型" |
