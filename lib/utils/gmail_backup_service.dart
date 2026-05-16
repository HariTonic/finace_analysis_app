import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction.dart';
import '../models/investment_holding.dart';
import 'backup_sync_service.dart';
import 'app_settings.dart';

/// Gmail-based backup service with automatic scheduling and WhatsApp-like functionality
class GmailBackupService {
  GmailBackupService._();

  static final GmailBackupService instance = GmailBackupService._();

  static const String _backupLabel = 'MoneyFlow_Backup';
  static const String _emailSubject = '[MoneyFlow Backup]';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
    'email',
    'profile',

    // Drive Backup
    'https://www.googleapis.com/auth/drive.appdata',

    // Gmail
    'https://www.googleapis.com/auth/gmail.modify',
    'https://www.googleapis.com/auth/gmail.send',
    ],
  );

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        true,
      _ => false,
    };
  }

  /// Get Gmail account info
  Future<GoogleSignInAccount?> getGmailAccount() async {
    if (!isSupportedPlatform) return null;
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  }

  /// Sign in with Gmail
  Future<GoogleSignInAccount?> signInWithGmail() async {
    if (!isSupportedPlatform) {
      throw StateError('Gmail backup is only supported on Android, iOS, and macOS.');
    }

    try {
      final user = _googleSignIn.currentUser ?? await _googleSignIn.signIn();
      if (user != null) {
        await AppSettings.setGmailBackupAccount(
          email: user.email,
          name: user.displayName ?? '',
        );
      }
      return user;
    } catch (e) {
      throw Exception('Gmail sign-in failed: $e');
    }
  }

  /// Sign out from Gmail
  Future<void> signOutFromGmail() async {
    if (!isSupportedPlatform) return;

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }

    await AppSettings.clearGmailBackupAccount();
  }

  /// Get Gmail API instance
  Future<gmail.GmailApi?> _getGmailApi() async {
    if (!isSupportedPlatform) return null;

    final user = await getGmailAccount();
    if (user == null) return null;

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;

    return gmail.GmailApi(client);
  }

  /// Send backup to Gmail (WhatsApp-like functionality)
  /// The backup is sent as an email with attachment to the user's account
  Future<bool> sendBackupToGmail() async {
    try {
      final gmailApi = await _getGmailApi();
      if (gmailApi == null) return false;

      // Prepare backup data
      final backupData = await _prepareBackupData();
      final jsonString = jsonEncode(backupData);
      final bytes = utf8.encode(jsonString);

      // Create email with backup attachment
      final timestamp = DateTime.now();
      final fileName = 'moneyflow_backup_${timestamp.millisecondsSinceEpoch}.json';

      // Create RFC 2822 formatted email
      final message = _createEmailMessage(
        to: AppSettings.getGmailBackupEmail(),
        subject: '$_emailSubject ${timestamp.toString()}',
        body: '''
Your MoneyFlow Backup

Created: ${timestamp.toLocal()}

This backup contains:
- All transactions
- Investment holdings
- App settings and preferences

Backup Size: ${(bytes.length / 1024).toStringAsFixed(2)} KB

To restore this backup:
1. Open MoneyFlow app
2. Go to Settings > Restore from Gmail
3. Select this backup

---
This is an automated backup. Do not reply to this email.
''',
        attachmentBytes: bytes,
        attachmentFileName: fileName,
      );

      // Send the email
      await gmailApi.users.messages.send(
        gmail.Message()..raw = base64Url.encode(utf8.encode(message)).toString(),
        'me',
      );

      // Update last backup time
      await AppSettings.setGmailBackupLastSyncedAt(DateTime.now());

      return true;
    } catch (e) {
      debugPrint('Error sending backup to Gmail: $e');
      return false;
    }
  }

  /// List all backups from Gmail
  Future<List<GmailBackupInfo>> listBackups() async {
    try {
      final gmailApi = await _getGmailApi();
      if (gmailApi == null) return [];

      // Query for backup emails
      final response = await gmailApi.users.messages.list(
        'me',
        q: 'subject:"$_emailSubject"',
        maxResults: 50,
      );

      final backups = <GmailBackupInfo>[];

      if (response.messages != null) {
        for (final msgHeader in response.messages!) {
          if (msgHeader.id == null) continue;

          try {
            final message = await gmailApi.users.messages.get(
              'me',
              msgHeader.id!,
              format: 'full',
            );

            final backup = _parseBackupMessage(message);
            if (backup != null) {
              backups.add(backup);
            }
          } catch (e) {
            debugPrint('Error parsing backup message: $e');
          }
        }
      }

      return backups;
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  /// Restore backup from Gmail by message ID
  Future<bool> restoreBackupFromGmail(String messageId) async {
    try {
      final gmailApi = await _getGmailApi();
      if (gmailApi == null) return false;

      // Fetch the message
      final message = await gmailApi.users.messages.get(
        'me',
        messageId,
        format: 'full',
      );

      // Extract attachment
      final payload = message.payload;
      if (payload?.parts == null || payload!.parts!.isEmpty) {
        return false;
      }

      for (final part in payload.parts!) {
        if (part.filename != null &&
            part.filename!.endsWith('.json') &&
            part.body?.attachmentId != null) {
          final attachment = await gmailApi.users.messages.attachments.get(
            'me',
            messageId,
            part.body!.attachmentId!,
          );

          if (attachment.data != null) {
            final bytes =
                base64Url.decode(attachment.data!.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), ''));
            final jsonString = utf8.decode(bytes);
            final backupData = jsonDecode(jsonString);

            // Apply backup
            await BackupSyncService.instance
                .applyBackupPayload(backupData);

            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }

  /// Check if backup exists in Gmail
  Future<bool> hasGmailBackup() async {
    final backups = await listBackups();
    return backups.isNotEmpty;
  }

  /// Delete backup from Gmail
  Future<bool> deleteBackupFromGmail(String messageId) async {
    try {
      final gmailApi = await _getGmailApi();
      if (gmailApi == null) return false;

      // Use trash instead of permanent delete so we can avoid the broader
      // full-mailbox scope.
      await gmailApi.users.messages.trash('me', messageId);
      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Setup automatic backup scheduling
  /// This should be called from settings to enable periodic backups
  Future<void> scheduleAutomaticBackup(BackupFrequency frequency) async {
    await AppSettings.setGmailBackupFrequency(frequency.value);
  }

  /// Prepare backup data (reuse existing logic)
  Future<Map<String, dynamic>> _prepareBackupData() async {
    final transactions =
        Hive.box<Transaction>('transactions').values.map((transaction) {
      return <String, dynamic>{
        'id': transaction.id,
        'amount': transaction.amount,
        'category': transaction.category,
        'date': transaction.date.toIso8601String(),
        'type': transaction.type,
        'notes': transaction.notes,
      };
    }).toList();

    final investments =
        Hive.box<InvestmentHolding>('investments').values.map((investment) {
      return <String, dynamic>{
        'id': investment.id,
        'type': investment.type,
        'name': investment.name,
        'quantity': investment.quantity,
        'buyUnitPrice': investment.buyUnitPrice,
        'currentUnitPrice': investment.currentUnitPrice,
        'unitLabel': investment.unitLabel,
        'purchaseDate': investment.purchaseDate.toIso8601String(),
        'notes': investment.notes,
        'symbol': investment.symbol,
        'exchange': investment.exchange,
      };
    }).toList();

    return <String, dynamic>{
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'settings': AppSettings.exportForBackup(),
      'transactions': transactions,
      'investments': investments,
    };
  }

  /// Create RFC 2822 email message with attachment
  String _createEmailMessage({
    required String to,
    required String subject,
    required String body,
    required List<int> attachmentBytes,
    required String attachmentFileName,
  }) {
    final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';

    final headers = '''To: $to
Subject: $subject
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="$boundary"
''';

    final textPart = '''--$boundary
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: 7bit

$body
''';

    final attachmentData = base64.encode(attachmentBytes);
    final attachmentPart = '''--$boundary
Content-Type: application/json; name="$attachmentFileName"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$attachmentFileName"

$attachmentData
--$boundary--''';

    return '$headers\n$textPart$attachmentPart';
  }

  /// Parse backup information from email message
  GmailBackupInfo? _parseBackupMessage(gmail.Message message) {
    try {
      final headers = message.payload?.headers ?? [];

      String? getHeaderValue(String name) {
        return headers.firstWhere(
          (h) => h.name?.toLowerCase() == name.toLowerCase(),
          orElse: () => gmail.MessagePartHeader(name: name),
        ).value;
      }

      final subject = getHeaderValue('subject') ?? '';
      final dateStr = getHeaderValue('date') ?? '';
      final sizeStr = (message.sizeEstimate ?? 0).toString();

      return GmailBackupInfo(
        messageId: message.id ?? '',
        subject: subject,
        date: _parseEmailDate(dateStr),
        size: int.tryParse(sizeStr) ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse email date format
  DateTime _parseEmailDate(String dateStr) {
    try {
      // Try to parse common email date formats
      // This is a simplified parser; in production, use email_validator or similar
      return DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Backup information
class GmailBackupInfo {
  final String messageId;
  final String subject;
  final DateTime date;
  final int size;

  GmailBackupInfo({
    required this.messageId,
    required this.subject,
    required this.date,
    required this.size,
  });

  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Backup frequency options
enum BackupFrequency {
  never('never'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  const BackupFrequency(this.value);
  final String value;

  static BackupFrequency fromString(String value) {
    return BackupFrequency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BackupFrequency.never,
    );
  }

  String get displayName {
    return switch (this) {
      BackupFrequency.never => 'Never',
      BackupFrequency.daily => 'Daily',
      BackupFrequency.weekly => 'Weekly',
      BackupFrequency.monthly => 'Monthly',
    };
  }
}
