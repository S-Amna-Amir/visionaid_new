import 'package:flutter/material.dart';
import '../../shared/colors.dart';
import '../../data/services/model_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Starting up…';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() => _status = 'Loading obstacle detector…');
      await ModelService.instance.loadYolo();

      setState(() => _status = 'Loading depth estimator…');
      await ModelService.instance.loadOnnx();

      if (!mounted) return;
      setState(() => _status = 'Ready!');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _status = 'Failed to load models:\n$e';
      });
      // Give the user time to read the error — do NOT navigate on failure.
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/pg1');
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
          if (!_hasError)
            const CircularProgressIndicator(color: Colors.white),
          if (_hasError)
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _status = 'Retrying…';
                });
                _init();
              },
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}