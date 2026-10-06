import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lankar/screens/auth/forgot_password_screen.dart';
import 'package:lankar/utils/app_theme.dart';

void main() {
  for (final smallScreen in [false, true]) {
    testWidgets('reset form remains usable with keyboard, small=$smallScreen', (
      tester,
    ) async {
      tester.view.physicalSize = smallScreen
          ? const Size(320, 640)
          : const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: smallScreen ? 300 : 340);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(smallScreen ? 1.6 : 1),
              ),
              child: child!,
            ),
            home: const ForgotPasswordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'invalid-email');
      await tester.ensureVisible(find.text('Send Reset Link'));
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      // Validation adds height while the keyboard already reduces the viewport.
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.ensureVisible(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.text('Send Reset Link'));
      expect(button.bottom, lessThanOrEqualTo(smallScreen ? 340 : 460));
      expect(tester.takeException(), isNull);
    });
  }
}
