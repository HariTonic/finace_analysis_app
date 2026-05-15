import 'package:hive/hive.dart';

part 'import_history.g.dart';

@HiveType(typeId: 3)
class ImportRecord extends HiveObject {
  @HiveField(0)
  DateTime importDate;

  @HiveField(1)
  int transactionCount;

  @HiveField(2)
  String source; // 'sms', 'csv', 'manual', etc.

  @HiveField(3)
  List<String> importedTransactionIds; // IDs of imported transactions

  @HiveField(4)
  int duplicatesSkipped;

  ImportRecord({
    required this.importDate,
    required this.transactionCount,
    required this.source,
    required this.importedTransactionIds,
    required this.duplicatesSkipped,
  });
}

class ImportHistoryManager {
  static const String boxName = 'import_history';

  // Initialize import history box
  static Future<void> initialize() async {
    try {
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ImportRecordAdapter());
      }
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<ImportRecord>(boxName);
      }
    } catch (e) {
      print('Error initializing import history: $e');
    }
  }

  // Add import record
  static Future<void> addImportRecord(
    int transactionCount,
    String source,
    List<String> transactionIds,
    int duplicatesSkipped,
  ) async {
    try {
      final box = Hive.box<ImportRecord>(boxName);
      final record = ImportRecord(
        importDate: DateTime.now(),
        transactionCount: transactionCount,
        source: source,
        importedTransactionIds: transactionIds,
        duplicatesSkipped: duplicatesSkipped,
      );
      await box.add(record);
    } catch (e) {
      print('Error adding import record: $e');
    }
  }

  // Get all import records
  static List<ImportRecord> getImportRecords() {
    try {
      final box = Hive.box<ImportRecord>(boxName);
      return box.values.toList().reversed.toList();
    } catch (e) {
      print('Error getting import records: $e');
      return [];
    }
  }

  // Get import records by source
  static List<ImportRecord> getImportRecordsBySource(String source) {
    try {
      final box = Hive.box<ImportRecord>(boxName);
      return box.values
          .where((record) => record.source == source)
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error getting import records by source: $e');
      return [];
    }
  }

  // Get total imported transaction count
  static int getTotalImportedCount() {
    try {
      final box = Hive.box<ImportRecord>(boxName);
      return box.values.fold<int>(
          0, (sum, record) => sum + record.transactionCount);
    } catch (e) {
      print('Error getting total imported count: $e');
      return 0;
    }
  }

  // Check if transaction was imported before
  static bool isTransactionImported(String transactionId) {
    try {
      final box = Hive.box<ImportRecord>(boxName);
      for (final record in box.values) {
        if (record.importedTransactionIds.contains(transactionId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking if transaction imported: $e');
      return false;
    }
  }

  // Clear old import records (older than specified days)
  static Future<void> clearOldRecords(int days) async {
    try {
      final box = Hive.box<ImportRecord>(boxName);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final keysToDelete = <dynamic>[];
      for (final entry in box.toMap().entries) {
        if (entry.value.importDate.isBefore(cutoffDate)) {
          keysToDelete.add(entry.key);
        }
      }

      for (final key in keysToDelete) {
        await box.delete(key);
      }
    } catch (e) {
      print('Error clearing old records: $e');
    }
  }
}
