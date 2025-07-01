import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

/// Widget that controls access to the admin dashboard by listening to Firebase
/// authentication state changes. It displays the login screen if the user is not
/// authenticated, or the admin dashboard if authenticated.
class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        /// While waiting for the auth state to initialize, show a loading spinner.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        /// If the user is authenticated, show the admin dashboard.
        /// TODO: Optionally verify admin privileges here (e.g., by checking email or claims).
        if (snapshot.hasData) {
          return const AdminDashboardScreen();
        }

        /// If no user is authenticated, show the login screen.
        return const AdminLoginScreen();
      },
    );
  }
}
