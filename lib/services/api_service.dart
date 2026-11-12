// lib/services/api_service.dart
//
// Central HTTP client for NexusShield. Handles auth token storage/refresh
// and every backend endpoint across Phases 1-10. Existing screens that
// already call analyzeScreenshot/analyzeText/checkUrl/chatWithCopilot keep
// working unchanged -- this file only adds capability, it doesn't remove any.
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
export '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BACKEND URL CONFIGURATION
// Backend is deployed on Vercel (FastAPI + Neon Postgres).
// Everything else is automatic.
// ─────────────────────────────────────────────────────────────────────────────
const String _PRODUCTION_URL = 'https://backend-tau-neon-p94ihvya7x.vercel.app';

// true = use the deployed Vercel backend above.
// When false, uses localhost for local dev.
const bool _USE_PRODUCTION = true;

String get _BASE_URL {
  if (_USE_PRODUCTION) return _PRODUCTION_URL;
  if (kIsWeb) return 'http://localhost:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Turns any error thrown by an API call into a short message that is safe
/// to show to users (no stack traces, exception class names or server internals).
String friendlyError(Object e) {
  if (e is ApiException) {
    if (e.statusCode == 413) return 'That image is too large. Please try a smaller screenshot.';
    if (e.statusCode == 429) return 'Too many requests. Please wait a moment and try again.';
    if (e.statusCode >= 500) return 'Our server had a problem. Please try again in a moment.';
    return e.message;
  }
  if (e is TimeoutException) {
    return 'The request timed out. Check your connection and try again.';
  }
  final text = e.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (text.contains('ApiException: 10')) {
    return 'Google sign-in is not set up for this app build. Its SHA-1 fingerprint must be added in Firebase.';
  }
  if (text.contains('sign_in_failed') || text.contains('network_error')) {
    return 'Google sign-in failed. Please try again.';
  }
  // Messages the app throws itself (Exception('...')) are already user-facing.
  if (text.startsWith('Exception: ')) return text.substring('Exception: '.length);
  return 'Something went wrong. Please try again.';
}

class ApiService extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  UserProfile? _currentUser;
  bool _initialized = false;

  bool get isAuthenticated => _accessToken != null;
  UserProfile? get currentUser => _currentUser;
  bool get isInitialized => _initialized;

  /// Call once at app startup to restore a saved session.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    if (_accessToken != null) {
      try {
        _currentUser = await getProfile();
      } catch (_) {
        // Token expired/invalid -- try a refresh once before giving up.
        final refreshed = await _tryRefresh();
        if (refreshed) {
          try {
            _currentUser = await getProfile();
          } catch (_) {
            await _clearSession();
          }
        } else {
          await _clearSession();
        }
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveSession(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_BASE_URL/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data['access_token'], data['refresh_token']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Wraps an authenticated request; retries once after a token refresh on 401.
  Future<http.Response> _authedRequest(Future<http.Response> Function() request) async {
    var response = await request();
    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await request();
      }
    }
    return response;
  }

  dynamic _decodeOrThrow(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String detail = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) detail = body['detail'].toString();
    } catch (_) {}
    throw ApiException(response.statusCode, detail);
  }

  // ── Phase 1: Auth ─────────────────────────────────────────────────────────
  Future<void> signup(String email, String password, String name) async {
    final response = await http.post(
      Uri.parse('$_BASE_URL/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeOrThrow(response);
    await _saveSession(data['access_token'], data['refresh_token']);
    _currentUser = await getProfile();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_BASE_URL/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'device_label': 'Mobile app'}),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeOrThrow(response);
    await _saveSession(data['access_token'], data['refresh_token']);
    _currentUser = await getProfile();
    notifyListeners();
  }

  Future<void> oauthLogin({
    required String provider,
    required String idToken,
    required String email,
    String name = '',
    String photoUrl = '',
  }) async {
    final response = await http.post(
      Uri.parse('$_BASE_URL/auth/oauth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider, 'id_token': idToken, 'email': email,
        'name': name, 'photo_url': photoUrl, 'device_label': 'Mobile app',
      }),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeOrThrow(response);
    await _saveSession(data['access_token'], data['refresh_token']);
    _currentUser = await getProfile();
    notifyListeners();
  }

  Future<String?> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$_BASE_URL/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 20));
    final data = _decodeOrThrow(response);
    return data['dev_reset_token']; // null in a real deployment with email sending wired up
  }

  Future<void> resetPassword(String token, String newPassword) async {
    final response = await http.post(
      Uri.parse('$_BASE_URL/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    ).timeout(const Duration(seconds: 20));
    _decodeOrThrow(response);
  }

  Future<String?> sendVerificationEmail() async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/auth/send-verification'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return data['dev_verify_token'];
  }

  Future<void> verifyEmail(String token) async {
    final response = await http.post(
      Uri.parse('$_BASE_URL/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    ).timeout(const Duration(seconds: 20));
    _decodeOrThrow(response);
    if (_currentUser != null) {
      _currentUser = await getProfile();
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> listSessions() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/auth/sessions'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> revokeSession(String sessionId) async {
    final response = await _authedRequest(() => http.delete(
          Uri.parse('$_BASE_URL/auth/sessions/$sessionId'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$_BASE_URL/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': _refreshToken}),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    await _clearSession();
  }

  // ── Phase 1: Profile ──────────────────────────────────────────────────────
  Future<UserProfile> getProfile() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/profile/me'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> fields) async {
    final response = await _authedRequest(() => http.patch(
          Uri.parse('$_BASE_URL/profile/me'),
          headers: _authHeaders,
          body: jsonEncode(fields),
        ));
    final data = _decodeOrThrow(response);
    _currentUser = UserProfile.fromJson(data);
    notifyListeners();
    return _currentUser!;
  }

  Future<void> deleteAccount() async {
    final response = await _authedRequest(() => http.delete(
          Uri.parse('$_BASE_URL/profile/me'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
    await _clearSession();
  }

  // ── Analysis (Phase 1.5 + 2) ──────────────────────────────────────────────
  Future<AnalysisResult> analyzeScreenshot(Uint8List bytes, {String language = 'en'}) async {
    
    final base64Image = base64Encode(bytes);
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/analyze/screenshot'),
          headers: _authHeaders,
          body: jsonEncode({'image_base64': base64Image, 'language': language}),
        ).timeout(const Duration(seconds: 45)));
    final data = _decodeOrThrow(response);
    return AnalysisResult.fromJson(data);
  }

  Future<AnalysisResult> analyzeText(String text, {String language = 'en'}) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/analyze/text'),
          headers: _authHeaders,
          body: jsonEncode({'text': text, 'language': language}),
        ).timeout(const Duration(seconds: 30)));
    final data = _decodeOrThrow(response);
    return AnalysisResult.fromJson(data);
  }

  Future<AnalysisResult> checkUrl(String url, {String language = 'en'}) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/analyze/url'),
          headers: _authHeaders,
          body: jsonEncode({'url': url, 'language': language}),
        ).timeout(const Duration(seconds: 30)));
    final data = _decodeOrThrow(response);
    return AnalysisResult.fromJson(data);
  }

  // ── Digital Arrest / Scam Call Detection (transcript-based) ──────────────
  Future<AnalysisResult> analyzeCall(String transcript, {String callerNumber = '', String language = 'en'}) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/analyze/call'),
          headers: _authHeaders,
          body: jsonEncode({'transcript': transcript, 'caller_number': callerNumber, 'language': language}),
        ).timeout(const Duration(seconds: 30)));
    final data = _decodeOrThrow(response);
    return AnalysisResult.fromJson(data);
  }

  // Internship / job offer verification
  Future<Map<String, dynamic>> analyzeInternship(String offerText, {String language = 'en'}) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/analyze/internship'),
          headers: _authHeaders,
          body: jsonEncode({'offer_text': offerText, 'language': language}),
        ).timeout(const Duration(seconds: 45)));
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  // ── Counterfeit Currency Detection ────────────────────────────────────────
  Future<CurrencyAnalysisResult> analyzeCurrency(Uint8List bytes, {String language = 'en'}) async {
    final base64Image = base64Encode(bytes);
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/analyze/currency'),
          headers: _authHeaders,
          body: jsonEncode({'image_base64': base64Image, 'language': language}),
        ).timeout(const Duration(seconds: 45)));
    final data = _decodeOrThrow(response);
    return CurrencyAnalysisResult.fromJson(data);
  }

  // ── Geospatial Crime Intelligence ─────────────────────────────────────────
  Future<List<ScamHotspot>> getHotspots({String? category}) async {
    final url = category != null
        ? '$_BASE_URL/intel/hotspots?category=$category'
        : '$_BASE_URL/intel/hotspots';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    final data = _decodeOrThrow(response);
    return (data as List).map((e) => ScamHotspot.fromJson(e)).toList();
  }

  // ── Fraud Network Intelligence ────────────────────────────────────────────
  Future<FraudNetworkGraph> getFraudNetwork(String value) async {
    final response = await http
        .get(Uri.parse('$_BASE_URL/intel/fraud-network?value=${Uri.encodeQueryComponent(value)}'))
        .timeout(const Duration(seconds: 20));
    final data = _decodeOrThrow(response);
    return FraudNetworkGraph.fromJson(data);
  }

  Future<Map<String, dynamic>> checkClipboard(String content) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/analyze/clipboard'),
          headers: _authHeaders,
          body: jsonEncode({'content': content}),
        ).timeout(const Duration(seconds: 15)));
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> getCategoriesAndLanguages() async {
    final response = await http.get(Uri.parse('$_BASE_URL/categories')).timeout(const Duration(seconds: 20));
    return _decodeOrThrow(response);
  }

  Future<String> chatWithCopilot(
      String message, List<Map<String, String>> history, {String language = 'en'}) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/copilot/chat'),
          headers: _authHeaders,
          body: jsonEncode({'message': message, 'history': history, 'language': language}),
        ).timeout(const Duration(seconds: 30)));
    final data = _decodeOrThrow(response);
    return data['reply'] as String;
  }

  // ── Phase 1: History ──────────────────────────────────────────────────────
  Future<Map<String, List<HistoryItem>>> getHistoryGrouped() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/history/grouped'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return data.map((key, value) =>
        MapEntry(key, (value as List).map((e) => HistoryItem.fromJson(e)).toList()));
  }

  Future<List<HistoryItem>> searchHistory(String query) async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/history?q=${Uri.encodeQueryComponent(query)}'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return (data['items'] as List).map((e) => HistoryItem.fromJson(e)).toList();
  }

  Future<void> deleteHistoryItem(String id) async {
    final response = await _authedRequest(() => http.delete(
          Uri.parse('$_BASE_URL/history/$id'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  Future<void> clearHistory() async {
    final response = await _authedRequest(() => http.delete(
          Uri.parse('$_BASE_URL/history'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  String get exportHistoryCsvUrl => '$_BASE_URL/history/export?format=csv';

  // ── Phase 6: PDF Reports ─────────────────────────────────────────────────
  String pdfReportUrl(String historyId) => '$_BASE_URL/reports/pdf/$historyId';

  Map<String, String> get downloadAuthHeaders =>
      _accessToken != null ? {'Authorization': 'Bearer $_accessToken'} : {};

  // ── Phase 1: Scam Reporting ──────────────────────────────────────────────
  Future<ScamReport> submitScamReport({
    String? screenshotBase64, String website = '', String phoneNumber = '',
    String upiId = '', String description = '', String category = 'Uncategorized',
  }) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/reports'),
          headers: _authHeaders,
          body: jsonEncode({
            'screenshot_base64': screenshotBase64, 'website': website,
            'phone_number': phoneNumber, 'upi_id': upiId,
            'description': description, 'category': category,
          }),
        ));
    final data = _decodeOrThrow(response);
    return ScamReport.fromJson(data);
  }

  Future<List<ScamReport>> myReports() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/reports/mine'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return (data as List).map((e) => ScamReport.fromJson(e)).toList();
  }

  // ── Phase 4: Threat Feed & News ──────────────────────────────────────────
  Future<List<ThreatFeedItem>> getThreatFeed() async {
    final response = await http.get(Uri.parse('$_BASE_URL/intel/threat-feed'));
    final data = _decodeOrThrow(response);
    return (data as List).map((e) => ThreatFeedItem.fromJson(e)).toList();
  }

  Future<List<NewsItem>> getNews() async {
    final response = await http.get(Uri.parse('$_BASE_URL/intel/news'));
    final data = _decodeOrThrow(response);
    return (data as List).map((e) => NewsItem.fromJson(e)).toList();
  }

  // ── Phase 4 & 10: Dashboard & Analytics ──────────────────────────────────
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/dashboard/summary'),
          headers: _authHeaders,
        ));
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> getPersonalAnalytics() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/dashboard/analytics'),
          headers: _authHeaders,
        ));
    return _decodeOrThrow(response);
  }

  // ── Phase 9: Notifications ───────────────────────────────────────────────
  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/notifications?unread_only=$unreadOnly'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return (data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    final response = await _authedRequest(() => http.patch(
          Uri.parse('$_BASE_URL/notifications/$id/read'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  Future<void> markAllNotificationsRead() async {
    final response = await _authedRequest(() => http.patch(
          Uri.parse('$_BASE_URL/notifications/read-all'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  // ── Phase 5: Family Protection ───────────────────────────────────────────
  Future<List<FamilyMember>> getFamilyMembers() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/family/members'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return (data as List).map((e) => FamilyMember.fromJson(e)).toList();
  }

  Future<void> inviteFamilyMember(String email, String label, {int minRiskToAlert = 70}) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/family/invite'),
          headers: _authHeaders,
          body: jsonEncode({
            'member_email': email, 'member_label': label, 'min_risk_to_alert': minRiskToAlert,
          }),
        ));
    _decodeOrThrow(response);
  }

  Future<void> removeFamilyMember(String linkId) async {
    final response = await _authedRequest(() => http.delete(
          Uri.parse('$_BASE_URL/family/members/$linkId'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  Future<List<Map<String, dynamic>>> getFamilyAlerts() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/family/alerts'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Phase 5: Organization / Enterprise ───────────────────────────────────
  Future<Map<String, dynamic>> createOrganization(String name) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/org/create'),
          headers: _authHeaders,
          body: jsonEncode({'name': name}),
        ));
    final data = _decodeOrThrow(response);
    _currentUser = await getProfile();
    notifyListeners();
    return data;
  }

  Future<void> inviteToOrg(String email) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/org/invite'),
          headers: _authHeaders,
          body: jsonEncode({'email': email}),
        ));
    _decodeOrThrow(response);
  }

  Future<List<Map<String, dynamic>>> getOrgMembers() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/org/members'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> getOrgDashboard() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/org/dashboard'),
          headers: _authHeaders,
        ));
    return _decodeOrThrow(response);
  }

  // ── Phase 5: Admin Panel ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> adminListUsers() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/admin/users'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> adminDeleteUser(String userId) async {
    final response = await _authedRequest(() => http.delete(
          Uri.parse('$_BASE_URL/admin/users/$userId'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  Future<List<Map<String, dynamic>>> adminListReports({String? status}) async {
    final url = status != null ? '$_BASE_URL/admin/reports?status=$status' : '$_BASE_URL/admin/reports';
    final response = await _authedRequest(() => http.get(Uri.parse(url), headers: _authHeaders));
    final data = _decodeOrThrow(response);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> adminReviewReport(String reportId, String status, {String notes = ''}) async {
    final response = await _authedRequest(() => http.patch(
          Uri.parse('$_BASE_URL/admin/reports/$reportId/review'),
          headers: _authHeaders,
          body: jsonEncode({'status': status, 'admin_notes': notes}),
        ));
    _decodeOrThrow(response);
  }

  Future<List<Map<String, dynamic>>> adminListScamDb() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/admin/scam-database'),
          headers: _authHeaders,
        ));
    final data = _decodeOrThrow(response);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> adminAddScamDbEntry({
    required String entryType, required String value,
    String category = 'Uncategorized', String severity = 'high', String notes = '',
  }) async {
    final response = await _authedRequest(() => http.post(
          Uri.parse('$_BASE_URL/admin/scam-database'),
          headers: _authHeaders,
          body: jsonEncode({
            'entry_type': entryType, 'value': value, 'category': category,
            'severity': severity, 'notes': notes,
          }),
        ));
    _decodeOrThrow(response);
  }

  Future<void> adminDeleteScamDbEntry(String entryId) async {
    final response = await _authedRequest(() => http.delete(
          Uri.parse('$_BASE_URL/admin/scam-database/$entryId'),
          headers: _authHeaders,
        ));
    _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> adminAnalytics() async {
    final response = await _authedRequest(() => http.get(
          Uri.parse('$_BASE_URL/admin/analytics'),
          headers: _authHeaders,
        ));
    return _decodeOrThrow(response);
  }
}
