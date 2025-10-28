import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/security_service.dart';

class ChangePinDialog extends StatefulWidget {
  const ChangePinDialog({super.key});

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final SecurityService _securityService = SecurityService();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _currentPinFocusNode = FocusNode();
  final FocusNode _newPinFocusNode = FocusNode();
  final FocusNode _confirmPinFocusNode = FocusNode();

  bool _isLoading = false;
  String _errorMessage = '';
  int _currentStep = 0; // 0: current PIN, 1: new PIN, 2: confirm PIN

  @override
  void initState() {
    super.initState();
    // Auto-focus the current PIN field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentPinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _currentPinFocusNode.dispose();
    _newPinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyCurrentPin() async {
    if (_currentPinController.text.length != 6) {
      setState(() {
        _errorMessage = 'PIN must be 6 digits';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final isValid =
          await _securityService.validatePin(_currentPinController.text);
      if (isValid) {
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
        // Auto-focus new PIN field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _newPinFocusNode.requestFocus();
        });
      } else {
        setState(() {
          _errorMessage = 'Current PIN is incorrect';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying PIN';
        _isLoading = false;
      });
    }
  }

  Future<void> _setNewPin() async {
    if (_newPinController.text.length != 6) {
      setState(() {
        _errorMessage = 'New PIN must be 6 digits';
      });
      return;
    }

    setState(() {
      _currentStep = 2;
      _errorMessage = '';
    });
    // Auto-focus confirm PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confirmPinFocusNode.requestFocus();
    });
  }

  Future<void> _confirmNewPin() async {
    if (_confirmPinController.text != _newPinController.text) {
      setState(() {
        _errorMessage = 'PINs do not match';
      });
      return;
    }

    if (_confirmPinController.text.length != 6) {
      setState(() {
        _errorMessage = 'PIN must be 6 digits';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _securityService.setupPin(_newPinController.text);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to change PIN';
        _isLoading = false;
      });
    }
  }

  Widget _buildCurrentPinStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Enter Current PIN',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _currentPinController,
          focusNode: _currentPinFocusNode,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '••••••',
            counterText: '',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
          onSubmitted: (_) => _verifyCurrentPin(),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyCurrentPin,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewPinStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Enter New PIN',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'PIN must be 6 digits',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _newPinController,
          focusNode: _newPinFocusNode,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '••••••',
            counterText: '',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
          onSubmitted: (_) => _setNewPin(),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 0;
                  _errorMessage = '';
                  _newPinController.clear();
                });
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _setNewPin,
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmPinStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Confirm New PIN',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Re-enter your new PIN',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPinController,
          focusNode: _confirmPinFocusNode,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '••••••',
            counterText: '',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
          onSubmitted: (_) => _confirmNewPin(),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                  _errorMessage = '';
                  _confirmPinController.clear();
                });
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmNewPin,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change PIN'),
            ),
          ],
        ),
      ],
    );
  }

  void _showChangePinHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help - Change PIN'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change PIN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('• PIN must be exactly 6 digits'),
              SizedBox(height: 8),
              Text('• You need to verify your current PIN first'),
              SizedBox(height: 8),
              Text('• Enter your new 6-digit PIN'),
              SizedBox(height: 8),
              Text('• Confirm your new PIN to complete the change'),
              SizedBox(height: 8),
              Text('• Your PIN secures access to all your records'),
              SizedBox(height: 8),
              Text('• Choose a PIN that is easy to remember but secure'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Change PIN')),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showChangePinHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _currentStep == 0
            ? _buildCurrentPinStep()
            : _currentStep == 1
                ? _buildNewPinStep()
                : _buildConfirmPinStep(),
      ),
    );
  }
}
