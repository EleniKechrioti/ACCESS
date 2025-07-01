import 'dart:async';

import 'package:access/web_screens/web_bloc/web_login_screen/login_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:access/theme/app_theme.dart' as AppTheme;
import 'package:access/theme/app_colors.dart';
import 'dart:html' as html;

/// Login screen for the Δήμος web app.
/// Handles user input for email and password, dispatches login events,
/// listens for login success or failure to navigate or show error messages.
/// Also listens to browser back button to handle redirection based on auth token.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Subscription for browser back button popstate events.
  StreamSubscription<html.PopStateEvent>? _popStateSubscription;

  @override
  void initState() {
    super.initState();
    _popStateSubscription = html.window.onPopState.listen((event) {
      if (html.window.localStorage['authToken'] == null) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _popStateSubscription?.cancel();
    super.dispose();
  }

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  /// Controls visibility of the password text field.
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Σύνδεση Δήμου',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        automaticallyImplyLeading: false,
      ),
      body: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            html.window.localStorage['authToken'] = 'user_authenticated';
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/webhome',
                  (Route<dynamic> route) => false,
            );
            html.window.history.replaceState(null, '', '/webhome');
          } else if (state is LoginFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: Theme.of(context).textTheme.labelLarge,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Κωδικός',
                    labelStyle: Theme.of(context).textTheme.labelLarge,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                state is LoginLoading
                    ? CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                )
                    : ElevatedButton(
                  onPressed: () {
                    context.read<LoginBloc>().add(LoginRequested(
                      email: emailController.text,
                      password: passwordController.text,
                    ));
                  },
                  child: Text(
                    'Σύνδεση',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: Text(
                    'Δεν έχεις λογαριασμό; Κάνε εγγραφή',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}