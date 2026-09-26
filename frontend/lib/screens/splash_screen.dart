// Splash screen (initial loading and auth check)
import 'package:flutter/material.dart';
import 'package:hifazat_app/auth/auth_provider.dart';
import 'package:hifazat_app/routes.dart';
import 'package:hifazat_app/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() {
    // We use addPostFrameCallback to ensure the build method has completed
    // and the context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Listen to changes in authState to navigate
      authProvider.addListener(() {
        if (!mounted) return;
        
        switch (authProvider.authState) {
          case AuthState.authenticated:
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            break;
          case AuthState.unauthenticated:
            Navigator.of(context).pushReplacementNamed(AppRoutes.checkout);
            break;
          case AuthState.uninitialized:
          case AuthState.loading:
            // Do nothing, wait for the state to change
            break;
        }
      });
      
      // Initial check
      if (authProvider.authState == AuthState.uninitialized) {
          authProvider.checkAuthStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Replace with your app logo
            Icon(Icons.shield, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text('Hifazat', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 40),
            LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}