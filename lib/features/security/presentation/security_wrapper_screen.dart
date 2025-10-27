import 'package:flutter/material.dart';
import '../../../core/services/security_service.dart';
import 'security_setup_screen.dart';
import 'auth_screen.dart';

class SecurityWrapperScreen extends StatefulWidget {
  final Widget child;

  const SecurityWrapperScreen({
    super.key,
    required this.child,
  });

  @override
  State<SecurityWrapperScreen> createState() => _SecurityWrapperScreenState();
}

class _SecurityWrapperScreenState extends State<SecurityWrapperScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _authenticationCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeAuthentication();
  }

  Future<void> _initializeAuthentication() async {
    if (mounted && !_authenticationCompleted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await _securityService.authenticate();

      if (mounted && !_authenticationCompleted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (_authenticationCompleted) {
        debugPrint(
            'SecurityWrapperScreen: Authentication already completed during initialize');
        return;
      }

      switch (result) {
        case AuthenticationResult.success:
          if (mounted && !_authenticationCompleted) {
            _authenticationCompleted = true;
            setState(() {
              _isAuthenticated = true;
            });
          }
          break;
        case AuthenticationResult.needsSetup:
          // Just set loading to false - build method will show setup screen
          if (mounted && !_authenticationCompleted) {
            setState(() {
              _isLoading = false;
            });
          }
          break;
        case AuthenticationResult.needsPin:
        case AuthenticationResult.failedBiometric:
          _navigateToAuth();
          break;
        case AuthenticationResult.failedPin:
          _navigateToAuth();
          break;
      }
    } catch (e) {
      if (mounted && !_authenticationCompleted) {
        setState(() {
          _isLoading = false;
        });
      }
      _navigateToAuth();
    }
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AuthScreen(
          onAuthenticationSuccess: () => _onAuthenticationSuccess(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _onAuthenticationSuccess() {
    debugPrint('SecurityWrapperScreen: _onAuthenticationSuccess called');

    if (_authenticationCompleted) {
      debugPrint(
          'SecurityWrapperScreen: Authentication already completed, skipping');
      return;
    }

    if (mounted) {
      _authenticationCompleted = true;
      setState(() {
        _isAuthenticated = true;
      });
      debugPrint('SecurityWrapperScreen: Authentication state set to true');
    } else {
      debugPrint(
          'SecurityWrapperScreen: Widget not mounted, skipping setState');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _buildLoadingScreen(),
      );
    }

    if (_isAuthenticated) {
      return widget.child;
    }

    // Show setup screen directly instead of navigating
    return SecuritySetupScreen(
      onSetupComplete: () {
        debugPrint('SecurityWrapperScreen: Setup completed callback triggered');
        _onAuthenticationSuccess();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.folder,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 40),

            // App Title
            Text(
              'My Records',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),

            const SizedBox(height: 8),

            Text(
              'Secure • Organized • Accessible',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
            ),

            const SizedBox(height: 60),

            // Loading Animation
            Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Initializing Security...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
