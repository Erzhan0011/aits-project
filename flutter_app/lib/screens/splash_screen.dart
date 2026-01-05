import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_router.dart';
import '../widgets/plane_emblem.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Increased delay for a smoother cinematic experience
    await Future.delayed(const Duration(milliseconds: 3000));
    
    if (!mounted) return;
    
    if (authProvider.isAuthenticated) {
      if (authProvider.isStaff || authProvider.isAdmin) {
        Navigator.pushReplacementNamed(context, AppRouter.staffDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Night Sky
      body: Stack(
        children: [
          // Subtle background texture
          const Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF38BDF8), Colors.transparent],
                    radius: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PlaneEmblem(size: 240),
                const SizedBox(height: 48),
                const Text(
                  'ZHAN AIRLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                ),
                Text(
                  'FLY WITH PASSION',
                  style: TextStyle(
                    color: const Color(0xFF38BDF8).withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 6.0,
                  ),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFF38BDF8).withOpacity(0.5),
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
