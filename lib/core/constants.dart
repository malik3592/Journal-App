class AppConfig {
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '303177826783-reruolvasuhsa2ao07p0suu68ajlr17m.apps.googleusercontent.com',
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '303177826783-m67q731cpn0v31lqu8anqirjqupg9mgg.apps.googleusercontent.com',
  );

  static const driveBackupFileName = 'journal-journal-backup.json';
  static const localJournalFileName = 'journal_journal.json';
}

class GoogleOAuthConfig {
  /// iOS OAuth client ID from Google Cloud Console (type: iOS).
  /// Also add the reversed client ID as a URL scheme in ios/Runner/Info.plist.
  static const iosClientId = AppConfig.googleIosClientId;

  /// Web OAuth client ID (type: Web application). Required for Android ID tokens.
  static const webClientId = AppConfig.googleWebClientId;
}
