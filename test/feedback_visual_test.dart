import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/widgets/app_feedback.dart';

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
  testWidgets('notification cards fit light/dark themes and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.5]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            themeAnimationDuration: Duration.zero,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: RepaintBoundary(
                key: const ValueKey('feedback-preview'),
                child: Scaffold(
                  body: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lankar',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: (dark ? AppTheme.dark : AppTheme.light)
                                  .colorScheme
                                  .onSurface,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FeedbackCard(
                            title: 'Welcome back',
                            message:
                                'You are signed in. Let us make every rupee count.',
                            tone: FeedbackTone.success,
                            onDismiss: () {},
                          ),
                          const SizedBox(height: 16),
                          FeedbackCard(
                            title: 'Income added',
                            message:
                                'Saved on this device. It will sync when a connection is available.',
                            tone: FeedbackTone.success,
                            onDismiss: () {},
                          ),
                          const SizedBox(height: 16),
                          FeedbackCard(
                            title: 'Connection problem',
                            message:
                                'Check your connection and try again. Your details are still here.',
                            tone: FeedbackTone.error,
                            onDismiss: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1 && const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('feedback-preview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/design-previews/feedback${dark ? '-dark' : ''}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });
}
