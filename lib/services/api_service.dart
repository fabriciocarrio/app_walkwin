import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;
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
    String password, {
    String? referralCode,
    String? province,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    if (referralCode != null && referralCode.isNotEmpty) {
      body['referral_code'] = referralCode.trim().toUpperCase();
    }
    if (province != null && province.isNotEmpty) {
      body['province'] = province;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode(body),
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

    // TODO: debug prints para ver por qué retorna HTML
    print('--- DEBUG LOGIN ---');
    print('URL: $baseUrl/auth/login');
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    print('-------------------');

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      await setToken(data['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final response = await http
        .get(Uri.parse('$baseUrl/user/stats'), headers: _headers)
        .timeout(const Duration(seconds: 15));
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
    final response = await http
        .post(
          Uri.parse('$baseUrl/steps/sync'),
          headers: _headers,
          body: jsonEncode({
            'date': date,
            'steps': steps,
            'source': source,
            'device_fingerprint': fingerprint,
          }),
        )
        .timeout(const Duration(seconds: 15));
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

  static Future<Map<String, dynamic>> generateDynamicSpawns({
    required double lat,
    required double lng,
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/map/generate-dynamic-spawns'),
      headers: _headers,
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );
    return jsonDecode(response.body);
  }

  /// Compra un cupón (no requiere ubicación).
  static Future<Map<String, dynamic>> purchaseCoupon(
    String businessId, {
    String? currency,
    String? offerId,
  }) async {
    await getToken();
    final body = <String, dynamic>{
      'business_id': businessId,
      if (currency != null) 'currency': currency,
      if (offerId != null) 'offer_id': offerId,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/redemptions/purchase'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        (data['error'] ?? data['message'] ?? 'Error al canjear.').toString(),
        response.statusCode,
      );
    }
    return data;
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

  static Future<Map<String, dynamic>> redeemWithCode(
    String businessId,
    String code,
  ) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/redemptions/redeem-with-code'),
      headers: _headers,
      body: jsonEncode({'business_id': businessId, 'code': code}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        (data['error'] ?? data['message'] ?? 'Error al canjear con código.')
            .toString(),
        response.statusCode,
      );
    }
    return data;
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
    required String name,
    required String email,
    String? phone,
    String? avatar,
    required int age,
    required double weightKg,
    int? heightCm,
    String? province,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings/profile'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'age': age,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'province': province,
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

  static Future<Map<String, dynamic>> fuseCollectibles({
    required String collectibleId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/exploration/collectibles/fuse'),
      headers: _headers,
      body: jsonEncode({'collectible_id': collectibleId}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCollectibleDetail(
    int collectibleId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/exploration/collectibles/$collectibleId'),
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

  static Future<Map<String, dynamic>> claimMissionReward({
    required String missionId,
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/exploration/missions/$missionId/claim'),
      headers: _headers,
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

  /// Returns progress toward all available achievements.
  /// Response: { success, data: [{ id, slug, name, criteria_type, target, current, percentage, unlocked }] }
  static Future<List<dynamic>> getAchievementProgress() async {
    final response = await http.get(
      Uri.parse('$baseUrl/achievements/progress'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data['data'] is List ? data['data'] : [];
  }

  static Future<List<dynamic>> getCollectibleSets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/exploration/sets'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : (data['data'] is List ? data['data'] : []);
  }

  // ── Clan API Methods ──────────────────────────────────────────

  static Future<Map<String, dynamic>> getMyClan() async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/clans/my'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> searchClans({
    String? search,
    String? department,
  }) async {
    await getToken();
    final query = <String, String>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (department != null && department.isNotEmpty)
      query['department'] = department;
    final uri = Uri.parse(
      '$baseUrl/clans',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers);
    final data = jsonDecode(response.body);
    return data is List ? data : (data['data'] is List ? data['data'] : []);
  }

  static Future<Map<String, dynamic>> createClan({
    required String name,
    String? description,
    String? logo,
    required String province,
    required String department,
  }) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/clans'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'logo': logo,
        'province': province,
        'department': department,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getClanDetail(int clanId) async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/clans/$clanId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateClan(
    int clanId, {
    String? name,
    String? description,
    String? logo,
  }) async {
    await getToken();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (logo != null) body['logo'] = logo;
    final response = await http.patch(
      Uri.parse('$baseUrl/clans/$clanId'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> joinClanByCode(String code) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/clans/join'),
      headers: _headers,
      body: jsonEncode({'code': code}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> joinClanById(int clanId) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/clans/$clanId/join'),
      headers: _headers,
      body: jsonEncode({'clan_id': clanId}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> leaveClan(int clanId) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/clans/$clanId/leave'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> kickMember(int clanId, int userId) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/clans/$clanId/kick'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> transferLeadership(
    int clanId,
    int userId,
  ) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/clans/$clanId/transfer'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> regenerateCode(int clanId) async {
    await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/clans/$clanId/regenerate-code'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getDepartmentRankings({
    String? department,
  }) async {
    await getToken();
    final query = <String, String>{};
    if (department != null && department.isNotEmpty)
      query['department'] = department;
    final uri = Uri.parse(
      '$baseUrl/rankings/departments',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getClanRankings(int clanId) async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/rankings/clan?clan_id=$clanId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getGlobalClanRankings() async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/rankings/global'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getReferralInfo() async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/user/referral-info'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getAuthProvinces() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/provinces'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    final data = jsonDecode(response.body);
    return data['provinces'] is List ? data['provinces'] : [];
  }

  static Future<List<dynamic>> getProvinces() async {
    await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/clans/provinces'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data['provinces'] is List ? data['provinces'] : [];
  }

  static Future<List<dynamic>> getDepartments({String? province}) async {
    await getToken();
    final query = <String, String>{};
    if (province != null && province.isNotEmpty) query['province'] = province;
    final uri = Uri.parse(
      '$baseUrl/clans/departments',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers);
    final data = jsonDecode(response.body);
    return data['departments'] is List ? data['departments'] : [];
  }

  static Future<void> logout() async {
    await clearToken();
  }
}
