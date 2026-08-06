import 'package:flutter/material.dart';
import '../di/injection.dart' as di;
import 'biometric_initializer.dart';

/// Screen shown before main app when biometric authentication is required.
class BiometricGateScreen extends StatefulWidget {
  final Widget child;

  const BiometricGateScreen({super.key, required this.child});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _isAvailable = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAndAuthenticate();
  }

  Future<void> _checkAndAuthenticate() async {
    final biometricInitializer = di.getIt<BiometricInitializer>();
    
    // Check if biometric is available
    final available = await biometricInitializer.isAvailable();
    setState(() {
      _isAvailable = available;
      _isLoading = false;
    });

    if (!available) {
      // Biometric not available, proceed to app
      setState(() {
        _isAuthenticated = true;
      });
      return;
    }

    // Perform authentication
    final authenticated = await biometricInitializer.authenticateIfNeeded();
    if (authenticated) {
      setState(() {
        _isAuthenticated = true;
      });
    } else {
      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
      });
    }
  }

  Future<void> _retryAuthentication() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _checkAndAuthenticate();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fingerprint,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Budget Tracker',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isAvailable
                    ? 'Authenticate to continue'
                    : 'Loading...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _retryAuthentication,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}