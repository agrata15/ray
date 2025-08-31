import 'package:flutter/material.dart';
import 'clients_screen.dart';
import 'home_screen.dart';
import 'cluster_screen.dart';
import 'dashboard_screen.dart';
import 'audit_screen.dart';
import 'appliances_screen.dart';

class NavigationHelper {
  static void navigateTo(BuildContext context, String screen) {
    late Widget destination;

    switch (screen) {
      case 'client':
        destination = ClientsScreen();
        break;
      case 'dashboard':
        destination = const DashboardScreen();
        break;
      case 'audit':
        destination = const AuditScreen();
        break;
      case 'appliances':
        destination = const AppliancesScreen();
        break;
      case 'home':
        destination = const HomeScreen();
        break;
      case 'cluster':
        destination =const ClusterScreen();
      default:
        destination =const HomeScreen();
        break; // exit early if invalid
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}