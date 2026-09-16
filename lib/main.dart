import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'providers/queue_provider.dart';
import 'screens/splash_screen.dart';

void main() => runApp(const QueueGoApp());

class QueueGoApp extends StatelessWidget {
  const QueueGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<QueueProvider>(
      create: (_) => QueueProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'QueueGo',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

