import 'dart:convert';
import 'package:http/http.dart' as http;
import'config.dart';

Future<Map<String, dynamic>> registerUser({
  required String firstName,
  required String lastName,
  required String email,
  required String password,
  required String mobileNumber,
}) async {
  final url = Uri.parse('${Config.baseUrl}/ray-app/api/register');
  final body = {
    "firstName": firstName,
    "lastName": lastName,
    "email": email,
    "password": password,
    "mobileNumber": mobileNumber,
    "langKey": "en",
    "countryId": 101,
    "clientId": "950229ed-9ac1-43ff-b849-9309e3f82b8a",
    "timezoneId": 14
  };

  try {
    print('Sending request to: $url');
    print('Request body: ${jsonEncode(body)}');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    // Check if response body is empty
    if (response.body.isEmpty) {
      return {
        "success": false,
        "message": "Server returned empty response"
      };
    }

    // Try to decode JSON response
    Map<String, dynamic>? responseBody;
    try {
      responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (jsonError) {
      return {
        "success": false,
        "message": "Invalid response format from server"
      };
    }

    // Check for successful response (200-299 are success codes)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Check if response has success field, otherwise assume success for 2xx codes
      if (responseBody['success'] == true || responseBody['success'] == null) {
        return {"success": true, "data": responseBody};
      }
    }

    // If we reach here, it's an error response
    String errorMessage = "Unknown error occurred";

    if (responseBody != null) {
      // Check for specific database constraint errors
      if (responseBody["detail"]?.toString().contains("ux_user_email") == true) {
        errorMessage = "Email address is already registered. Please use a different email.";
      } else if (responseBody["detail"]?.toString().contains("ux_user_mobile") == true) {
        errorMessage = "Mobile number is already registered. Please use a different number.";
      } else {
        errorMessage = responseBody["message"]?.toString() ??
            responseBody["detail"]?.toString() ??
            responseBody["error"]?.toString() ??
            "Server error (${response.statusCode})";
      }
    } else {
      errorMessage = "Server error (${response.statusCode})";
    }

    return {
      "success": false,
      "message": errorMessage
    };
  } catch (e) {
    return {
      "success": false,
      "message": "Network error: ${e.toString()}"
    };
  }
}