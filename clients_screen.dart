import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'clients_api.dart' hide MainApiService;
import 'config.dart';
import 'navigation_helper.dart';
import 'cluster_api.dart';
import 'home_screen.dart';

class ClientsScreen extends StatefulWidget {
  @override
  _ClientsScreenState createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> nodes = [];
  List<Map<String, dynamic>> ssids = [];
  String? selectedClusterId;
  String? selectedClusterName;
  List<Map<String, dynamic>> clusterChildren = [];
  List<Map<String, dynamic>> clusterScreens = [];

  // Cluster functionality variables
  List<Map<String, dynamic>> clusters = [];
  Map<String, List<Map<String, dynamic>>> clusterChildrenMap = {};
  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> screens = [];
  List<String> logs = [];
  String clusterPath = '';
  bool showClusterPopup = false;
  String token = '';

  bool isLoading = false;
  bool isLoadingNodes = false;
  bool isLoadingSSIDs = false;
  String? errorMessage;
  String searchQuery = '';
  String statusFilter = 'all';
  String? selectedNodeId;
  String? selectedSSID;
  final TextEditingController searchController = TextEditingController();

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _backgroundAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _refreshData();
    loadTokenAndClusters();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

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
    ).animate(_backgroundAnimationController);
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  // Cluster functionality methods
  void addLog(String message) {
    if (mounted) {
      setState(() {
        logs.insert(0, "[${DateTime.now().toIso8601String().substring(11, 19)}] $message");
      });
    }
  }

  Future<void> loadTokenAndClusters() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token') ?? '';

      if (token.isNotEmpty) {
        addLog("✅ Token found. Fetching cluster list...");
        await fetchClusters();
      } else {
        addLog("❌ Token not found in SharedPreferences");
      }
    } catch (e) {
      addLog("❌ Error loading token: $e");
    }
  }
  Future<void> fetchClusters() async {
    try {
      // Make sure MainApiService is properly imported and available
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/ray-app/api/clusters'), // Adjust endpoint as needed
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 30));

      print("Cluster API Response: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          List<Map<String, dynamic>> clusterList = [];

          if (decoded is List) {
            // Safely convert each item in the list
            for (var item in decoded) {
              if (item is Map<String, dynamic>) {
                clusterList.add(item);
              } else if (item is Map) {
                // Convert Map to Map<String, dynamic>
                clusterList.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (decoded is Map<String, dynamic>) {
            // Handle different possible response structures
            if (decoded.containsKey('data') && decoded['data'] is List) {
              final dataList = decoded['data'] as List;
              for (var item in dataList) {
                if (item is Map<String, dynamic>) {
                  clusterList.add(item);
                } else if (item is Map) {
                  clusterList.add(Map<String, dynamic>.from(item));
                }
              }
            } else if (decoded.containsKey('clusters') && decoded['clusters'] is List) {
              final clustersList = decoded['clusters'] as List;
              for (var item in clustersList) {
                if (item is Map<String, dynamic>) {
                  clusterList.add(item);
                } else if (item is Map) {
                  clusterList.add(Map<String, dynamic>.from(item));
                }
              }
            } else if (decoded.containsKey('items') && decoded['items'] is List) {
              final itemsList = decoded['items'] as List;
              for (var item in itemsList) {
                if (item is Map<String, dynamic>) {
                  clusterList.add(item);
                } else if (item is Map) {
                  clusterList.add(Map<String, dynamic>.from(item));
                }
              }
            } else {
              // If the entire response is a single cluster object
              clusterList = [decoded];
            }
          }

          setState(() {
            clusters = clusterList;
          });

          addLog('✅ Loaded ${clusters.length} clusters');

          // Load current cluster info
          await loadCurrentClusterInfo();
        }
      } else {
        addLog('❌ Failed to fetch clusters. Status: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('Error response: ${response.body}');
        }
      }
    } catch (e) {
      addLog('❌ Error loading clusters: $e');
      print('Cluster fetch error: $e');
    }
  }

  Future<void> loadCurrentClusterInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      selectedClusterId = prefs.getString('selected_cluster_id');
      selectedClusterName = prefs.getString('selected_cluster_name');

      if (selectedClusterId != null) {
        addLog('📍 Current cluster: $selectedClusterName ($selectedClusterId)');
      }
    } catch (e) {
      addLog('❌ Error loading current cluster info: $e');
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
      });

      addLog('🔄 Switching to cluster: $clusterId');

      // Load cluster details
      await Future.wait([
        loadClusterChildren(clusterId, clusterName),
        loadClusterScreens(clusterId),
        loadClusterPath(),
      ]);

      addLog('✅ Cluster data loaded successfully');

    } catch (e) {
      addLog('❌ Error on cluster tap: $e');
      print('Cluster tap error: $e');
    }
  }

  Future<void> loadClusterChildren(String clusterId, String clusterName) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/ray-app/api/clusters/$clusterId/children'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<Map<String, dynamic>> childrenList = [];

        if (decoded is List) {
          // Safely convert each item in the list
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              childrenList.add(item);
            } else if (item is Map) {
              childrenList.add(Map<String, dynamic>.from(item));
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is List) {
            final dataList = decoded['data'] as List;
            for (var item in dataList) {
              if (item is Map<String, dynamic>) {
                childrenList.add(item);
              } else if (item is Map) {
                childrenList.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (decoded.containsKey('children') && decoded['children'] is List) {
            final childrenListRaw = decoded['children'] as List;
            for (var item in childrenListRaw) {
              if (item is Map<String, dynamic>) {
                childrenList.add(item);
              } else if (item is Map) {
                childrenList.add(Map<String, dynamic>.from(item));
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            clusterChildrenMap[clusterId] = childrenList;
            children = childrenList;
          });
          addLog('👶 Found ${childrenList.length} child clusters for $clusterName');
        }
      } else {
        addLog('❌ Failed to load children for $clusterName. Status: ${response.statusCode}');
      }
    } catch (e) {
      addLog('❌ Error loading children for $clusterName: $e');
      print('Children loading error: $e');
    }
  }

  Future<void> loadClusterScreens(String clusterId) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/ray-app/api/clusters/$clusterId/screens'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<Map<String, dynamic>> screensList = [];

        if (decoded is List) {
          // Safely convert each item in the list
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              screensList.add(item);
            } else if (item is Map) {
              screensList.add(Map<String, dynamic>.from(item));
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is List) {
            final dataList = decoded['data'] as List;
            for (var item in dataList) {
              if (item is Map<String, dynamic>) {
                screensList.add(item);
              } else if (item is Map) {
                screensList.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (decoded.containsKey('screens') && decoded['screens'] is List) {
            final screensListRaw = decoded['screens'] as List;
            for (var item in screensListRaw) {
              if (item is Map<String, dynamic>) {
                screensList.add(item);
              } else if (item is Map) {
                screensList.add(Map<String, dynamic>.from(item));
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            screens = screensList;
          });
          addLog('🖥️ Found ${screensList.length} screens');
        }
      }
    } catch (e) {
      addLog('❌ Error loading screens: $e');
    }
  }

  Future<void> loadClusterPath() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/ray-app/api/clusters/path'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String path = '';

        if (decoded is Map<String, dynamic>) {
          path = decoded['path']?.toString() ?? decoded['clusterPath']?.toString() ?? '';
        } else if (decoded is String) {
          path = decoded;
        }

        if (mounted) {
          setState(() {
            clusterPath = path;
          });
          addLog('🧭 Path: $clusterPath');
        }
      }
    } catch (e) {
      addLog('❌ Error loading cluster path: $e');
    }
  }

  Future<void> switchToCluster(String clusterId, String clusterName) async {
    try {
      addLog('🔄 Switching to cluster: $clusterName ($clusterId)');

      // Call cluster switch API
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/ray-app/api/clusters/$clusterId/switch'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        addLog('✅ Cluster switched successfully');

        // Update preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_cluster_id', clusterId);
        await prefs.setString('selected_cluster_name', clusterName);

        // Update token if provided in response
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded.containsKey('token')) {
            String newToken = decoded['token'].toString();
            await prefs.setString('auth_token', newToken);
            setState(() {
              token = newToken;
            });
          }
        } catch (e) {
          // Handle JSON decode errors gracefully
          print('Token update error: $e');
        }

        if (mounted) {
          setState(() {
            selectedClusterName = clusterName;
            selectedClusterId = clusterId;
          });

          hideClusterPopupCard();

          // Navigate to home screen with new cluster
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                key: ValueKey('home_${clusterId}'),
                selectedClusterId: clusterId,
              ),
            ),
                (route) => false,
          );
        }
      } else {
        addLog('❌ Failed to switch cluster. Status: ${response.statusCode}');
      }
    } catch (e) {
      addLog('❌ Error switching cluster: $e');
      print('Cluster switch error: $e');
    }
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

  // Get authentication token
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Refresh all data
  Future<void> _refreshData() async {
    await Future.wait([
      _loadNodesFromCache(),
      _loadSSIDsFromCache(),
    ]);
    await _loadClientsFromCache();
  }

  // Load nodes from cache/API
  Future<void> _loadNodesFromCache() async {
    try {
      String? token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        throw Exception("Authentication token not available");
      }

      String apiUrl = '${Config.baseUrl}/ray-app/api/nodes;;searchInChild=false;pagination=false;isForSDWan=true;status=ONLINE;includeDetails=basic?isLessData=true';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<Map<String, dynamic>> fetchedNodes = [];

        if (decoded is List) {
          fetchedNodes = decoded.map<Map<String, dynamic>>((e) =>
          Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
        } else if (decoded is Map) {
          final dynamic data = decoded['data'] ?? decoded['nodes'] ?? decoded['items'];
          if (data is List) {
            fetchedNodes = data.map<Map<String, dynamic>>((e) =>
            Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
          }
        }

        setState(() {
          nodes = fetchedNodes;
        });
        print('Successfully loaded ${nodes.length} nodes');
      }
    } catch (e) {
      print('Error loading nodes: $e');
    }
  }

  // Enhanced SSID loading with comprehensive debugging
  Future<void> _loadSSIDsFromCache() async {
    try {
      String? token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        throw Exception("Authentication token not available");
      }

      String apiUrl = '${Config.baseUrl}/ray-app/api/ssids;published=true;pagination=false;instance.rayDefinition.type.code=wlan';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<Map<String, dynamic>> fetchedSSIDs = [];

        if (decoded is List) {
          fetchedSSIDs = decoded.map<Map<String, dynamic>>((e) =>
          Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
        } else if (decoded is Map) {
          final possibleKeys = [
            'data', 'ssids', 'items', 'networks', 'results',
            'raySSIDDTOS', 'ssidList', 'networkList', 'content'
          ];

          for (String key in possibleKeys) {
            if (decoded.containsKey(key) && decoded[key] is List) {
              final List<dynamic> dataList = decoded[key] as List<dynamic>;
              fetchedSSIDs = dataList.map<Map<String, dynamic>>((e) =>
              Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
              break;
            }
          }
        }

        setState(() {
          ssids = fetchedSSIDs;
        });

        print('✅ Successfully loaded ${ssids.length} SSIDs');
      }
    } catch (e) {
      print('❌ Error loading SSIDs: $e');
    }
  }

  // Enhanced client loading
  Future<void> _loadClientsFromCache() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      String? token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        throw Exception("Authentication token not available. Please login again.");
      }

      List<Map<String, dynamic>> allClients = [];

      List<String> apMacAddresses = nodes
          .where((node) => node.containsKey('macAddress') && node['macAddress'] != null)
          .map((node) => node['macAddress'].toString())
          .where((mac) => mac.isNotEmpty)
          .toSet()
          .toList();

      if (apMacAddresses.isEmpty) {
        apMacAddresses = ["28:b7:7c:e0:c9:c0"];
      }

      print('🔄 Loading clients for ${ssids.length} SSIDs...');

      for (int index = 0; index < ssids.length; index++) {
        var ssid = ssids[index];
        int? uniqueId = _extractUniqueId(ssid);
        String? ssidName = _extractSSIDName(ssid);

        if (uniqueId == null || ssidName == null) continue;

        final payload = {
          "apMacAddresses": apMacAddresses,
          "uniqueId": uniqueId
        };

        try {
          final response = await http.post(
            Uri.parse('${Config.baseUrl}/ray-stats/api/stations/cache'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payload),
          ).timeout(Duration(seconds: 30));

          if (response.statusCode == 200 && response.body.isNotEmpty) {
            final decoded = json.decode(response.body);
            List<Map<String, dynamic>> ssidClients = [];

            if (decoded is List) {
              ssidClients = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            } else if (decoded is Map) {
              final Map<String, dynamic> decodedMap = Map<String, dynamic>.from(decoded);
              const possibleKeys = ['data', 'items', 'clients', 'results', 'rayStationDTOS', 'stations'];

              for (String key in possibleKeys) {
                if (decodedMap.containsKey(key) && decodedMap[key] is List) {
                  ssidClients = (decodedMap[key] as List).whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e)).toList();
                  break;
                }
              }
            }

            for (var client in ssidClients) {
              String finalSSIDName = ssidName;
              if (ssidName.toLowerCase() == 'raystaff') {
                finalSSIDName = 'rayemp';
              }

              client['ssid'] = finalSSIDName;
              client['networkName'] = finalSSIDName;
              client['connectedSSID'] = finalSSIDName;
              client['_sourceSSID'] = ssidName;
              client['_uniqueId'] = uniqueId;
            }

            allClients.addAll(ssidClients);
          }
        } catch (e) {
          print('❌ Error loading clients for SSID $ssidName: $e');
          continue;
        }

        await Future.delayed(Duration(milliseconds: 200));
      }

      setState(() {
        clients = allClients;
      });

      print('🎉 Successfully loaded ${clients.length} total clients');

    } catch (e) {
      print('❌ Error loading clients: $e');
      setState(() => errorMessage = 'Failed to load connected clients: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Helper methods
  String? _extractSSIDName(Map<String, dynamic> ssidData) {
    const possibleNameFields = ['name', 'ssidName', 'networkName', 'ssid', 'wifiName'];

    for (String field in possibleNameFields) {
      if (ssidData.containsKey(field) &&
          ssidData[field] != null &&
          ssidData[field].toString().isNotEmpty) {
        return ssidData[field].toString();
      }
    }

    if (ssidData.containsKey('instance') && ssidData['instance'] is Map) {
      final instance = ssidData['instance'] as Map<String, dynamic>;
      for (String field in possibleNameFields) {
        if (instance.containsKey(field) &&
            instance[field] != null &&
            instance[field].toString().isNotEmpty) {
          return instance[field].toString();
        }
      }
    }

    return null;
  }

  int? _extractUniqueId(Map<String, dynamic> ssidData) {
    const possibleIdFields = ['uniqueId', 'id', 'ssidId', 'networkId'];

    for (String field in possibleIdFields) {
      if (ssidData.containsKey(field) && ssidData[field] != null) {
        final value = ssidData[field];
        if (value is int) return value;
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }

    if (ssidData.containsKey('instance') && ssidData['instance'] is Map) {
      final instance = ssidData['instance'] as Map<String, dynamic>;
      for (String field in possibleIdFields) {
        if (instance.containsKey(field) && instance[field] != null) {
          final value = instance[field];
          if (value is int) return value;
          if (value is String) {
            final parsed = int.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
      }
    }

    return null;
  }

  List<String> get availableSSIDs {
    final ssidNames = <String>{};
    for (var ssid in ssids) {
      final name = _extractSSIDName(ssid);
      if (name != null && name.isNotEmpty) ssidNames.add(name);
    }
    return ssidNames.map((s) => s.toLowerCase() == 'raystaff' ? 'rayemp' : s).toList()..sort();
  }

  int getClientCountForSSID(String ssidName) {
    return clients.where((client) => _matchesSSIDFilter(client, ssidName)).length;
  }

  List<Map<String, dynamic>> get filteredClients {
    return clients.where((client) {
      final matchesSSID = selectedSSID == null || _matchesSSIDFilter(client, selectedSSID!);
      final matchesSearch = searchQuery.isEmpty || _matchesSearchQuery(client, searchQuery);
      return matchesSSID && matchesSearch;
    }).toList();
  }

  bool _matchesSearchQuery(Map<String, dynamic> client, String query) {
    final lowerQuery = query.toLowerCase();
    final searchFields = [
      'username', 'clientMacAddress', 'clientIpv4Address', 'hostname',
      'deviceType', 'manufacturer', 'ssid', 'networkName'
    ];

    for (String field in searchFields) {
      if (client.containsKey(field) && client[field] != null) {
        if (client[field].toString().toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _matchesSSIDFilter(Map<String, dynamic> client, String selectedSSIDName) {
    final ssidFields = ['ssid', 'networkName', 'connectedSSID'];
    for (var field in ssidFields) {
      if (client.containsKey(field) &&
          client[field] != null &&
          client[field].toString().toLowerCase() == selectedSSIDName.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  // Build ice background
  Widget _buildIceBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Color(0xFF0A0A0A), Color(0xFF1A0A2E), _backgroundAnimation.value)!,
                Color.lerp(Color(0xFF1A0A2E), Color(0xFF2D1B47), _backgroundAnimation.value)!,
                Color.lerp(Color(0xFF2D1B47), Color(0xFF3D2766), _backgroundAnimation.value)!,
                Color.lerp(Color(0xFF3D2766), Color(0xFF4A1A5C), _backgroundAnimation.value)!,
              ],
            ),
          ),
          child: Container(),
        );
      },
    );
  }

  // Build cluster popup
  Widget _buildClusterPopupCard() {
    final filteredClusters = clusters.where((c) =>
    c['id'] != null &&
        c['id'] != 'fallback' &&
        c['name'] != null
    ).toList();

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
                  width: MediaQuery.of(context).size.width * 0.92,
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A0A0A), Color(0xFF1A0A2E), Color(0xFF2D1B47)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Color(0xFF8E44AD).withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF8E44AD).withOpacity(0.4),
                        blurRadius: 40,
                        offset: Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA), Color(0xFF7B1FA2)],
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
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.account_tree_rounded, color: Colors.white, size: 28),
                            ),
                            SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cluster Hierarchy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${filteredClusters.length} clusters available',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (selectedClusterName != null) ...[
                                    SizedBox(height: 4),
                                    Text(
                                      'Current: $selectedClusterName',
                                      style: TextStyle(
                                        color: Colors.cyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.white, size: 24),
                              onPressed: hideClusterPopupCard,
                            ),
                          ],
                        ),
                      ),
                      // Body
                      Expanded(
                        child: filteredClusters.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off, size: 64, color: Colors.white.withOpacity(0.5)),
                              SizedBox(height: 16),
                              Text(
                                'No clusters found',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Check your connection and try again',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await fetchClusters();
                                },
                                icon: Icon(Icons.refresh),
                                label: Text('Refresh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF8E44AD),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          padding: EdgeInsets.all(20),
                          itemCount: filteredClusters.length,
                          itemBuilder: (context, index) {
                            return _buildPopupClusterTile(
                              filteredClusters[index],
                              level: 0,
                              uniqueKey: 'popup_$index',
                            );
                          },
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
    final isCurrentCluster = clusterId == selectedClusterId;

    // Get children for this cluster
    final children = clusterChildrenMap[clusterId] ?? [];
    final hasChildren = children.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(left: level * 20.0, right: 8.0, top: 6.0, bottom: 6.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentCluster
              ? [Color(0xFF4CAF50), Color(0xFF66BB6A)]
              : level == 0
              ? [Color(0xFF2D1B47), Color(0xFF3D2766)]
              : [Color(0xFF1A0A2E), Color(0xFF2D1B47)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isCurrentCluster
                ? Colors.green.withOpacity(0.5)
                : Color(0xFF8E44AD).withOpacity(0.3)
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
          maintainState: true,
          title: GestureDetector(
            onTap: () async {
              if (isCurrentCluster) {
                addLog('ℹ️ Already in cluster: $clusterName');
                return;
              }

              await switchToCluster(clusterId, clusterName);
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clusterName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentCluster ? Colors.white : Colors.cyan,
                          decoration: isCurrentCluster ? null : TextDecoration.underline,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: $clusterId',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12
                        ),
                      ),
                      if (isCurrentCluster) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'CURRENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          leading: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCurrentCluster
                    ? [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.6)]
                    : [Color(0xFF8E44AD), Color(0xFFAB47BC)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                isCurrentCluster ? Icons.check_circle : Icons.folder_rounded,
                size: 20,
                color: isCurrentCluster ? Color(0xFF4CAF50) : Colors.white
            ),
          ),
          trailing: hasChildren
              ? Icon(Icons.expand_more, color: Colors.white)
              : SizedBox.shrink(),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          onExpansionChanged: (expanded) async {
            if (expanded && children.isEmpty) {
              // Load children on expansion
              await loadClusterChildren(clusterId, clusterName);
            }
          },
          children: children.isEmpty
              ? [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white.withOpacity(0.6), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'No child clusters available',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12
                    ),
                  ),
                ],
              ),
            ),
          ]
              : children
              .map((child) => _buildPopupClusterTile(
            child,
            level: level + 1,
            uniqueKey: '${uniqueKey}_${child['id']}',
          ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildIceBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(140),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A0A0A), Color(0xFF1A0A2E), Color(0xFF2D1B47)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // AppBar
                    Container(
                      height: 56,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              icon: Icon(Icons.menu, color: Colors.white),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          Text(
                            "Connected Clients",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              letterSpacing: 1,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.white),
                            onPressed: _refreshData,
                          ),
                        ],
                      ),
                    ),
                    // Tab Bar
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A0A2E), Color(0xFF2D1B47)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Settings Tab
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF3282B8).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.settings, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Settings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          // Clusters Tab
                          GestureDetector(
                            onTap: showClusterPopupCard,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF8E44AD).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.account_tree_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Clusters (${clusters.length})',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          drawer: AppDrawer(
            selectedScreen: 'client',
            onSelectScreen: (screen) {
              Navigator.pop(context);
              NavigationHelper.navigateTo(context, screen);
            },
          ),
          body: Column(
            children: [
              // Search and Filter Section
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A0A2E).withOpacity(0.8),
                      Color(0xFF2D1B47).withOpacity(0.8),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Search Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search clients by name, MAC, IP, device type...',
                          hintStyle: TextStyle(color: Colors.white60),
                          prefixIcon: Icon(Icons.search, color: Colors.white70),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xFF8E44AD),
                              width: 2,
                            ),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              searchController.clear();
                              setState(() => searchQuery = '');
                            },
                          )
                              : null,
                        ),
                        onChanged: (value) => setState(() => searchQuery = value),
                      ),
                    ),
                    SizedBox(height: 16),

                    // SSID Filter Chips
                    if (availableSSIDs.isNotEmpty)
                      Container(
                        height: 50,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // All SSIDs chip
                            Container(
                              margin: EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text('All SSIDs (${clients.length})'),
                                selected: selectedSSID == null,
                                selectedColor: Color(0xFF8E44AD).withOpacity(0.8),
                                backgroundColor: Colors.black.withOpacity(0.3),
                                labelStyle: TextStyle(
                                  color: selectedSSID == null ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) => setState(() => selectedSSID = null),
                                showCheckmark: false,
                              ),
                            ),
                            // Individual SSID chips
                            ...availableSSIDs.map((ssid) {
                              int count = getClientCountForSSID(ssid);
                              return Container(
                                margin: EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text('$ssid ($count)'),
                                  selected: selectedSSID == ssid,
                                  selectedColor: Color(0xFF8E44AD).withOpacity(0.8),
                                  backgroundColor: Colors.black.withOpacity(0.3),
                                  labelStyle: TextStyle(
                                    color: selectedSSID == ssid ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (selected) {
                                    setState(() => selectedSSID = selected ? ssid : null);
                                  },
                                  showCheckmark: false,
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                    // Results counter
                    if (selectedSSID != null || searchQuery.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            TextButton.icon(
                              icon: Icon(Icons.clear_all, size: 16, color: Colors.white70),
                              label: Text('Clear Filters', style: TextStyle(color: Colors.white70)),
                              onPressed: () {
                                setState(() {
                                  selectedSSID = null;
                                  searchQuery = '';
                                  searchController.clear();
                                });
                              },
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${filteredClients.length} of ${clients.length} clients',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: _buildMainContent(),
                ),
              ),
            ],
          ),
        ),
        if (showClusterPopup) _buildClusterPopupCard(),
      ],
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF8E44AD).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 4,
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Loading clients...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(32),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.1),
                Colors.red.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8E44AD),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredClients.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(32),
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selectedSSID != null ? Icons.wifi_off : Icons.devices,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Text(
                selectedSSID != null
                    ? 'No clients connected to "$selectedSSID"'
                    : clients.isEmpty
                    ? 'No connected clients found'
                    : 'No clients match your search',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              if (searchQuery.isNotEmpty || selectedSSID != null) ...[
                SizedBox(height: 12),
                Text(
                  'Try adjusting your filters',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredClients.length,
      itemBuilder: (context, index) {
        final client = filteredClients[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.wifi, color: Colors.white, size: 24),
            ),
            title: Text(
              client['username']?.toString() ??
                  client['clientName']?.toString() ??
                  client['hostname']?.toString() ??
                  'Unknown Device',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 16,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Text(
                  'MAC: ${client['clientMacAddress'] ?? client['macAddress'] ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'IP: ${client['clientIpv4Address'] ?? client['ipAddress'] ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                if (client['ssid'] != null || client['networkName'] != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SSID: ${client['ssid'] ?? client['networkName']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (client['deviceType'] != null || client['manufacturer'] != null) ...[
                  SizedBox(height: 6),
                  Text(
                    'Device: ${client['deviceType'] ?? ''} ${client['manufacturer'] ?? ''}'.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                'Connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
  Future<void> _loadClientsForSingleSSID(Map<String, dynamic> ssid, List<String> apMacAddresses, String token, int index) async {
    Future<void> _loadClientsForSingleSSID(
        Map<String, dynamic> ssid,
        List<String> apMacAddresses,
        String token,
        int index
        ) async {
      // This is used for concurrent loading if needed
      // Currently using sequential loading with delays for API rate limiting

      // You can implement the actual loading logic here if needed
      // for true concurrent processing of individual SSIDs

      // Example implementation:
      /*
  int? uniqueId = _extractUniqueId(ssid);
  String? ssidName = _extractSSIDName(ssid);

  if (uniqueId == null || ssidName == null) return;

  final payload = {
    "apMacAddresses": apMacAddresses,
    "uniqueId": uniqueId
  };

  try {
    final response = await http.post(
      Uri.parse('${Config.baseUrl}/ray-stats/api/stations/cache'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    ).timeout(Duration(seconds: 30));

    // Process response and return clients for this SSID
    // Implementation depends on your specific needs

  } catch (e) {
    print('Error loading clients for SSID $ssidName: $e');
    rethrow;
  }
  */
    }

  }

