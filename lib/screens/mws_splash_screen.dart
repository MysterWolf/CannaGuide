import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MwsSplashScreen extends StatefulWidget {
  const MwsSplashScreen({super.key});

  @override
  State<MwsSplashScreen> createState() => _MwsSplashScreenState();
}

class _MwsSplashScreenState extends State<MwsSplashScreen> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/mws_mark_dark.png',
              width: 120,
              height: 120,
            ),
            SizedBox(height: 20),
            Text(
              'mysterwolf',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: Color(0xFFCDD6F4),
                letterSpacing: 2.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'studios',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C7086),
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 36),
            Text(
              'Know before you go.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF585B70),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
