import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiServices {
  // 1. Check if MAC exists in Ray Pool
  static Future<Map<String, dynamic>?> checkMacInRayPool(String macAddress) async {
    final uri = Uri.parse("http://192.168.110.44:38099/ray-hub-service/api/nodes/$macAddress/mac");
    print("Formatted MAC going into API: $macAddress");
    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print("Unexpected JSON format");
          return null;
        }
      } else {
        print("MAC Check Failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("MAC Check Error: $e");
      return null;
    }
  }

  // 2. Verify node with MAC, serial code, and node mode
  static Future<bool> verifyNode({
    required String macAddress,
    required String securityCode,
    required String nodeMode,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/ray-app/api/nodes/verify');

    final body = {
      "macAddress": macAddress,
      "securityCode": securityCode,
      "nodeMode": nodeMode,
      "licenceKey": null,
      "regenerateCertificate": false,
    };

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print("✅ Node verified successfully");
        return true;
      } else {
        print("❌ Node verification failed: ${response.statusCode}");
        print("❌ Node verification failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Node verification error: $e");
      return false;
    }
  }
}
