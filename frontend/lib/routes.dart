import 'package:flutter/widgets.dart';
import 'package:hifazat_app/screens/auth/login_screen.dart';
import 'package:hifazat_app/screens/auth/registration_screen.dart';
import 'package:hifazat_app/screens/checkout_screen.dart';
import 'package:hifazat_app/screens/incident_detail_screen.dart';
import 'package:hifazat_app/screens/incident_filter_screen.dart';
import 'package:hifazat_app/screens/main_screen.dart'; // Import the new main screen
import 'package:hifazat_app/screens/report_incident_screen.dart';
import 'package:hifazat_app/screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home'; // This is now the MainScreen with the nav bar
  static const String reportIncident = '/report-incident';
  // stats, profile etc. are now part of MainScreen, so we don't need separate routes for them
  static const String checkout = '/checkout'; // Guest access
  static const String incidentFilter = '/incident-filter';
  static const String incidentDetail = '/incident-detail';

  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegistrationScreen(),
    // MODIFIED: /home now points to MainScreen
    home: (context) => const MainScreen(), 
    reportIncident: (context) => ReportIncidentScreen(),
    checkout: (context) => const CheckoutScreen(),
    incidentFilter: (context) => const IncidentFilterScreen(),
    incidentDetail: (context) => const IncidentDetailScreen(),
  };
}