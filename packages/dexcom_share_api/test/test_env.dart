import "dart:io";

Map<String, String> loadTestEnv({
  String dotEnvPath = ".env",
  Map<String, String> environment = const {},
}) {
  final fromFile = _parseDotEnvFile(dotEnvPath);

  final merged = <String, String>{};
  merged.addAll(fromFile);
  merged.addAll(environment);
  return merged;
}

Map<String, String> _parseDotEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};

  final out = <String, String>{};
  final lines = file.readAsLinesSync();
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith("#")) continue;

    final idx = line.indexOf("=");
    if (idx <= 0) continue;

    final key = line.substring(0, idx).trim();
    if (key.isEmpty) continue;

    var value = line.substring(idx + 1).trim();
    if (value.length >= 2) {
      final first = value.codeUnitAt(0);
      final last = value.codeUnitAt(value.length - 1);
      final isDoubleQuoted = first == 0x22 && last == 0x22;
      final isSingleQuoted = first == 0x27 && last == 0x27;
      if (isDoubleQuoted || isSingleQuoted) {
        value = value.substring(1, value.length - 1);
      }
    }

    out.putIfAbsent(key, () => value);
  }

  return out;
}
