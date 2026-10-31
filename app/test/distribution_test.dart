import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/app_info.dart';
import 'package:fotoatlas/app/providers.dart';
import 'package:fotoatlas/app/theme.dart';
import 'package:fotoatlas/features/settings/settings_page.dart';

import 'support/fake_backend.dart';

/// Fase 8 (ADR 0019): ícone, versão e as regras do instalador que protegem o
/// catálogo. O teste de instalar/atualizar/desinstalar de verdade é o
/// `tools\scripts\test-installer.ps1` (CI).
void main() {
  group('ícone do app', () {
    test('app_icon.ico tem de 16 a 256 px, gerado da logo (não é o do Flutter)', () {
      final bytes = File('windows/runner/resources/app_icon.ico').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(data.getUint16(0, Endian.little), 0);
      expect(data.getUint16(2, Endian.little), 1, reason: 'tipo ícone');
      final count = data.getUint16(4, Endian.little);
      final sizes = <int>{};
      for (var i = 0; i < count; i++) {
        final w = data.getUint8(6 + 16 * i);
        sizes.add(w == 0 ? 256 : w);
        final length = data.getUint32(6 + 16 * i + 8, Endian.little);
        final offset = data.getUint32(6 + 16 * i + 12, Endian.little);
        expect(offset + length, lessThanOrEqualTo(bytes.length));
      }
      expect(sizes, containsAll([16, 20, 24, 32, 40, 48, 64, 256]));
      // O ícone padrão do `flutter create` tem 33.772 bytes.
      expect(bytes.length, isNot(33772));
    });

    test('o gerador usa a mesma logo do menu lateral', () {
      final shell = File('lib/app/shell.dart').readAsStringSync();
      final generator = File('tool/gen_app_icon.dart').readAsStringSync();
      expect(shell, contains('Icons.travel_explore'));
      expect(generator, contains('Icons.travel_explore'));
    });
  });

  group('versão', () {
    test('rótulo com e sem versão definida pelo build', () {
      expect(appVersionLabel('1.0.0'), 'Versão 1.0.0');
      expect(appVersionLabel(''), 'Versão de desenvolvimento');
    });

    testWidgets('Configurações mostra a versão e onde ficam o catálogo e as configurações', (tester) async {
      tester.view
        ..physicalSize = const Size(1400, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [backendProvider.overrideWithValue(FakeBackend())],
          child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sobre o FotoAtlas'), findsOneWidget);
      expect(find.text('Versão de desenvolvimento'), findsOneWidget);
      expect(find.textContaining(r'C:\Users\Teste\AppData\Roaming\FotoAtlas'), findsOneWidget);
      expect(find.textContaining('Atualizar o FotoAtlas não mexe nessa pasta'), findsOneWidget);
    });
  });

  group('instalador (installer\\fotoatlas.iss)', () {
    final iss = File('../installer/fotoatlas.iss').readAsStringSync();
    final main = File('windows/runner/main.cpp').readAsStringSync();
    String setting(String name) => RegExp('^$name=(.*)\$', multiLine: true).firstMatch(iss)!.group(1)!.trim();

    test('não atualiza nem desinstala com o app aberto, e nunca o fecha à força', () {
      final mutex = setting('AppMutex');
      expect(main, contains('CreateMutexW(nullptr, FALSE, L"$mutex")'));
      expect(setting('CloseApplications'), 'no');
    });

    test('AppId fixo (é por ele que a atualização acha a versão instalada)', () {
      expect(setting('AppId'), '{{6B0E5A52-3C4D-4F7B-9E21-8A1D2F0C7B3E}');
    });

    test('instala por usuário, com atalhos no menu Iniciar e na área de trabalho', () {
      expect(setting('PrivilegesRequired'), 'lowest');
      expect(iss, contains(r'Name: "{autoprograms}\FotoAtlas"; Filename: "{app}\fotoatlas.exe"'));
      expect(iss, contains(r'Name: "{autodesktop}\FotoAtlas"; Filename: "{app}\fotoatlas.exe"'));
      expect(setting('SetupIconFile'), r'..\app\windows\runner\resources\app_icon.ico');
    });

    test('só apaga dentro da pasta do programa; o catálogo só com pergunta (padrão Não) e para a Lixeira', () {
      // Seções que apagam arquivos: só caminhos em {app}.
      final deletes = RegExp(r'^Type: \w+; Name: "([^"]+)"', multiLine: true).allMatches(iss).map((m) => m.group(1)!);
      expect(deletes, isNotEmpty);
      for (final path in deletes) {
        expect(path, startsWith(r'{app}\'));
      }
      expect(iss, isNot(contains('[UninstallDelete]')));
      expect(iss, isNot(contains('DelTree')));
      expect(iss, isNot(contains('DeleteFile(')));
      // As pastas do usuário só aparecem no código da pergunta ao desinstalar.
      final code = iss.substring(iss.indexOf('[Code]'));
      final setup = iss.substring(0, iss.indexOf('[Code]')).split('\n').where((l) => !l.startsWith(';')).join('\n');
      expect(setup, isNot(contains('{userappdata}')));
      expect(setup, isNot(contains('{localappdata}')));
      expect(code, contains('MB_YESNO or MB_DEFBUTTON2, IDNO) <> IDYES then'));
      expect(code, contains("'SendToRecycleBin'"));
    });
  });
}
