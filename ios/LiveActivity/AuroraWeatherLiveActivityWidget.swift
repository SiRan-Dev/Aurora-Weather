import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AuroraWeatherLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    AuroraWeatherLiveActivityWidget()
  }
}

/// 锁屏 + 灵动岛实时活动。
struct AuroraWeatherLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AuroraWeatherActivityAttributes.self) { context in
      LockScreenLiveActivityView(state: context.state)
        .activityBackgroundTint(AuroraLivePalette.background)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 6) {
            Image(systemName: WeatherSymbol.symbol(for: context.state.icon))
              .font(.title3)
              .foregroundStyle(AuroraLivePalette.accent)
            Text(context.state.city)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.state.temp)°")
            .font(.system(size: 34, weight: .semibold, design: .rounded))
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 10) {
            Text(context.state.text)
            Spacer()
            Text("最高 \(context.state.tempMax)°  最低 \(context.state.tempMin)°")
            Spacer()
            Text(
              "更新 \(context.state.updatedAt.formatted(date: .omitted, time: .shortened))"
            )
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      } compactLeading: {
        Image(systemName: WeatherSymbol.symbol(for: context.state.icon))
          .foregroundStyle(AuroraLivePalette.accent)
      } compactTrailing: {
        Text("\(context.state.temp)°")
          .font(.caption2.weight(.semibold))
      } minimal: {
        Text("\(context.state.temp)°")
          .font(.caption2.weight(.semibold))
      }
      .keylineTint(AuroraLivePalette.accent)
    }
  }
}

/// 锁屏卡片。
struct LockScreenLiveActivityView: View {
  let state: AuroraWeatherActivityAttributes.ContentState

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Image(systemName: WeatherSymbol.symbol(for: state.icon))
            .foregroundStyle(AuroraLivePalette.accent)
          Text(state.city)
            .font(.headline)
            .lineLimit(1)
        }
        Text(state.text)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text("最高 \(state.tempMax)° / 最低 \(state.tempMin)°")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        HStack(alignment: .top, spacing: 2) {
          Text(state.temp)
            .font(.system(size: 42, weight: .semibold, design: .rounded))
          Text("°")
            .font(.system(size: 24, weight: .medium, design: .rounded))
        }
        Text("更新于 \(state.updatedAt.formatted(date: .omitted, time: .shortened))")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(16)
  }
}

/// 实时活动配色。
enum AuroraLivePalette {
  static let background = Color(red: 0.05, green: 0.08, blue: 0.16).opacity(0.92)
  static let accent = Color(red: 0.35, green: 0.85, blue: 0.95)
}

/// 和风天气图标代码 → SF Symbol 映射。
enum WeatherSymbol {
  static func symbol(for icon: String) -> String {
    guard let code = Int(icon) else { return "cloud.fill" }
    switch code {
    case 100:
      return "sun.max.fill"
    case 101, 102:
      return "cloud.sun.fill"
    case 103, 104:
      return "cloud.fill"
    case 150, 151:
      return "moon.stars.fill"
    case 153, 154:
      return "cloud.moon.fill"
    case 302, 303, 304:
      return "cloud.bolt.rain.fill"
    case 300...399:
      return "cloud.rain.fill"
    case 400...499:
      return "cloud.snow.fill"
    case 500...515:
      return "cloud.fog.fill"
    case 900, 901:
      return "thermometer.sun.fill"
    case 999:
      return "thermometer.snowflake"
    default:
      return "cloud.fill"
    }
  }
}
