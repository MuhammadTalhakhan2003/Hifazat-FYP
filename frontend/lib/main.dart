import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/auth/auth_provider.dart';
import 'package:hifazat_app/providers/category_provider.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/providers/map_provider.dart';
import 'package:hifazat_app/providers/stats_provider.dart';
import 'package:hifazat_app/providers/user_provider.dart';
import 'package:hifazat_app/routes.dart';
import 'package:hifazat_app/utils/app_colors.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await dotenv.load(fileName: ".env");
  await ApiClient.instance.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
      ],
      child: const HifazatApp(),
    ),
  );
}

class HifazatApp extends StatelessWidget {
  const HifazatApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- NEW: A clean and professional Light Theme ---
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primarySwatch: AppColors.primaryMaterialColor, // Use the swatch for default component colors
      primaryColor: AppColors.primaryBlue,

      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentPurple,
        background: AppColors.backgroundLight,
        surface: AppColors.surfaceLight, // For cards
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: AppColors.textDark,
        onSurface: AppColors.textDark, // Text on cards
        error: Colors.red,
        onError: Colors.white,
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textDark),
        bodyMedium: TextStyle(color: AppColors.textGrey),
        titleLarge: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight, // White app bar
        foregroundColor: AppColors.textDark, // Dark icons and title
        elevation: 1,
        centerTitle: true,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.textGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 2,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
      ),
    );

    return MaterialApp(
      title: 'Hifazat App',
      debugShowCheckedModeBanner: false,
      // Apply the new light theme
      theme: lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}