import 'package:ffi/ffi.dart';

import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';

/// Move/renomeia [from] para [to] **sem nunca sobrescrever** (regra 5):
/// `MoveFileExW` sem `MOVEFILE_REPLACE_EXISTING`, com `WRITE_THROUGH`.
/// Se [to] já existir, lança [Win32Exception] (`ERROR_ALREADY_EXISTS`).
void moveNoReplace(String from, String to) => using((arena) {
  final ok = moveFileEx(
    toExtendedPath(from).toNativeUtf16(allocator: arena),
    toExtendedPath(to).toNativeUtf16(allocator: arena),
    movefileWriteThrough,
  );
  if (ok == 0) throw Win32Exception('MoveFileExW', getLastError(), to);
});
