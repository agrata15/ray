import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class MainApiService {
  static const String baseUrl = '${Config.baseUrl}';

  /// Login API
  static Future<http.Response> checkIfUserExists(String email) async {
    final url = Uri.parse('${Config.baseUrl}/api/users/isUserExist/$email');
    return await http.get(url);
  }

  static Future<http.Response> getLockDuration(String userId) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/configurations/lockDuration/key/user?userId=$userId');
    return await http.get(url);
  }

  static Future<http.Response> getMaxFailedAttempts(String userId) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/configurations/maxFailedAttempts/key/user?userId=$userId');
    return await http.get(url);
  }

  /// Cloud API
  static Future<http.Response> getAccount(String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/account');
    return await http.get(url, headers: _authHeader(token));
  }

  static Future<http.Response> getUserPermissions(String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/users/permissions');
    return await http.get(url, headers: _authHeader(token));
  }

  static Future<http.Response> getClusterScreens(String clusterId, String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/20b14844-7d45-49e4-8a7a-003a041644b2/screens');
    return await http.get(url, headers: _authHeader(token));
  }

  static Future<http.Response> getClusterView(String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/view');
    return await http.get(url, headers: _authHeader(token));
  }

  static Future<http.Response> getAccessibleClusters(String userId, String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/configurations/realTimeDataFetchTime/key/user?userId=fe2b0f73-f242-422f-aff6-d3bad4ceb39e');
    return await http.get(url, headers: _authHeader(token));
  }

  static Future<http.Response> registerDevice(Map<String, dynamic> payload, String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-notification/api/devices');
    return await http.post(
      url,
      headers: _authHeader(token),
      body: jsonEncode(payload), // ✅ Properly encode payload
    );
  }

  static Future<http.Response> getClusterPath(String token) async {
    final url = Uri.parse('${Config.baseUrl}//ray-app/api/clusters/path');
    return await http.get(url, headers: _authHeader(token));
  }

  static Future<http.Response> getClusterChildren(String clusterId, String token) async {
    final url = Uri.parse('${Config.baseUrl}/ray-app/api/clusters/20b14844-7d45-49e4-8a7a-003a041644b2/children?isLessData=true&sort=name');
    return await http.get(url, headers: _authHeader(token));
  }

  /// Header Builder
  static Map<String, String> _authHeader(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
