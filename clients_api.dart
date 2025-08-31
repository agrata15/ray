import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiService {
  static const String baseUrl = '${Config.baseUrl}';
  static const String _authUrl = '$baseUrl/api/authenticate';

  // 🔄 Fetch token using POST with proper credentials
  static Future<String?> refreshToken() async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/authenticate'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final String token = response.body.trim();
        if (token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          print('✅ Token refreshed successfully');
          return token;
        }
      }
      print('❌ Token refresh failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error refreshing token: $e');
      return null;
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return token != null && token.isNotEmpty ? token : null;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  // 🔐 Universal authorized request method
  static Future<http.Response> authorizedRequest({
    required String url,
    required String method,
    Map<String, dynamic>? body,
    bool retryOn401 = true,
  }) async {
    String? token = await getToken();

    if (token == null || token.isEmpty) {
      print('🔄 Token is null/empty, refreshing...');
      token = await refreshToken();
      if (token == null || token.isEmpty) {
        throw Exception('Auth token is missing after refresh');
      }
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    print('🌐 Making $method request to: $url');

    http.Response response = await _makeHttpRequest(url, method, headers, body);
    print('📡 $method Response Status: ${response.statusCode}');

    // Retry on 401 if enabled
    if (response.statusCode == 401 && retryOn401) {
      print('🔄 Token expired (401), refreshing and retrying...');
      token = await refreshToken();

      if (token == null || token.isEmpty) {
        throw Exception('Failed to get valid token after refresh');
      }

      final newHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      response = await _makeHttpRequest(url, method, newHeaders, body);
      print('📡 Retry $method Response Status: ${response.statusCode}');
    }

    return response;
  }

  // Helper method to make actual HTTP requests
  static Future<http.Response> _makeHttpRequest(
      String url,
      String method,
      Map<String, String> headers,
      Map<String, dynamic>? body,
      ) async {
    final uri = Uri.parse(url);
    final bodyJson = body != null && body.isNotEmpty ? jsonEncode(body) : null;

    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(uri, headers: headers);
      case 'POST':
        return await http.post(uri, headers: headers, body: bodyJson);
      case 'PUT':
        return await http.put(uri, headers: headers, body: bodyJson);
      case 'DELETE':
        return await http.delete(uri, headers: headers);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  // Convenience methods
  static Future<http.Response> authorizedGet(String url) async {
    return await authorizedRequest(url: url, method: 'GET');
  }

  static Future<http.Response> authorizedPost(String url, Map<String, dynamic> body) async {
    return await authorizedRequest(url: url, method: 'POST', body: body);
  }

  // 🗑️ Clear token (for logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    print('✅ Token cleared');
  }

  // 🔍 Check if token exists
  static Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

// 🌐 Main API Service for Ray App specific endpoints
class MainApiService {
  static const String baseUrl = '${Config.baseUrl}';

  // 🔹 Smart endpoint discovery - tries multiple endpoints with different methods
  static Future<http.Response?> _tryEndpoints({
    required List<String> endpoints,
    required List<String> methods,
    Map<String, dynamic>? body,
  }) async {
    for (String endpoint in endpoints) {
      for (String method in methods) {
        try {
          print('🔍 Trying $method $endpoint');

          final response = await ApiService.authorizedRequest(
            url: endpoint,
            method: method,
            body: body,
            retryOn401: true,
          );

          // Success cases
          if (response.statusCode == 200) {
            print('✅ Success: $method $endpoint returned ${response.statusCode}');
            return response;
          }

          // Skip 404 and 405 errors - try next endpoint/method
          if (response.statusCode == 404 || response.statusCode == 405) {
            print('⚠️ $method $endpoint returned ${response.statusCode} - trying next');
            continue;
          }

          // For other errors (like 401, 403, 500), still return the response
          // as it might contain useful error information
          print('⚠️ $method $endpoint returned ${response.statusCode}');
          return response;

        } catch (e) {
          print('❌ $method $endpoint failed: $e');
          continue;
        }
      }
    }

    print('❌ All endpoint/method combinations failed');
    return null;
  }

  // 🔹 Get cluster list with smart endpoint discovery
  static Future<List<Map<String, dynamic>>> fetchClusters() async {
    try {
      // Define possible cluster endpoints in order of preference
      final clusterEndpoints = [
        '$baseUrl/ray-app/api/clusters/view',      // Your working endpoint
        '$baseUrl/ray-app/api/clusters',           // Standard REST
        '$baseUrl/api/clusters/view',
        '$baseUrl/api/clusters',
        '$baseUrl/clusters/view',
        '$baseUrl/clusters',
      ];

      // Try GET first, then POST for each endpoint
      final methods = ['GET', 'POST'];

      final response = await _tryEndpoints(
        endpoints: clusterEndpoints,
        methods: methods,
      );

      if (response == null) {
        print('❌ All cluster endpoints failed');
        return [];
      }

      return _parseClusterResponse(response);
    } catch (e) {
      print('❌ Error in fetchClusters: $e');
      return [];
    }
  }

  // 🔹 Helper method to parse cluster response
  static List<Map<String, dynamic>> _parseClusterResponse(http.Response response) {
    try {
      print('🔍 Parsing response - Status: ${response.statusCode}');
      print('🔍 Response body: ${response.body}');

      if (response.statusCode != 200) {
        print('❌ Non-200 status code: ${response.statusCode}');
        return [];
      }

      if (response.body.isEmpty) {
        print('❌ Empty response body');
        return [];
      }

      final responseData = jsonDecode(response.body);
      print('🔍 Parsed response type: ${responseData.runtimeType}');

      // Handle different response formats
      List<dynamic> dataList = [];

      if (responseData is List) {
        // Direct array response
        dataList = responseData;
      } else if (responseData is Map) {
        // Check for common data wrapper fields
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            dataList = data;
          } else if (data is Map) {
            dataList = [data];
          }
        } else if (responseData.containsKey('clusters')) {
          final clusters = responseData['clusters'];
          if (clusters is List) {
            dataList = clusters;
          } else if (clusters is Map) {
            dataList = [clusters];
          }
        } else if (responseData.containsKey('items')) {
          final items = responseData['items'];
          if (items is List) {
            dataList = items;
          } else if (items is Map) {
            dataList = [items];
          }
        } else {
          // Treat the entire object as a single item
          dataList = [responseData];
        }
      }

      print('🔍 Data list length: ${dataList.length}');

      // Convert to List<Map<String, dynamic>>
      final result = dataList.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          print('⚠️ Unexpected item type: ${item.runtimeType}');
          return <String, dynamic>{'raw_data': item.toString()};
        }
      }).toList();

      print('✅ Successfully parsed ${result.length} cluster(s)');
      return result;
    } catch (e) {
      print('❌ Error parsing cluster response: $e');
      return [];
    }
  }

  // 🔹 Get current cluster path
  static Future getClusterPath() async {
    try {
      final pathEndpoints = [
        '$baseUrl/ray-app/api/clusters/path',
        '$baseUrl/api/clusters/path',
        '$baseUrl/clusters/path',
      ];

      final response = await _tryEndpoints(
        endpoints: pathEndpoints,
        methods: ['GET', 'POST'],
      );

      if (response?.statusCode == 200) {
        return jsonDecode(response!.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting cluster path: $e');
      return null;
    }
  }

  // 🔹 Get child clusters
  static Future<List<Map<String, dynamic>>> getClusterChildren(String clusterId) async {
    try {
      final childEndpoints = [
        '$baseUrl/ray-app/api/clusters/$clusterId/children',
        '$baseUrl/api/clusters/$clusterId/children',
        '$baseUrl/clusters/$clusterId/children',
      ];

      final response = await _tryEndpoints(
        endpoints: childEndpoints,
        methods: ['GET', 'POST'],
      );

      if (response != null) {
        return _parseClusterResponse(response);
      }
      return [];
    } catch (e) {
      print('❌ Error getting cluster children: $e');
      return [];
    }
  }

  // 🔹 Get screens in a cluster
  static Future<List<Map<String, dynamic>>> getClusterScreens(String clusterId) async {
    try {
      final screenEndpoints = [
        '$baseUrl/ray-app/api/clusters/$clusterId/screens',
        '$baseUrl/api/clusters/$clusterId/screens',
        '$baseUrl/clusters/$clusterId/screens',
      ];

      final response = await _tryEndpoints(
        endpoints: screenEndpoints,
        methods: ['GET', 'POST'],
      );

      if (response != null) {
        return _parseClusterResponse(response);
      }
      return [];
    } catch (e) {
      print('❌ Error getting cluster screens: $e');
      return [];
    }
  }

  // 🔹 Switch current cluster
  static Future<bool> switchCluster(String clusterId) async {
    try {
      final switchEndpoints = [
        '$baseUrl/ray-app/api/switchCluster/$clusterId',
        '$baseUrl/api/switchCluster/$clusterId',
        '$baseUrl/switchCluster/$clusterId',
      ];

      final response = await _tryEndpoints(
        endpoints: switchEndpoints,
        methods: ['POST', 'PUT'],
        body: {'clusterId': clusterId},
      );

      return response?.statusCode == 200;
    } catch (e) {
      print('❌ Error switching cluster: $e');
      return false;
    }
  }

  // 🔹 Get comprehensive cluster data
  static Future<Map<String, dynamic>> getAllClusterData() async {
    try {
      final results = await Future.wait([
        fetchClusters(),
        getClusterPath(),
      ]);

      return {
        'clusters': results[0] as List<Map<String, dynamic>>,
        'currentPath': results[1] as Map<String, dynamic>?,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting all cluster data: $e');
      return {
        'clusters': <Map<String, dynamic>>[],
        'currentPath': null,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // 🔹 Diagnostic method to test all endpoints
  static Future<Map<String, dynamic>> testAllEndpoints() async {
    final results = <String, dynamic>{};

    final testEndpoints = [
      '$baseUrl/ray-app/api/clusters/view',
      '$baseUrl/ray-app/api/clusters',
      '$baseUrl/api/clusters/view',
      '$baseUrl/api/clusters',
      '$baseUrl/clusters/view',
      '$baseUrl/clusters',
    ];

    for (String endpoint in testEndpoints) {
      for (String method in ['GET', 'POST']) {
        try {
          final response = await ApiService.authorizedRequest(
            url: endpoint,
            method: method,
            retryOn401: false, // Don't retry for diagnostics
          );

          results['$method $endpoint'] = {
            'status': response.statusCode,
            'body_length': response.body.length,
            'success': response.statusCode == 200,
          };
        } catch (e) {
          results['$method $endpoint'] = {
            'error': e.toString(),
            'success': false,
          };
        }
      }
    }

    return results;
  }
}