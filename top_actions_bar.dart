// enhanced_top_actions_bar.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cluster_api.dart'; // Your existing API service
import 'home_screen.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color darkPurple = Color(0xFF6B46C1);
  static const Color lightPurple = Color(0xFFA855F7);
  static const Color accentPurple = Color(0xFF9333EA);

  static const Color primaryBlack = Color(0xFF0A0A0A);
  static const Color cardBlack = Color(0xFF1A1A1A);
  static const Color surfaceBlack = Color(0xFF2D2D2D);
  static const Color borderGray = Color(0xFF3A3A3A);

  static const Color neonCyan = Color(0xFF00F5FF);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonOrange = Color(0xFFFF6B35);
  static const Color neonYellow = Color(0xFFFFED4E);

  static const Color gradientStart = Color(0xFF1A0033);
  static const Color gradientEnd = Color(0xFF000000);
}

class TopActionsBar extends StatefulWidget {
  final VoidCallback onSettingsTap;
  final String? selectedClusterId;

  const TopActionsBar({
    Key? key,
    required this.onSettingsTap,
    this.selectedClusterId,
  }) : super(key: key);

  @override
  State<TopActionsBar> createState() => _EnhancedTopActionsBarState();
}

class _EnhancedTopActionsBarState extends State<TopActionsBar>
    with TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _popupController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Cluster Data
  List<Map<String, dynamic>> clusters = [];
  Map<String, List<Map<String, dynamic>>> clusterChildrenMap = {};
  String token = '';
  String selectedClusterName = '';
  String selectedClusterId = '';
  bool isLoading = true;
  bool showClusterPopup = false;
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTokenAndClusters();

    // Set initial cluster ID if provided
    if (widget.selectedClusterId != null) {
      selectedClusterId = widget.selectedClusterId!;
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _popupController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _popupController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _popupController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        logs.insert(0, "[${DateTime.now().toIso8601String().substring(11, 19)}] $message");
      });
    }
  }

  Future<void> _loadTokenAndClusters() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token') ?? '';

    // Load saved cluster info
    selectedClusterName = prefs.getString('selected_cluster_name') ?? '';
    if (widget.selectedClusterId == null) {
      selectedClusterId = prefs.getString('selected_cluster_id') ?? '';
    }

    if (token.isNotEmpty) {
      _addLog("✅ Token found.Fetching cluster list...");
      await _fetchClusters();
    } else {
      _addLog("❌ Token not found in SharedPreferences");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchClusters() async {
    try {
      final response = await MainApiService.getClusterView(token);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'];

          if (mounted) {
            if (data is List) {
              setState(() {
                clusters = List<Map<String, dynamic>>.from(data);
                isLoading = false;
              });
              _addLog('✅ Loaded ${clusters.length} clusters');

              // Auto-select current cluster name if we have ID but no name
              if (selectedClusterId.isNotEmpty && selectedClusterName.isEmpty) {
                final currentCluster = clusters.firstWhere(
                      (c) => c['id']?.toString() == selectedClusterId,
                  orElse: () => {},
                );
                if (currentCluster.isNotEmpty) {
                  setState(() {
                    selectedClusterName = currentCluster['name']?.toString() ?? '';
                  });
                }
              }

            } else if (data is Map) {
              setState(() {
                clusters = [Map<String, dynamic>.from(data)];
                isLoading = false;
              });
              _addLog('✅ Loaded 1 cluster (single map)');
            }
          }
        }
      } else {
        _addLog('❌ Failed to fetch clusters. Status: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ Error loading clusters: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadClusterChildren(String clusterId, String clusterName) async {
    if (clusterChildrenMap.containsKey(clusterId)) return;

    try {
      final childRes = await MainApiService.getClusterChildren(clusterId, token);
      if (childRes.statusCode == 200) {
        final childrenDecoded = jsonDecode(childRes.body);
        if (childrenDecoded is List) {
          setState(() {
            clusterChildrenMap[clusterId] = List<Map<String, dynamic>>.from(childrenDecoded);
          });
          _addLog('📥 Fetched children for $clusterName');
        }
      }
    } catch (e) {
      _addLog('❌ Error loading children for $clusterName: $e');
    }
  }

  void _showClusterPopup() {
    setState(() {
      showClusterPopup = true;
    });
    _popupController.forward();
  }

  void _hideClusterPopup() {
    _popupController.reverse().then((_) {
      if (mounted) {
        setState(() {
          showClusterPopup = false;
        });
      }
    });
  }

  Future<void> _switchCluster(String clusterId, String clusterName) async {
    try {
      _addLog('🔄 Switching to cluster: $clusterName ($clusterId)');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Switching to $clusterName...'),
              ],
            ),
            backgroundColor: Color(0xFF8E44AD),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Call change cluster API
      await MainApiService.changeCluster(clusterId);
      _addLog('✅ Cluster switched successfully');

      // Get updated token
      final prefs = await SharedPreferences.getInstance();
      String newToken = prefs.getString('auth_token') ?? '';

      if (newToken.isNotEmpty) {
        _addLog('✅ New token retrieved');

        // Save cluster context
        await prefs.setString('selected_cluster_id', clusterId);
        await prefs.setString('selected_cluster_name', clusterName);
        await prefs.setString('cluster_switched', 'true');

        // Update local state
        if (mounted) {
          setState(() {
            token = newToken;
            selectedClusterName = clusterName;
            selectedClusterId = clusterId;
          });
        }

        // Hide popup
        if (mounted) {
          _hideClusterPopup();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        // Navigate to HomeScreen after delay
        await Future.delayed(Duration(milliseconds: 200));

        if (mounted) {
          _addLog('🏠 Navigating to HomeScreen with cluster: $clusterName');

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                key: ValueKey('home_${clusterId}_${DateTime.now().millisecondsSinceEpoch}'),
                selectedClusterId: clusterId,
              ),
            ),
                (route) => false,
          );

          _addLog('✅ Navigation to HomeScreen completed');
        }
      } else {
        throw Exception('Failed to get new token after cluster switch');
      }

    } catch (e) {
      _addLog('❌ Error switching cluster: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Failed to switch to $clusterName: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                AppColors.gradientStart.withOpacity(0.9),
                AppColors.primaryBlack.withOpacity(0.95),
                AppColors.cardBlack.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Current cluster info
              if (selectedClusterName.isNotEmpty) ...[
                _buildCurrentClusterInfo(),
                const SizedBox(height: 16),
              ],

              // Action buttons row
              Row(
                children: [
                  // Clusters button
                  Expanded(
                    flex: 2,
                    child: _buildEnhancedActionButton(
                      title: 'Clusters',
                      subtitle: '${clusters.length} available',
                      icon: Icons.account_tree_rounded,
                      primaryColor: AppColors.primaryPurple,
                      onTap: _showClusterPopup,
                      isLoading: isLoading,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Settings button
                  Expanded(
                    child: _buildEnhancedActionButton(
                      title: 'Settings',
                      subtitle: 'Configure',
                      icon: Icons.settings_rounded,
                      primaryColor: AppColors.neonCyan,
                      onTap: widget.onSettingsTap,
                      isCompact: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Cluster popup overlay
        if (showClusterPopup) _buildClusterPopupCard(),
      ],
    );
  }

  Widget _buildCurrentClusterInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surfaceBlack,
        border: Border.all(
          color: AppColors.neonGreen.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonGreen.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonGreen.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          // Cluster info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Cluster',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: _showClusterPopup,
                  child: Text(
                    selectedClusterName,
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.cyan,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Quick switch button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showClusterPopup,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.neonGreen.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.neonGreen,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required VoidCallback onTap,
    bool isCompact = false,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.8),
            primaryColor.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: isCompact ? _buildCompactButton(
              title: title,
              icon: icon,
              isLoading: isLoading,
            ) : _buildFullButton(
              title: title,
              subtitle: subtitle,
              icon: icon,
              primaryColor: primaryColor,
              isLoading: isLoading,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required bool isLoading,
  }) {
    return Row(
      children: [
        // Icon container with shimmer effect
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Stack(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              if (isLoading)
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment(_shimmerAnimation.value - 1, 0),
                              end: Alignment(_shimmerAnimation.value, 0),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                isLoading ? 'Loading...' : subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Arrow indicator
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.8),
            size: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactButton({
    required String title,
    required IconData icon,
    required bool isLoading,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildClusterPopupCard() {
    final filteredClusters = clusters.where((c) => c['id'] != 'fallback').toList();

    return AnimatedBuilder(
      animation: _popupController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.85 * _opacityAnimation.value),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.92,
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0A0A0A),
                        Color(0xFF1A0A2E),
                        Color(0xFF2D1B47),
                        Color(0xFF3D2766),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFF8E44AD).withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8E44AD).withOpacity(0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6A1B9A),
                              Color(0xFF8E24AA),
                              Color(0xFF44124E),
                              Color(0xFF7B1FA2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(26),
                            topRight: Radius.circular(26),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.account_tree_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cluster Hierarchy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${filteredClusters.length} clusters available',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                onPressed: _hideClusterPopup,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Body
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF0A0A0A),
                                Color(0xFF1A0A2E),
                                Color(0xFF2D1B47),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(26),
                              bottomRight: Radius.circular(26),
                            ),
                          ),
                          child: filteredClusters.isEmpty
                              ? Center(
                            child: isLoading
                                ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Loading clusters...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                                : const Text(
                              'No clusters found',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                              : Scrollbar(
                            thumbVisibility: true,
                            thickness: 6,
                            radius: const Radius.circular(10),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(
                                  filteredClusters.length,
                                      (index) => _buildPopupClusterTile(
                                    filteredClusters[index],
                                    level: 0,
                                    uniqueKey: 'popup_$index',
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupClusterTile(Map<String, dynamic> cluster, {int level = 0, required String uniqueKey}) {
    final clusterId = cluster['id']?.toString() ?? '';
    final clusterName = cluster['name']?.toString() ?? 'Unnamed';
    final children = clusterChildrenMap[clusterId] ?? [];
    final tileKey = '${uniqueKey}_${clusterId}_$level';
    final isCurrentCluster = clusterId == selectedClusterId;

    return Container(
      key: ValueKey(tileKey),
      margin: EdgeInsets.only(
        left: level * 20.0,
        right: 8.0,
        top: 6.0,
        bottom: 6.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentCluster
              ? [const Color(0xFF4A148C), const Color(0xFF6A1B9A)] // Highlight current cluster
              : level == 0
              ? [const Color(0xFF2D1B47), const Color(0xFF3D2766)]
              : [const Color(0xFF1A0A2E), const Color(0xFF2D1B47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentCluster
              ? const Color(0xFF8E44AD).withOpacity(0.8)
              : const Color(0xFF8E44AD).withOpacity(0.3),
          width: isCurrentCluster ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentCluster
                ? const Color(0xFF8E44AD).withOpacity(0.4)
                : Colors.black.withOpacity(0.3),
            blurRadius: isCurrentCluster ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        key: ValueKey('expansion_$tileKey'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: GestureDetector(
          onTap: () => _switchCluster(clusterId, clusterName),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  clusterName,
                  style: TextStyle(
                    fontSize: 16 - (level * 1.0),
                    fontWeight: isCurrentCluster ? FontWeight.w900 : (level == 0 ? FontWeight.bold : FontWeight.w600),
                    color: isCurrentCluster ? Colors.white : Colors.cyan,
                    decoration: TextDecoration.underline,
                    decorationColor: isCurrentCluster ? Colors.white : Colors.cyan,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrentCluster) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        subtitle: Text(
          'ID: $clusterId',
          style: TextStyle(
            fontSize: 12 - (level * 0.5),
            color: Colors.white.withOpacity(0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCurrentCluster
                  ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                  : level == 0
                  ? [const Color(0xFF8E44AD), const Color(0xFFAB47BC)]
                  : [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isCurrentCluster
                ? Icons.check_circle_rounded
                : (level == 0 ? Icons.folder_rounded : Icons.folder_open_rounded),
            size: 20 - (level * 2.0),
            color: Colors.white,
          ),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        onExpansionChanged: (expanded) async {
          if (expanded && mounted) {
            await _loadClusterChildren(clusterId, clusterName);
          }
        },
        children: children.isEmpty
            ? [
          Padding(
            padding: EdgeInsets.only(
              left: (level + 1) * 20.0 + 20.0,
              right: 12,
              top: 4,
              bottom: 4,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No child clusters available in this node',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ]
            : List.generate(
          children.length,
              (index) => _buildPopupClusterTile(
            children[index],
            level: level + 1,
            uniqueKey: '${uniqueKey}_child_$index',
          ),
        ),
      ),
    );
  }
}