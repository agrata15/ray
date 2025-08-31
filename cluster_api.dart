import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'token_api.dart';
import 'config.dart';// Make sure this provides TokenManager.getToken()

class MainApiService {
  static const String baseUrl = '${Config.baseUrl}';
  static Map<String, String> _authHeader(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 🔹 Get cluster list
  static Future<http.Response> getClusterView(String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/view');
    try {
      print('🔷 GET $url');
      final response = await http.get(url, headers: _authHeader(token));
      print('📥 Status: ${response.statusCode}');
      print('📥 Body: ${response.body}');
      return response;
    } catch (e) {
      print('❌ Error in getClusterView: $e');
      rethrow;
    }
  }

  // 🔹 Get current cluster path
  static Future<http.Response> getClusterPath(String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/path');
    try {
      print('🧭 GET $url');
      final response = await http.get(url, headers: _authHeader(token));
      print('📍 Path Status: ${response.statusCode}');
      print('📍 Path Body: ${response.body}');
      return response;
    } catch (e) {
      print('❌ Error in getClusterPath: $e');
      rethrow;
    }
  }

  // 🔹 Get child clusters
  static Future<http.Response> getClusterChildren(String clusterId,
      String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/$clusterId/children');
    try {
      print('👶 GET $url');
      final response = await http.get(url, headers: _authHeader(token));
      print('_________📦 Children Status: ${response.statusCode}');
      print('📦 Children Body: ${response.body}');
      return response;
    } catch (e) {
      print('❌ Error in getClusterChildren: $e');
      rethrow;
    }
  }

  // 🔹 Get screens in a cluster
  static Future<http.Response> getClusterScreens(String clusterId,
      String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/$clusterId/screens');
    try {
      print('🖥️ GET $url');
      final response = await http.get(url, headers: _authHeader(token));
      print('📺 Screens Status: ${response.statusCode}');
      print('📺 Screens Body: ${response.body}');
      return response;
    } catch (e) {
      print('❌ Error in getClusterScreens: $e');
      rethrow;
    }
  }
  static Future<void> changeCluster(String clusterId) async {
    try {
      // Get token from SharedPreferences
      String? token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        print('🔄 No token found, refreshing...');
        token = await ApiService.refreshToken();
        if (token == null || token.isEmpty) {
          throw Exception('❌ Failed to get valid token');
        }
      }

      final url = Uri.parse('${Config.baseUrl}/api/switchCluster/$clusterId');
      print('🔄 POST $url');
      print('🔍 Using token: ${token.substring(0, 20)}...');

      var response = await http.post(url, headers: _authHeader(token));
      print('📊 Response status: ${response.statusCode}');
      print('📊 Response body: ${response.body}');

      // Handle expired token
      if (response.statusCode == 401) {
        print('🔄 Token expired, refreshing and retrying...');
        token = await ApiService.refreshToken();
        if (token == null || token.isEmpty) {
          throw Exception('❌ Failed to get valid token after refresh');
        }
        response = await http.post(url, headers: _authHeader(token));
        print('📊 Retry response status: ${response.statusCode}');
        print('📊 Retry response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        print('✅ Cluster switched successfully to: $clusterId');

        // Parse the response and extract the new token
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            String? newToken;

            // Check for id_token first (as shown in your logs)
            if (body.containsKey('id_token')) {
              newToken = body['id_token'].toString();
              print('🔍 Found id_token in response');
            }
            // Also check for token field as fallback
            else if (body.containsKey('token')) {
              newToken = body['token'].toString();
              print('🔍 Found token in response');
            }

            if (newToken != null && newToken is String && newToken.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_token', newToken);
              print('✅ New token saved after cluster switch');
              print('🔍 New token: ${newToken.substring(0, 30)}...');
            } else {
              print('⚠️ No new token found in response');
            }
          }
        } catch (e) {
          print('⚠️ Failed to parse response or extract token: $e');
          // Don't throw error here, cluster switch was successful
        }
      } else {
        print('❌ Failed to switch cluster to $clusterId: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to switch cluster: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in changeCluster: $e');
      rethrow;
    }
  }
  // 🔹 FIXED: Fetch clusters using actual endpoints
  static Future<List<Map<String, dynamic>>> fetchClusters() async {
    try {
      final String endpoint = '${Config.baseUrl}/api/clusters';
      final http.Response response = await ApiService.authorizedGet(endpoint);

      print('🔍 Clusters Response Status: ${response.statusCode}');
      print('🔍 Clusters Raw Response: ${response.body}');

      if (response.statusCode != 200) {
        print('❌ Failed to fetch clusters: ${response.statusCode}');
        return [];
      }

      final dynamic decodedBody = jsonDecode(response.body);

      dynamic dataField;
      if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('data')) {
        dataField = decodedBody['data'];
      } else {
        dataField = decodedBody;
      }

      if (dataField is List) {
        return dataField
            .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (dataField is Map<String, dynamic>) {
        return [dataField];
      } else {
        print('❌ Unexpected data format: ${dataField.runtimeType}');
        return [];
      }
    } catch (e) {
      print('❌ Error in fetchClusters: $e');
      return [];
    }
  }

  // 🔹 NEW: Alternative method using your existing getClusterView
  static Future<List<Map<String, dynamic>>> fetchClustersUsingView() async {
    try {
      // Get token first
      String? token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        print('🔄 No token available, refreshing...');
        await ApiService.refreshToken();
        token = await ApiService.getToken();

        if (token == null || token.isEmpty) {
          throw Exception('Unable to get valid token');
        }
      }

      // Use your existing getClusterView method
      final response = await getClusterView(token);

      // Handle 401 (token expired)
      if (response.statusCode == 401) {
        print('🔄 Token expired, refreshing and retrying...');
        await ApiService.refreshToken();
        token = await ApiService.getToken();

        if (token != null && token.isNotEmpty) {
          final retryResponse = await getClusterView(token);
          return _parseClusterResponse(retryResponse);
        }
      }

      return _parseClusterResponse(response);
    } catch (e) {
      print('❌ Error in fetchClustersUsingView: $e');
      return [];
    }
  }

  // 🔹 NEW: Helper method to parse cluster response
  static List<Map<String, dynamic>> _parseClusterResponse(http.Response response) {
    try {
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('🔍 Parsing cluster response: $responseData');

        // Check if response has a 'data' field
        final dataField = responseData['data'];

        if (dataField != null) {
          if (dataField is List) {
            return List<Map<String, dynamic>>.from(dataField);
          } else if (dataField is Map) {
            return [Map<String, dynamic>.from(dataField)];
          }
        } else {
          // If no 'data' field, check if the response itself is the data
          if (responseData is List) {
            return List<Map<String, dynamic>>.from(responseData);
          } else if (responseData is Map) {
            return [Map<String, dynamic>.from(responseData)];
          }
        }
      }

      print('❌ Failed to parse cluster response: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      return [];
    } catch (e) {
      print('❌ Error parsing cluster response: $e');
      return [];
    }
  }

  // 🔹 NEW: Get comprehensive cluster data
  static Future<Map<String, dynamic>> getClusterData() async {
    try {
      // Get token first
      String? token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        await ApiService.refreshToken();
        token = await ApiService.getToken();

        if (token == null || token.isEmpty) {
          throw Exception('Unable to get valid token');
        }
      }

      // Fetch cluster view and path simultaneously
      final futures = await Future.wait([
        getClusterView(token),
        getClusterPath(token),
      ]);

      final clusterViewResponse = futures[0];
      final clusterPathResponse = futures[1];

      return {
        'clusters': _parseClusterResponse(clusterViewResponse),
        'currentPath': clusterPathResponse.statusCode == 200
            ? jsonDecode(clusterPathResponse.body)
            : null,
        'success': clusterViewResponse.statusCode == 200,
      };
    } catch (e) {
      print('❌ Error in getClusterData: $e');
      return {
        'clusters': <Map<String, dynamic>>[],
        'currentPath': null,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 🔹 NEW: Get cluster details with children and screens
  static Future<Map<String, dynamic>> getClusterDetails(String clusterId) async {
    try {
      // Get token first
      String? token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        await ApiService.refreshToken();
        token = await ApiService.getToken();

        if (token == null || token.isEmpty) {
          throw Exception('Unable to get valid token');
        }
      }

      // Fetch children and screens simultaneously
      final futures = await Future.wait([
        getClusterChildren(clusterId, token),
        getClusterScreens(clusterId, token),
      ]);

      final childrenResponse = futures[0];
      final screensResponse = futures[1];

      return {
        'clusterId': clusterId,
        'children': childrenResponse.statusCode == 200
            ? jsonDecode(childrenResponse.body)
            : [],
        'screens': screensResponse.statusCode == 200
            ? jsonDecode(screensResponse.body)
            : [],
        'success': childrenResponse.statusCode == 200 || screensResponse.statusCode == 200,
      };
    } catch (e) {
      print('❌ Error in getClusterDetails: $e');
      return {
        'clusterId': clusterId,
        'children': [],
        'screens': [],
        'success': false,
        'error': e.toString(),
      };
    }
  }
}