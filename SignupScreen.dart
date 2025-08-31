

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_services.dart';
import 'license_agreement_screen.dart';
import 'config.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _currentStep = 0;
  final TextEditingController _macController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  String _selectedMode = 'Bridge No Firewall';

  final List<String> _modes = [
    'Gateway',
    'Bridge + Firewall',
    'Bridge No Firewall',
    'Not Applicable',
    'Access',
    'Core',
  ];

  Future<void> fetchDeviceMacAndCheckInRayPool() async {
    final macAddress = _macController.text.trim();
    final serialCode = _serialController.text.trim();

    // final macPattern = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\$');
    final macPattern = RegExp(r'^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$');
    if (!macPattern.hasMatch(macAddress)) {
      _showErrorDialog("Invalid MAC address format. Please use format XX:XX:XX:XX:XX:XX");
      return;
    }

    if (macAddress.isEmpty) {
      _showErrorDialog("Please enter MAC address.");
      return;
    }

    if (serialCode.isEmpty) {
      _showErrorDialog("Please enter the last 6 letters of the serial number.");
      return;
    }

    final Map<String, dynamic>? macData = await ApiServices.checkMacInRayPool(macAddress);

    if (macData != null) {
      final securityCode = (macData['securityCode'] as String?) ?? serialCode;
      final verified = await ApiServices.verifyNode(
        macAddress: macAddress,
        securityCode: securityCode,
        nodeMode: 'CLIENT'

      );

      if (verified) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LicenseAgreementScreen(macAddress: _macController.text.trim()),
          ),
        );
      } else {
        _showErrorDialog("Device verification failed.");
      }
    } else {
      _showErrorDialog("MAC not found in Ray Pool.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildBackgroundIcons(width),
          Center(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/download.png',
                      width: 180,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign up to use our service',
                      style: TextStyle(fontSize: 16, color: Color(0xFF444444)),
                    ),
                    const SizedBox(height: 20),
                    _buildStepper(),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _macController,
                      decoration: const InputDecoration(
                        hintText: 'MAC Address *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serialController,
                      decoration: const InputDecoration(
                        hintText: 'Last 6 letters of serial number',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedMode,
                      items: _modes.map((mode) => DropdownMenuItem(value: mode, child: Text(mode))).toList(),
                      onChanged: (value) {
                        setState(() => _selectedMode = value!);
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: fetchDeviceMacAndCheckInRayPool,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6a1b9a),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign in to existing account',
                        style: TextStyle(
                          color: Color(0xFF6a1b9a),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundIcons(double width) {
    return Stack(
      children: [
        Positioned(top: 40, left: 30, child: Opacity(opacity: 0.18, child: Text('📡', style: TextStyle(fontSize: 40)))),
        Positioned(bottom: 120, left: 60, child: Opacity(opacity: 0.18, child: Text('📱', style: TextStyle(fontSize: 40)))),
        Positioned(top: 100, right: 40, child: Opacity(opacity: 0.18, child: Text('💡', style: TextStyle(fontSize: 40)))),
        Positioned(bottom: 80, right: 80, child: Opacity(opacity: 0.18, child: Text('🔗', style: TextStyle(fontSize: 40)))),
        Positioned(bottom: 30, left: width / 2 - 20, child: Opacity(opacity: 0.18, child: Text('⚙️', style: TextStyle(fontSize: 40)))),
      ],
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

  Widget _buildStepLine() => Container(width: 5, height: 3, color: const Color(0xFF6a1b9a));
}