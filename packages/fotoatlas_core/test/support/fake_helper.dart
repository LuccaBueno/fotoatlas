// Helper falso para testar o HelperClient: fala o protocolo JSON-lines v1.
//
// Modos (--mode): normal | crash-once | mute | bad-protocol | stuck | phone-stuck | phone-crash
// phone-stuck: um celular com 1 foto; a leitura (devices.hashObject) nunca
// responde nem obedece ao system.cancel. O system.shutdown é confirmado; quando
// o stdin fecha, como o helper real ao fechar a sessão WPD, a leitura em
// andamento falha com not_found e o processo trava sem sair (só finalizado).
// stuck: responde ao ping, mas trava ao receber system.shutdown (como uma
// leitura WPD presa) e não sai nem com o stdin fechado.
// --marker <arquivo>: em crash-once/phone-crash, cai só se o marcador ainda não existir.
// --crash-on list|hash: em phone-crash, onde cair.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

void main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final mode = arg('--mode') ?? 'normal';
  final marker = arg('--marker');
  final stuckReads = <Object?>[];
  // Celular simulado: phone-stuck (leitura presa) ou phone-crash (o helper
  // cai uma vez, na listagem da pasta ou na leitura, conforme --crash-on).
  final phone = mode == 'phone-stuck' || mode == 'phone-crash';
  final crashOn = arg('--crash-on');
  bool crashOnce(String point) {
    if (mode != 'phone-crash' || crashOn != point || marker == null || File(marker).existsSync()) return false;
    File(marker).writeAsStringSync('caiu');
    return true;
  }

  void send(Map<String, Object?> m) => stdout.write('${jsonEncode(m)}\n');

  send({
    'v': 1,
    'event': 'hello',
    'data': {'protocol': mode == 'bad-protocol' ? 2 : 1, 'helperVersion': 'fake', 'pid': pid},
  });
  if (mode == 'mute') {
    await stdin.drain<void>();
    return;
  }

  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final req = (jsonDecode(line) as Map).cast<String, Object?>();
    final id = req['id'];
    switch (req['method']) {
      case 'system.ping':
        send({
          'v': 1,
          'id': id,
          'ok': true,
          'result': {'uptimeMs': 1},
        });
      case 'devices.list' when phone:
        send({
          'v': 1,
          'id': id,
          'ok': true,
          'result': {
            'devices': [
              {
                'deviceId': 'wpd:travado',
                'friendlyName': 'Celular travado',
                'serial': 'TRAVADO-1',
                'kind': 'android',
                'status': 'ok',
                'storages': [
                  {'storageId': 'st', 'name': 'Interno'},
                ],
              },
            ],
          },
        });
      case 'devices.listChildren' when phone:
        final params = (req['params'] as Map).cast<String, Object?>();
        if (params['objectId'] == 'st' && crashOnce('list')) exit(3);
        final items = switch (params['objectId']) {
          '' => [
            {'objectId': 'st', 'name': 'Interno', 'isFolder': true},
          ],
          'st' => [
            {'objectId': 'f1', 'name': 'IMG_1.jpg', 'isFolder': false, 'size': 10, 'modified': '1'},
          ],
          _ => <Map<String, Object?>>[],
        };
        send({
          'v': 1,
          'id': id,
          'event': 'entries',
          'data': {'items': items},
        });
        send({
          'v': 1,
          'id': id,
          'ok': true,
          'result': {'count': items.length},
        });
      case 'devices.hashObject' when mode == 'phone-crash':
        if (crashOnce('hash')) exit(3);
        send({
          'v': 1,
          'id': id,
          'ok': true,
          'result': {'sha256': sha256.convert(List.filled(10, 1)).toString(), 'size': 10, 'modified': '1'},
        });
      case 'devices.hashObject' when phone:
        stuckReads.add(id); // preso: só responde no shutdown
      case 'system.cancel' when phone:
        break; // a leitura presa não obedece
      case 'system.shutdown' when mode == 'phone-stuck':
        // Confirma e espera o stdin fechar (abaixo).
        send({'v': 1, 'id': id, 'ok': true, 'result': <String, Object?>{}});
      case 'system.shutdown' when mode == 'stuck':
        while (true) {
          sleep(const Duration(seconds: 1));
        }
      case 'system.shutdown':
        send({'v': 1, 'id': id, 'ok': true, 'result': <String, Object?>{}});
        await stdout.flush();
        exit(0);
      case 'volumes.list':
        if (mode == 'crash-once' && marker != null && !File(marker).existsSync()) {
          File(marker).writeAsStringSync('caiu');
          exit(3);
        }
        send({
          'v': 1,
          'id': id,
          'ok': true,
          'result': {
            'volumes': [
              {
                'guidPath': r'\\?\Volume{00000000-0000-0000-0000-0000000000aa}\',
                'mountPoints': [r'E:\'],
                'label': 'Falso',
                'fileSystem': 'exFAT',
                'serial': 42,
                'totalBytes': 1000,
                'freeBytes': 10,
                'driveType': 'removable',
                'isSystem': false,
                'isBoot': false,
                'physicalDisks': [
                  {
                    'diskNumber': 3,
                    'serial': null,
                    'model': 'Pendrive',
                    'sizeBytes': 1000,
                    'busType': 'usb',
                    'removableMedia': true,
                    'identityConfidence': 'weak',
                  },
                ],
              },
            ],
          },
        });
      default:
        send({
          'v': 1,
          'id': id,
          'ok': false,
          'error': {'code': 'bad_request', 'message': 'desconhecido', 'retryable': false},
        });
    }
  }
  // stdin fechou.
  if (mode == 'phone-stuck') {
    for (final r in stuckReads) {
      send({
        'v': 1,
        'id': r,
        'ok': false,
        'error': {'code': 'not_found', 'message': 'Sessão do aparelho fechada.', 'retryable': false},
      });
    }
    await stdout.flush();
    while (true) {
      sleep(const Duration(seconds: 1));
    }
  }
}
