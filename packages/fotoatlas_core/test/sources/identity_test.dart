import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

void main() {
  final hd = fakeVolume(r'X:\vol1', mount: r'E:\');
  final identity = SourceIdentity(
    volumeGuid: hd.guidPath,
    volumeSerial: hd.serial,
    volumeLabel: hd.label,
    fileSystem: hd.fileSystem,
    volumeSizeBytes: hd.totalBytes,
    reliableDiskSerial: 'WD-TESTE-0001',
  );

  test('troca de letra: o mesmo volume é reconhecido', () {
    final moved = fakeVolume(r'X:\vol1', mount: r'G:\');
    final result = IdentityScoring.match(identity, [moved]);
    expect(result, isA<Matched>());
    expect((result as Matched).volume.displayMount, r'G:\');
  });

  test('mesmo HD em outro PC (GUID diferente) com disco confiável', () {
    final elsewhere = fakeVolume(r'X:\outro_guid');
    expect(IdentityScoring.match(identity, [elsewhere]), isA<Matched>());
  });

  test('GUID diferente sem disco confiável: pergunta ao usuário', () {
    final elsewhere = fakeVolume(r'X:\outro_guid', diskSerial: null, diskConfidence: 'weak');
    expect(IdentityScoring.match(identity, [elsewhere]), isA<Ambiguous>());
  });

  test('disco reformatado (serial do volume mudou) não é reconhecido sozinho', () {
    final reformatted = fakeVolume(r'X:\vol1', serial: 0x0BADF00D);
    expect(IdentityScoring.match(identity, [reformatted]), isNot(isA<Matched>()));
  });

  test('dois candidatos fortes (disco clonado): ambíguo', () {
    final cloneA = fakeVolume(r'X:\clone_a');
    final cloneB = fakeVolume(r'X:\clone_b');
    expect(IdentityScoring.match(identity, [cloneA, cloneB]), isA<Ambiguous>());
  });

  test('nada parecido: desconectada', () {
    final other = fakeVolume(r'X:\x', serial: 1, label: 'Outro', fs: 'exFAT', total: 5, diskSerial: 'OUTRO-123');
    expect(IdentityScoring.match(identity, [other]), isA<NotConnected>());
    expect(IdentityScoring.match(identity, []), isA<NotConnected>());
  });

  test('volume do sistema (EFI) nunca é candidato', () {
    final efi = VolumeInfo(guidPath: hd.guidPath, serial: hd.serial, isSystem: true);
    expect(IdentityScoring.match(identity, [efi]), isA<NotConnected>());
  });
}
