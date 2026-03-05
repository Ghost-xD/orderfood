import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UserService {
  final String baseUrl = "https://qx-xsuiuwj7yq-uc.a.run.app";
  final _storage = const FlutterSecureStorage();

  Future<T> executeSecureCall<T>(Future<T> Function() apiCall) async {
    try {
      
      return await apiCall();
    } catch (e) {
      if (e is AuthenticationException) {
        await refreshToken();
        return await apiCall();
      } else {
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> userData) async {
    String url = '$baseUrl/user/register';
    try {
      http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      ).timeout(const Duration(seconds: 20));
      if(response.statusCode == 400){
        throw Exception('Weak Password: ${response.body}');
      }
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to register user: ${response.body}');
      }
    } on Exception {
      rethrow;
    }    
  }

  Future<void> refreshToken() async {
    try {
      String? refreshToken = await _storage.read(key: 'refresh_token');
      var response = await http.post(
        Uri.parse('$baseUrl/user/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        await _storage.write(key: 'access_token', value: data['access_token']);
      } else {
        throw Exception('Failed to refresh token');
      }
    } catch (e) {
      throw Exception('Failed to refresh token: $e');
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    String url = '$baseUrl/user/login';
    try {
      http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the service: $e');
    }
  }

  Future<Map<String, dynamic>> getUserDetails(String email, String token) async {
    String url = '$baseUrl/user/user/$email';
    try {
      http.Response response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } 
      if (response.statusCode == 401) {
        throw AuthenticationException('Unauthorized: Token may be expired or invalid');
      } else {
        throw Exception('Failed to fetch user details: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the service: $e');
    }
  }

  Future<Map<String, dynamic>> updateUser(String email, Map<String, dynamic> userData) async {
    return executeSecureCall(() async {
      String? token = await _storage.read(key: 'access_token');
      String url = '$baseUrl/user/update/$email';
      var response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AuthenticationException('Unauthorized: Token may be expired or invalid');
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to update user: ${response.body}');
      }
      return jsonDecode(response.body);
    });
  }

  Future<void> deleteUser(String email, String token) async {
    await executeSecureCall<void>(() async {
      String url = '$baseUrl/user/delete/$email';
      var response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        throw AuthenticationException('Unauthorized: Token may be expired or invalid');
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to delete user: ${response.body}');
      }
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    String url = '$baseUrl/reset-password';
    try {
      http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to send password reset email: ${response.body}');
      }
      if (response.statusCode == 401) {
        throw AuthenticationException('Unauthorized: Token may be expired or invalid');
      }
    } catch (e) {
      throw Exception('Failed to connect to the service: $e');
    }
  }

  Future<bool> isHeicM(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      Uint8List bytes = await file.readAsBytes();

      bool isHeicFormat = filePath.toLowerCase().endsWith('.heic') || 
                        (bytes.isNotEmpty && bytes[0] == 0x66 && bytes[1] == 0x74 && bytes[2] == 0x79 && bytes[3] == 0x70 && bytes[4] == 0x68 && bytes[5] == 0x65 && bytes[6] == 0x69 && bytes[7] == 0x63);
      return isHeicFormat;
    } catch (e) {
      return false;
    }
  }

}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  @override
  String toString() => message;
}
