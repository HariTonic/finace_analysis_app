import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> saveExportData(String csv) async {
  Directory directory;
  try {
    final downloads = await getExternalStorageDirectories(type: StorageDirectory.downloads);
    if (downloads != null && downloads.isNotEmpty) {
      directory = downloads.first;
    } else if (Platform.isAndroid) {
      directory = (await getExternalStorageDirectory())!;
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
  } catch (_) {
    directory = await getApplicationDocumentsDirectory();
  }

  final filename = 'finance_export_${DateTime.now().millisecondsSinceEpoch}.csv';
  final file = File('${directory.path}/$filename');
  await file.writeAsString(csv);
  return file.path;
}
