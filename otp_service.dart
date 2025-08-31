import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class OtpService {
  // Helper method to log request and response details
  static void _logApiCall(String stepName, String method, String url,
      Map<String, String> headers, dynamic payload, http.Response response) {
    print("\n" + "="*60);
    print("🔥 API CALL: $stepName");
    print("="*60);
    print("📍 Method: $method");
    print("📍 URL: $url");
    print("📍 Headers: ${jsonEncode(headers)}");

    if (payload != null) {
      print("📤 Request Payload:");
      if (payload is String) {
        print(payload);
      } else {
        print(jsonEncode(payload));
      }
    }

    print("📥 Response Status: ${response.statusCode}");
    print("📥 Response Headers: ${response.headers}");
    print("📥 Response Body:");
    try {
      // Try to pretty print JSON
      final jsonResponse = jsonDecode(response.body);
      print(JsonEncoder.withIndent('  ').convert(jsonResponse));
    } catch (e) {
      // If not JSON, print as string
      print(response.body);
    }
    print("="*60 + "\n");
  }

  static Future<bool> runOtpApisWithToken(
      String otp,
      String macAddress,
      String username,
      String password,
      ) async {
    try {
      // Validate input parameters
      print("🔍 Input Validation:");
      print("OTP: '$otp'");
      print("MAC Address: '$macAddress'");
      print("Username: '$username'");
      print("Password: '${password.isNotEmpty ? '***' : 'EMPTY'}'");

      if (otp.isEmpty) {
        print("❌ OTP is empty!");
        return false;
      }

      if (macAddress.isEmpty) {
        print("❌ MAC Address is empty!");
        return false;
      }

      if (username.isEmpty) {
        print("❌ Username is empty!");
        return false;
      }

      if (password.isEmpty) {
        print("❌ Password is empty!");
        return false;
      }
      // Step 1: Activate account
      final activateUrl = "${Config.baseUrl}/ray-app/api/account/$username/activate";
      final activateHeaders = {'Content-Type': 'application/json'};
      final activatePayload = {
        "otp": otp,
        "macAddress": macAddress,
      };

      final activateRes = await http.post(
        Uri.parse(activateUrl),
        headers: activateHeaders,
        body: jsonEncode(activatePayload),
      );

      _logApiCall("STEP 1 - ACTIVATE ACCOUNT", "POST", activateUrl,
          activateHeaders, activatePayload, activateRes);

      if (activateRes.statusCode != 200) {
        print("❌ Activation failed: ${activateRes.body}");
        return false;
      }

      // Extract clusterId and userId from activation response
      final activationData = jsonDecode(activateRes.body);
      final clusterId = activationData['clusters'][0]['id'];
      final userId = activationData['id'];
      if (clusterId == null || userId == null) {
        print("❌ Invalid activation response: missing cluster ID or user ID");
        return false;
      }

      print("✅ Extracted - Cluster ID: $clusterId, User ID: $userId");

      // Step 2: Authenticate
      final authUrl = "${Config.baseUrl}/api/authenticate";
      final authHeaders = {'Content-Type': 'application/json'};
      final authPayload = {
        "username": username,
        "password": password,
        "rememberMe": true,
      };

      final authRes = await http.post(
        Uri.parse(authUrl),
        headers: authHeaders,
        body: jsonEncode(authPayload),
      );

      _logApiCall("STEP 2 - AUTHENTICATE", "POST", authUrl,
          authHeaders, authPayload, authRes);

      if (authRes.statusCode != 200) {
        print("❌ Authentication failed: ${authRes.body}");
        return false;
      }

      final token = jsonDecode(authRes.body)['id_token'];
      if (token == null || token is! String) {
        print("❌ Invalid token in response: $token");
        return false;
      }

      // 🔐 Print token for debugging
      print("🔐 Retrieved Token: $token");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      print("📦 Token saved in SharedPreferences: $token");

      final authHeader = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 🔄 Refresh cluster children
      final childrenUrl = "${Config.baseUrl}/ray-app/api/clusters/$clusterId/children?sort=name";
      final childrenRes = await http.get(
        Uri.parse(childrenUrl),
        headers: authHeader,
      );

      _logApiCall("REFRESH CLUSTER CHILDREN", "GET", childrenUrl,
          authHeader, null, childrenRes);

      if (childrenRes.statusCode != 200) {
        print("⚠️ Children refresh failed: ${childrenRes.body}");
        return false;
      }

      // Step 3: Add Node
      final addNodeUrl = "${Config.baseUrl}/ray-app/api/clusters/$clusterId/addNodes";

      // Generate security code from MAC address (use last segment or full MAC as needed)
      String securityCode = macAddress.split(":").last;
      if (securityCode.isEmpty) {
        // Fallback: use last 4 characters of MAC address without colons
        securityCode = macAddress.replaceAll(":", "").substring(macAddress.replaceAll(":", "").length >= 4 ? macAddress.replaceAll(":", "").length - 4 : 0);
      }

      print("🔧 Generated Security Code: '$securityCode' from MAC: '$macAddress'");

      final addNodePayload = [
        {
          "nodeMode": "CLIENT",
          "macAddress": macAddress,
          "securityCode": securityCode,
          "skuId": "SUP-TOTAL",
          "isFirstNFR": true
        }
      ];

      // Validate payload before sending
      print("🔍 Add Node Payload Validation:");
      print("MAC Address in payload: '${addNodePayload[0]['macAddress']}'");
      print("Security Code in payload: '${addNodePayload[0]['securityCode']}'");

      if (addNodePayload[0]['macAddress'].toString().isEmpty) {
        print("❌ MAC Address is still empty in payload!");
        return false;
      }

      if (addNodePayload[0]['securityCode'].toString().isEmpty) {
        print("❌ Security Code is still empty in payload!");
        return false;
      }

      final addNodeRes = await http.post(
        Uri.parse(addNodeUrl),
        headers: authHeader,
        body: jsonEncode(addNodePayload),
      );

      _logApiCall("STEP 3 - ADD NODE", "POST", addNodeUrl,
          authHeader, addNodePayload, addNodeRes);

      if (addNodeRes.statusCode != 200) {
        print("❌ Add Node failed: ${addNodeRes.body}");
        return false;
      }

      // Step 4: Register Device
      final deviceUrl = "${Config.baseUrl}/ray-notification/api/devices";
      final devicePayload = {
        "clusterId": clusterId,
        "userId": userId,
        "emailId": username,
        "view": "web",
        "os": "Linux x86_64",
        "osVersion": "Linux x86_64",
        "model": "Mozilla/5.0",
        "timezone": "Asia/Calcutta",
        "firebaseId": "a224da7220016f2ae88fdd6af78f29ab",
        "identifier": "a224da7220016f2ae88fdd6af78f29ab"
      };

      final deviceRes = await http.post(
        Uri.parse(deviceUrl),
        headers: authHeader,
        body: jsonEncode(devicePayload),
      );

      _logApiCall("STEP 4 - REGISTER DEVICE", "POST", deviceUrl,
          authHeader, devicePayload, deviceRes);

      if (deviceRes.statusCode != 200 && deviceRes.statusCode != 201) {
        print("❌ Device registration failed (status ${deviceRes.statusCode}): ${deviceRes.body}");
        return false;
      } else {
        print("✅ Device registration successful (status ${deviceRes.statusCode})");
      }

      // Step 5: Final APIs
      print("\n🔄 Running Final APIs...");

      final finalUrls = [
        "${Config.baseUrl}/ray-app/api/account",
        "${Config.baseUrl}/ray-app/api/users/permissions",
        "${Config.baseUrl}/ray-app/api/clusters/$clusterId/children?sort=name",
      ];

      final finalApiNames = [
        "FINAL API 1 - GET ACCOUNT",
        "FINAL API 2 - GET PERMISSIONS",
        "FINAL API 3 - GET CLUSTER CHILDREN"
      ];

      final finalResponses = await Future.wait([
        http.get(Uri.parse(finalUrls[0]), headers: authHeader),
        http.get(Uri.parse(finalUrls[1]), headers: authHeader),
        http.get(Uri.parse(finalUrls[2]), headers: authHeader),
      ]);

      // Log each final API response
      for (int i = 0; i < finalResponses.length; i++) {
        _logApiCall(finalApiNames[i], "GET", finalUrls[i],
            authHeader, null, finalResponses[i]);
      }

      if (finalResponses.every((res) => res.statusCode == 200)) {
        print("✅ All APIs completed successfully");
        return true;
      } else {
        print("⚠️ Some final APIs failed:");
        for (int i = 0; i < finalResponses.length; i++) {
          if (finalResponses[i].statusCode != 200) {
            print("❌ ${finalApiNames[i]} failed: ${finalResponses[i].body}");
          }
        }
        return false;
      }
    } catch (e, stackTrace) {
      print("❌ Exception in runOtpApisWithToken: $e");
      print("📍 Stack trace: $stackTrace");
      return false;
    }
  }
}