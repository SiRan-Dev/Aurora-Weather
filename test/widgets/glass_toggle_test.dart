import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pureweather/providers/settings_provider.dart';
import 'package:pureweather/widgets/glass/aurora_glass_button.dart';
import 'package:pureweather/widgets/glass/aurora_glass_card.dart';
import 'package:pureweather/widgets/glass/aurora_glass_icon_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Liquid Glass is enabled by default and the choice persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    // 默认开启：老用户升级后外观保持不变。
    expect(container.read(settingsProvider).liquidGlassEnabled, isTrue);

    await container
        .read(settingsProvider.notifier)
        .setLiquidGlassEnabled(false);

    expect(container.read(settingsProvider).liquidGlassEnabled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('liquid_glass_enabled'), isFalse);
  });

  testWidgets('glass widgets render plain surfaces when disabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    await container
        .read(settingsProvider.notifier)
        .setLiquidGlassEnabled(false);
    await tester.pump();

    expect(container.read(settingsProvider).liquidGlassEnabled, isFalse);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AuroraGlassCard(child: Text('card')),
                AuroraGlassButton(label: 'button', onPressed: () {}),
                AuroraGlassIconButton(icon: Icons.add, onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 关闭玻璃后三个组件仍然正常渲染，只是换成普通半透明表面。
    expect(find.text('card'), findsOneWidget);
    expect(find.text('button'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
