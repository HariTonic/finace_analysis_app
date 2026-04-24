import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/investment_holding.dart';
import '../models/transaction.dart';
import 'app_settings.dart';

class BackupSyncService {
  BackupSyncService._();

  static final BackupSyncService instance = BackupSyncService._();

  static const String _backupFileName = 'finance_management_backup_v1.json';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      drive.DriveApi.driveAppdataScope,
      'email',
      'profile',
    ],
  );

  bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  Future<GoogleSignInAccount?> restorePreviousSignIn() async {
    if (!isSupportedPlatform) {
      return null;
    }

    final user = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (user != null) {
      await AppSettings.setBackupAccount(
        email: user.email,
        name: user.displayName ?? '',
      );
    }
    return user;
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (!isSupportedPlatform) {
      throw StateError('Google Drive backup is supported on Android, iOS, and macOS only.');
    }

    final user = _googleSignIn.currentUser ?? await _googleSignIn.signIn();
    if (user != null) {
      await AppSettings.setBackupAccount(
        email: user.email,
        name: user.displayName ?? '',
      );
    }
    return user;
  }

  Future<void> signOut() async {
    if (!isSupportedPlatform) {
      return;
    }

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }

    await AppSettings.clearBackupAccount();
  }

  Future<bool> hasRemoteBackup() async {
    final api = await _getDriveApi();
    if (api == null) {
      return false;
    }

    final file = await _findBackupFile(api);
    return file != null;
  }

  Future<bool> uploadBackup() async {
    final api = await _getDriveApi();
    if (api == null) {
      return false;
    }

    final payload = await _createBackupPayload();
    final json = jsonEncode(payload);
    final bytes = utf8.encode(json);
    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    final existingFile = await _findBackupFile(api);
    final metadata = drive.File()
      ..name = _backupFileName
      ..modifiedTime = DateTime.now().toUtc();

    if (existingFile == null) {
      metadata.parents = <String>['appDataFolder'];
      await api.files.create(metadata, uploadMedia: media);
    } else {
      await api.files.update(metadata, existingFile.id!, uploadMedia: media);
    }

    await AppSettings.setBackupLastSyncedAt(DateTime.now());
    return true;
  }

  Future<bool> restoreBackup() async {
    final api = await _getDriveApi();
    if (api == null) {
      return false;
    }

    final file = await _findBackupFile(api);
    if (file?.id == null) {
      return false;
    }

    final media = await api.files.get(
      file!.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final chunks = await media.stream.toList();
    final bytes = chunks.expand((chunk) => chunk).toList();
    final decoded = jsonDecode(utf8.decode(bytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup data format is invalid.');
    }

    await _applyBackupPayload(decoded);
    return true;
  }

  Future<void> backupIfEnabled() async {
    if (!AppSettings.isBackupEnabled()) {
      return;
    }

    final accountEmail = AppSettings.getBackupAccountEmail();
    if (accountEmail.isEmpty) {
      return;
    }

    try {
      await restorePreviousSignIn();
      await uploadBackup();
    } catch (_) {
      // Keep auto-backup non-blocking for transaction/profile flows.
    }
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    if (!isSupportedPlatform) {
      return null;
    }

    final user = await restorePreviousSignIn();
    if (user == null) {
      return null;
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      return null;
    }

    return drive.DriveApi(client);
  }

  Future<drive.File?> _findBackupFile(drive.DriveApi api) async {
    final response = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      $fields: 'files(id, name, modifiedTime)',
      pageSize: 1,
    );

    if (response.files == null || response.files!.isEmpty) {
      return null;
    }

    return response.files!.first;
  }

  Future<Map<String, dynamic>> _createBackupPayload() async {
    final transactions = Hive.box<Transaction>('transactions').values.map((transaction) {
      return <String, dynamic>{
        'id': transaction.id,
        'amount': transaction.amount,
        'category': transaction.category,
        'date': transaction.date.toIso8601String(),
        'type': transaction.type,
        'notes': transaction.notes,
      };
    }).toList();
    final investments = Hive.box<InvestmentHolding>('investments').values.map((investment) {
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

  Future<void> _applyBackupPayload(Map<String, dynamic> payload) async {
    final settings = payload['settings'];
    if (settings is Map<String, dynamic>) {
      await AppSettings.restoreFromBackup(settings);
    }

    final box = Hive.box<Transaction>('transactions');
    await box.clear();
    final investmentBox = Hive.box<InvestmentHolding>('investments');
    await investmentBox.clear();

    final transactions = payload['transactions'];
    if (transactions is List) {
      for (final item in transactions) {
        if (item is! Map) {
          continue;
        }

        final transaction = Transaction(
          id: '${item['id'] ?? DateTime.now().toIso8601String()}',
          amount: ((item['amount'] ?? 0) as num).toDouble(),
          category: '${item['category'] ?? ''}',
          date: DateTime.tryParse('${item['date'] ?? ''}') ?? DateTime.now(),
          type: '${item['type'] ?? 'expense'}',
          notes: '${item['notes'] ?? ''}',
        );
        await box.add(transaction);
      }
    }

    final investments = payload['investments'];
    if (investments is List) {
      for (final item in investments) {
        if (item is! Map) {
          continue;
        }

        final investment = InvestmentHolding(
          id: '${item['id'] ?? DateTime.now().toIso8601String()}',
          type: '${item['type'] ?? 'other'}',
          name: '${item['name'] ?? ''}',
          quantity: ((item['quantity'] ?? 0) as num).toDouble(),
          buyUnitPrice: ((item['buyUnitPrice'] ?? 0) as num).toDouble(),
          currentUnitPrice: ((item['currentUnitPrice'] ?? 0) as num).toDouble(),
          unitLabel: '${item['unitLabel'] ?? ''}',
          purchaseDate: DateTime.tryParse('${item['purchaseDate'] ?? ''}') ?? DateTime.now(),
          notes: '${item['notes'] ?? ''}',
          symbol: '${item['symbol'] ?? ''}',
          exchange: '${item['exchange'] ?? ''}',
        );
        await investmentBox.add(investment);
      }
    }

    final createdAt = DateTime.tryParse('${payload['createdAt'] ?? ''}');
    await AppSettings.setBackupLastSyncedAt(createdAt ?? DateTime.now());
  }
}
