import 'dart:io' show Platform;

class SmsMessage {
  final String sender;
  final String body;
  final DateTime date;
  final String id;

  SmsMessage({
    required this.sender,
    required this.body,
    required this.date,
    required this.id,
  });
}

class SmsService {
  // Direct inbox reading is intentionally disabled to avoid
  // restricted SMS permissions and Play Protect install blocks.
  static Future<List<SmsMessage>> fetchSmsMessages() async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      return [];
    } catch (e) {
      print('Error fetching SMS: $e');
      return [];
    }
  }

  // Manual message import keeps the app installable without SMS permissions.
  static Future<List<SmsMessage>> parseSmsText(String rawText) async {
    final messages = <SmsMessage>[];
    final lines = rawText.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        // Parse SMS format: sender|date|body
        final parts = line.split('|');
        if (parts.length >= 3) {
          messages.add(
            SmsMessage(
              sender: parts[0].trim(),
              body: parts[2].trim(),
              date: DateTime.tryParse(parts[1]) ?? DateTime.now(),
              id: '${parts[0]}_${parts[1]}'.hashCode.toString(),
            ),
          );
        }
      } catch (e) {
        print('Error parsing SMS line: $e');
      }
    }

    return messages;
  }
}
