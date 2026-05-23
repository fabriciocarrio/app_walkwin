import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.30.59:8000/api/v1';
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static String? _token;
  static String? _cachedFingerprint;

  /// Returns a stable device identifier for anti-fraud checks.
  static Future<String> _getFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      _cachedFingerprint = android.id; // ANDROID_ID
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      _cachedFingerprint = ios.identifierForVendor ?? 'unknown';
    } else {
      _cachedFingerprint = 'unknown';
    }
    return _cachedFingerprint!;
  }

  static Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<void> loadToken() async {
    _token = await _storage.read(key: 'auth_token');
  }

  static Future<String?> getToken() async {
    _token ??= await _storage.read(key: 'auth_token');
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['token'] != null) {
      await setToken(data['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      await setToken(data['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/stats'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPepitaBalance() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/pepitas/balance'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> convertCoinsToPepitas({
    required int coins,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/pepitas/convert'),
      headers: _headers,
      body: jsonEncode({'coins': coins}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    await getToken();
    final rootApi = baseUrl.replaceFirst('/api/v1', '/api');
    final response = await http.get(
      Uri.parse('$rootApi/user'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> syncSteps(
    String date,
    int steps, {
    String source = 'native_sensor',
  }) async {
    final fingerprint = await _getFingerprint();
    final response = await http.post(
      Uri.parse('$baseUrl/steps/sync'),
      headers: _headers,
      body: jsonEncode({
        'date': date,
        'steps': steps,
        'source': source,
        'device_fingerprint': fingerprint,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getNearbyBusinesses(
    double lat,
    double lng, {
    int radius = 5000,
  }) async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/businesses/nearby?lat=$lat&lng=$lng'),
      headers: _headers,
    );
    if (response.statusCode == 401) {
      throw Exception('Sesion expirada. Inicia sesion nuevamente.');
    }
    if (response.statusCode != 200) {
      throw Exception('Error cargando comercios (${response.statusCode}).');
    }
    final body = jsonDecode(response.body);
    return body is List ? body : [];
  }

  static Future<List<dynamic>> getFeaturedBusinesses() async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/businesses/featured'),
      headers: _headers,
    );
    if (response.statusCode == 401) {
      throw Exception('Sesion expirada. Inicia sesion nuevamente.');
    }
    if (response.statusCode != 200) {
      throw Exception('Error cargando destacados (${response.statusCode}).');
    }
    final body = jsonDecode(response.body);
    return body is List ? body : [];
  }

  static Future<Map<String, dynamic>> checkin(
    String businessId,
    double lat,
    double lng, {
    String? qrPayload,
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/checkin'),
      headers: _headers,
      body: jsonEncode({
        'business_id': businessId,
        'lat': lat,
        'lng': lng,
        if (qrPayload != null) 'qr_payload': qrPayload,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getMapNearbyPoints({
    required double lat,
    required double lng,
    int? radiusM,
  }) async {
    await getToken();
    final query = <String, String>{
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      if (radiusM != null) 'radius': radiusM.toString(),
    };
    final uri = Uri.parse(
      '$baseUrl/map/nearby-points',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> claimMapShop({
    required String businessId,
    required double lat,
    required double lng,
    String? qrPayload,
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/map/shops/$businessId/claim'),
      headers: _headers,
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        if (qrPayload != null) 'qr_payload': qrPayload,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> claimMapTouristLocation({
    required String poiId,
    required double lat,
    required double lng,
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/map/tourist-locations/$poiId/claim'),
      headers: _headers,
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> claimMapDynamicSpawn({
    required String spawnId,
    required double lat,
    required double lng,
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/map/dynamic-spawns/$spawnId/claim'),
      headers: _headers,
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );
    return jsonDecode(response.body);
  }

  /// Compra un cupón con monedas o pepitas (no requiere ubicación).
  static Future<Map<String, dynamic>> purchaseCoupon(
    String businessId, {
    String currency = 'coins',
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/redemptions/purchase'),
      headers: _headers,
      body: jsonEncode({
        'business_id': businessId,
        if (currency != 'coins') 'currency': currency,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> validateRedemption(
    String qrCodeHash,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/redemptions/validate'),
      headers: _headers,
      body: jsonEncode({'qr_code_hash': qrCodeHash}),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getRedemptions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/redemptions'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> updateStepSource(String source) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings/step-source'),
      headers: _headers,
      body: jsonEncode({'source': source}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/settings/profile'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required int age,
    required double weightKg,
    int? heightCm,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings/profile'),
      headers: _headers,
      body: jsonEncode({
        'age': age,
        'weight_kg': weightKg,
        'height_cm': heightCm,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getWeeklyActivity() async {
    final response = await http.get(
      Uri.parse('$baseUrl/activity/weekly'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getExplorationMapState({
    required double latitude,
    required double longitude,
  }) async {
    final query = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
    };
    final uri = Uri.parse(
      '$baseUrl/exploration/mapstate',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getExplorationNearby({
    required double lat,
    required double lng,
    int? radiusM,
  }) async {
    final query = <String, String>{
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      if (radiusM != null) 'radius': radiusM.toString(),
    };
    final uri = Uri.parse(
      '$baseUrl/exploration/nearby-pois',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> claimExplorationPoi({
    required String poiId,
    required double lat,
    required double lng,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/exploration/claim-poi'),
      headers: _headers,
      body: jsonEncode({'poi_id': poiId, 'latitude': lat, 'longitude': lng}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCollectibles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/exploration/collectibles'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCollectibleInventory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/exploration/inventory'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCollectibleCatalog() async {
    final response = await http.get(
      Uri.parse('$baseUrl/exploration/collectibles-catalog'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> collectSpawn({
    required String spawnId,
    required double lat,
    required double lng,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/exploration/collect-spawn'),
      headers: _headers,
      body: jsonEncode({
        'spawn_id': spawnId,
        'latitude': lat,
        'longitude': lng,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getGeoMissions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/exploration/missions'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateGeoMissionProgress({
    required String missionId,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/exploration/missions/$missionId/progress'),
      headers: _headers,
      body: jsonEncode({}),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getUserAchievements() async {
    final response = await http.get(
      Uri.parse('$baseUrl/achievements/user'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : (data['data'] is List ? data['data'] : []);
  }

  static Future<List<dynamic>> getCollectibleSets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/exploration/sets'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : (data['data'] is List ? data['data'] : []);
  }

  static Future<void> logout() async {
    await clearToken();
  }
}
