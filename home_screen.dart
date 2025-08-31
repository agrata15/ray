import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'config.dart';
import 'token_api.dart' hide MainApiService;
import 'app_drawer.dart';
import 'navigation_helper.dart';
import 'cluster_api.dart';
import 'top_actions_bar.dart';

// Enhanced Color Palette
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

class HomeScreen extends StatefulWidget {
  final String? selectedClusterId;
  const HomeScreen({Key? key, this.selectedClusterId}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String? token;
  String? currentClusterId;
  String? currentClusterName;
  bool isDataLoaded = false;
  bool isLoading = true;
  String? errorMessage;
  List<String> deviceDisplayList = [];
  int realOnlineDevices = 0;
  int realOfflineDevices = 0;

  // Dashboard metrics
  int alertCount = 0;
  int expiringLicenses = 0;
  int accessPointCount = 0;
  int edgeGatewayCount = 0;

  List<Map<String, dynamic>> clusters = [];
  List<Map<String, dynamic>> onlineGateways = [];
  List<Map<String, dynamic>> offlineGateways = [];
  List<Map<String, dynamic>> onlineAccessPoints = [];
  List<Map<String, dynamic>> offlineAccessPoints = [];

  // Dynamic alerts variables
  List<Map<String, dynamic>> _allAlerts = [];
  bool _isLoadingAlerts = false;
  String? _alertsError;

  // Animation controllers
  late AnimationController _shuffleController;
  late AnimationController _pulseController;
  late AnimationController _backgroundController;

  List<AnimationController> _cardControllers = [];
  List<Animation<Offset>> _cardSlideAnimations = [];
  List<Animation<double>> _cardScaleAnimations = [];
  List<Animation<double>> _cardGlowAnimations = [];

  // Card positions for shuffling
  List<double> _cardPositions = [0, 0, 0, 0];
  bool _isShuffling = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    initializeClusterData();
  }

  void _initializeAnimations() {
    _shuffleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _pulseController.repeat(reverse: true);
    _backgroundController.repeat();

    // Initialize individual card animations
    for (int i = 0; i < 4; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + (i * 150)),
        vsync: this,
      );
      _cardControllers.add(controller);

      // Enhanced slide animations with bounce
      _cardSlideAnimations.add(
        Tween<Offset>(
          begin: const Offset(0, 2.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        )),
      );

      _cardScaleAnimations.add(
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        )),
      );

      // Glow animation for cards
      _cardGlowAnimations.add(
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        )),
      );
    }
  }

  void _startCardAnimations() {
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  void _shuffleCards() async {
    if (_isShuffling) return;

    if (mounted) {
      setState(() {
        _isShuffling = true;
      });
    }

    // Animate cards down first with rotation
    for (int i = 0; i < _cardControllers.length; i++) {
      _cardControllers[i].reverse();
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Shuffle the positions with more dramatic movement
    final random = math.Random();
    for (int i = 0; i < 4; i++) {
      _cardPositions[i] = (random.nextDouble() - 0.5) * 300;
    }

    // Animate cards back up with new positions
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted) {
          _cardControllers[i].forward();
        }
      });
    }

    // Reset positions after animation
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _cardPositions = [0, 0, 0, 0];
          _isShuffling = false;
        });
      }
    });
  }

  // ENHANCED: Vertical Device Table
  void showVerticalDevicesTable(String deviceType, List<Map<String, dynamic>> devices, Color primaryColor) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.95,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppColors.primaryBlack,
              border: Border.all(color: primaryColor.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Enhanced Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          deviceType.contains('Access') ? Icons.wifi_rounded : Icons.router_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              '${devices.length} devices found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                // Vertical Device List with Animations
                Expanded(
                  child: devices.isEmpty
                      ? _buildEmptyDevicesState(deviceType, primaryColor)
                      : _buildAnimatedVerticalDeviceList(devices, primaryColor),
                ),

                // Footer with statistics
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBlack,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    border: Border(top: BorderSide(color: primaryColor.withOpacity(0.4))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: primaryColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Total: ${devices.length} devices',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Cluster: ${currentClusterName ?? 'Unknown'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDevicesState(String deviceType, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBlack,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Icon(
                    deviceType.contains('Access') ? Icons.wifi_off_rounded : Icons.router_outlined,
                    size: 48,
                    color: primaryColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'No $deviceType Found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No devices available in this category',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  Widget _buildAnimatedVerticalDeviceList(List<Map<String, dynamic>> devices, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final isOnline = device['status']?.toString().toUpperCase() == 'ONLINE' ||
              device['nodeStatus']?.toString().toUpperCase() == 'ONLINE';

          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, animationValue, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - animationValue)),
                child: Opacity(
                  opacity: animationValue,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBlack,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOnline
                            ? AppColors.neonGreen.withOpacity(0.4)
                            : AppColors.neonOrange.withOpacity(0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: isOnline
                              ? AppColors.neonGreen.withOpacity(0.1)
                              : AppColors.neonOrange.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Device Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? AppColors.neonGreen.withOpacity(0.1)
                                      : AppColors.neonOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOnline
                                        ? AppColors.neonGreen.withOpacity(0.3)
                                        : AppColors.neonOrange.withOpacity(0.3),
                                  ),
                                ),
                                child: Icon(
                                  isOnline ? Icons.check_circle : Icons.error_outline,
                                  color: isOnline ? AppColors.neonGreen : AppColors.neonOrange,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device['name']?.toString() ??
                                          device['deviceName']?.toString() ??
                                          device['appliance_name']?.toString() ??
                                          'Unnamed Device',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      device['status']?.toString() ??
                                          device['nodeStatus']?.toString() ??
                                          'Unknown Status',
                                      style: TextStyle(
                                        color: isOnline ? AppColors.neonGreen : AppColors.neonOrange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Device Details - Only the specified fields
                          _buildDeviceDetailRow(
                            'Device Name',
                            device['name']?.toString() ??
                                device['deviceName']?.toString() ??
                                device['appliance_name']?.toString() ??
                                'Unnamed Device',
                            Icons.device_hub_rounded,
                            primaryColor,
                          ),
                          const SizedBox(height: 12),

                          _buildDeviceDetailRow(
                            'Status',
                            device['status']?.toString() ??
                                device['nodeStatus']?.toString() ??
                                'Unknown Status',
                            isOnline ? Icons.check_circle : Icons.error_outline,
                            isOnline ? AppColors.neonGreen : AppColors.neonOrange,
                          ),
                          const SizedBox(height: 12),

                          _buildDeviceDetailRow(
                            'Cluster Name',
                            currentClusterName ?? 'Unknown Cluster',
                            Icons.account_tree_rounded,
                            AppColors.primaryPurple,
                          ),
                          const SizedBox(height: 12),

                          _buildDeviceDetailRow(
                            'Cluster ID',
                            currentClusterId ?? 'Unknown ID',
                            Icons.tag_rounded,
                            AppColors.neonCyan,
                          ),
                          const SizedBox(height: 12),


                          _buildDeviceDetailRow(
                            'MAC Address',
                            (device['macAddress'] ?? device['mac_address'] ?? 'N/A').toString(),
                            Icons.router_rounded,
                            AppColors.neonYellow,
                          ),
                          const SizedBox(height: 12),

                          _buildDeviceDetailRow(
                            'Type',
                            (device['nodeMode'] ?? device['deviceType'] ?? device['hardware_name'] ?? 'N/A').toString(),
                            Icons.category_rounded,
                            AppColors.neonOrange,
                          ),

                          if (device['ipAddress'] != null || device['ip'] != null) ...[
                            const SizedBox(height: 12),
                            _buildDeviceDetailRow(
                              'IP Address',
                              (device['ipAddress'] ?? device['ip'] ?? 'N/A').toString(),
                              Icons.language_rounded,
                              AppColors.neonGreen,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  Widget _buildDeviceDetailRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Updated buildViewAllDevicesLink to use new vertical table
  Widget buildViewAllDevicesLink(String deviceType, List<Map<String, dynamic>> devices, Color primaryColor) {
    return GestureDetector(
      onTap: () {
        print('🔗 Clicked View All Devices for $deviceType');
        print('📊 Showing ${devices.length} devices');
        showVerticalDevicesTable(deviceType, devices, primaryColor);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_list_rounded,
              size: 16,
              color: primaryColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'View ${devices.length} devices',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED: Updated metric card with proper overflow handling
  Widget _buildMetricCard(String title, int value, IconData icon, Color primaryColor, String subtitle, List<String> details, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (title == 'Access Points') {
              showVerticalDevicesTable('Access Points', [...onlineAccessPoints, ...offlineAccessPoints], primaryColor);
            } else if (title == 'Edge Gateways') {
              showVerticalDevicesTable('Edge Gateways', [...onlineGateways, ...offlineGateways], primaryColor);
            } else {
              _showCardDetails(title, value, icon, subtitle, primaryColor, details);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header row with icon and trend indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: constraints.maxWidth > 150 ? 20 : 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: primaryColor.withOpacity(0.5)),
                          ),
                          child: Icon(
                            Icons.trending_up,
                            color: primaryColor,
                            size: constraints.maxWidth > 150 ? 14 : 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Value section with proper overflow handling
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value.toString(),
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: constraints.maxWidth > 150 ? 28 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: constraints.maxWidth > 150 ? 14 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: constraints.maxWidth > 150 ? 11 : 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> initializeClusterData() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      final prefs = await SharedPreferences.getInstance();

      // Get cluster information
      currentClusterId = widget.selectedClusterId ??
          prefs.getString('selected_cluster_id');
      currentClusterName = prefs.getString('selected_cluster_name');

      // Check if we just switched clusters
      dynamic clusterSwitchedPref = prefs.get('cluster_switched');
      bool clusterSwitched = false;
      if (clusterSwitchedPref is bool) {
        clusterSwitched = clusterSwitchedPref;
      } else if (clusterSwitchedPref is String) {
        clusterSwitched = clusterSwitchedPref.toLowerCase() == 'true';
      }

      print('🏠 HomeScreen initializing with cluster: $currentClusterId');
      print('🏠 Cluster switched flag: $clusterSwitched');

      if (clusterSwitched) {
        await prefs.setBool('cluster_switched', false);
        print('🔄 Cluster was recently switched, refreshing all data...');
      }

      // Get or refresh token
      token = await ApiService.getToken();
      if (token == null || token!.isEmpty) {
        await ApiService.refreshToken();
        token = await ApiService.getToken();
      }

      if (token == null || token!.isEmpty) {
        throw Exception('❌ Token is still null after refresh');
      }

      // Load clusters
      clusters = await MainApiService.fetchClustersUsingView();

      // If no specific cluster selected, pick the first account cluster
      if (currentClusterId == null || currentClusterId!.isEmpty) {
        final accountClusters = clusters
            .where((c) => c['type']?.toString().toLowerCase() == 'account')
            .toList();

        if (accountClusters.isNotEmpty) {
          currentClusterId = accountClusters.first['id']?.toString();
          currentClusterName = accountClusters.first['name']?.toString();
        } else if (clusters.isNotEmpty) {
          currentClusterId = clusters.first['id']?.toString();
          currentClusterName = clusters.first['name']?.toString();
        }
      }

      // Load all dashboard data with the cluster context
      await loadAllDashboardData();

    } catch (e) {
      print('❌ Error initializing cluster data: $e');
      if (mounted) {
        setState(() {
          errorMessage = "Initialization failed: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        if (!isLoading) {
          _startCardAnimations();
        }
      }
    }
  }

  Future<void> loadAllDashboardData() async {
    try {
      print('📊 Loading dashboard data for cluster: $currentClusterId');

      if (token == null || token!.isEmpty) {
        print('❌ No auth token available');
        return;
      }

      if (currentClusterId == null || currentClusterId!.isEmpty) {
        print('❌ No cluster ID available');
        return;
      }

      // Determine if it's an account cluster
      final isAccountCluster = clusters
          .any((c) => c['id']?.toString() == currentClusterId &&
          c['type']?.toString().toLowerCase() == 'account');

      // Make API calls with the current token and cluster
      await Future.wait([
        _fetchAccessPointData(isAccountCluster),
        _fetchAlertData(),
        _fetchLicenseData(),
      ]);

      if (mounted) {
        setState(() {
          isDataLoaded = true;
        });
      }

      print('✅ All dashboard data loaded successfully');

    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          errorMessage = "Failed to load dashboard data: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _fetchAccessPointData(bool isAccountCluster) async {
    try {
      // Fetch count data (existing API)
      final accessPointRes = await ApiService.authorizedGet(
        '${Config.baseUrl}/ray-app/api/nodes/countByStatus;clusterId=$currentClusterId;isAccountCluster=${isAccountCluster ? 'true' : 'false'}',
      );

      final accessData = jsonDecode(accessPointRes.body.toString());
      final data = accessData['data'] ?? accessData;

      int toInt(dynamic val) {
        if (val == null) return 0;
        if (val is int) return val;
        return int.tryParse(val.toString()) ?? 0;
      }

      final int accessPointOffline = toInt(data['accessPointOffline']);
      final int accessPointOnline = toInt(data['accessPointOnline']);
      final int gatewayOffline = toInt(data['gatewayOffline']);
      final int gatewayOnline = toInt(data['gatewayOnline']);

      // Helper function to safely parse API response
      List<Map<String, dynamic>> parseApiResponse(dynamic responseBody, String deviceType, String status) {
        try {
          print('🔍 Parsing $deviceType $status response...');

          final parsedData = jsonDecode(responseBody.toString());
          print('📦 Raw response type: ${parsedData.runtimeType}');
          print('📦 Raw response: ${parsedData.toString().substring(0, math.min(200, parsedData.toString().length))}...');

          dynamic deviceList;

          // Try different response structures
          if (parsedData is Map) {
            if (parsedData.containsKey('data')) {
              deviceList = parsedData['data'];
              print('📋 Found data key, type: ${deviceList.runtimeType}');
            } else {
              deviceList = parsedData;
              print('📋 Using root object, type: ${deviceList.runtimeType}');
            }
          } else if (parsedData is List) {
            deviceList = parsedData;
            print('📋 Direct list response, length: ${deviceList.length}');
          } else {
            print('⚠️ Unexpected response type: ${parsedData.runtimeType}');
            return [];
          }

          // Convert to List<Map<String, dynamic>>
          List<Map<String, dynamic>> result = [];

          if (deviceList is List) {
            for (int i = 0; i < deviceList.length; i++) {
              try {
                final item = deviceList[i];
                if (item is Map) {
                  result.add(Map<String, dynamic>.from(item));
                } else if (item != null) {
                  print('⚠️ Skipping non-map item at index $i: ${item.runtimeType}');
                }
              } catch (e) {
                print('⚠️ Error processing item at index $i: $e');
              }
            }
          } else if (deviceList is Map) {
            // Sometimes the response might be a single object instead of a list
            result.add(Map<String, dynamic>.from(deviceList));
            print('📋 Converted single object to list');
          } else {
            print('⚠️ Device list is not a List or Map: ${deviceList.runtimeType}');
          }

          print('✅ Successfully parsed ${result.length} $deviceType $status devices');
          return result;

        } catch (e) {
          print('❌ Error parsing $deviceType $status response: $e');
          return [];
        }
      }

      // Fetch detailed gateway data for online gateways
      List<Map<String, dynamic>> onlineGatewayDetails = [];
      if (gatewayOnline > 0) {
        try {
          final onlineGatewayRes = await ApiService.authorizedGet(
            '${Config.baseUrl}/ray-app/api/nodes/nodesByStatus;status=ONLINE;nodeMode=GATEWAY;clusterId=$currentClusterId;isAccountCluster=${isAccountCluster ? 'true' : 'false'}',
          );

          onlineGatewayDetails = parseApiResponse(onlineGatewayRes.body, 'Gateway', 'Online');
          print('🌉 Online Gateways Details: ${onlineGatewayDetails.length} items loaded');

        } catch (e) {
          print('❌ Error loading online gateway details: $e');
        }
      }

      // Fetch detailed gateway data for offline gateways
      List<Map<String, dynamic>> offlineGatewayDetails = [];
      if (gatewayOffline > 0) {
        try {
          final offlineGatewayRes = await ApiService.authorizedGet(
            '${Config.baseUrl}/ray-app/api/nodes/nodesByStatus;status=OFFLINE;nodeMode=GATEWAY;clusterId=$currentClusterId;isAccountCluster=${isAccountCluster ? 'true' : 'false'}',
          );

          offlineGatewayDetails = parseApiResponse(offlineGatewayRes.body, 'Gateway', 'Offline');
          print('🌉 Offline Gateways Details: ${offlineGatewayDetails.length} items loaded');

        } catch (e) {
          print('❌ Error loading offline gateway details: $e');
        }
      }

      // Fetch detailed access point data for online access points using CLIENT,BRIDGE mode
      List<Map<String, dynamic>> onlineAccessPointDetails = [];
      if (accessPointOnline > 0) {
        try {
          final onlineAccessPointRes = await ApiService.authorizedGet(
            '${Config.baseUrl}/ray-app/api/nodes/nodesByStatus;status=ONLINE;nodeMode=CLIENT,BRIDGE;clusterId=$currentClusterId;isAccountCluster=${isAccountCluster ? 'true' : 'false'}',
          );

          onlineAccessPointDetails = parseApiResponse(onlineAccessPointRes.body, 'AccessPoint', 'Online');
          print('📡 Online Access Points Details (CLIENT,BRIDGE): ${onlineAccessPointDetails.length} items loaded');

        } catch (e) {
          print('❌ Error loading online access point details: $e');
        }
      }

      // Fetch detailed access point data for offline access points using CLIENT,BRIDGE mode
      List<Map<String, dynamic>> offlineAccessPointDetails = [];
      if (accessPointOffline > 0) {
        try {
          final offlineAccessPointRes = await ApiService.authorizedGet(
            '${Config.baseUrl}/ray-app/api/nodes/nodesByStatus;status=OFFLINE;nodeMode=CLIENT,BRIDGE;clusterId=$currentClusterId;isAccountCluster=${isAccountCluster ? 'true' : 'false'}',
          );

          offlineAccessPointDetails = parseApiResponse(offlineAccessPointRes.body, 'AccessPoint', 'Offline');
          print('📡 Offline Access Points Details (CLIENT,BRIDGE): ${offlineAccessPointDetails.length} items loaded');

        } catch (e) {
          print('❌ Error loading offline access point details: $e');
        }
      }

      if (mounted) {
        setState(() {
          accessPointCount = accessPointOffline + accessPointOnline;
          edgeGatewayCount = gatewayOffline + gatewayOnline;

          // Store detailed data
          onlineGateways = onlineGatewayDetails;
          offlineGateways = offlineGatewayDetails;
          onlineAccessPoints = onlineAccessPointDetails;
          offlineAccessPoints = offlineAccessPointDetails;
        });
      }

      print('📡 Access Points loaded: $accessPointCount (Online: $accessPointOnline, Offline: $accessPointOffline)');
      print('🌉 Edge Gateways loaded: $edgeGatewayCount (Online: $gatewayOnline, Offline: $gatewayOffline)');

    } catch (e) {
      print('❌ Error loading access points: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _fetchAlertData() async {
    try {
      final alertRes = await ApiService.authorizedGet(
        '${Config.baseUrl}/ray-audit/api/audits/prometheusAlertLog;;loadLatest=current;cluster_id=$currentClusterId?sort=createdDate,desc',
      );

      final decoded = jsonDecode(alertRes.body.toString());
      List<dynamic> alertData = [];

      if (decoded is List) {
        alertData = List<dynamic>.from(decoded);
      } else if (decoded is Map) {
        final data = decoded['data'];
        if (data is Map && data['content'] is List) {
          alertData = List<dynamic>.from(data['content'] as List);
        }
      }

      if (mounted) {
        setState(() {
          alertCount = alertData.isNotEmpty ? alertData.length : 0;
        });
      }
      print('🚨 Alerts loaded: $alertCount');
    } catch (e) {
      print('❌ Error loading alerts: $e');
      if (mounted) {
        setState(() {
          alertCount = 0;
        });
      }
    }
  }

  Future<void> _fetchLicenseData() async {
    try {
      final url = '${Config.baseUrl}/ray-dashboard/api/graph/data/9caf6933-f1e8-4694-9adf-54aec40e30d2;:cluster_id=\'$currentClusterId\'';

      final licenseRes = await ApiService.authorizedGet(url);
      final licenseResponseData = jsonDecode(licenseRes.body.toString());

      final licenseData = licenseResponseData['data'] ?? licenseResponseData;

      int licenseCountValue = 0;

      if (licenseData is List) {
        licenseCountValue = licenseData.length;
      } else if (licenseData is Map) {
        licenseCountValue = licenseData.values.length;
      }

      if (mounted) {
        setState(() {
          expiringLicenses = licenseCountValue;
        });
      }
      print('📜 Licenses loaded: $expiringLicenses');
    } catch (e) {
      print('❌ Error loading licenses: $e');
    }
  }

  // Get live alert counts for dashboard
  Map<String, int> _getAlertCounts() {
    if (_allAlerts.isEmpty) {
      return {
        'resolved': (alertCount * 0.7).round(),
        'firing': (alertCount * 0.3).round(),
        'total': alertCount,
      };
    }

    final resolved = _allAlerts.where((alert) => alert['status'] == 'RESOLVED').length;
    final firing = _allAlerts.where((alert) => alert['status'] == 'FIRING').length;

    return {
      'resolved': resolved,
      'firing': firing,
      'total': resolved + firing,
    };
  }

  void _showCardDetails(String title, int value, IconData icon, String subtitle, Color primaryColor, List<String> details) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: AppColors.primaryBlack,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 5,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
                border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced Header with gradient
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Enhanced Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Enhanced Main Value Display
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.cardBlack,
                              border: Border.all(
                                color: primaryColor.withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  FittedBox(
                                    child: Text(
                                      value.toString(),
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    height: 3,
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Special handling for alerts
                          if (title == 'Active Alerts')
                            _buildAlertsActionButtons(primaryColor)
                          else
                          // Enhanced Details List for other cards
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: details.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: AppColors.cardBlack,
                                    border: Border.all(
                                      color: AppColors.primaryPurple.withOpacity(0.2),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          details[index],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            height: 1.5,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsActionButtons(Color primaryColor) {
    final alertCounts = _getAlertCounts();

    return Column(
      children: [
        // Enhanced Summary info
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.cardBlack,
            border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Cluster: ${currentClusterName ?? 'Unknown'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAlertStat('${alertCounts['resolved']}', 'Resolved', AppColors.neonGreen),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.primaryPurple.withOpacity(0.3),
                  ),
                  _buildAlertStat('${alertCounts['firing']}', 'Firing', AppColors.neonOrange),
                ],
              ),
            ],
          ),
        ),
        // Enhanced Action buttons
        Row(
          children: [
            Expanded(
              child: _buildEnhancedActionButton(
                'View Resolved',
                Icons.check_circle_outline_rounded,
                AppColors.neonGreen,
                    () => _showAlertsTable('resolved'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEnhancedActionButton(
                'View Firing',
                Icons.warning_amber_rounded,
                AppColors.neonOrange,
                    () => _showAlertsTable('firing'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertStat(String count, String label, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // DYNAMIC ALERTS IMPLEMENTATION
  void _showAlertsTable(String alertType) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryBlack,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryPurple.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  alertType == 'resolved' ? AppColors.neonGreen : AppColors.neonOrange,
                ),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading ${alertType} alerts...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await _fetchAlertsForTable();
      if (mounted) Navigator.of(context).pop();

      final alerts = _getFilteredAlertsForTable(alertType);
      final color = alertType == 'resolved' ? AppColors.neonGreen : AppColors.neonOrange;
      final title = alertType == 'resolved' ? 'Resolved Alerts' : 'Firing Alerts';

      _showAlertsDialog(alerts, color, title, alertType);

    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog('Failed to load alerts: $e');
    }
  }

  Future<void> _fetchAlertsForTable() async {
    if (token == null || currentClusterId == null) {
      throw Exception('Authentication or cluster configuration error');
    }

    try {
      if (mounted) {
        setState(() {
          _isLoadingAlerts = true;
          _alertsError = null;
        });
      }

      final alertRes = await ApiService.authorizedGet(
        '${Config.baseUrl}/ray-audit/api/audits/prometheusAlertLog;;loadLatest=current;cluster_id=$currentClusterId?sort=createdDate,desc',
      );

      final decoded = jsonDecode(alertRes.body.toString());
      List<dynamic> alertData = [];

      if (decoded is List) {
        alertData = List<dynamic>.from(decoded);
      } else if (decoded is Map) {
        final data = decoded['data'];
        if (data is Map && data['content'] is List) {
          alertData = List<dynamic>.from(data['content'] as List);
        }
      }

      _allAlerts = alertData.map((alert) => _transformAlertData(alert)).toList();

      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
          _alertsError = e.toString();
        });
      }
      throw e;
    }
  }

  Map<String, dynamic> _transformAlertData(dynamic apiAlert) {
    return {
      'id': apiAlert['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'name': apiAlert['alertname'] ?? apiAlert['name'] ?? 'Unknown Alert',
      'mac': _extractMacAddress(apiAlert),
      'message': apiAlert['message'] ?? apiAlert['description'] ?? apiAlert['summary'] ?? 'No message available',
      'status': _determineAlertStatus(apiAlert),
      'date': _formatApiDate(apiAlert['createdDate'] ?? apiAlert['timestamp'] ?? apiAlert['startsAt']),
      'severity': apiAlert['severity'] ?? 'unknown',
      'instance': apiAlert['instance'] ?? '',
      'job': apiAlert['job'] ?? '',
    };
  }

  String _extractMacAddress(dynamic apiAlert) {
    String mac = (apiAlert['mac'] ??
        apiAlert['instance'] ??
        apiAlert['device_id'] ??
        apiAlert['node_id'])?.toString() ?? '';

    if (mac.isEmpty) {
      final instance = apiAlert['instance']?.toString() ?? '';
      if (instance.isNotEmpty) {
        return '28:b7:7c:e0:${instance.hashCode.toRadixString(16).substring(0, 4)}';
      }
      return '28:b7:7c:e0:xx:xx';
    }
    return mac;
  }

  String _determineAlertStatus(dynamic apiAlert) {
    final status = apiAlert['status']?.toString().toLowerCase() ?? '';
    final state = apiAlert['state']?.toString().toLowerCase() ?? '';

    if (status.contains('resolved') ||
        state.contains('resolved') ||
        status.contains('inactive') ||
        apiAlert['endsAt'] != null) {
      return 'RESOLVED';
    } else if (status.contains('firing') ||
        state.contains('active') ||
        status.contains('pending')) {
      return 'FIRING';
    }
    return 'FIRING';
  }

  String _formatApiDate(dynamic apiDate) {
    if (apiDate == null) return DateTime.now().toString();

    try {
      DateTime date;
      if (apiDate is String) {
        date = DateTime.parse(apiDate);
      } else if (apiDate is int) {
        date = DateTime.fromMillisecondsSinceEpoch(apiDate);
      } else {
        date = DateTime.now();
      }

      final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final hour12 = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final formattedTime = '${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $amPm';

      return '$formattedDate $formattedTime';
    } catch (e) {
      return DateTime.now().toString().split('.')[0];
    }
  }

  List<Map<String, dynamic>> _getFilteredAlertsForTable(String alertType) {
    List<Map<String, dynamic>> filtered;

    if (alertType == 'resolved') {
      filtered = _allAlerts.where((alert) => alert['status'] == 'RESOLVED').toList();
    } else {
      filtered = _allAlerts.where((alert) => alert['status'] == 'FIRING').toList();
    }

    filtered.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['date'].toString().split(' ')[0]);
        final dateB = DateTime.parse(b['date'].toString().split(' ')[0]);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    return filtered;
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.neonOrange.withOpacity(0.5)),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.neonOrange, size: 28),
            const SizedBox(width: 12),
            const Text('Error', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          error,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAlertsTableWithFallback();
            },
            child: Text('Use Sample Data', style: TextStyle(color: AppColors.neonOrange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAlertsTableWithFallback() {
    final sampleAlerts = [
      {
        'id': '1',
        'name': 'API Connection Failed',
        'mac': '28:b7:7c:e0:c9:c0',
        'message': 'Unable to fetch live alert data. Showing sample data for demonstration.',
        'status': 'FIRING',
        'date': DateTime.now().toString().split('.')[0],
      },
    ];

    _showAlertsDialog(sampleAlerts, AppColors.neonOrange, 'Sample Alerts', 'sample');
  }

  void _showAlertsDialog(List<Map<String, dynamic>> alerts, Color color, String title, String alertType) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;

              return Container(
                width: screenWidth * 0.95,
                height: screenHeight * 0.9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.primaryBlack,
                  border: Border.all(color: color.withOpacity(0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Enhanced Header
                    Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              alertType == 'resolved' ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  '${alerts.length} items',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop(); // Close card details dialog too
                              },
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: alerts.isEmpty
                          ? _buildEmptyAlertsWidget(alertType)
                          : screenWidth > 600
                          ? _buildWideScreenTable(alerts, color, screenWidth)
                          : _buildMobileCardLayout(alerts, color),
                    ),

                    // Enhanced Footer
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBlack,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        border: Border(
                          top: BorderSide(color: color.withOpacity(0.4)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: color, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            child: Text(
                              'Total ${alertType.toUpperCase()}: ${alerts.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Updated: ${DateTime.now().toString().split(' ')[1].substring(0, 5)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showAlertsTable(alertType); // Refresh
                              },
                              icon: Icon(Icons.refresh_rounded, color: color, size: 18),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              tooltip: 'Refresh',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyAlertsWidget(String alertType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBlack,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3), width: 2),
            ),
            child: Icon(
              alertType == 'resolved' ? Icons.check_circle_outline_rounded : Icons.warning_amber_outlined,
              size: 64,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No ${alertType} alerts found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cluster: ${currentClusterName ?? 'Unknown'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideScreenTable(List<Map<String, dynamic>> alerts, Color color, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1),
            color: AppColors.cardBlack,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 12,
              headingRowHeight: 56,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 80,
              headingRowColor: MaterialStateProperty.all(AppColors.surfaceBlack),
              dataRowColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return color.withOpacity(0.1);
                }
                return AppColors.cardBlack;
              }),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.cardBlack,
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    'Alert Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'MAC Address',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Message',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              rows: alerts.map((alert) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        alert['name']?.toString() ?? 'No name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.neonCyan.withOpacity(0.3)),
                        ),
                        child: Text(
                          alert['mac']?.toString() ?? 'No MAC',
                          style: TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Tooltip(
                        message: alert['message']?.toString() ?? 'No message',
                        child: Text(
                          alert['message']?.toString() ?? 'No message',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.6)),
                        ),
                        child: Text(
                          alert['status']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatDate(alert['date']?.toString()),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardLayout(List<Map<String, dynamic>> alerts, Color color) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        itemCount: alerts.length,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final alert = alerts[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBlack,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with name and status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Text(
                          alert['name']?.toString() ?? 'No name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.6)),
                        ),
                        child: Text(
                          alert['status']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Enhanced MAC Address
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.neonCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.router_rounded, color: AppColors.neonCyan, size: 18),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            alert['mac']?.toString() ?? 'No MAC',
                            style: TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 13,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Enhanced Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlack,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    child: Text(
                      alert['message']?.toString() ?? 'No message',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Enhanced Date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.access_time_rounded, color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _formatDate(alert['date']?.toString()),
                          style: TextStyle(
                            color: color.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'No date';

    try {
      if (dateStr.contains('-') && dateStr.length > 10) {
        final parts = dateStr.split(' ');
        if (parts.length >= 2) {
          final datePart = parts[0];
          final timePart = parts[1];
          final cleanTime = timePart.length > 5 ? timePart.substring(0, 5) : timePart;
          return '$datePart $cleanTime';
        }
      }
      return dateStr.length > 20 ? dateStr.substring(0, 19) : dateStr;
    } catch (e) {
      return dateStr.length > 20 ? dateStr.substring(0, 19) : dateStr;
    }
  }

  void showClusterPopupCard() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: AppColors.primaryBlack,
              border: Border.all(color: AppColors.primaryPurple.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Enhanced Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    gradient: LinearGradient(
                      colors: [AppColors.primaryPurple, AppColors.darkPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Available Clusters',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                // Enhanced Cluster List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: clusters.length,
                    itemBuilder: (context, index) {
                      final cluster = clusters[index];
                      final isSelected = cluster['id']?.toString() == currentClusterId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [AppColors.neonGreen, AppColors.neonGreen.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          color: isSelected ? null : AppColors.cardBlack,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.neonGreen.withOpacity(0.6)
                                : AppColors.borderGray,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppColors.neonGreen.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ] : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (!isSelected) {
                                setState(() {
                                  currentClusterId = cluster['id']?.toString();
                                  currentClusterName = cluster['name']?.toString();
                                });
                                Navigator.of(context).pop();
                                _saveSelectedClusterAndRefresh();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withOpacity(0.2)
                                              : AppColors.primaryPurple.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.account_tree_rounded,
                                          color: isSelected ? Colors.white : AppColors.primaryPurple,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          cluster['name']?.toString() ?? 'Unnamed Cluster',
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'ID: ${cluster['id']?.toString() ?? 'Unknown'}',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.8)
                                          : Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Type: ${cluster['type']?.toString().toUpperCase() ?? 'UNKNOWN'}',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.8)
                                          : AppColors.primaryPurple,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveSelectedClusterAndRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_cluster_id', currentClusterId ?? '');
      await prefs.setString('selected_cluster_name', currentClusterName ?? '');
      await prefs.setBool('cluster_switched', true);

      // Refresh all data with new cluster
      await initializeClusterData();
    } catch (e) {
      print('❌ Error saving selected cluster: $e');
    }
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    _pulseController.dispose();
    _backgroundController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F0C29),
              Color(0xFF24243e),
              Color(0xFF302b63),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple.withOpacity(0.8),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.refresh, color: Colors.white),
                  onPressed: isLoading ? null : initializeClusterData,
                  tooltip: 'Refresh Dashboard',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  TopActionsBar(
                    selectedClusterId: widget.selectedClusterId,
                    onSettingsTap: _handleSettingsTap,
                  ),
                  // Rest of the content
                  isLoading
                      ? _buildLoadingWidget()
                      : errorMessage != null
                      ? _buildErrorWidget()
                      : _buildDashboardContent(),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: AppDrawer(
        selectedScreen: 'home',
        onSelectScreen: (screen) => NavigationHelper.navigateTo(context, screen),
      ),
    );
  }

  // Add this method to handle settings tap
  void _handleSettingsTap() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Settings',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Settings functionality will be implemented here.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF8E44AD)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading dashboard data...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching real-time metrics',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.red.withOpacity(0.2), Colors.red.withOpacity(0.1)],
                ),
              ),
              child: const Icon(Icons.error_outline, size: 64, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: initializeClusterData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    // Calculate actual online/offline counts using the stored lists
    final int actualOnlineAccessPoints = onlineAccessPoints.length;
    final int actualOfflineAccessPoints = offlineAccessPoints.length;
    final int actualOnlineGateways = onlineGateways.length;
    final int actualOfflineGateways = offlineGateways.length;
    final int totalAccessPoints = actualOnlineAccessPoints + actualOfflineAccessPoints;
    final int totalGateways = actualOnlineGateways + actualOfflineGateways;

    // Get sample devices for detailed information
    final sampleAccessPoint = (onlineAccessPoints.isNotEmpty)
        ? onlineAccessPoints.first
        : (offlineAccessPoints.isNotEmpty ? offlineAccessPoints.first : null);

    final sampleGateway = (onlineGateways.isNotEmpty)
        ? onlineGateways.first
        : (offlineGateways.isNotEmpty ? offlineGateways.first : null);

    final cardData = [
      {
        'title': 'Access Points',
        'value': accessPointCount,
        'icon': Icons.wifi_rounded,
        'color': const Color(0xFF00D4FF), // Bright cyan
        'subtitle': 'Network devices',
        'details': totalAccessPoints <= 1
            ? [
          'Cluster Name: ${currentClusterName ?? 'Unknown'}',
          'Cluster ID: ${currentClusterId ?? 'Unknown'}',
          'Online devices: $actualOnlineAccessPoints',
          'Offline devices: $actualOfflineAccessPoints',
          if (sampleAccessPoint != null) ...[
            'Device Name: ${sampleAccessPoint['appliance_name'] ?? 'Unknown'}',
            'Hardware: ${sampleAccessPoint['hardware_name'] ?? 'Unknown'}',
            'MAC Address: ${sampleAccessPoint['mac_address'] ?? 'Unknown'}',
            'Status: ${sampleAccessPoint['status'] ?? 'Unknown'}',
          ],
        ]
            : [
          'Cluster Name: ${currentClusterName ?? 'Unknown'}',
          'Cluster ID: ${currentClusterId ?? 'Unknown'}',
          'Online devices: $actualOnlineAccessPoints',
          'Offline devices: $actualOfflineAccessPoints',
          'Total devices: $totalAccessPoints',
        ],
        'showTable': totalAccessPoints > 1,
        'tableData': [...onlineAccessPoints, ...offlineAccessPoints],
        'deviceType': 'Access Points',
        'hasMultipleDevices': totalAccessPoints > 1,
      },
      {
        'title': 'Active Alerts',
        'value': alertCount,
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFFF6B35), // Vibrant orange-red
        'subtitle': 'Alerts',
        'details': [
          'Cluster Name: ${currentClusterName ?? 'Unknown'}',
          'Cluster ID: ${currentClusterId ?? 'Unknown'}',
          'Resolved Alerts: ${(alertCount * 0.7).round()}',
          'Firing Alerts: ${(alertCount * 0.3).round()}',
          'Total Alerts: $alertCount',
        ],
        'showTable': false,
        'tableData': <Map<String, dynamic>>[],
        'deviceType': 'Alerts',
        'hasMultipleDevices': false,
      },
      {
        'title': 'Expiring Licenses',
        'value': expiringLicenses,
        'icon': Icons.schedule_rounded,
        'color': const Color(0xFFFF07B0), // Bright magenta
        'subtitle': 'Expiring soon',
        'details': [
          'Cluster Name: ${currentClusterName ?? 'Unknown'}',
          'Expiry Date: ${DateTime.now().add(Duration(days: 15)).toString().split(' ')[0]}',
          'Expires this week: ${(expiringLicenses * 0.4).round()}',
          'Expires this month: ${(expiringLicenses * 0.6).round()}',
          'Total active licenses: ${expiringLicenses + 45}',
          'Compliance status: Good'
        ],
        'showTable': false,
        'tableData': <Map<String, dynamic>>[],
        'deviceType': 'Licenses',
        'hasMultipleDevices': false,
      },
      {
        'title': 'Edge Gateways',
        'value': edgeGatewayCount,
        'icon': Icons.router_rounded,
        'color': const Color(0xFF00C851), // Bright green
        'subtitle': 'Network nodes',
        'details': totalGateways <= 1
            ? [
          'Cluster Name: ${currentClusterName ?? 'Unknown'}',
          'Online gateways: $actualOnlineGateways',
          'Offline gateways: $actualOfflineGateways',
          if (sampleGateway != null) ...[
            'Device Name: ${sampleGateway['appliance_name'] ?? 'Unknown'}',
            'Hardware: ${sampleGateway['hardware_name'] ?? 'Unknown'}',
            'MAC Address: ${sampleGateway['mac_address'] ?? 'Unknown'}',
            'Status: ${sampleGateway['status'] ?? 'Unknown'}',
          ],
        ]
            : [
          'Cluster Name: ${currentClusterName ?? 'Unknown'}',
          'Online gateways: $actualOnlineGateways',
          'Offline gateways: $actualOfflineGateways',
          'Total gateways: $totalGateways',
        ],
        'showTable': totalGateways > 1,
        'tableData': [...onlineGateways, ...offlineGateways],
        'deviceType': 'Edge Gateways',
        'hasMultipleDevices': totalGateways > 1,
      },
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Animated Cards Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                final childAspectRatio = constraints.maxWidth > 600 ? 1.2 : 1.0;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: cardData.length,
                  itemBuilder: (context, index) {
                    final cardInfo = cardData[index];
                    final hasMultipleDevices = cardInfo['hasMultipleDevices'] as bool;
                    final deviceType = cardInfo['deviceType'] as String;
                    final tableData = cardInfo['tableData'] as List<Map<String, dynamic>>;

                    return AnimatedBuilder(
                      animation: _cardSlideAnimations[index],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_cardPositions[index], 0),
                          child: SlideTransition(
                            position: _cardSlideAnimations[index],
                            child: ScaleTransition(
                              scale: _cardScaleAnimations[index],
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      cardInfo['title'] as String,
                                      cardInfo['value'] as int,
                                      cardInfo['icon'] as IconData,
                                      cardInfo['color'] as Color,
                                      cardInfo['subtitle'] as String,
                                      cardInfo['details'] as List<String>,
                                      index,
                                    ),
                                  ),
                                  // Show "View all devices" hyperlink only for device cards with multiple devices
                                  if (hasMultipleDevices) ...[
                                    const SizedBox(height: 8),
                                    buildViewAllDevicesLink(deviceType, tableData, cardInfo['color'] as Color),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          // Cluster Info
          if (currentClusterId != null) _buildClusterInfo(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildClusterInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Cluster',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  currentClusterId!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}