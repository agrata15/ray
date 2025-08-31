import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cluster_api.dart';
import 'home_screen.dart';

class AppDrawer extends StatefulWidget {
  final String selectedScreen;
  final Function(String screenName) onSelectScreen;

  const AppDrawer({
    super.key,
    required this.selectedScreen,
    required this.onSelectScreen,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with TickerProviderStateMixin {
  // Cluster management variables
  List<Map<String, dynamic>> clusters = [];
  List<Map<String, dynamic>> allClusters = [];
  List<Map<String, dynamic>> filteredClusters = [];
  Map<String, List<Map<String, dynamic>>> clusterChildrenMap = {};
  Map<String, bool> expandedClusters = {};
  List<Map<String, dynamic>> pathClusters = [];
  String clusterPath = '';
  bool isLoadingClusters = false;
  String token = '';
  String selectedClusterName = '';
  String selectedClusterId = '';
  bool showClusterSection = false;

  // Search functionality
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Animation controllers
  late AnimationController _clusterAnimationController;
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late Animation<double> _clusterAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTokenAndClusters();
    searchController.addListener(_onSearchChanged);
  }

  void _initializeAnimations() {
    _clusterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _clusterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _clusterAnimationController,
      curve: Curves.easeInOutCubic,
    ));

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _backgroundController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text.toLowerCase();
      _filterClusters();
    });
  }

  void _filterClusters() {
    if (searchQuery.isEmpty) {
      filteredClusters = clusters.where((c) => c['id'] != 'fallback').toList();
      _reloadOriginalChildren();
    } else {
      // Global search across all clusters
      filteredClusters = _searchClustersGlobally(allClusters, searchQuery);
    }
  }

  List<Map<String, dynamic>> _searchClustersGlobally(
      List<Map<String, dynamic>> clusterList, String query) {
    List<Map<String, dynamic>> results = [];
    Set<String> addedClusterIds = {};

    void searchRecursively(List<Map<String, dynamic>> clusters, String parentPath) {
      for (var cluster in clusters) {
        if (cluster['id'] == 'fallback') continue;

        final clusterId = cluster['id']?.toString() ?? '';
        final clusterName = cluster['name']?.toString().toLowerCase() ?? '';
        final clusterIdString = clusterId.toLowerCase();

        bool matches = clusterName.contains(query) || clusterIdString.contains(query);

        if (matches && !addedClusterIds.contains(clusterId)) {
          Map<String, dynamic> clusterCopy = Map<String, dynamic>.from(cluster);
          clusterCopy['searchPath'] = parentPath.isEmpty ? clusterName : '$parentPath > ${cluster['name']}';
          results.add(clusterCopy);
          addedClusterIds.add(clusterId);
        }

        // Always search children, regardless of current cluster position
        final children = clusterChildrenMap[clusterId] ?? [];
        if (children.isNotEmpty) {
          String newPath = parentPath.isEmpty
              ? cluster['name']?.toString() ?? ''
              : '$parentPath > ${cluster['name']}';
          searchRecursively(children, newPath);
        }
      }
    }

    searchRecursively(clusterList, '');
    return results;
  }

  Future<void> _reloadOriginalChildren() async {
    clusterChildrenMap.clear();
    await _loadAllClusterChildren();
  }

  void _flattenAllClusters() {
    allClusters = [];

    void flattenRecursively(List<Map<String, dynamic>> clusterList) {
      for (var cluster in clusterList) {
        if (cluster['id'] != 'fallback') {
          allClusters.add(cluster);
          final clusterId = cluster['id']?.toString() ?? '';
          final children = clusterChildrenMap[clusterId] ?? [];
          if (children.isNotEmpty) {
            flattenRecursively(children);
          }
        }
      }
    }

    flattenRecursively(clusters);
  }

  @override
  void dispose() {
    _clusterAnimationController.dispose();
    _backgroundController.dispose();
    _pulseController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenAndClusters() async {
    if (!mounted) return;

    setState(() {
      isLoadingClusters = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token') ?? '';
      selectedClusterName = prefs.getString('selected_cluster_name') ?? '';
      selectedClusterId = prefs.getString('selected_cluster_id') ?? '';

      if (token.isNotEmpty) {
        await _fetchClusters();
      }
    } catch (e) {
      debugPrint('Error loading token and clusters: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingClusters = false;
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

          if (!mounted) return;

          if (data is List) {
            setState(() {
              clusters = List<Map<String, dynamic>>.from(data);
              _filterClusters();
            });
          } else if (data is Map) {
            setState(() {
              clusters = [Map<String, dynamic>.from(data)];
              _filterClusters();
            });
          } else {
            setState(() {
              clusters = [Map<String, dynamic>.from(decoded)];
              _filterClusters();
            });
          }

          await _loadAllClusterChildren();
          _flattenAllClusters();

          try {
            final pathRes = await MainApiService.getClusterPath(token);
            if (pathRes.statusCode == 200) {
              final decodedPath = jsonDecode(pathRes.body);
              if (mounted) {
                setState(() {
                  if (decodedPath is List) {
                    pathClusters = _parseClusterPath(decodedPath);
                    clusterPath = pathClusters.map((p) => p['name']).join(' > ');
                  } else if (decodedPath is Map && decodedPath.containsKey('path')) {
                    final pathData = decodedPath['path'];
                    pathClusters = _parseClusterPath(pathData);
                    clusterPath = pathClusters.map((p) => p['name']).join(' > ');
                  }
                });
              }
            }
          } catch (e) {
            debugPrint('Error fetching cluster path: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading clusters: $e');
    }
  }

  Future<void> _loadAllClusterChildren() async {
    await _loadChildrenRecursively(clusters);
  }

  Future<void> _loadChildrenRecursively(
      List<Map<String, dynamic>> clusterList) async {
    for (var cluster in clusterList) {
      final clusterId = cluster['id']?.toString() ?? '';
      if (clusterId.isNotEmpty && clusterId != 'fallback') {
        await _loadClusterChildren(clusterId);
        final children = clusterChildrenMap[clusterId] ?? [];
        if (children.isNotEmpty) {
          await _loadChildrenRecursively(children);
        }
      }
    }
  }

  List<Map<String, dynamic>> _parseClusterPath(dynamic path) {
    List<Map<String, dynamic>> pathClustersList = [];

    try {
      if (path is List) {
        for (int i = 0; i < path.length; i++) {
          final pathItem = path[i];
          if (pathItem is Map<String, dynamic>) {
            pathClustersList.add({
              'name': pathItem['name']?.toString() ?? 'Unknown',
              'id': pathItem['id']?.toString() ?? '',
              'fullPath': path.take(i + 1).map((p) => p['name']).join(' > '),
              'isLast': i == path.length - 1,
            });
          }
        }
      } else if (path is String && path.isNotEmpty) {
        final normalized = path.replaceAll(' > ', '/').replaceAll('>', '/').trim();
        final pathSegments = normalized.split('/').where((s) => s.trim().isNotEmpty).toList();

        for (int i = 0; i < pathSegments.length; i++) {
          final segment = pathSegments[i];
          pathClustersList.add({
            'name': segment,
            'id': segment,
            'fullPath': pathSegments.take(i + 1).join(' > '),
            'isLast': i == pathSegments.length - 1,
          });
        }
      }
    } catch (e) {
      debugPrint('Error parsing cluster path: $e');
    }

    return pathClustersList;
  }

  // Enhanced cluster switching with proper navigation and home refresh
  Future<void> _onClusterTap(String clusterId, String clusterName) async {
    final scaffoldMessenger = mounted ? ScaffoldMessenger.of(context) : null;

    try {
      if (mounted && scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF8E44AD),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await MainApiService.changeCluster(clusterId);

      final prefs = await SharedPreferences.getInstance();
      String newToken = prefs.getString('auth_token') ?? '';

      if (newToken.isNotEmpty) {
        await prefs.setString('selected_cluster_id', clusterId);
        await prefs.setString('selected_cluster_name', clusterName);
        await prefs.setString('cluster_switched', 'true');

        if (mounted && scaffoldMessenger != null) {
          setState(() {
            token = newToken;
            selectedClusterName = clusterName;
            selectedClusterId = clusterId;
          });

          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
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
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 2),
            ),
          );

          // Close drawer first
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }

          // Navigate to fresh home screen with new cluster and refresh data
          await Future.delayed(const Duration(milliseconds: 200));

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  key: ValueKey('home_${clusterId}_${DateTime.now().millisecondsSinceEpoch}'),
                  selectedClusterId: clusterId,
                ),
              ),
                  (route) => false,
            );
          }
        }
      } else {
        throw Exception('Failed to get new token after cluster switch');
      }
    } catch (e) {
      if (mounted && scaffoldMessenger != null) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Failed to switch: ${e.toString().length > 30 ? e.toString().substring(0, 30) + '...' : e.toString()}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE53E3E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadClusterChildren(String clusterId) async {
    if (clusterChildrenMap.containsKey(clusterId)) return;

    try {
      final childRes = await MainApiService.getClusterChildren(clusterId, token);
      if (childRes.statusCode == 200) {
        final childrenDecoded = jsonDecode(childRes.body);
        if (childrenDecoded is List) {
          setState(() {
            clusterChildrenMap[clusterId] = List<Map<String, dynamic>>.from(childrenDecoded);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading children for cluster $clusterId: $e');
    }
  }

  void _toggleClusterSection() {
    setState(() {
      showClusterSection = !showClusterSection;
    });

    if (showClusterSection) {
      _clusterAnimationController.forward();
      if (clusters.isEmpty && token.isNotEmpty) {
        _fetchClusters();
      }
    } else {
      _clusterAnimationController.reverse();
    }
  }

  // Fixed search bar with proper constraints
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      height: 40, // Fixed height to prevent overflow
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF3A3A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8E44AD).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Global cluster search...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.search_rounded, color: Color(0xFF8E44AD), size: 18),
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
            iconSize: 18,
            icon: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.7)),
            onPressed: () => searchController.clear(),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  // Fixed drawer item with proper constraints
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, bool isSelected, {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      height: 48, // Fixed height to prevent overflow
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isSelected ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, // Fixed width
                  height: 32, // Fixed height
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFF8E44AD).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : const Color(0xFF8E44AD),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (trailing != null)
                  SizedBox(
                    width: 24, // Fixed width for trailing
                    height: 24, // Fixed height for trailing
                    child: trailing,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Fixed cluster tile with proper constraints and overflow prevention
  Widget _buildClusterTile(Map<String, dynamic> cluster, {int level = 0}) {
    final clusterId = cluster['id']?.toString() ?? '';
    final clusterName = cluster['name']?.toString() ?? 'Unnamed';
    final searchPath = cluster['searchPath']?.toString();
    final children = clusterChildrenMap[clusterId] ?? [];
    final isSelected = selectedClusterId == clusterId;
    final hasActualChildren = children.isNotEmpty && searchQuery.isEmpty;
    final isExpanded = expandedClusters[clusterId] ?? false;

    // Constrained margins to prevent overflow
    final leftMargin = (4.0 + (level * 12.0)).clamp(4.0, 48.0); // Clamp max indentation
    final shouldShowDepthIndicator = level > 0;

    if (hasActualChildren) {
      return Container(
        margin: EdgeInsets.only(left: leftMargin, right: 4, top: 1, bottom: 1),
        constraints: const BoxConstraints(minHeight: 40), // Minimum height constraint
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ExpansionTile(
              key: Key('expansion_$clusterId'),
              dense: true,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              childrenPadding: EdgeInsets.zero,
              maintainState: true,
              initiallyExpanded: isExpanded,
              backgroundColor: isSelected ? const Color(0xFF8E44AD).withOpacity(0.08) : null,
              collapsedBackgroundColor: isSelected ? const Color(0xFF8E44AD).withOpacity(0.05) : null,
              iconColor: const Color(0xFF8E44AD),
              collapsedIconColor: const Color(0xFF8E44AD),
              title: GestureDetector(
                onTap: () => _onClusterTap(clusterId, clusterName),
                child: _buildClusterContent(cluster, isSelected, level, searchPath, shouldShowDepthIndicator),
              ),
              onExpansionChanged: (expanded) async {
                setState(() {
                  expandedClusters[clusterId] = expanded;
                });
                if (expanded && mounted) {
                  await _loadClusterChildren(clusterId);
                }
              },
              children: children.map((child) => _buildClusterTile(child, level: level + 1)).toList(),
            ),
          ),
        ),
      );
    } else {
      return Container(
        margin: EdgeInsets.only(left: leftMargin, right: 4, top: 1, bottom: 1),
        constraints: const BoxConstraints(minHeight: 40), // Minimum height constraint
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _onClusterTap(clusterId, clusterName),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _buildClusterContent(cluster, isSelected, level, searchPath, shouldShowDepthIndicator),
            ),
          ),
        ),
      );
    }
  }

  // Fixed cluster content with proper overflow handling
  Widget _buildClusterContent(Map<String, dynamic> cluster, bool isSelected, int level, String? searchPath, bool shouldShowDepthIndicator) {
    final clusterId = cluster['id']?.toString() ?? '';
    final clusterName = cluster['name']?.toString() ?? 'Unnamed';

    return Container(
      constraints: const BoxConstraints(minHeight: 36, maxHeight: 60), // Height constraints
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
          colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF333333)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? Colors.white.withOpacity(0.3)
              : const Color(0xFF8E44AD).withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Constrained depth indicators
          if (shouldShowDepthIndicator)
            Container(
              width: 20, // Fixed width for depth indicators
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(
                    (level - 1).clamp(0, 2),
                        (index) => Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  if (level > 2)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'L$level',
                        style: const TextStyle(
                          fontSize: 7,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Container(
            width: 24, // Fixed width
            height: 24, // Fixed height
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFF8E44AD).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              level == 0 ? Icons.folder : Icons.article,
              size: 12,
              color: isSelected ? Colors.white : const Color(0xFF8E44AD),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clusterName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (searchPath != null && searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Path: $searchPath',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.orange.withOpacity(0.8),
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
                Text(
                  'ID: ${clusterId.length > 12 ? '${clusterId.substring(0, 12)}...' : clusterId}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (isSelected)
            const SizedBox(
              width: 16, // Fixed width
              height: 16, // Fixed height
              child: Icon(Icons.check_circle, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }

  // Fixed breadcrumb navigation with proper constraints
  Widget _buildBreadcrumbNavigation() {
    if (pathClusters.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 80), // Height constraint
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF3A3A3A)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8E44AD).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.navigation, color: Color(0xFF8E44AD), size: 12),
              SizedBox(width: 6),
              Text(
                'Navigation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 24, // Fixed height for horizontal list
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pathClusters.length + 1, // +1 for home button
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Home button that refreshes data
                  return GestureDetector(
                    onTap: () async {
                      if (clusters.isNotEmpty) {
                        final rootCluster = clusters.first;
                        final rootId = rootCluster['id']?.toString() ?? '';
                        final rootName = rootCluster['name']?.toString() ?? 'Root';

                        if (rootId.isNotEmpty && rootId != selectedClusterId) {
                          await _onClusterTap(rootId, rootName);
                        }
                      }
                    },
                    child: Container(
                      width: 28, // Fixed width
                      height: 24, // Fixed height
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: selectedClusterId.isEmpty || pathClusters.isEmpty
                            ? const LinearGradient(colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)])
                            : null,
                        color: selectedClusterId.isEmpty || pathClusters.isEmpty
                            ? null
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(Icons.home, color: Colors.white, size: 12),
                    ),
                  );
                }

                final pathIndex = index - 1;
                final pathCluster = pathClusters[pathIndex];
                final isLast = pathCluster['isLast'] as bool? ?? false;
                final clusterName = pathCluster['name']?.toString() ?? 'Unknown';
                final clusterId = pathCluster['id']?.toString() ?? '';

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right, color: Colors.grey, size: 12),
                    ),
                    GestureDetector(
                      onTap: isLast ? null : () async {
                        if (clusterId.isNotEmpty && clusterId != selectedClusterId && mounted) {
                          await _onClusterTap(clusterId, clusterName);
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 80, minWidth: 20), // Width constraints
                        height: 24, // Fixed height
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isLast
                              ? const LinearGradient(colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)])
                              : null,
                          color: isLast ? null : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isLast
                                ? Colors.white.withOpacity(0.3)
                                : const Color(0xFF8E44AD).withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            clusterName,
                            style: TextStyle(
                              color: isLast ? Colors.white : Colors.grey[300],
                              fontSize: 9,
                              fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Drawer(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(const Color(0xFF1A0A2E), const Color(0xFF2D1B47), _backgroundAnimation.value)!,
                  Color.lerp(const Color(0xFF2D1B47), const Color(0xFF3D2766), _backgroundAnimation.value)!,
                  Color.lerp(const Color(0xFF3D2766), const Color(0xFF1A0A2E), _backgroundAnimation.value)!,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Fixed Header with proper constraints
                Container(
                  height: 100, // Fixed header height
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA), Color(0xFFAB47BC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const SafeArea(
                    child: Center(
                      child: Text(
                        'CONTROLLER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // Expanded scrollable content
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Cluster Section Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: _buildDrawerItem(
                            Icons.storage_outlined,
                            'Clusters (${filteredClusters.length})',
                            _toggleClusterSection,
                            widget.selectedScreen == 'cluster',
                            trailing: AnimatedRotation(
                              turns: showClusterSection ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Animated cluster content with proper constraints
                      SliverToBoxAdapter(
                        child: AnimatedBuilder(
                          animation: _clusterAnimation,
                          builder: (context, child) {
                            return SizeTransition(
                              sizeFactor: _clusterAnimation,
                              axisAlignment: -1.0,
                              child: FadeTransition(
                                opacity: _clusterAnimation,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen height
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Search bar
                                      _buildSearchBar(),

                                      // Breadcrumb navigation
                                      _buildBreadcrumbNavigation(),

                                      // Current cluster info
                                      if (selectedClusterName.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                          height: 50, // Fixed height
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF8E44AD).withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 20, // Fixed width
                                                height: 20, // Fixed height
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Icon(Icons.check_circle, color: Colors.white, size: 12),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Text(
                                                      'Active Cluster',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      selectedClusterName,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Loading/Empty State with constraints
                      if (showClusterSection && isLoadingClusters)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            height: 80, // Fixed height
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2A2A2A), Color(0xFF3A3A3A)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF8E44AD).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Loading clusters...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (showClusterSection && filteredClusters.isEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(minHeight: 100, maxHeight: 120), // Height constraints
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2A2A2A), Color(0xFF3A3A3A)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_off,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'No clusters found matching "$searchQuery"'
                                      : 'No clusters available',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Search is global across all clusters',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Constrained Cluster List with maximum height to prevent overflow
                      if (showClusterSection && filteredClusters.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.3, // Max 30% of screen height
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              itemCount: filteredClusters.length,
                              itemBuilder: (context, index) {
                                return _buildClusterTile(filteredClusters[index]);
                              },
                            ),
                          ),
                        ),

                      // Divider
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          height: 0.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Other drawer items with proper spacing
                      SliverToBoxAdapter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDrawerItem(
                              Icons.home_rounded,
                              'Home',
                                  () => widget.onSelectScreen('home'),
                              widget.selectedScreen == 'home',
                            ),
                            _buildDrawerItem(
                              Icons.people_rounded,
                              'Client',
                                  () => widget.onSelectScreen('client'),
                              widget.selectedScreen == 'client',
                            ),
                            _buildDrawerItem(
                              Icons.dashboard_rounded,
                              'Dashboard',
                                  () => widget.onSelectScreen('dashboard'),
                              widget.selectedScreen == 'dashboard',
                            ),
                            _buildDrawerItem(
                              Icons.receipt_long_rounded,
                              'Audit',
                                  () => widget.onSelectScreen('audit'),
                              widget.selectedScreen == 'audit',
                            ),
                            _buildDrawerItem(
                              Icons.devices_other_rounded,
                              'Appliances',
                                  () => widget.onSelectScreen('appliances'),
                              widget.selectedScreen == 'appliances',
                            ),
                            const SizedBox(height: 20), // Bottom padding
                          ],
                        ),
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
}