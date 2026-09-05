import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.subtitle});
  final String subtitle;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/polyht_logo.png', width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 20),
                  const Text('e-PolyPariksha HP', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(widget.subtitle, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 3)),
                  const SizedBox(height: 12),
                  Text('e-PolyPariksha HP', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 1)),
                  const SizedBox(height: 40),
                  SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
