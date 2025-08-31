import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'SignUpScreen.dart';
import 'password_screen.dart';
import 'login_api.dart';
import 'home_screen.dart';
import 'appliances_screen.dart';
import 'cluster_screen.dart';
import 'dashboard_screen.dart';
import 'audit_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ray Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  bool _showError = false;
  String _apiMessage = '';
  Color _messageColor = Colors.red;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _callLoginApis(String email) async {
    const dummyUserId = '90d4aa1b-ac17-4d19-84e9-6ab48f3ca9de';
    setState(() {
      _isLoading = true;
      _apiMessage = '';
      _showError = false;
    });

    try {
      final userExists = await MainApiService.checkIfUserExists(email);
      final body = userExists.body.trim().toLowerCase();

      if (userExists.statusCode == 200 && body.contains("true")) {
        final lockDuration = await MainApiService.getLockDuration(dummyUserId);
        final maxFailedAttempts = await MainApiService.getMaxFailedAttempts(dummyUserId);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("email", email);



        Future.delayed(const Duration(seconds: 1), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PasswordScreen(email: email)),
          );
        });
      } else {
        setState(() {
          _showError = true;
          _apiMessage = '❌ User does not exist. Please create an account.';
          _messageColor = const Color(0xFFFF5252);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _apiMessage = '❌ Error calling APIs: $e';
        _messageColor = const Color(0xFFFF5252);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D0D), // Deep black
              Color(0xFF1A0033), // Dark purple
              Color(0xFF2D1B69), // Medium purple
              Color(0xFF6A1B9A), // Bright purple
              Color(0xFF1A0033), // Dark purple
              Color(0xFF000000), // Pure black
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildFloatingParticles(),
            Center(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        elevation: 20,
                        shadowColor: const Color(0xFF6A1B9A).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: const Color(0xFF6A1B9A).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        color: Colors.black.withOpacity(0.7),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.black.withOpacity(0.8),
                                const Color(0xFF1A0033).withOpacity(0.9),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // RAY Logo with enhanced styling
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.1),
                                      const Color(0xFF6A1B9A).withOpacity(0.2),
                                      Colors.black.withOpacity(0.3),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6A1B9A).withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFF9C27B0).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/download.png',
                                  width: 180,
                                  height: 60,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback if image fails to load
                                    return ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [
                                          Color(0xFFE1BEE7),
                                          Color(0xFFBA68C8),
                                          Color(0xFF9C27B0),
                                        ],
                                      ).createShader(bounds),
                                      child: const Text(
                                        'RAY',
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 4,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to your account',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6A1B9A).withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _emailController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Email Address',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: const Color(0xFF9C27B0).withOpacity(0.8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: _showError
                                            ? const Color(0xFFFF5252)
                                            : const Color(0xFF6A1B9A).withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF9C27B0),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() => _showError = value.trim().isEmpty);
                                  },
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                              if (_apiMessage.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _messageColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _messageColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _apiMessage,
                                    style: TextStyle(
                                      color: _messageColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 24),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6A1B9A),
                                      Color(0xFF9C27B0),
                                      Color(0xFFBA68C8),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6A1B9A).withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () async {
                                    final email = _emailController.text.trim();
                                    if (email.isEmpty) {
                                      setState(() => _showError = true);
                                    } else {
                                      await _callLoginApis(email);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Text(
                                    'Continue',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Secure • Fast • Reliable',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: BackgroundPainter(_fadeController.value),
          ),
        );
      },
    );
  }

  Widget _buildFloatingParticles() {
    return Stack(
      children: [
        _buildFloatingIcon('📡', 40, 30, 3000, 0.15),
        _buildFloatingIcon('📱', 60, -20, 4000, 0.12),
        _buildFloatingIcon('💡', -40, 100, 3500, 0.18),
        _buildFloatingIcon('🔗', -80, -60, 2800, 0.14),
        _buildFloatingIcon('⚙️', 0, -80, 3200, 0.16),
        _buildFloatingIcon('🌐', -100, 20, 4500, 0.13),
        _buildFloatingIcon('🔒', 100, 80, 2500, 0.17),
      ],
    );
  }

  Widget _buildFloatingIcon(String icon, double dx, double dy, int duration, double opacity) {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            dx * (1 + 0.5 * _fadeController.value),
            dy * (1 + 0.3 * _fadeController.value),
          ),
          child: Center(
            child: Opacity(
              opacity: opacity * _fadeController.value,
              child: Text(
                icon,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double animationValue;

  BackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Create subtle moving circles
    for (int i = 0; i < 5; i++) {
      paint.color = const Color(0xFF6A1B9A).withOpacity(0.1 * animationValue);
      final center = Offset(
        size.width * (0.2 + 0.6 * i / 5) + 50 * animationValue,
        size.height * (0.3 + 0.4 * i / 5) + 30 * animationValue,
      );
      canvas.drawCircle(center, 100 + 50 * i * animationValue, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}