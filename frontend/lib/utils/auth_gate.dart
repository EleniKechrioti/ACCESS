import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../blocs/my_account_bloc/my_account_bloc.dart';
import '../screens/login_screen.dart';
import '../screens/myaccount_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStateStream;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // While waiting for auth state (especially first time app opens)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session != null) {
          // User is signed in
          return BlocListener<MyAccountBloc, MyAccountState>(
            listener: (context, state) {
              if (state is MyAccountSignedOut) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const MyAccountScreen(),
          );
        }

        // Not signed in
        return LoginScreen();
      },
    );
  }
}
