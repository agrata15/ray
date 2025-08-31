import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String otp;
  final String macAddress;

  const OtpVerificationScreen({super.key, required this.email,required this.password,required this.otp,required this.macAddress});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    final enteredOtp = _otpController.text.trim();

    if (enteredOtp.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 5-digit OTP")),
      );
      return;
    }

    try {
      final success = await OtpService.runOtpApisWithToken(
        enteredOtp,
        widget.macAddress,
        widget.email,
        widget.password,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP Verified & All APIs success!")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyApp()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("OTP verified but some secured APIs failed.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error verifying OTP: $e")),
      );
    }
  }

  Widget _buildStepper() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStepCircle(1),
            _buildStepLine(),
            _buildStepCircle(2),
            _buildStepLine(),
            _buildStepCircle(3),
            _buildStepLine(),
            _buildStepCircle(4, active: true),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            Expanded(child: Text('MAC Address Register', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
            Expanded(child: Text('Terms & Condit...', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
            Expanded(child: Text('Registration', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
            Expanded(child: Text('OTP Verification', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
          ],
        ),
      ],
    );
  }

  Widget _buildStepCircle(int step, {bool active = false}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6a1b9a) : Colors.white,
        border: Border.all(color: const Color(0xFF6a1b9a), width: 3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF6a1b9a),
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

                Text.rich(
                  TextSpan(
                    text: 'You will receive OTP on ',
                    children: [
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Type your OTP here *",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _isButtonEnabled = value.trim().length == 5;
                    });
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("OTP Resent")),
                        );
                      },
                      child: const Text("Resend OTP"),
                    ),
                    ElevatedButton(
                      onPressed: _isButtonEnabled ? _verifyOtp : null,
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Navigate to sign in page
                    },
                    child: const Text("Sign in to existing account"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
