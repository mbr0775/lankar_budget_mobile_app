import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';
import '../../widgets/auth_design.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (!mounted) return;
    final prefs = results[0] as SharedPreferences;
    final session = Supabase.instance.client.auth.currentSession;
    // The router owns recovery and callback errors, including cold starts.
    final destination = session != null
        ? AppRoutes.home
        : (prefs.getBool(PrefKeys.seenOnboarding) ?? false)
        ? AppRoutes.login
        : AppRoutes.onboarding;
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    SizedBox(height: constraints.maxHeight * .14),
                    const Entrance(
                      child: FinanceScene(height: 260, showLogo: true),
                    ),
                    const SizedBox(height: 18),
                    const Entrance(
                      child: Column(
                        children: [
                          Text(
                            'Lankar',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Small steps. Bigger possibilities.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 80,
                      child: MediaQuery.disableAnimationsOf(context)
                          ? const LinearProgressIndicator(
                              value: 1,
                              minHeight: 3,
                              color: primaryBlue,
                            )
                          : LinearProgressIndicator(
                              minHeight: 3,
                              color: primaryBlue,
                              backgroundColor: primaryBlue.withValues(
                                alpha: .1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                    ),
                    const SizedBox(height: 65),
                    Text(
                      'BY TOKILO TECHNOLOGIES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
}
