import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'dimensional_design.dart';

class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.name,
    required this.email,
  });
  final String name;
  final String email;
  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? 'U'
        : '${words.first.characters.first}${words.length > 1 ? words.last.characters.first : ''}'
              .toUpperCase();
    return RaisedPanel(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandNavy, Color(0xFF1B577A), primaryBlue],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          const Text(
            'YOUR LANKAR SPACE',
            style: TextStyle(
              color: Color(0xFFC9E9F8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 24),
          ProfileMedallion(initials: initials),
          const SizedBox(height: 24),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC9E9F8),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .15)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFFC9E9F8),
                  size: 15,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Your account',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileMedallion extends StatelessWidget {
  const ProfileMedallion({super.key, required this.initials});
  final String initials;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 112,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 80,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF041B2B).withValues(alpha: .35),
                borderRadius: BorderRadius.circular(100),
                boxShadow: const [
                  BoxShadow(color: Color(0x44041B2B), blurRadius: 14),
                ],
              ),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateX(.08)
              ..rotateY(-.14),
            child: Container(
              width: 94,
              height: 94,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE5F8FF),
                    Color(0xFF6FCBF0),
                    Color(0xFF1E6D98),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .65)),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0xFF0C4566),
                    offset: Offset(4, 7),
                  ),
                  BoxShadow(
                    color: secondaryBlue.withValues(alpha: .4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-.4, -.5),
                    radius: 1.2,
                    colors: [
                      Color(0xFF3EADD7),
                      Color(0xFF18587C),
                      Color(0xFF102E45),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF9BDCF3).withValues(alpha: .65),
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
