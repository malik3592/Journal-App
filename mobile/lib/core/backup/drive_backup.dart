import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:journal/core/constants.dart';
import 'package:journal/core/errors.dart';

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class DriveBackupService {
  DriveBackupService()
    : _googleSignIn = GoogleSignIn(
        scopes: const ['email', drive.DriveApi.driveFileScope],
        clientId: Platform.isIOS && GoogleOAuthConfig.iosClientId.isNotEmpty
            ? GoogleOAuthConfig.iosClientId
            : null,
        serverClientId: GoogleOAuthConfig.webClientId.isEmpty
            ? null
            : GoogleOAuthConfig.webClientId,
      );

  final GoogleSignIn _googleSignIn;

  Future<GoogleSignInAccount?> currentUser() async {
    try {
      return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount> signIn() async {
    var account = await currentUser();
    account ??= await _googleSignIn.signIn();
    if (account == null) {
      throw AppException('Google sign-in was cancelled.');
    }
    final granted = await _googleSignIn.requestScopes(const [
      'email',
      drive.DriveApi.driveFileScope,
    ]);
    if (!granted) {
      throw AppException('Google Drive permission was not granted.');
    }
    return account;
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<drive.DriveApi> _api() async {
    final account = await signIn();
    final headers = await account.authHeaders;
    if (headers['Authorization'] == null) {
      throw AppException(
        'Google Drive did not return an access token. Check OAuth client IDs.',
      );
    }
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  Future<String?> _findBackupId(drive.DriveApi api) async {
    final listed = await api.files.list(
      q: "name = '${AppConfig.driveBackupFileName}' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, modifiedTime)',
    );
    final files = listed.files ?? const [];
    if (files.isEmpty) return null;
    return files.first.id;
  }

  Future<void> backup(String json) async {
    try {
      final api = await _api();
      final bytes = utf8.encode(json);
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );
      final metadata = drive.File()
        ..name = AppConfig.driveBackupFileName
        ..mimeType = 'application/json';
      final existingId = await _findBackupId(api);
      if (existingId == null) {
        await api.files.create(metadata, uploadMedia: media);
        return;
      }
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(_driveError(e));
    }
  }

  Future<String> restore() async {
    try {
      final api = await _api();
      final id = await _findBackupId(api);
      if (id == null) {
        throw AppException(
          'No ${AppConfig.driveBackupFileName} file was found in Google Drive.',
        );
      }
      final response = await api.files.get(
        id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        throw AppException('Google Drive returned an empty backup file.');
      }
      final chunks = await response.stream.toList();
      final bytes = <int>[];
      for (final chunk in chunks) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(_driveError(e));
    }
  }

  String _driveError(Object error) {
    final text = error.toString();
    if (text.contains('sign_in_failed') || text.contains('ApiException: 10')) {
      return 'Google sign-in is not configured for this app. Add OAuth client IDs in Google Cloud for package com.journal.journal.';
    }
    if (text.contains('network_error') || text.contains('SocketException')) {
      return 'Could not reach Google Drive. Check your internet connection.';
    }
    return text;
  }
}
