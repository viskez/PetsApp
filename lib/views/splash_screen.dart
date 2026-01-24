// lib/views/splash_screen.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.loginBuilder});

  final WidgetBuilder? loginBuilder;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final nextBuilder = widget.loginBuilder ?? (_) => const LoginScreen();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: nextBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 90, color: scheme.onPrimary),
            const SizedBox(height: 16),
            Text(
              'PetsApp',
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Virtual Intelligence, Smart Knowledge & Energy Zone',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onPrimary.withOpacity(0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
