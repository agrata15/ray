import 'package:flutter/material.dart';
import 'registration_screen.dart';
import 'config.dart';

class LicenseAgreementScreen extends StatefulWidget {
  final String macAddress;

  const LicenseAgreementScreen({super.key, required this.macAddress});

  @override
  State<LicenseAgreementScreen> createState() => _LicenseAgreementScreenState();
}

class _LicenseAgreementScreenState extends State<LicenseAgreementScreen> {
  bool isChecked = false;
  int currentStep = 1; // Step 1 = License Agreement (0-indexed
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('License Agreement'),
        backgroundColor: const Color(0xFF6a1b9a),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Sign up to use our service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Interactive Stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStep("MAC", 0),
                _buildStepLine(),
                _buildStep("License", 1),
                _buildStepLine(),
                _buildStep("Register", 2),
                _buildStepLine(),
                _buildStep("OTP", 3),
              ],
            ),
            const SizedBox(height: 20),

            // License Text
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  '''READ THE TERMS AND CONDITIONS OF THIS LICENSE AGREEMENT CAREFULLY BEFORE OPENING THE PACKAGE CONTAINING THE COMPUTER SOFTWARE AND THE ACCOMPANYING USER DOCUMENTATION (COLLECTIVELY, THE "SOFTWARE") OR BEFORE INSTALLING / START USING THE SOFTWARE. THE SOFTWARE IS COPYRIGHTED AND LICENSED (NOT SOLD). BY OPENING THE PACKAGE CONTAINING THE SOFTWARE, YOU ARE ACCEPTING AND AGREEING TO THE TERMS OF THIS LICENSE AGREEMENT. IF YOU ARE NOT WILLING TO BE BOUND BY THE TERMS OF THIS LICENSE AGREEMENT, YOU SHOULD RETURN THE PACKAGE UNOPENED WITHIN SEVEN (7) DAYS OF YOUR INVOICE DATE, AND YOU WILL RECEIVE A CREDIT OR A REFUND. THIS LICENSE AGREEMENT REPRESENTS THE ENTIRE AGREEMENT CONCERNING THE SOFTWARE BETWEEN YOU AND RAY PTE. LTD. AND IT SUPERCEDES ANY PRIOR PROPOSAL, REPRESENTATION, OR UNDERSTANDING BETWEEN THE PARTIES.

LICENSE GRANT. This is a legal agreement between You/ End User and Ray Pte. Ltd. ("Ray"). Ray grants to You, and You accept, a non-transferable, nonexclusive license to use one copy of the Software in machine readable, object code form only, and the accompanying user documentation ("User Documentation") for the Software, only as authorized in this Agreement. For purposes of this Agreement, the "Software" includes not only the computer program contained in this package and updates thereto, but also all applications or modifications written by Ray for You utilizing the Application Programming contained in the Software ("Ray Tools"), if any. You have a non-transferable, royalty free license to use such applications or modifications under the terms of this License.

COPYRIGHT. The Software contains trade secret and proprietary information owned by Ray or its third-party licensors and is protected by copyright laws and international trade provisions. You must treat the Software like any other copyrighted material and, you shall not disclose, copy, transfer or transmit the Software or the User Documentation, electronically or otherwise, for any purpose. All permitted copies of the Software and the User Documentation must include Ray’s copyright and other proprietary notices.

OTHER RESTRICTIONS. You agree that the Software and the User Documentation are proprietary products and that all right, title and interest in and to the Software and User Documentation, including all associated intellectual property rights, are and shall at all times remain with Ray and its third-party licensors. You shall not sublicense, assign, transfer, sell, rent, lend or lease the Software or the User Documentation, or any portions thereof, and any attempt to do so is null and void. You shall not reverse engineer, disassemble, decompile or make any attempt to ascertain, derive or obtain the source code for the Software. The Software shall be used at a single location and for that number of users as has been agreed.

LIMITED WARRANTY. For a period of thirty (30) days from the date of Your receipt of the Software (the "Warranty Period"), Ray warrants that the media on which the Software is distributed will be free from defects in materials and workmanship and that the Software will perform substantially in accordance with the functional specifications contained in the User Documentation. Any written or oral information or representations provided by Ray agents, employees, resellers, consultants or service providers with respect to the use or operation of the Software will in no way increase the scope of this warranty.

CUSTOMER REMEDIES. If during the Warranty Period the Software fails to comply with the warranty set forth above, Ray's entire liability and Your exclusive remedy will be either a) repair or replacement of the Software, or if in Ray's opinion such repair or replacement is not possible, then b) a full refund of the price paid for the Software. The foregoing remedies apply only if You return all copies of the Software to Ray within 30 days of receipt by You. This limited warranty is void if failure of the Software has resulted from accident, abuse, misuse or negligence of any kind in the use, handling or operation of the Software, including any use not consistent with the User Documentation or Ray training.''',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    setState(() {
                      isChecked = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'I agree to the terms and conditions mentioned above.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Next Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isChecked
                    ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegistrationScreen(macAddress: widget.macAddress),


                    ),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6a1b9a),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade400,
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
          ],
        ),
      ),
    );
  }

  // Step Circle Builder
  Widget _buildStep(String title, int index) {
    bool isCompleted = index < currentStep;
    bool isActive = index == currentStep;

    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isCompleted
              ? Colors.green
              : isActive
              ? Colors.blue
              : Colors.grey[300],
          child: isCompleted
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : Text(
            '${index + 1}',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // Line Between Steps
  Widget _buildStepLine() {
    return Container(
      width: 30,
      height: 2,
      color: Colors.grey,
    );
  }
}
