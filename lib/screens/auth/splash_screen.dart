// lib/screens/auth/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import '../../navigation/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      duration: const Duration(milliseconds: 900), vsync: this,
    );
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _mainCtrl,
          curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _mainCtrl,
          curve: const Interval(0, 0.8, curve: Curves.elasticOut)),
    );
    _pulseAnim = Tween<double>(begin: 1, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _mainCtrl.forward();
    _mainCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseCtrl.repeat(reverse: true);
      }
    });

    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // Run prefs fetch and minimum display time in parallel
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      Future.delayed(const Duration(milliseconds: 1200)), // minimum splash time
    ]);

    if (!mounted) return;

    final prefs       = results[0] as SharedPreferences;
    final seenOnboard = prefs.getBool(PrefKeys.seenOnboarding) ?? false;
    final session     = Supabase.instance.client.auth.currentSession;

    Widget destination;
    if (session != null) {
      destination = const MainShell();
    } else if (!seenOnboard) {
      destination = const OnboardingScreen();
    } else {
      destination = const LoginScreen();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => destination,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF5F5), Color(0xFFFFE8E8), Color(0xFFFFF0F0)],
          ),
        ),
        child: Stack(
          children: [
            // Top-right decoration
            Positioned(
              top: -80, right: -80,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      primaryRed.withOpacity(0.12),
                      primaryRed.withOpacity(0),
                    ]),
                  ),
                ),
              ),
            ),
            // Bottom-left decoration
            Positioned(
              bottom: -120, left: -120,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: 340, height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      primaryRed.withOpacity(0.08),
                      primaryRed.withOpacity(0),
                    ]),
                  ),
                ),
              ),
            ),
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_mainCtrl, _pulseCtrl]),
                builder: (_, __) => FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with pulse
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            width: 160, height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [primaryRed, secondaryRed],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryRed.withOpacity(0.3),
                                  blurRadius: 36,
                                  spreadRadius: 8,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 140, height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Image.asset(
                                      'assets/icon/app_icon.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_balance_wallet,
                                        color: primaryRed, size: 56,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        // App name
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _mainCtrl,
                            curve: const Interval(0.4, 1, curve: Curves.easeOut),
                          ),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [primaryRed, secondaryRed],
                                ).createShader(bounds),
                                child: const Text(
                                  'Lankar',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Cash Management System',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 52),
                        // Slim loading bar instead of circular spinner
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _mainCtrl,
                            curve: const Interval(0.5, 1, curve: Curves.easeOut),
                          ),
                          child: SizedBox(
                            width: 100,
                            child: LinearProgressIndicator(
                              backgroundColor: primaryRed.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  primaryRed),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom branding
            Positioned(
              bottom: 36, left: 0, right: 0,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _mainCtrl,
                  curve: const Interval(0.6, 1, curve: Curves.easeOut),
                ),
                child: Column(
                  children: [
                    Text('Powered by',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 3),
                    Text(
                      'Tokilo Technologies',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}