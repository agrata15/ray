import 'package:flutter/material.dart';
import 'dart:convert';
import 'app_drawer.dart';
import 'cluster_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'cluster_screen.dart';
import 'appliances_screen.dart';
import 'dashboard_screen.dart';
import 'audit_screen.dart';
import 'navigation_helper.dart';
import 'cluster_api.dart';

class ClusterScreen extends StatefulWidget {
  const ClusterScreen({super.key});

  @override
  State<ClusterScreen> createState() => _ClusterScreenState();
}

class _ClusterScreenState extends State<ClusterScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> clusters = [];
  Map<String, List<Map<String, dynamic>>> clusterChildrenMap = {};
  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> screens = [];
  // At the top of your widget/state class
  List<Map<String, dynamic>> pathClusters = [];

  List<String> logs = [];
  String clusterPath = '';
  bool isLoading = true;
  String token = '';
  String selectedClusterName = '';
  String selectedClusterId = '';
  bool showClusterPopup = false;
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    loadTokenAndClusters();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    // Start background animation
    _backgroundController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void navigateTo(String page) {
    Widget screen;
    switch (page) {
      case 'Home':
        screen = const HomeScreen();
        break;
      case "Clients":
        screen = const ClusterScreen();
        break;
      case "Appliances":
        screen = const AppliancesScreen();
        break;
      case "Dashboard":
        screen = const DashboardScreen();
        break;
      case "AuditLog":
        screen = const AuditScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void addLog(String message) {
    if (mounted) {
      setState(() {
        logs.insert(0, "[${DateTime.now().toIso8601String().substring(11, 19)}] $message");
      });
    } else {
      print("[${DateTime.now().toIso8601String().substring(11, 19)}] $message");
    }
  }

  Future<void> loadTokenAndClusters() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token') ?? '';
    if (token.isNotEmpty) {
      addLog("✅ Token found. Fetching cluster list...");
      await fetchClusters();
    } else {
      addLog("❌ Token not found in SharedPreferences");
    }
  }

  Future<void> fetchClusters() async {
    try {
      final response = await MainApiService.getClusterView(token);
      print("Cluster API Response: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'];
          print('📦 decoded: $decoded');
          print('📦 decoded > data type: ${data.runtimeType}');

          if (!mounted) return;

          if (data is List) {
            setState(() {
              clusters = List<Map<String, dynamic>>.from(data);
            });
            addLog('✅ Loaded ${clusters.length} clusters');
            print('🔧 Clusters loaded: ${clusters.map((c) => c['name']).join(', ')}');
          } else if (data is Map) {
            setState(() {
              clusters = [Map<String, dynamic>.from(data)];
            });
            addLog('✅ Loaded 1 cluster (single map)');
            print('🔧 Single cluster loaded: ${data['name']}');
          } else {
            addLog('❌ Unexpected format for data: ${data.runtimeType}');
            setState(() {
              clusters = [Map<String, dynamic>.from(decoded)];
            });
            addLog('✅ Loaded ${clusters.length} clusters');
            print('🔧 Fallback clusters loaded: ${clusters.map((c) => c['name']).join(', ')}');
          }

          // Also fetch the current cluster path to show breadcrumbs
          try {
            final pathRes = await MainApiService.getClusterPath(token);
            if (pathRes.statusCode == 200) {
              final decodedPath = jsonDecode(pathRes.body);
              final newPath = decodedPath['path']?.toString() ?? '';
              if (mounted) {
                setState(() {
                  clusterPath = newPath;
                  pathClusters = parseClusterPath(newPath);
                });
              }
              addLog('🧭 Path: $clusterPath');
            } else {
              addLog('⚠️ Failed to fetch cluster path. Status: ${pathRes.statusCode}');
            }
          } catch (e) {
            addLog('❌ Error fetching cluster path: $e');
          }
        } else {
          addLog('❌ Response is not a Map');
          print('🔧 Response is not a Map: ${decoded.runtimeType}');
        }
      } else {
        addLog('❌ Failed to fetch clusters. Status: ${response.statusCode}');
        print('🔧 Failed to fetch clusters. Status: ${response.statusCode}');
      }
    } catch (e) {
      addLog('❌ Error loading clusters: $e');
      print('🔧 Error loading clusters: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  // New method to parse cluster path and create clickable segments
  List<Map<String, dynamic>> parseClusterPath(String path) {
    if (path.isEmpty) return [];

    pathClusters = []; // reset before rebuilding

    final normalized = path.replaceAll(' > ', '/').replaceAll('>', '/').trim();
    final pathSegments = normalized.split('/').where((s) => s.trim().isNotEmpty).toList();

    for (int i = 0; i < pathSegments.length; i++) {
      final segment = pathSegments[i];

      Map<String, dynamic> clusterInfo = clusters.firstWhere(
            (c) => c['name'] == segment || c['id'] == segment,
        orElse: () => {},
      );

      if (clusterInfo.isEmpty) {
        for (final childrenList in clusterChildrenMap.values) {
          final found = childrenList.firstWhere(
                (c) => c['name'] == segment || c['id'] == segment,
            orElse: () => {},
          );
          if (found.isNotEmpty) {
            clusterInfo = found;
            break;
          }
        }
      }

      pathClusters.add({
        'name': segment,
        'id': clusterInfo['id'] ?? segment,
        'fullPath': pathSegments.take(i + 1).join('/'),
        'isLast': i == pathSegments.length - 1,
      });
    }

    return pathClusters;
  }

  // New method to handle path cluster clicks
  Future<void> onPathClusterTap(String clusterId, String clusterName, String fullPath) async {
    try {
      addLog('🔄 Switching to path cluster: $clusterName ($clusterId)');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Switching to $clusterName...',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF8E44AD),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await MainApiService.changeCluster(clusterId);
      addLog('✅ Cluster switched successfully');

      final prefs = await SharedPreferences.getInstance();
      String newToken = prefs.getString('auth_token') ?? '';

      if (newToken.isNotEmpty) {
        addLog('✅ New token retrieved');

        await prefs.setString('selected_cluster_id', clusterId);
        await prefs.setString('selected_cluster_name', clusterName);
        await prefs.setString('cluster_switched', 'true');

        if (mounted) {
          setState(() {
            token = newToken;
            selectedClusterName = clusterName;
            selectedClusterId = clusterId;
            children = [];
            screens = [];
            clusterPath = '';
            pathClusters = [];
          });
        }

        // Fetch updated data for the new cluster
        await onClusterTap(clusterId, clusterName);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Switched to $clusterName',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to get new token after cluster switch');
      }
    } catch (e) {
      addLog('⚠ Error switching to path cluster: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Failed to switch to $clusterName: ${e.toString()}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  Future<void> onClusterTap(String clusterId, String clusterName) async {
    try {
      addLog('👉 Tapped Cluster: $clusterName ($clusterId)');
      setState(() {
        selectedClusterName = clusterName;
        selectedClusterId = clusterId;
        children = [];
        screens = [];
        clusterPath = '';
        pathClusters =[];
      });

      addLog('✅ Switched to cluster: $clusterId');

      final childRes = await MainApiService.getClusterChildren(clusterId, token);
      final screenRes = await MainApiService.getClusterScreens(clusterId, token);
      final pathRes = await MainApiService.getClusterPath(token);

      if (childRes.statusCode == 200) {
        final decodedChildren = jsonDecode(childRes.body);
        if (decodedChildren is List) {
          setState(() {
            children = List<Map<String, dynamic>>.from(decodedChildren);
          });
          addLog('👶 Found ${children.length} child clusters');
        }
      }

      if (screenRes.statusCode == 200) {
        final decodedScreens = jsonDecode(screenRes.body);
        if (decodedScreens is List) {
          setState(() {
            screens = List<Map<String, dynamic>>.from(decodedScreens);
          });
          addLog('🖥️ Found ${screens.length} screens');
        }
      }

      if (pathRes.statusCode == 200) {
        final decodedPath = jsonDecode(pathRes.body);
        setState(() {
          clusterPath = decodedPath['path']?.toString() ?? '';
          pathClusters=parseClusterPath(clusterPath);
        });
        addLog('🧭 Path: $clusterPath');
      }
    } catch (e) {
      addLog('❌ Error on cluster tap: $e');
    }
  }

  Widget buildClusterHyperlink(String clusterName, String clusterId) {
    return GestureDetector(
      onTap: () => onClusterTap(clusterId, clusterName),
      child: Text(
        clusterName,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }


  Widget buildClusterButton(String clusterName, String clusterId) {
    return TextButton(
      onPressed: () => onClusterTap(clusterId, clusterName),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        clusterName,
        style: const TextStyle(
          decoration: TextDecoration.underline,
          fontSize: 16,
        ),
      ),
    );
  }

  Future<void> loadClusterChildren(String clusterId, String clusterName) async {
    if (clusterChildrenMap.containsKey(clusterId)) return;

    try {
      final childRes = await MainApiService.getClusterChildren(clusterId, token);
      if (childRes.statusCode == 200) {
        final childrenDecoded = jsonDecode(childRes.body);
        if (childrenDecoded is List) {
          setState(() {
            clusterChildrenMap[clusterId] = List<Map<String, dynamic>>.from(childrenDecoded);
          });
          addLog('📥 Fetched children for $clusterName');
        }
      }
    } catch (e) {
      addLog('❌ Error loading children for $clusterName: $e');
    }
  }

  Widget buildClusterChildrenHyperlink(String clusterName, String clusterId) {
    return GestureDetector(
      onTap: () => loadClusterChildren(clusterId, clusterName),
      child: Text(
        clusterName,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget buildLoadChildrenButton(String clusterName, String clusterId) {
    return TextButton(
      onPressed: () => loadClusterChildren(clusterId, clusterName),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        clusterName,
        style: const TextStyle(
          decoration: TextDecoration.underline,
          fontSize: 16,
        ),
      ),
    );
  }

  void showClusterPopupCard() {
    setState(() {
      showClusterPopup = true;
    });
    _animationController.forward();
  }

  void hideClusterPopupCard() {
    _animationController.reverse().then((_) {
      setState(() {
        showClusterPopup = false;
      });
    });
  }

  void navigateToHomeWithCluster() {
    if (selectedClusterId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cluster first')),
      );
    }
  }
  Widget _buildClickableClusterPath() {
    print('🔍 Building clickable path - pathClusters length: ${pathClusters.length}');
    print('🔍 clusterPath: "$clusterPath"');
    print('🔍 pathClusters: $pathClusters');

    if (pathClusters.isEmpty) {
      print('🔍 PathClusters is empty, showing SizedBox.shrink()');
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8E44AD).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF8E44AD),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cluster Path',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fixed scrollable breadcrumb - removes overflow issues
          SizedBox(
            height: 44, // Fixed height to prevent overflow
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.home_rounded,
                    color: Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  // Build breadcrumb items without Flexible widgets
                  for (int index = 0; index < pathClusters.length; index++) ...[
                    // Add separator before each item (except first)
                    if (index > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '/',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    // Breadcrumb item - removed Flexible wrapper
                    _buildBreadcrumbItem(pathClusters[index], index),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper method to build individual breadcrumb items
  Widget _buildBreadcrumbItem(Map<String, dynamic> pathCluster, int index) {
    final isLast = pathCluster['isLast'] as bool? ?? false;

    return GestureDetector(
      onTap: isLast
          ? null
          : () {
        print('🖱️ Tapping path cluster: ${pathCluster['name']} (${pathCluster['id']})');
        onPathClusterTap(
          pathCluster['id'].toString(),
          pathCluster['name'].toString(),
          pathCluster['fullPath'].toString(),
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 120, // Prevent extremely wide items
          minHeight: 32,
          maxHeight: 36, // Add max height constraint
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isLast
              ? const Color(0xFF8E44AD)
              : const Color(0xFF8E44AD).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF8E44AD).withOpacity(isLast ? 1.0 : 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            pathCluster['name'].toString(),
            style: TextStyle(
              color: isLast ? Colors.white : const Color(0xFF8E44AD),
              fontSize: 12, // Reduced font size
              fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
              decoration: isLast ? TextDecoration.none : TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
  Widget _buildClusterPopupCard() {
    final filteredClusters = clusters.where((c) => c['id'] != 'fallback').toList();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.85 * _opacityAnimation.value),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9, // Reduced from 0.95
                  height: MediaQuery.of(context).size.height * 0.75, // Reduced from 0.85
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24), // Reduced from 28
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: const Color(0xFF8E44AD).withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8E44AD).withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header - Made more compact
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Reduced padding
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                          color: Color(0xFF8E44AD),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8), // Reduced from 10
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10), // Reduced from 12
                              ),
                              child: const Icon(
                                Icons.account_tree_rounded,
                                color: Colors.white,
                                size: 20, // Reduced from 24
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cluster Hierarchy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16, // Reduced from 18
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Select and manage clusters',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12, // Reduced from 13
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: hideClusterPopupCard,
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Body - Removed horizontal scrolling, optimized for vertical only
                      Expanded(
                        child: filteredClusters.isEmpty
                            ? Center(
                          child: isLoading
                              ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 50, // Reduced from 60
                                height: 50, // Reduced from 60
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2, // Reduced from 3
                                ),
                              ),
                              const SizedBox(height: 20), // Reduced from 24
                              const Text(
                                'Loading clusters...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14, // Reduced from 16
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                              : const Text(
                            'No clusters found',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16, // Reduced from 18
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                            : Scrollbar(
                          thumbVisibility: true,
                          thickness: 4, // Reduced from 6
                          radius: const Radius.circular(8), // Reduced from 10
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), // Extra bottom padding
                            itemCount: filteredClusters.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8), // Add spacing between items
                              child: _buildPopupClusterTile(
                                filteredClusters[index],
                                level: 0,
                                uniqueKey: 'popup_$index',
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

    return Container(
      key: ValueKey(tileKey),
      margin: EdgeInsets.only(
        left: level * 12.0, // Reduced indentation for better space usage
        right: 6.0,
        top: 1.0, // Minimal top margin
        bottom: 1.0, // Minimal bottom margin
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8), // Smaller radius for compactness
        border: Border.all(
          color: const Color(0xFF8E44AD).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: ValueKey('expansion_$tileKey'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // More compact padding
          childrenPadding: const EdgeInsets.only(bottom: 4), // Reduced children padding
          maintainState: true,
          dense: true, // Makes the tile more compact
          visualDensity: VisualDensity.compact, // Additional compactness
          title: GestureDetector(
            onTap: () async {
              try {
                addLog('🔄 Switching to cluster: $clusterName ($clusterId)');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Switching to $clusterName...',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF8E44AD),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }

                await MainApiService.changeCluster(clusterId);
                addLog('✅ Cluster switched successfully');

                final prefs = await SharedPreferences.getInstance();
                String newToken = prefs.getString('auth_token') ?? '';

                if (newToken.isNotEmpty) {
                  addLog('✅ New token retrieved: ${newToken.substring(0, 30)}...');

                  await prefs.setString('selected_cluster_id', clusterId);
                  await prefs.setString('selected_cluster_name', clusterName);
                  await prefs.setString('cluster_switched', 'true');

                  if (mounted) {
                    setState(() {
                      token = newToken;
                      selectedClusterName = clusterName;
                      selectedClusterId = clusterId;
                    });
                  }

                  if (mounted) {
                    hideClusterPopupCard();
                  }

                  await Future.delayed(const Duration(milliseconds: 200));

                  if (mounted) {
                    addLog('🏠 Navigating to HomeScreen with cluster: $clusterName');

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(
                          key: ValueKey('home_${clusterId}_${DateTime.now().millisecondsSinceEpoch}'),
                          selectedClusterId: clusterId,
                        ),
                      ),
                          (route) => false,
                    );

                    addLog('✅ Navigation to HomeScreen completed');
                  }
                } else {
                  throw Exception('Failed to get new token after cluster switch');
                }
              } catch (e) {
                addLog('❌ Error switching cluster: $e');

                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Failed to switch to $clusterName: ${e.toString()}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            child: Text(
              clusterName,
              style: TextStyle(
                fontSize: 13, // Consistent readable size
                fontWeight: level == 0 ? FontWeight.bold : FontWeight.w500,
                color: Colors.cyan,
                decoration: TextDecoration.underline,
                decorationColor: Colors.cyan,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1, // Keep all titles to single line for consistency
            ),
          ),
          subtitle: Text(
            'ID: $clusterId',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          leading: Container(
            width: 28, // Fixed width for consistent alignment
            height: 28, // Fixed height for consistent alignment
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              level == 0 ? Icons.folder_rounded : Icons.folder_open_rounded,
              size: 16, // Consistent icon size
              color: Colors.white,
            ),
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          onExpansionChanged: (expanded) async {
            if (expanded && mounted) {
              await loadClusterChildren(clusterId, clusterName);
            }
          },
          children: children.isEmpty
              ? [
            Container(
              margin: EdgeInsets.only(
                left: (level + 1) * 12.0 + 8.0,
                right: 8,
                top: 2,
                bottom: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'No child clusters',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
              : [
            ...children.asMap().entries.map(
                  (entry) => Container(
                margin: const EdgeInsets.only(bottom: 2), // Minimal spacing between children
                child: _buildPopupClusterTile(
                  entry.value,
                  level: level + 1,
                  uniqueKey: '${uniqueKey}_child_${entry.key}',
                ),
              ),
            ),
            const SizedBox(height: 4), // Small final padding
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(const Color(0xFF0F0C29), const Color(0xFF24243e), _backgroundAnimation.value)!,
                  Color.lerp(const Color(0xFF24243e), const Color(0xFF302b63), _backgroundAnimation.value)!,
                  Color.lerp(const Color(0xFF302b63), const Color(0xFF0F0C29), _backgroundAnimation.value)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
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
                      'Cluster Management',
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
                      onPressed: isLoading ? null : loadTokenAndClusters,
                      tooltip: 'Refresh Clusters',
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _buildMainContent(),
                ),
              ],
            ),
          );
        },
      ),
      drawer: AppDrawer(
        selectedScreen: 'clients',
        onSelectScreen: (screen) => NavigationHelper.navigateTo(context, screen),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Action Buttons Section
          _buildActionButtons(),
          const SizedBox(height: 20),
          // Main Content Area
          if (isLoading)
            _buildLoadingWidget()
          else if (children.isNotEmpty || screens.isNotEmpty || clusterPath.isNotEmpty)
            _buildSelectedClusterInfo()
          else
            _buildWelcomeSection(),
          const SizedBox(height: 20),
          // Console/Logs Section
          //  _buildConsoleSection(),
          const SizedBox(height: 20),
          // Popup overlay
          if (showClusterPopup) _buildClusterPopupCard(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'Settings',
              Icons.settings_rounded,
              const Color(0xFF3F51B5),
                  () {
                // Settings action
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              'Clusters (${clusters.length})',
              Icons.account_tree_rounded,
              const Color(0xFF8E44AD),
              showClusterPopupCard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: const Color(0xFF8E44AD).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E44AD).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
              'Loading clusters...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we fetch your clusters',
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

  Widget _buildWelcomeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: const Color(0xFF8E44AD).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E44AD).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.account_tree_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome to Cluster Management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a cluster from the list above to view its details, children, and available screens.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Total clusters available: ${clusters.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedClusterInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: const Color(0xFF8E44AD).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E44AD).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with horizontal scrolling for long names
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              gradient: LinearGradient(
                colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Cluster',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          selectedClusterName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content with horizontal scrolling
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (pathClusters.isNotEmpty) ...[
                  _buildClickableClusterPath(),
                  const SizedBox(height: 16),
                ] else if (clusterPath.isNotEmpty) ...[
                  _buildInfoCard(
                    'Cluster Path',
                    clusterPath,
                    Icons.location_on_rounded,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                ],
                if (children.isNotEmpty) ...[
                  _buildInfoCard(
                    'Child Clusters (${children.length})',
                    children.map((c) => c['name']?.toString() ?? 'Unnamed').join(', '),
                    Icons.account_tree_rounded,
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                ],
                if (screens.isNotEmpty) ...[
                  _buildInfoCard(
                    'Available Screens (${screens.length})',
                    screens.map((s) => s['name']?.toString() ?? 'Unnamed screen').join(', '),
                    Icons.monitor_rounded,
                    Colors.orange,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Make content horizontally scrollable for long text
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 100,
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
          colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
        )
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
            )
                : LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}