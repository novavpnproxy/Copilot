import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: .82, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF10263B), Color(0xFF091321), Color(0xFF07101C)])),
          child: SafeArea(child: Center(child: FadeTransition(opacity: _fade, child: ScaleTransition(scale: _scale, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shield_moon_outlined, size: 118, color: Color(0xFF35D0BA)),
            SizedBox(height: 24),
            Text('NOVA VPN', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3.5)),
            SizedBox(height: 9),
            Text('JEYRAN GROUP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2.8, color: Color(0xFF35D0BA))),
          ]))))),
        ),
      );
}
