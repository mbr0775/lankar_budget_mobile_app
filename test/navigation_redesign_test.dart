import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lankar/navigation/app_bottom_nav.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/widgets/auth_design.dart' show BrandLockup;
import 'package:lankar/widgets/home/total_balance_card.dart';
import 'package:lankar/widgets/home/quick_actions_row.dart';

const _labels = ['Home', 'Books', 'Reports', 'Analytics', 'Profile'];

class _DockHost extends StatefulWidget {
  const _DockHost({required this.onSelected, this.preview = false});
  final ValueChanged<int> onSelected;
  final bool preview;
  @override
  State<_DockHost> createState() => _DockHostState();
}

class _DockHostState extends State<_DockHost> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: widget.preview
        ? ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 16),
              const BrandLockup(),
              const SizedBox(height: 28),
              const Text(
                'Your overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              const TotalBalanceCard(
                displayBalance: 9395.50,
                symbol: r'$',
                bookCount: 3,
                monthIncome: 6120,
                monthExpense: 2336,
              ),
              const SizedBox(height: 24),
              QuickActionsRow(onBooksTap: () {}, onReportsTap: () {}),
            ],
          )
        : Column(
            children: [
              Expanded(child: Center(child: Text('Destination $selected'))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  key: const ValueKey('page-control'),
                  height: 48,
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  alignment: Alignment.center,
                  child: const Text('Page content stays above the dock'),
                ),
              ),
            ],
          ),
    bottomNavigationBar: AppBottomNav(
      selectedIndex: selected,
      onTap: (index) {
        setState(() => selected = index);
        widget.onSelected(index);
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = Platform.environment['AUTH_PREVIEW_FONT'];
    if (font != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  Future<void> show(
    WidgetTester tester, {
    bool dark = false,
    bool reduced = true,
    bool rtl = false,
    double scale = 1,
    double bottomInset = 0,
    bool preview = false,
    Size size = const Size(390, 844),
    ValueChanged<int>? onSelected,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: RepaintBoundary(
              key: const ValueKey('nav-preview'),
              child: child!,
            ),
          ),
        ),
        home: _DockHost(onSelected: onSelected ?? (_) {}, preview: preview),
      ),
    );
    await tester.pump();
    if (preview) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/icon/app_icon.png'),
          tester.element(find.byType(_DockHost)),
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  Finder tab(String label) =>
      find.byKey(ValueKey('nav-tab-${label.toLowerCase()}'));
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('nav-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('all five destinations work with one accessible selected tab', (
    tester,
  ) async {
    final selections = <int>[];
    final semantics = tester.ensureSemantics();
    await show(tester, onSelected: selections.add);
    for (int index = 0; index < _labels.length; index++) {
      await tester.tap(tab(_labels[index]));
      await tester.pumpAndSettle();
      expect(find.text('Destination $index'), findsOneWidget);
      for (int other = 0; other < _labels.length; other++) {
        final node = tester.getSemantics(tab(_labels[other]));
        expect(node.label, _labels[other]);
        expect(node.flagsCollection.isButton, isTrue);
        expect(
          node.flagsCollection.isSelected == ui.Tristate.isTrue,
          other == index,
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
      }
      final highlight = tester.getRect(
        find.byKey(const ValueKey('nav-highlight')),
      );
      final target = tester.getRect(tab(_labels[index]));
      expect(highlight.center.dx, closeTo(target.center.dx, .01));
      expect(
        tester.getRect(find.byKey(const ValueKey('page-control'))).bottom,
        lessThan(tester.getRect(find.byType(AppBottomNav)).top),
      );
      expect(tester.takeException(), isNull);
    }
    expect(selections, [1, 2, 3, 4]);
    await tester.tap(tab('Profile'));
    await tester.pumpAndSettle();
    expect(selections, [1, 2, 3, 4]);
    semantics.dispose();
  });

  testWidgets('dock adapts to large text, gesture insets, RTL, and dark mode', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await show(
        tester,
        dark: dark,
        size: const Size(280, 640),
        scale: 2,
        rtl: true,
        bottomInset: 34,
      );
      for (final label in _labels) {
        await tester.tap(tab(label));
        await tester.pumpAndSettle();
        final highlight = tester.getRect(
          find.byKey(const ValueKey('nav-highlight')),
        );
        final target = tester.getRect(tab(label));
        expect(highlight.center.dx, closeTo(target.center.dx, .01));
        expect(target.width, greaterThanOrEqualTo(44));
        expect(target.height, greaterThanOrEqualTo(48));
        expect(target.bottom, lessThanOrEqualTo(640 - 34));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('selection glides and reduced motion changes tabs immediately', (
    tester,
  ) async {
    await show(tester, reduced: false);
    final initial = tester.getRect(find.byKey(const ValueKey('nav-highlight')));
    await tester.tap(tab('Analytics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getRect(find.byKey(const ValueKey('nav-highlight')));
    final target = tester.getRect(tab('Analytics'));
    expect(midway.center.dx, greaterThan(initial.center.dx));
    expect(midway.center.dx, lessThan(target.center.dx));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('nav-highlight'))).center.dx,
      closeTo(target.center.dx, .01),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester);
    await tester.tap(tab('Profile'));
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const ValueKey('nav-highlight'))).center.dx,
      closeTo(tester.getRect(tab('Profile')).center.dx, .01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs can be reached and activated with a keyboard', (
    tester,
  ) async {
    final selections = <int>[];
    await show(tester, onSelected: selections.add);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections, [1]);
    expect(find.text('Destination 1'), findsOneWidget);
  });

  testWidgets('preview the floating dock against the blue dashboard', (
    tester,
  ) async {
    await show(tester, preview: true);
    await capture(tester, 'navigation');
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, dark: true, preview: true);
    await tester.tap(tab('Reports'));
    await tester.pumpAndSettle();
    await capture(tester, 'navigation-dark');
    expect(tester.takeException(), isNull);
  });
}
