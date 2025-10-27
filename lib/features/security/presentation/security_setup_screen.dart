import 'package:flutter/material.dart';
import '../../../core/services/security_service.dart';

class SecuritySetupScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const SecuritySetupScreen({
    super.key,
    required this.onSetupComplete,
  });

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final SecurityService _securityService = SecurityService();
  final PageController _pageController = PageController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  int _currentPage = 0;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _biometricAvailable = false;
  bool _enableBiometric = false;
  bool _setupCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _securityService.isBiometricAvailable();
    if (mounted && !_setupCompleted) {
      setState(() {
        _biometricAvailable = isAvailable;
        _enableBiometric = isAvailable;
      });
    }
  }

  Future<void> _setupSecurity() async {
    if (_setupCompleted) return; // Prevent multiple calls

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      debugPrint('SecuritySetupScreen: Starting PIN setup...');
      final success = await _securityService.setupPin(_pinController.text);
      debugPrint('SecuritySetupScreen: PIN setup result: $success');

      if (!mounted || _setupCompleted) {
        debugPrint(
            'SecuritySetupScreen: Widget disposed or setup already completed, exiting');
        return;
      }

      if (success) {
        if (_enableBiometric && _biometricAvailable) {
          debugPrint(
              'SecuritySetupScreen: Enabling biometric authentication...');
          await _securityService.setBiometricEnabled(true);
        }

        if (!mounted || _setupCompleted) {
          debugPrint(
              'SecuritySetupScreen: Widget disposed during biometric setup, exiting');
          return;
        }

        debugPrint(
            'SecuritySetupScreen: Setup completed successfully, calling onSetupComplete');
        _setupCompleted = true;

        // Call the callback - this will trigger navigation and dispose this widget
        widget.onSetupComplete();
      } else {
        debugPrint('SecuritySetupScreen: PIN setup failed');
        if (mounted && !_setupCompleted) {
          setState(() {
            _errorMessage = 'Failed to setup security. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('SecuritySetupScreen: Exception during setup: $e');
      if (mounted && !_setupCompleted) {
        setState(() {
          _errorMessage = 'Setup failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted && !_setupCompleted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _validateAndProceed() {
    if (_setupCompleted) return; // Prevent action if setup is completed

    // Clear any previous error messages
    if (mounted && !_setupCompleted) {
      setState(() {
        _errorMessage = '';
      });
    }

    // Validate PIN fields
    if (_pinController.text.isEmpty) {
      if (mounted && !_setupCompleted) {
        setState(() {
          _errorMessage = 'Please enter a PIN';
        });
      }
      return;
    }

    if (_pinController.text.length < 4) {
      if (mounted && !_setupCompleted) {
        setState(() {
          _errorMessage = 'PIN must be at least 4 digits';
        });
      }
      return;
    }

    if (_confirmPinController.text.isEmpty) {
      if (mounted && !_setupCompleted) {
        setState(() {
          _errorMessage = 'Please confirm your PIN';
        });
      }
      return;
    }

    if (_pinController.text != _confirmPinController.text) {
      if (mounted && !_setupCompleted) {
        setState(() {
          _errorMessage = 'PINs do not match';
        });
      }
      return;
    }

    // If validation passes, proceed to next page
    _nextPage();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Container(
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
            children: [
              // Progress Indicator
              LinearProgressIndicator(
                value: (_currentPage + 1) / 3,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    if (mounted && !_setupCompleted) {
                      setState(() {
                        _currentPage = page;
                        _errorMessage = '';
                      });
                    }
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildPinSetupPage(),
                    _buildBiometricSetupPage(),
                  ],
                ),
              ),

              // Navigation Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousPage,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_currentPage == 2) {
                                  _setupSecurity();
                                } else if (_currentPage == 1) {
                                  _validateAndProceed();
                                } else {
                                  _nextPage();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_currentPage == 2
                                ? 'Complete Setup'
                                : 'Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
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
                Icons.security,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Secure Your Records',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),

            const SizedBox(height: 16),

            Text(
              'Let\'s set up security for your personal records. This will help keep your information safe and private.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Security Features
            Column(
              children: [
                _buildFeatureItem(
                  icon: Icons.pin,
                  title: 'PIN Protection',
                  description: 'Secure access with a personal PIN',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.fingerprint,
                  title: 'Biometric Authentication',
                  description: 'Quick access with fingerprint',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.lock,
                  title: 'Data Encryption',
                  description: 'Your data is encrypted and secure',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinSetupPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Text(
              'Create Your PIN',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),

            const SizedBox(height: 16),

            Text(
              'Choose a secure PIN to protect your records. You\'ll need this to access the app.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // PIN Input
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: 'Enter PIN',
                hintText: '• • • • • •',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),

            const SizedBox(height: 16),

            // Confirm PIN Input
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: 'Confirm PIN',
                hintText: '• • • • • •',
                counterText: '',
                errorText: _errorMessage.isEmpty ? null : _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricSetupPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Text(
              'Biometric Authentication',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              _biometricAvailable
                  ? 'Enable fingerprint authentication for quick and secure access to your records.'
                  : 'Biometric authentication is not available on this device. You can continue with PIN authentication.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (_biometricAvailable) ...[
              Icon(
                Icons.fingerprint,
                size: 80,
                color: _enableBiometric
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 32),
              SwitchListTile(
                title: const Text('Enable Fingerprint'),
                subtitle: const Text('Use your fingerprint to unlock the app'),
                value: _enableBiometric,
                onChanged: (value) {
                  if (mounted && !_setupCompleted) {
                    setState(() {
                      _enableBiometric = value;
                    });
                  }
                },
              ),
            ] else ...[
              Icon(
                Icons.fingerprint_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 32),
              Text(
                'Not Available',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
