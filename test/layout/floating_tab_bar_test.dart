import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pureweather/core/constants/app_constants.dart';

void main() {
  testWidgets(
    'floating tab bar overlays the full-height body and keeps only the safe area',
    (tester) async {
      const screenHeight = 844.0;
      const safeBottom = 34.0;

      tester.view.physicalSize = const Size(390, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late double bodyPaddingBottom;
      late double scrollInset;

      const bodyKey = Key('body');
      const barKey = Key('bar');

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, screenHeight),
            padding: EdgeInsets.only(top: 47, bottom: safeBottom),
            viewPadding: EdgeInsets.only(top: 47, bottom: safeBottom),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              // 与 MainScreen 一致：内容延伸到屏幕底部，底栏浮在上面。
              extendBody: true,
              body: Builder(
                builder: (context) {
                  bodyPaddingBottom = MediaQuery.paddingOf(context).bottom;
                  scrollInset = floatingTabBarScrollInset(context);
                  return const SizedBox.expand(key: bodyKey);
                },
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: const SizedBox(key: barKey, height: kFloatingTabBarHeight),
              ),
            ),
          ),
        ),
      );

      // Scaffold 在 extendBody 下把 body 的 padding.bottom 设为
      // 底栏上沿到屏幕底部的距离（底栏 + 安全区）。
      expect(bodyPaddingBottom, kFloatingTabBarHeight + safeBottom);

      // 滚到底时最后一项停在内边距之上，即底栏上方再留一个间距，
      // 不能多算一个底栏高度，也不能少算安全区。
      expect(
        scrollInset,
        kFloatingTabBarHeight + safeBottom + kFloatingTabBarContentGap,
      );

      // body 铺满整个屏幕，底栏悬浮在内容之上，底边只留系统安全区。
      final bodyRect = tester.getRect(find.byKey(bodyKey));
      final barRect = tester.getRect(find.byKey(barKey));
      expect(bodyRect.height, screenHeight);
      expect(barRect.top, screenHeight - kFloatingTabBarHeight - safeBottom);
      expect(barRect.bottom, screenHeight - safeBottom);
    },
  );
}
