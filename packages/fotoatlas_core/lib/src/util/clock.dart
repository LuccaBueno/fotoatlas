/// Agora, em ms Unix UTC (convenção do catálogo).
int nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

/// FILETIME (100 ns desde 1601-01-01 UTC) → DateTime UTC.
DateTime fileTimeToDateTime(int fileTime) => DateTime.utc(1601).add(Duration(microseconds: fileTime ~/ 10));
