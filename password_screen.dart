import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cluster_screen.dart';
import 'dashboard_screen.dart';
import 'config.dart';
import 'home_screen.dart';

class PasswordScreen extends StatefulWidget {
  final String email;

  const PasswordScreen({super.key, required this.email});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> with TickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isChecked = false;
  bool _isLoading = false;
  String _errorMessage = '';

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shakeController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _shakeAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loginUser(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final url = Uri.parse('${Config.baseUrl}/api/authenticate');
    final body = jsonEncode({
      "username": email,
      "password": password,
      "rememberMe": true,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print("🔐 Status Code: ${response.statusCode}");
      print("🔐 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final token = json['id_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("auth_token", token.toString());

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (response.statusCode == 401) {
        _triggerShake();
        setState(() {
          _errorMessage = "🔒 Invalid email or password.";
        });
      } else if (response.statusCode == 400) {
        _triggerShake();
        setState(() {
          _errorMessage = "⚠️ Validation failed. Please check input.";
        });
      } else if (response.statusCode == 500) {
        _triggerShake();
        setState(() {
          _errorMessage = "🔧 Server error (500). Contact admin or try later.";
        });
      } else {
        _triggerShake();
        setState(() {
          _errorMessage = "❌ Unexpected error: ${response.statusCode}";
        });
      }
    } catch (e) {
      _triggerShake();
      setState(() {
        _errorMessage = "🌐 Network error: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onNextPressed() {
    final password = _passwordController.text.trim();

    if (!_isChecked) {
      _triggerShake();
      setState(() => _errorMessage = "🤖 Please verify you're not a robot.");
      return;
    }

    if (password.isEmpty) {
      _triggerShake();
      setState(() => _errorMessage = "🔐 Password cannot be empty.");
      return;
    }

    _loginUser(widget.email, password);
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
            _buildBackButton(),
            Center(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value * 10, 0),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            constraints: const BoxConstraints(maxWidth: 400),
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
                                    // Animated Avatar
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF6A1B9A),
                                                  Color(0xFF9C27B0),
                                                  Color(0xFFE1BEE7),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF6A1B9A).withOpacity(0.4),
                                                  blurRadius: 20,
                                                  spreadRadius: 5,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.lock_outline,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    // Welcome back text
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [
                                          Color(0xFFE1BEE7),
                                          Color(0xFFBA68C8),
                                          Color(0xFF9C27B0),
                                        ],
                                      ).createShader(bounds),
                                      child: const Text(
                                        'Welcome',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Email display
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6A1B9A).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF6A1B9A).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.email_outlined,
                                            size: 16,
                                            color: const Color(0xFF9C27B0),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              widget.email,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.9),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    // Password field
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
                                        controller: _passwordController,
                                        obscureText: !_passwordVisible,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: "Enter your password",
                                          labelStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.lock_outline,
                                            color: const Color(0xFF9C27B0).withOpacity(0.8),
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                              color: const Color(0xFF9C27B0).withOpacity(0.8),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _passwordVisible = !_passwordVisible;
                                              });
                                            },
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
                                              color: const Color(0xFF6A1B9A).withOpacity(0.5),
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
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // CAPTCHA checkbox
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF6A1B9A).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Transform.scale(
                                            scale: 1.2,
                                            child: Checkbox(
                                              value: _isChecked,
                                              onChanged: (value) {
                                                setState(() => _isChecked = value!);
                                              },
                                              activeColor: const Color(0xFF6A1B9A),
                                              checkColor: Colors.white,
                                              side: BorderSide(
                                                color: const Color(0xFF9C27B0).withOpacity(0.6),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            "🤖 I'm not a robot",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Error message
                                    if (_errorMessage.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF5252).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFFF5252).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              color: Color(0xFFFF5252),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _errorMessage,
                                                style: const TextStyle(
                                                  color: Color(0xFFFF5252),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 24),

                                    // Login button
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
                                        onPressed: _isLoading ? null : _onNextPressed,
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
                                            : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Sign In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Security notice
                                    Text(
                                      '🔐 Your data is encrypted and secure',
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
                        );
                      },
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

  Widget _buildBackButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.3),
            border: Border.all(
              color: const Color(0xFF6A1B9A).withOpacity(0.3),
            ),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
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
        _buildFloatingIcon('🔐', 40, 30, 3000, 0.15),
        _buildFloatingIcon('🛡️', 60, -20, 4000, 0.12),
        _buildFloatingIcon('🔑', -40, 100, 3500, 0.18),
        _buildFloatingIcon('⚡', -80, -60, 2800, 0.14),
        _buildFloatingIcon('🚀', 0, -80, 3200, 0.16),
        _buildFloatingIcon('🌟', -100, 20, 4500, 0.13),
        _buildFloatingIcon('💫', 100, 80, 2500, 0.17),
      ],
    );
  }

  Widget _buildFloatingIcon(String icon, double dx, double dy, int duration, double opacity) {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            dx * (1 + 0.5 * math.sin(_fadeController.value * math.pi * 2)),
            dy * (1 + 0.3 * math.cos(_fadeController.value * math.pi * 2)),
          ),
          child: Center(
            child: Opacity(
              opacity: opacity * _fadeController.value,
              child: Text(
                icon,
                style: const TextStyle(fontSize: 35),
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
    for (int i = 0; i < 6; i++) {
      paint.color = const Color(0xFF6A1B9A).withOpacity(0.08 * animationValue);
      final center = Offset(
        size.width * (0.1 + 0.8 * i / 6) + 30 * math.sin(animationValue * math.pi * 2 + i),
        size.height * (0.2 + 0.6 * i / 6) + 20 * math.cos(animationValue * math.pi * 2 + i),
      );
      canvas.drawCircle(center, 80 + 40 * i * animationValue, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}