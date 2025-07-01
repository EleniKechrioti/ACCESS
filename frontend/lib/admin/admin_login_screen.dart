import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Screen that provides a login form for admin users.
/// Handles input validation, sign-in with Firebase Auth,
/// and displays errors or loading states accordingly.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  /// Attempts to sign in using email and password.
  /// Shows loading indicator and handles errors with messages.
  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Navigation happens automatically via AuthGate / StreamBuilder
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'Παρουσιάστηκε άγνωστο σφάλμα.';
        });
      } finally {
        // Only update state if widget is still mounted
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Dispose controllers to avoid memory leaks.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Builds the UI for the Admin login screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400), // Limit width for web
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Είσοδος Διαχειριστή', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Παρακαλώ εισάγετε ένα έγκυρο email.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Παρακαλώ εισάγετε τον κωδικό σας.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _signIn,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                      child: const Text('Είσοδος'),
                    ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 15),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
