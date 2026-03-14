import 'package:flutter/services.dart';

class MunqabatService {
  static const String _assetPath = 'assets/munqabat_list.csv';

  Future<List<String>> loadManqabatNames() async {
    final raw = await rootBundle.loadString(_assetPath);
    final names = <String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toLowerCase().startsWith('sr')) continue;
      final cols = _splitCsvLine(trimmed);
      if (cols.length < 3) continue;
      final name = cols[2].trim();
      if (name.isEmpty) continue;
      names.add(name);
    }
    final list = names.toList()..sort();
    return list;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(ch);
    }
    result.add(buffer.toString());
    return result;
  }
}
