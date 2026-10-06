import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../widgets/auth_design.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _finishing = false;
  static const _pages = [
    (
      'ONE PLACE. ALL YOUR MONEY.',
      'Less guesswork.\nMore control.',
      'Keep personal, business, and project cash books together. Know where your money goes.',
      Icons.auto_stories_outlined,
      'A book for every part of life',
    ),
    (
      'LIFE DOESN\'T WAIT FOR WI-FI.',
      'Offline today.\nIn sync tomorrow.',
      'Record income and expenses wherever you are. Lankar syncs your entries when you reconnect.',
      Icons.cloud_done_outlined,
      'Keep going, even offline',
    ),
    (
      'SEE WHAT\'S POSSIBLE.',
      'Small insights.\nSmarter decisions.',
      'Understand your income and spending with clear reports. Export a PDF whenever you need it.',
      Icons.insights_rounded,
      'Clarity you can take with you',
    ),
  ];
  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefKeys.seenOnboarding, true);
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your preference. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 14, 0),
                  child: Row(
                    children: [
                      const Expanded(child: BrandLockup()),
                      TextButton(
                        onPressed: _finishing ? null : _finish,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _pages.length,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    itemBuilder: (context, index) => AnimatedBuilder(
                      animation: _pageCtrl,
                      builder: (context, child) {
                        final page =
                            _pageCtrl.hasClients &&
                                _pageCtrl.position.haveDimensions
                            ? (_pageCtrl.page ?? 0)
                            : _currentPage.toDouble();
                        final offset = (page - index).clamp(-1.0, 1.0);
                        final reduced = MediaQuery.disableAnimationsOf(context);
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .001)
                            ..rotateY(reduced ? 0 : offset * .16),
                          child: Opacity(
                            opacity: reduced ? 1 : (1 - offset.abs() * .4),
                            child: child,
                          ),
                        );
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final data = _pages[index];
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FinanceScene(
                                  variant: index,
                                  height: constraints.maxHeight < 510
                                      ? 220
                                      : 300,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  data.$1,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  data.$2,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    height: 1.13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  data.$3,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.65,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Icon(
                                      data.$4,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        data.$5,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
                  child: Row(
                    children: [
                      for (int i = 0; i < _pages.length; i++)
                        Semantics(
                          label: 'Page ${i + 1} of ${_pages.length}',
                          selected: i == _currentPage,
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _currentPage ? 26 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? primaryBlue
                                  : primaryBlue.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '0${_currentPage + 1} / 03',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
                  child: AuthSubmitButton(
                    label: _currentPage == 2 ? 'Get started' : 'Continue',
                    loading: _finishing,
                    onPressed: () {
                      if (_currentPage == 2) {
                        _finish();
                      } else if (MediaQuery.disableAnimationsOf(context)) {
                        _pageCtrl.jumpToPage(_currentPage + 1);
                      } else {
                        _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeInOutCubic,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
