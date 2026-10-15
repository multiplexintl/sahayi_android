import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Splash (Version 2): brand while the app checks permission, updates and the
/// saved session (SplashController does the work and navigates on).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return V2Screen(
      child: Builder(builder: (context) {
        final c = context.c;
        final t = Theme.of(context).textTheme;
        return Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/images/launch_icon.png', width: 160, height: 160),
              Text('Sahayi', style: t.displaySmall),
              const SizedBox(height: 2),
              Text('Warehouse checking made simple', style: t.bodySmall),
              const SizedBox(height: Space.xxl),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: c.primary),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
