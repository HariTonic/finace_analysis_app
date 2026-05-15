import '../models/transaction.dart';

class TransactionCsvService {
  static const List<String> _headers = <String>[
    'ID',
    'Amount',
    'Category',
    'Date',
    'Type',
    'Notes',
  ];

  static String buildCsv(List<Transaction> transactions) {
    final rows = <List<String>>[
      _headers,
      ...transactions.map((transaction) => <String>[
            transaction.id,
            transaction.amount.toString(),
            transaction.category,
            transaction.date.toIso8601String(),
            transaction.type,
            transaction.notes,
          ]),
    ];

    return rows.map(_encodeRow).join('\n');
  }

  static List<Transaction> parseTransactions(String csv) {
    final rows = _parseCsvRows(csv);
    if (rows.isEmpty) {
      return <Transaction>[];
    }

    final headerIndex = rows.indexWhere((row) {
      if (row.length < _headers.length) {
        return false;
      }
      return row
              .take(_headers.length)
              .map((value) => value.trim().toLowerCase())
              .join('|') ==
          _headers.map((value) => value.toLowerCase()).join('|');
    });

    if (headerIndex == -1) {
      return <Transaction>[];
    }

    final transactions = <Transaction>[];
    for (final row in rows.skip(headerIndex + 1)) {
      if (row.every((value) => value.trim().isEmpty)) {
        continue;
      }
      if (row.length < _headers.length) {
        continue;
      }

      final id = row[0].trim();
      final amount = double.tryParse(row[1].trim());
      final category = row[2].trim();
      final date = DateTime.tryParse(row[3].trim());
      final type = row[4].trim();
      final notes = row.sublist(5).join(',').trim();

      if (id.isEmpty ||
          amount == null ||
          date == null ||
          category.isEmpty ||
          type.isEmpty) {
        continue;
      }

      transactions.add(
        Transaction(
          id: id,
          amount: amount,
          category: category,
          date: date,
          type: type,
          notes: notes,
        ),
      );
    }

    return transactions;
  }

  static String _encodeRow(List<String> values) {
    return values.map(_escapeCell).join(',');
  }

  static String _escapeCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  static List<List<String>> _parseCsvRows(String csv) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < csv.length; index++) {
      final char = csv[index];

      if (char == '"') {
        final isEscapedQuote =
            inQuotes && index + 1 < csv.length && csv[index + 1] == '"';
        if (isEscapedQuote) {
          cell.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (!inQuotes && char == ',') {
        row.add(cell.toString());
        cell.clear();
        continue;
      }

      if (!inQuotes && (char == '\n' || char == '\r')) {
        if (char == '\r' && index + 1 < csv.length && csv[index + 1] == '\n') {
          index++;
        }
        row.add(cell.toString());
        cell.clear();
        if (row.any((value) => value.isNotEmpty)) {
          rows.add(List<String>.from(row));
        }
        row.clear();
        continue;
      }

      cell.write(char);
    }

    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      if (row.any((value) => value.isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
    }

    return rows;
  }
}
