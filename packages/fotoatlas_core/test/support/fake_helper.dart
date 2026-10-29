// Helper falso para testar o HelperClient: fala o protocolo JSON-lines v1.
//
// Modos (--mode): normal | crash-once | mute | bad-protocol | stuck
// stuck: responde ao ping, mas trava ao receber system.shutdown (como uma
// leitura WPD presa) e não sai nem com o stdin fechado.
// --marker <arquivo>: em crash-once, cai só se o marcador ainda não existir.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final mode = arg('--mode') ?? 'normal';
  final marker = arg('--marker');
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
}
