import 'dart:io';

import 'package:path/path.dart' as p;

import '../helper/helper_client.dart';
import '../platform/win_fs.dart';
import 'move_no_replace.dart';
import 'source_reader.dart';

/// Por que um arquivo não foi para a Lixeira.
enum RecycleRefusal {
  /// O tamanho ou a data mudaram desde a conferência.
  changed,

  /// Não está mais lá.
  missing,

  /// Neste disco o Windows apagaria de vez (pendrive, cartão, rede, arquivo
  /// maior que a Lixeira, Lixeira desligada): nada foi removido.
  noRecycleBin,

  /// Aberto em outro programa.
  inUse,

  /// A Lixeira não está disponível agora (o helper caiu ou não iniciou).
  unavailable,

  /// Outro erro do Windows.
  error,
}

/// Resultado de [RecycleBin.recycle]: `refusal == null` = foi para a Lixeira.
class RecycleOutcome {
  const RecycleOutcome.recycled({this.recycledPath}) : refusal = null, message = null;
  const RecycleOutcome.refused(RecycleRefusal this.refusal, String this.message) : recycledPath = null;

  final RecycleRefusal? refusal;
  final String? message;

  /// Onde o Windows guardou o arquivo na Lixeira (diagnóstico e testes).
  final String? recycledPath;
  bool get recycled => refusal == null;
}

/// A **única** forma de o core remover um arquivo de usuário ("Limpar
/// repetidos", ADR 0027): para a Lixeira do Windows, nunca de vez. Quem
/// chama já conferiu o conteúdo (SHA-256) do arquivo e da cópia que fica.
abstract interface class RecycleBin {
  /// Manda [path] para a Lixeira se ele ainda tiver [size] bytes e a data de
  /// modificação [mtime] (FILETIME).
  Future<RecycleOutcome> recycle(String path, {required int size, required int? mtime});
}

/// Lixeira de verdade, pelo helper (`files.recycle`, IFileOperation do Shell
/// com recusa de remoção definitiva; `docs/protocolo-helper.md` §5.5).
class HelperRecycleBin implements RecycleBin {
  HelperRecycleBin(this.client);
  final HelperClient client;

  @override
  Future<RecycleOutcome> recycle(String path, {required int size, required int? mtime}) async {
    try {
      final r = await client.call(
        'files.recycle',
        params: {'path': path, 'expectedSize': size, 'expectedMtime': ?mtime?.toString()},
        timeout: const Duration(minutes: 2),
      );
      return RecycleOutcome.recycled(recycledPath: r['recycledPath'] as String?);
    } on HelperException catch (e) {
      return switch (e.code) {
        'changed' => RecycleOutcome.refused(RecycleRefusal.changed, e.message),
        'not_found' => RecycleOutcome.refused(RecycleRefusal.missing, e.message),
        'no_recycle_bin' => RecycleOutcome.refused(RecycleRefusal.noRecycleBin, e.message),
        'in_use' => RecycleOutcome.refused(RecycleRefusal.inUse, e.message),
        'helper_unavailable' ||
        'helper_closed' ||
        'timeout' ||
        'helper_crashed' => RecycleOutcome.refused(RecycleRefusal.unavailable, e.message),
        _ => RecycleOutcome.refused(RecycleRefusal.error, e.message),
      };
    }
  }
}

/// "Lixeira" de teste: **move** o arquivo (sem substituir e sem copiar) para
/// uma pasta temporária do próprio teste. Recusa qualquer pasta fora do
/// temporário do sistema ou sem `fotoatlas_test` no nome. Só testes e a CLI
/// com `--test-recycle-dir`.
class FolderRecycleBin implements RecycleBin {
  FolderRecycleBin(String dir) : dir = p.normalize(p.absolute(dir)) {
    final temp = p.normalize(p.absolute(Directory.systemTemp.path)).toLowerCase();
    if (!this.dir.toLowerCase().startsWith('$temp${p.separator}') || !p.basename(this.dir).contains('fotoatlas_test')) {
      throw ArgumentError('A lixeira de teste precisa ser uma pasta fotoatlas_test* no temporário do sistema.');
    }
    Directory(this.dir).createSync(recursive: true);
  }

  final String dir;
  int _n = 0;

  /// Recusa como um disco sem Lixeira (testes do caminho "nada é removido").
  bool refuseAll = false;

  @override
  Future<RecycleOutcome> recycle(String path, {required int size, required int? mtime}) async {
    final f = File(path);
    if (!f.existsSync()) return const RecycleOutcome.refused(RecycleRefusal.missing, 'O arquivo não está mais lá.');
    final stat = f.statSync();
    if (stat.size != size || (mtime != null && attributesOf(path).mtime != mtime)) {
      return const RecycleOutcome.refused(RecycleRefusal.changed, 'O arquivo mudou (tamanho ou data diferente).');
    }
    if (refuseAll) {
      return const RecycleOutcome.refused(RecycleRefusal.noRecycleBin, 'Este disco não tem Lixeira (teste).');
    }
    while (true) {
      final target = p.join(dir, '${DateTime.now().microsecondsSinceEpoch}_${_n++}_${p.basename(path)}');
      try {
        moveNoReplace(path, target);
        return RecycleOutcome.recycled(recycledPath: target);
      } on Win32Exception catch (e) {
        if (e.code == 80 || e.code == 183) continue; // nome ocupado: outro nome
        return RecycleOutcome.refused(RecycleRefusal.error, 'Não foi possível mover (erro ${e.code}).');
      }
    }
  }
}
