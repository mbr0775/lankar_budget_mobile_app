import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// Shared native Flutter visuals. Motion stops when the OS requests it.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [
                    const Color(0xFF0C1E2C),
                    const Color(0xFF153C55),
                    const Color(0xFF0C1E2C),
                  ]
                : [Colors.white, const Color(0xFFEAF5FC), brandMist],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -100, right: -140, child: _halo(380, dark)),
            Positioned(bottom: -180, left: -180, child: _halo(420, dark)),
            child,
          ],
        ),
      ),
    );
  }

  Widget _halo(double size, bool dark) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            secondaryBlue.withValues(alpha: dark ? .13 : .10),
            secondaryBlue.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 42, this.showName = true});
  final double size;
  final bool showName;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * .26),
          border: Border.all(color: const Color(0xFFDDECF5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Transform.scale(
          scale: 1.35,
          child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.contain),
        ),
      ),
      if (showName) ...[
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Lankar',
            style: TextStyle(
              fontSize: size * .53,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
        ),
      ],
    ],
  );
}

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Perspective tilt and independently floating layers give the artwork depth.
class FinanceScene extends StatefulWidget {
  const FinanceScene({
    super.key,
    this.variant = 0,
    this.height = 260,
    this.showLogo = false,
  });
  final int variant;
  final double height;
  final bool showLogo;
  @override
  State<FinanceScene> createState() => _FinanceSceneState();
}

class _FinanceSceneState extends State<FinanceScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = .25;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 340,
              height: 270,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final wave = math.sin(_motion.value * math.pi * 2);
                  final dark = Theme.of(context).brightness == Brightness.dark;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 238,
                        height: 238,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: secondaryBlue.withValues(alpha: .07),
                          border: Border.all(
                            color: secondaryBlue.withValues(alpha: .13),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: -.38,
                        child: Container(
                          width: 310,
                          height: 174,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: secondaryBlue.withValues(alpha: .16),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 52,
                        right: 52,
                        bottom: 18,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: .19),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .0015)
                          ..setTranslationRaw(0.0, wave * 7, 0.0)
                          ..rotateX(-.07 + wave * .025)
                          ..rotateY(-.13 + wave * .045)
                          ..rotateZ(-.045),
                        child: Container(
                          width: widget.showLogo ? 172 : 246,
                          height: 172,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                secondaryBlue,
                                primaryBlue,
                                Color(0xFF11517D),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: .27),
                                blurRadius: 24,
                                offset: const Offset(9, 18),
                              ),
                            ],
                          ),
                          child: widget.showLogo
                              ? Center(
                                  child: Container(
                                    width: 122,
                                    height: 122,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Transform.scale(
                                      scale: 1.25,
                                      child: Image.asset(
                                        'assets/icon/app_icon.png',
                                      ),
                                    ),
                                  ),
                                )
                              : _cardContent(),
                        ),
                      ),
                      Positioned(
                        top: 13 + wave * -5,
                        right: 12,
                        child: _floatingTile(
                          dark,
                          widget.showLogo
                              ? const Icon(
                                  Icons.north_east_rounded,
                                  size: 32,
                                  color: primaryBlue,
                                )
                              : const BrandLockup(size: 53, showName: false),
                        ),
                      ),
                      if (!widget.showLogo)
                        Positioned(
                          bottom: 29 + wave * 5,
                          left: 3,
                          child: _floatingTile(
                            dark,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    widget.variant == 1
                                        ? Icons.cloud_done_outlined
                                        : Icons.trending_up_rounded,
                                    color: dark
                                        ? const Color(0xFF7FCBF1)
                                        : primaryBlue,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.variant == 1
                                          ? 'Always in sync'
                                          : 'A clearer picture',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.variant == 1
                                          ? 'Online or offline'
                                          : 'Every rupee, accounted for',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _floatingTile(bool dark, Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF18374D) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: secondaryBlue.withValues(alpha: .14)),
      boxShadow: [
        BoxShadow(
          color: brandNavy.withValues(alpha: .10),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );

  Widget _cardContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            widget.variant == 1
                ? Icons.wifi_off_rounded
                : Icons.account_balance_wallet_outlined,
            color: Colors.white70,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  'YOUR CASH BOOK',
                  'READY WHEN YOU ARE',
                  'YOUR MONEY, IN VIEW',
                ][widget.variant],
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white70,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ),
          const Icon(Icons.more_horiz, color: Colors.white70, size: 18),
        ],
      ),
      const SizedBox(height: 17),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          widget.variant == 1
              ? 'Keep life moving.'
              : widget.variant == 2
              ? 'See the bigger picture.'
              : 'Room to grow.',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -.5,
          ),
        ),
      ),
      const Spacer(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < 7; i++) ...[
            Container(
              width: 14,
              height: [13.0, 22.0, 18.0, 31.0, 27.0, 39.0, 48.0][i],
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .22 + i * .09),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 7),
          ],
          const Spacer(),
          const Icon(Icons.north_east_rounded, color: Colors.white, size: 26),
        ],
      ),
    ],
  );
}

class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.backAction,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? backAction;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: BrandLockup()),
                          if (backAction != null)
                            IconButton(
                              onPressed: backAction,
                              tooltip: 'Back to sign in',
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                        ],
                      ),
                      AnimatedSize(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: keyboard
                            ? const SizedBox(height: 20)
                            : FinanceScene(
                                height: constraints.maxHeight < 740 ? 165 : 205,
                              ),
                      ),
                      Entrance(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: primaryBlue.withValues(alpha: .10),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandNavy.withValues(alpha: .05),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                semanticsLabel: 'Please wait',
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(label, textAlign: TextAlign.center)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
    ),
  );
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        const Expanded(child: Divider()),
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'or continue with',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.validator,
    this.obscure = false,
    this.toggleObscure,
    this.keyboardType,
    this.autofillHints,
    this.last = false,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool obscure;
  final VoidCallback? toggleObscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool last;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      autocorrect: false,
      enableSuggestions: toggleObscure == null,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                onPressed: toggleObscure,
                tooltip: obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
      ),
    ),
  );
}
