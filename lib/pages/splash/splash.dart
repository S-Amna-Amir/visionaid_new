import 'package:flutter/material.dart';
import '../../shared/colors.dart';
import '../../data/services/model_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Loading models…';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Load both models concurrently while the splash is visible
      await ModelService.instance.loadAll();

      if (!mounted) return;
      setState(() => _status = 'Ready!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed to load models:\n$e');
      // Still navigate after a short pause so the user isn't stuck
      await Future.delayed(const Duration(seconds: 3));
    }

    if (!mounted) return;
    Navigator.pushNamed(context, '/pg1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(
            child: Text(
              'VisionAid',
              style: TextStyle(
                fontSize: 30,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}