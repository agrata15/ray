import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'otp_verification_screen.dart';
import 'registration_api.dart';

class RegistrationScreen extends StatefulWidget {
  final String macAddress;
  const RegistrationScreen({super.key, required this.macAddress});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _currentStep = 2;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  String _timezone = 'Asia/Kolkata';
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String _errorText = '';
  List<String> _passwordErrors = [];
  String? _selectedCountry = 'India';

  final List<String> _countries = [
    'India', 'United States', 'Germany', 'France', 'Japan', 'China'
  ]..sort();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordValidation);
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordValidation);
    _confirmPasswordController.removeListener(() {});
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordValidation() {
    String password = _passwordController.text;
    setState(() {
      _passwordErrors = [];
      if (password.length < 8) _passwordErrors.add('Min. 8 Character');
      if (!password.contains(RegExp(r'[A-Z]'))) _passwordErrors.add('Upper case');
      if (!password.contains(RegExp(r'[a-z]'))) _passwordErrors.add('Lower case');
      if (!password.contains(RegExp(r'[0-9]'))) _passwordErrors.add('Min. one number');
      if (!password.contains(RegExp(r'[!@#\\\$%^&*(),.?":{}|<>]'))) _passwordErrors.add('Special Character');
    });
  }

  void _validateAndProceed() async {
    setState(() {
      _errorText = '';
    });

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorText = 'Passwords do not match.';
      });
      return;
    }

    if (_passwordErrors.isNotEmpty) {
      return;
    }

    final response = await registerUser(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
    );

    if (response['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            otp: '',
            macAddress: widget.macAddress,
          ),
        ),
      );
    } else {
      setState(() {
        _errorText = response['message']?.toString() ?? 'Registration failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/download.png', width: 180, height: 60),
                const SizedBox(height: 20),
                const Text(
                  'Sign up to use our service',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _buildStepper(),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: _buildTextField('First Name *', _firstNameController)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField('Last Name *', _lastNameController)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField('Email Id *', _emailController),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildPasswordField('Password *', _passwordController, true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildPasswordField('Confirm Password *', _confirmPasswordController, false)),
                  ],
                ),
                const SizedBox(height: 10),
                if (_passwordController.text.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Password Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                      _buildValidationRow('Min. 8 Character', _passwordController.text.length >= 8),
                      _buildValidationRow('Upper case', RegExp(r'[A-Z]').hasMatch(_passwordController.text)),
                      _buildValidationRow('Lower case', RegExp(r'[a-z]').hasMatch(_passwordController.text)),
                      _buildValidationRow('Min. one number', RegExp(r'[0-9]').hasMatch(_passwordController.text)),
                      _buildValidationRow('Special Character', RegExp(r'[!@#\\\$%^&*(),.?":{}|<>]').hasMatch(_passwordController.text)),
                    ],
                  ),
                const SizedBox(height: 10),
                if (_confirmPasswordController.text.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        _confirmPasswordController.text == _passwordController.text ? Icons.check_circle : Icons.cancel,
                        color: _confirmPasswordController.text == _passwordController.text ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _confirmPasswordController.text == _passwordController.text ? 'Passwords match' : 'Passwords do not match',
                        style: TextStyle(
                          color: _confirmPasswordController.text == _passwordController.text ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                if (_errorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_errorText, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _timezone,
                  items: const [
                    DropdownMenuItem(value: 'Asia/Kolkata', child: Text('Asia/Kolkata')),
                    DropdownMenuItem(value: 'Asia/Dubai', child: Text('Asia/Dubai')),
                  ],
                  onChanged: (val) => setState(() => _timezone = val!),
                  decoration: const InputDecoration(labelText: 'Timezone *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  items: _countries.map((country) {
                    return DropdownMenuItem<String>(
                      value: country,
                      child: Text(country),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCountry = value!;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Country *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                _buildTextField('Mobile Number *', _mobileController),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                    ElevatedButton(
                      onPressed: _validateAndProceed,
                      child: const Text('Next'),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStepCircle(1, _currentStep == 0),
            _buildStepLine(),
            _buildStepCircle(2, _currentStep == 1),
            _buildStepLine(),
            _buildStepCircle(3, _currentStep == 2),
            _buildStepLine(),
            _buildStepCircle(4, _currentStep == 3),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            Expanded(child: Text('MAC Address', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
            Expanded(child: Text('License', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
            Expanded(child: Text('Registration', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
            Expanded(child: Text('OTP Verify', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
          ],
        ),
      ],
    );
  }

  Widget _buildStepCircle(int step, bool isActive) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6a1b9a) : Colors.white,
        border: Border.all(color: const Color(0xFF6a1b9a), width: 3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF6a1b9a),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 25,
      height: 3,
      color: const Color(0xFF6a1b9a),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool isMain) {
    return TextField(
      controller: controller,
      obscureText: isMain ? !_passwordVisible : !_confirmPasswordVisible,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            (isMain ? _passwordVisible : _confirmPasswordVisible)
                ? Icons.visibility
                : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              if (isMain) {
                _passwordVisible = !_passwordVisible;
              } else {
                _confirmPasswordVisible = !_confirmPasswordVisible;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildValidationRow(String text, bool isValid) {

    return Row(
      children: [
        Icon(isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? Colors.green : Colors.red, size: 18),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: isValid ? Colors.green : Colors.red)),
      ],
    );
  }
}
