import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _pinKey = 'user_pin_hash';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _securitySetupKey = 'security_setup_completed';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      print('SecurityService: canCheckBiometrics=$isAvailable');
      print('SecurityService: isDeviceSupported=$isDeviceSupported');
      print('SecurityService: availableBiometrics=$availableBiometrics');

      return isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
    } catch (e) {
      print('SecurityService: Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Authenticate with biometrics
  Future<AuthenticationResult> authenticateWithBiometricsDetailed() async {
    try {
      print('SecurityService: Starting biometric authentication...');

      // Check if biometrics are available
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool deviceSupported = await _localAuth.isDeviceSupported();

      print(
          'SecurityService: isAvailable=$isAvailable, deviceSupported=$deviceSupported');

      if (!isAvailable || !deviceSupported) {
        print('SecurityService: Biometrics not available or not supported');
        return AuthenticationResult.failedBiometric;
      }

      // Check for enrolled biometrics
      final availableBiometrics = await getAvailableBiometrics();
      print('SecurityService: availableBiometrics=$availableBiometrics');

      if (availableBiometrics.isEmpty) {
        print('SecurityService: No enrolled biometrics found');
        return AuthenticationResult.failedBiometric;
      }

      print('SecurityService: Attempting biometric authentication...');

      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your personal records',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      print('SecurityService: Authentication result: $isAuthenticated');

      if (isAuthenticated) {
        print('SecurityService: Authentication successful!');
        // Auto-enable biometric authentication if this is the first successful authentication
        final isEnabled = await isBiometricEnabled();
        if (!isEnabled) {
          await setBiometricEnabled(true);
        }
        return AuthenticationResult.success;
      } else {
        print('SecurityService: Authentication failed or cancelled');
        return AuthenticationResult.failedBiometric;
      }
    } catch (e) {
      print('SecurityService: Biometric authentication error: $e');
      // Biometric authentication error - return failure
      return AuthenticationResult.failedBiometric;
    }
  }

  // Authenticate with biometrics (legacy method)
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your personal records',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      // Auto-enable biometric authentication if this is the first successful authentication
      if (isAuthenticated) {
        final isEnabled = await isBiometricEnabled();
        if (!isEnabled) {
          await setBiometricEnabled(true);
        }
      }

      return isAuthenticated;
    } catch (e) {
      // Biometric authentication error - return false
      return false;
    }
  }

  // Hash PIN for secure storage
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Set up PIN
  Future<bool> setupPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashedPin = _hashPin(pin);
      await prefs.setString(_pinKey, hashedPin);
      await prefs.setBool(_securitySetupKey, true);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Validate PIN
  Future<bool> validatePin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_pinKey);
      if (storedHash == null) return false;

      final hashedPin = _hashPin(pin);
      return hashedPin == storedHash;
    } catch (e) {
      return false;
    }
  }

  // Check if security is set up
  Future<bool> isSecuritySetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_securitySetupKey) ?? false;
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  // Check if PIN exists
  Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) != null;
  }

  // Clear all security data (for reset purposes)
  Future<void> clearSecurityData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_securitySetupKey);
  }

  // Main authentication method
  Future<AuthenticationResult> authenticate() async {
    final isSetup = await isSecuritySetup();
    if (!isSetup) {
      return AuthenticationResult.needsSetup;
    }

    final biometricEnabled = await isBiometricEnabled();
    final biometricAvailable = await isBiometricAvailable();

    if (biometricEnabled && biometricAvailable) {
      try {
        final authenticated = await authenticateWithBiometrics();
        if (authenticated) {
          return AuthenticationResult.success;
        } else {
          return AuthenticationResult.failedBiometric;
        }
      } catch (e) {
        return AuthenticationResult.failedBiometric;
      }
    }

    return AuthenticationResult.needsPin;
  }
}

enum AuthenticationResult {
  success,
  needsSetup,
  needsPin,
  failedBiometric,
  failedPin,
}
