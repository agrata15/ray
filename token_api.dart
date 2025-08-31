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
      final prefs = await SharedPreferences.getInstance();

      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/authenticate'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // The response body IS the JWT token, not JSON
        final String token = response.body.trim();

        if (token.isNotEmpty) {
          await prefs.setString('auth_token', token);
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

  static Future<String?> getToken({String? switchClusterId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      // If no token, refresh it
      if (token == null || token.isEmpty) {
        print('🔄 No token found, refreshing...');
        token = await refreshToken();
        if (token == null || token.isEmpty) {
          throw Exception('❌ Failed to get valid token');
        }
      }

      // If clusterId is provided → Switch cluster
      if (switchClusterId != null && switchClusterId.isNotEmpty) {
        final url = Uri.parse('${Config.baseUrl}/ray-app/api/switchCluster/$switchClusterId');
        print('🔄 POST $url');
        var response = await http.post(url, headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        });

        // Handle expired token
        if (response.statusCode == 401) {
          print('🔄 Token expired, refreshing and retrying...');
          token = await refreshToken();
          if (token == null || token.isEmpty) throw Exception('❌ Failed to refresh token');
          response = await http.post(url, headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          });
        }

        // Update token if switch cluster response contains a new one
        if (response.statusCode == 200) {
          try {
            final body = jsonDecode(response.body);
            if (body is Map && body.containsKey('token')) {
              final newToken = body['token'];
              if (newToken is String && newToken.isNotEmpty) {
                await prefs.setString('auth_token', newToken);
                token = newToken;
                print('✅ Token updated after cluster switch');
              }
            }
          } catch (e) {
            print('ℹ️ No new token or parsing failed: $e');
          }
          print('✅ Cluster switched successfully');
        } else {
          print('❌ Failed to switch cluster: ${response.body}');
        }
      }

      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  static Future<http.Response> getClients(String? clusterId, String token) async {
    final clusterParam = clusterId != null ? '?clusterId=$clusterId' : '';
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clients$clusterParam');
    try {
      print('🔄 GET $url');
      final response = await http.get(url, headers: _authHeader(token));
      print('🔁 Status: ${response.statusCode}');
      return response;
    } catch (e) {
      print('❌ Error in getClients: $e');
      rethrow;
    }
  }

  static Map<String, String> _authHeader(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
  // 🔐 Authorized GET request
  static Future<http.Response> authorizedGet(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('❌ No token found in SharedPreferences');
    }

    return await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  // 🔐 Authorized POST request
  static Future<http.Response> authorizedPost(String url, {Map<String, dynamic>? body}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('❌ No token found in SharedPreferences');
    }

    return await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body != null ? jsonEncode(body) : null,
    );
  }

  // 🔐 Generic authorized request with auto retry
  static Future<http.Response> authorizedRequest({
    required String url,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    String? token = await getToken();

    if (token == null || token.isEmpty) {
      print('🔄 Token is null/empty, refreshing...');
      token = await refreshToken();
      if (token == null || token.isEmpty) {
        throw Exception('Auth token is missing after refresh');
      }
    }

    print('🌐 Making $method request to: $url');

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    http.Response response = await _makeHttpRequest(method, url, headers, body);

    print('📡 $method Response Status: ${response.statusCode}');

    // Handle 405 Method Not Allowed
    if (response.statusCode == 405) {
      print('❌ Method Not Allowed (405) - $method not supported for $url');
      throw Exception('Method Not Allowed: $method request not supported for $url');
    }

    // Retry on 401
    if (response.statusCode == 401) {
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

      response = await _makeHttpRequest(method, url, newHeaders, body);
      print('📡 Retry $method Response Status: ${response.statusCode}');
    }

    return response;
  }

  // Helper method to make HTTP requests based on method
  static Future<http.Response> _makeHttpRequest(
      String method,
      String url,
      Map<String, String> headers,
      Map<String, dynamic>? body
      ) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(Uri.parse(url), headers: headers);
      case 'POST':
        return await http.post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'PUT':
        return await http.put(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'DELETE':
        return await http.delete(Uri.parse(url), headers: headers);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
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

  static Map<String, String> _authHeader(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 🔹 Get cluster list with method flexibility
  static Future<http.Response> getClusterView(String token, {String method = 'GET'}) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/view');
    try {
      print('🔷 $method $url');

      final headers = _authHeader(token);
      http.Response response;

      if (method.toUpperCase() == 'POST') {
        response = await http.post(url, headers: headers);
      } else {
        response = await http.get(url, headers: headers); // Fixed: Use GET for GET requests
      }

      print('📥 Status: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      // If GET fails with 405, try POST
      if (response.statusCode == 405 && method.toUpperCase() == 'GET') {
        print('🔄 GET failed with 405, trying POST...');
        response = await http.post(url, headers: headers);
        print('📥 POST Status: ${response.statusCode}');
        print('📥 POST Body: ${response.body}');
      }

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
      final response = await http.get(url, headers: _authHeader(token)); // Fixed: Use GET instead of POST
      print('📍 Path Status: ${response.statusCode}');
      print('📍 Path Body: ${response.body}');
      return response;
    } catch (e) {
      print('❌ Error in getClusterPath: $e');
      rethrow;
    }
  }

  // 🔹 Get child clusters
  static Future<http.Response> getClusterChildren(String clusterId, String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/$clusterId/children');
    try {
      print('👶 GET $url');
      final response = await http.get(url, headers: _authHeader(token)); // Fixed: Use GET instead of POST
      print('📦 Children Status: ${response.statusCode}');
      print('📦 Children Body: ${response.body}');
      return response;
    } catch (e) {
      print('❌ Error in getClusterChildren: $e');
      rethrow;
    }
  }

  // 🔹 Get screens in a cluster
  static Future<http.Response> getClusterScreens(String clusterId, String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/$clusterId/screens');
    try {
      print('🖥️ GET $url');
      final response = await http.get(url, headers: _authHeader(token)); // Fixed: Use GET instead of POST
      print('📺 Screens Status: ${response.statusCode}');
      print('📺 Screens Body: ${response.body}');
      return response;
    } catch (e) {
      print('❌ Error in getClusterScreens: $e');
      rethrow;
    }
  }

  // 🔹 Switch current cluster
  static Future<http.Response> switchCluster(String clusterId) async {
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
    final response = await http.post(url, headers: _authHeader(token));

    // Handle token expiry
    if (response.statusCode == 401) {
      print('🔄 Token expired, refreshing and retrying...');
      token = await ApiService.refreshToken();
      if (token != null && token.isNotEmpty) {
        return await http.post(url, headers: _authHeader(token));
      }
    }

    // ✅ If switching returns a new token in body (depends on API design)
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('token')) {
        final newToken = body['token'];
        if (newToken != null && newToken is String && newToken.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', newToken);
          print('✅ Token updated after cluster switch');
        }
      }
    } catch (e) {
      print('ℹ️ No new token in response or failed to parse: $e');
    }

    return response;
  }


  // 🔹 Fetch clusters with better error handling and method flexibility
  static Future<List<Map<String, dynamic>>> fetchClusters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('📦 Token in prefs: ${prefs.getString('auth_token')}');

      // Try different possible cluster endpoints with different methods
      final List<Map<String, String>> endpointConfigs = [
        {'url': '$baseUrl/ray-app/api/clusters/view', 'method': 'GET'},
        {'url': '$baseUrl/ray-app/api/clusters/view', 'method': 'POST'},
        {'url': '$baseUrl/ray-app/api/clusters', 'method': 'GET'},
        {'url': '$baseUrl/ray-app/api/clusters', 'method': 'POST'},
        {'url': '$baseUrl/api/clusters', 'method': 'GET'},
        {'url': '$baseUrl/api/clusters', 'method': 'POST'},
        {'url': '$baseUrl/clusters', 'method': 'GET'},
        {'url': '$baseUrl/clusters', 'method': 'POST'},
      ];

      http.Response? response;

      // Try each endpoint and method combination
      for (Map<String, String> config in endpointConfigs) {
        try {
          String endpoint = config['url']!;
          String method = config['method']!;

          print('🔍 Trying $method $endpoint');

          response = await ApiService.authorizedRequest(
            url: endpoint,
            method: method,
          );

          if (response.statusCode == 200) {
            print('✅ Working endpoint found: $method $endpoint');
            break;
          } else if (response.statusCode != 404 && response.statusCode != 405) {
            // If it's not a 404 or 405, it might be the right endpoint with other issues
            break;
          }
        } catch (e) {
          print('❌ $config failed: $e');
          continue;
        }
      }

      if (response == null) {
        print('❌ All cluster endpoints and methods failed');
        return [];
      }

      print('🔍 Clusters Response Status: ${response.statusCode}');
      print('🔍 Clusters Raw Response: ${response.body}');

      return _parseClusterResponse(response);
    } catch (e) {
      print('❌ Error in fetchClusters: $e');
      return [];
    }
  }

  // 🔹 Fetch clusters with automatic token management
  static Future<List<Map<String, dynamic>>> fetchClustersWithAutoAuth() async {
    try {
      String? token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        print('🔄 No token available, refreshing...');
        token = await ApiService.refreshToken();

        if (token == null || token.isEmpty) {
          throw Exception('Unable to get valid token');
        }
      }

      // Try both GET and POST for the cluster view
      http.Response response = await getClusterView(token, method: 'GET');

      if (response.statusCode == 401) {
        print('🔄 Token expired, refreshing and retrying...');
        token = await ApiService.refreshToken();

        if (token != null && token.isNotEmpty) {
          response = await getClusterView(token, method: 'GET');
        }
      }

      return _parseClusterResponse(response);
    } catch (e) {
      print('❌ Error in fetchClustersWithAutoAuth: $e');
      return [];
    }
  }

  // 🔹 Helper method to parse cluster response
  static List<Map<String, dynamic>> _parseClusterResponse(http.Response response) {
    try {
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('🔍 Parsing response data: $responseData');

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
      return [];
    } catch (e) {
      print('❌ Error parsing cluster response: $e');
      return [];
    }
  }


  // 🔹 Get all cluster data in one call
  static Future<Map<String, dynamic>> getAllClusterData() async {
    try {
      String? token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        token = await ApiService.refreshToken();

        if (token == null || token.isEmpty) {
          throw Exception('Unable to get valid token');
        }
      }

      // Fetch all cluster-related data
      final futures = await Future.wait([
        getClusterView(token),
        getClusterPath(token),
      ]);

      final clusterView = futures[0];
      final clusterPath = futures[1];

      return {
        'clusters': _parseClusterResponse(clusterView),
        'currentPath': clusterPath.statusCode == 200 ? jsonDecode(clusterPath.body) : null,
      };
    } catch (e) {
      print('❌ Error in getAllClusterData: $e');
      return {
        'clusters': <Map<String, dynamic>>[],
        'currentPath': null,
      };
    }
  }
}