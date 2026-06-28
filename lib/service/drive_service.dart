import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';

/// Thin wrapper around the Google Drive REST API v3.
///
/// On mobile (Android/iOS): uses google_sign_in for auth tokens.
/// On desktop (macOS/Windows/Linux): uses browser-based OAuth2 loopback flow.
///
/// Folder structure:
/// ```
/// FlashMind/
///   <deckCode>/        (GroupCode for legacy, deckId for user-created)
///     cards.json
///     progress.json
/// ```
class DriveService {
  static const String _driveApi = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApi = 'https://www.googleapis.com/upload/drive/v3';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive',
  ];
  static const String _rootFolderName = 'FlashMind';

  // OAuth2 credentials (Desktop client — browser-based loopback flow)
  // Provided via --dart-define or fallback to env at compile time.
  static const String _clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String _clientSecret =
      String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// Whether we have a valid (or refreshable) token.
  bool get isAuthorized {
    if (_isMobile) {
      return Get.find<AuthService>().isLoggedIn;
    }
    return _accessToken != null;
  }

  /// Authorizes for Drive access.
  /// Mobile: uses google_sign_in. Desktop: browser-based OAuth2 loopback.
  Future<bool> authorize() async {
    if (_isMobile) return _authorizeMobile();
    return _authorizeDesktop();
  }

  // ──────────────── MOBILE AUTH (google_sign_in) ────────────────

  Future<bool> _authorizeMobile() async {
    final authService = Get.find<AuthService>();
    if (!authService.isLoggedIn) {
      final account = await authService.signInWithGoogle();
      if (account == null) return false;
    }
    return true;
  }

  Future<Map<String, String>> _mobileAuthHeaders() async {
    final account = Get.find<AuthService>().user.value;
    if (account == null) throw DriveException('Not signed in');
    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
      promptIfNecessary: true,
    );
    if (headers == null) throw DriveException('Drive authorization denied');
    return headers;
  }

  // ──────────────── DESKTOP AUTH (browser loopback) ─────────────

  Future<bool> _authorizeDesktop() async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
      });

      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        await server.close();
        throw DriveException('Could not open browser for sign-in');
      }

      String? code;
      await server.first.timeout(const Duration(minutes: 2)).then((request) {
        code = request.uri.queryParameters['code'];
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('<html><body style="font-family:sans-serif;text-align:center;'
              'padding:60px"><h2>✅ Signed in!</h2>'
              '<p>You can close this tab and return to FlashMind.</p>'
              '</body></html>')
          ..close();
      });
      await server.close();

      if (code == null) throw DriveException('No authorization code received');

      final tokenRes = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'code': code,
          'client_id': _clientId,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret,
        },
      );
      if (tokenRes.statusCode != 200) {
        throw DriveException('Token exchange failed: ${tokenRes.body}');
      }
      final tokenData = jsonDecode(tokenRes.body);
      _accessToken = tokenData['access_token'];
      _refreshToken = tokenData['refresh_token'] ?? _refreshToken;
      _tokenExpiry = DateTime.now()
          .add(Duration(seconds: tokenData['expires_in'] as int? ?? 3600));

      debugPrint('DriveService: authorized successfully');
      return true;
    } catch (e) {
      debugPrint('DriveService: authorization error: $e');
      return false;
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) throw DriveException('No refresh token');
    final res = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'client_id': _clientId,
        'refresh_token': _refreshToken,
        'grant_type': 'refresh_token',
        if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret,
      },
    );
    if (res.statusCode != 200) {
      _accessToken = null;
      throw DriveException('Token refresh failed: ${res.body}');
    }
    final data = jsonDecode(res.body);
    _accessToken = data['access_token'];
    _tokenExpiry = DateTime.now()
        .add(Duration(seconds: data['expires_in'] as int? ?? 3600));
  }

  // ──────────────── UNIFIED AUTH HEADERS ────────────────────────

  /// Returns authorization headers. Auto-detects mobile vs desktop.
  Future<Map<String, String>> _authHeaders() async {
    if (_isMobile) return _mobileAuthHeaders();
    if (_accessToken == null) throw DriveException('Not authorized');
    if (_tokenExpiry != null &&
        DateTime.now()
            .isAfter(_tokenExpiry!.subtract(const Duration(seconds: 60)))) {
      await _refreshAccessToken();
    }
    return {'Authorization': 'Bearer $_accessToken'};
  }

  /// Finds a file/folder by name inside [parentId]. Returns the file ID or null.
  Future<String?> _findByName(
    String name,
    Map<String, String> headers, {
    String? parentId,
    bool isFolder = false,
  }) async {
    final mime =
        isFolder ? " and mimeType='application/vnd.google-apps.folder'" : '';
    final parent = parentId != null ? " and '$parentId' in parents" : '';
    final q = "name='$name'$mime$parent and trashed=false";
    final uri = Uri.parse('$_driveApi/files?q=${Uri.encodeComponent(q)}'
        '&fields=files(id,name)&spaces=drive');
    final res = await http.get(uri, headers: headers);
    _check(res);
    final files = (jsonDecode(res.body)['files'] as List?) ?? [];
    return files.isNotEmpty ? files.first['id'] as String : null;
  }

  /// Creates a folder with [name] inside [parentId]. Returns the new folder ID.
  Future<String> _createFolder(String name, Map<String, String> headers,
      {String? parentId}) async {
    final body = <String, dynamic>{
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
      if (parentId != null) 'parents': [parentId],
    };
    final res = await http.post(
      Uri.parse('$_driveApi/files?fields=id'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _check(res);
    return jsonDecode(res.body)['id'] as String;
  }

  /// Ensures a folder exists, creating it if necessary. Returns the folder ID.
  Future<String> _ensureFolder(String name, Map<String, String> headers,
      {String? parentId}) async {
    final existing =
        await _findByName(name, headers, parentId: parentId, isFolder: true);
    if (existing != null) return existing;
    return _createFolder(name, headers, parentId: parentId);
  }

  /// Returns the folder ID for `FlashMind/<deckCode>/`.
  Future<String> ensureDeckFolder(String deckCode) async {
    final headers = await _authHeaders();
    final rootId = await _ensureFolder(_rootFolderName, headers);
    return _ensureFolder(deckCode, headers, parentId: rootId);
  }

  /// Lists all subfolder names inside the FlashMind root folder on Drive.
  /// Returns folder names like ["FA_EN", "DE_EN"].
  Future<List<String>> listDeckFolders() async {
    final headers = await _authHeaders();
    final rootId = await _findByName(_rootFolderName, headers, isFolder: true);
    if (rootId == null) return [];

    final q = "'$rootId' in parents"
        " and mimeType='application/vnd.google-apps.folder'"
        " and trashed=false";
    final uri = Uri.parse('$_driveApi/files?q=${Uri.encodeComponent(q)}'
        '&fields=files(name)&pageSize=100');
    final res = await http.get(uri, headers: headers);
    _check(res);

    final files = (jsonDecode(res.body)['files'] as List?) ?? [];
    return files.map((f) => f['name'] as String).toList();
  }

  /// Uploads a JSON object as [fileName] inside [folderId].
  /// If the file already exists, it is updated; otherwise created.
  Future<void> uploadJson(
      String folderId, String fileName, dynamic jsonData) async {
    final headers = await _authHeaders();
    final existingId = await _findByName(fileName, headers, parentId: folderId);

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    if (existingId != null) {
      final res = await http.patch(
        Uri.parse('$_uploadApi/files/$existingId?uploadType=media&fields=id'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonString,
      );
      _check(res);
    } else {
      final metadata = jsonEncode({
        'name': fileName,
        'parents': [folderId],
      });
      final boundary = 'FlashMindBoundary';
      final multipart = '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadata\r\n'
          '--$boundary\r\n'
          'Content-Type: application/json\r\n\r\n'
          '$jsonString\r\n'
          '--$boundary--';

      final res = await http.post(
        Uri.parse('$_uploadApi/files?uploadType=multipart&fields=id'),
        headers: {
          ...headers,
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: multipart,
      );
      _check(res);
    }
    debugPrint('DriveService: uploaded $fileName to folder $folderId');
  }

  /// Downloads [fileName] from [folderId] and returns the parsed JSON,
  /// or null if the file doesn't exist.
  Future<dynamic> downloadJson(String folderId, String fileName) async {
    final headers = await _authHeaders();
    final fileId = await _findByName(fileName, headers, parentId: folderId);
    if (fileId == null) return null;

    final res = await http.get(
      Uri.parse('$_driveApi/files/$fileId?alt=media'),
      headers: headers,
    );
    _check(res);
    return jsonDecode(res.body);
  }

  void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw DriveException('Drive API error ${res.statusCode}: ${res.body}');
  }
}

class DriveException implements Exception {
  final String message;
  DriveException(this.message);
  @override
  String toString() => 'DriveException: $message';
}
