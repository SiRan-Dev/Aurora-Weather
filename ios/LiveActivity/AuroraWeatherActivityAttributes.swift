import ActivityKit
import Foundation

/// 实时活动属性定义。
///
/// ContentState 直接携带全部天气数据，不依赖 App Groups，
/// 因此免费证书侧载（ESign 重签）也能正常使用。
struct AuroraWeatherActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// 城市名称
    var city: String
    /// 当前温度
    var temp: String
    /// 体感温度
    var feelsLike: String
    /// 天气描述
    var text: String
    /// 和风天气图标代码
    var icon: String
    /// 今日最高温度
    var tempMax: String
    /// 今日最低温度
    var tempMin: String
    /// 数据更新时间
    var updatedAt: Date
  }
}
