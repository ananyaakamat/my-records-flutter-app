import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/security_service.dart';
import '../../folders/providers/folder_provider.dart';
import 'security_setup_screen.dart';
import 'auth_screen.dart';

// Global authentication state provider
final authenticationStateProvider = StateProvider<bool>((ref) => false);

class SecurityWrapperScreen extends ConsumerStatefulWidget {
  final Widget child;

  const SecurityWrapperScreen({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SecurityWrapperScreen> createState() =>
      _SecurityWrapperScreenState();
}

class _SecurityWrapperScreenState extends ConsumerState<SecurityWrapperScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _authenticationCompleted = false;
  bool _needsAuthentication = false;

  @override
  void initState() {
    super.initState();
    // Check if authentication has already been completed
    final isGloballyAuthenticated = ref.read(authenticationStateProvider);

    if (isGloballyAuthenticated) {
      setState(() {
        _isLoading = false;
        _isAuthenticated = true;
        _authenticationCompleted = true;
      });
    } else {
      _initializeAuthentication();
    }
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
          // Set state to show auth screen instead of navigating
          if (mounted && !_authenticationCompleted) {
            setState(() {
              _isLoading = false;
              _needsAuthentication = true;
            });
          }
          break;
        case AuthenticationResult.failedPin:
          // Set state to show auth screen instead of navigating
          if (mounted && !_authenticationCompleted) {
            setState(() {
              _isLoading = false;
              _needsAuthentication = true;
            });
          }
          break;
      }
    } catch (e) {
      if (mounted && !_authenticationCompleted) {
        setState(() {
          _isLoading = false;
          _needsAuthentication = true;
        });
      }
    }
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
      // Set global authentication state
      ref.read(authenticationStateProvider.notifier).state = true;
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
      // Watch folder provider to ensure folders are loaded before showing child
      return _FolderAwareWrapper(child: widget.child);
    }

    // Show authentication screen if PIN/biometric is needed
    if (_needsAuthentication) {
      return AuthScreen(
        onAuthenticationSuccess: () {
          debugPrint(
              'SecurityWrapperScreen: Auth completed callback triggered');
          _onAuthenticationSuccess();
        },
      );
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
        child: Container(
          // Add horizontal padding to increase width by 20% (reduce content area by 20%)
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.1,
          ),
          child: Column(
            children: [
              // Top spacer to position content in upper-middle area
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),

              // App Logo/Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
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

              // Bottom spacer to keep content in upper portion
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderAwareWrapper extends ConsumerWidget {
  final Widget child;

  const _FolderAwareWrapper({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderNotifier = ref.read(folderProvider.notifier);

    // Show loading screen until folder provider has been initialized
    // The folder provider loads folders in its constructor, but we need to wait
    // for the initial load to complete
    return FutureBuilder<void>(
      future: _ensureFoldersLoaded(folderNotifier),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: _buildFoldersLoadingScreen(context),
          );
        }

        // Once folders are loaded (or loading is complete), show the child
        return child;
      },
    );
  }

  Future<void> _ensureFoldersLoaded(FolderNotifier folderNotifier) async {
    // Wait for folders to be loaded
    await folderNotifier.loadFolders();
    // Add a small delay to ensure state is fully propagated
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Widget _buildFoldersLoadingScreen(BuildContext context) {
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
        child: Container(
          // Add horizontal padding to increase width by 20% (reduce content area by 20%)
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.1,
          ),
          child: Column(
            children: [
              // Top spacer to position content in upper-middle area
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),

              // App Logo/Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
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
                    'Loading Your Folders...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),

              // Bottom spacer to keep content in upper portion
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
