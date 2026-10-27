import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/l10n/strings.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'support/fake_backend.dart';
import 'widgets_test.dart' show harness, openDevices;

const pixel = DeviceInfo(
  deviceId: 'wpd:pixel',
  friendlyName: 'Pixel de Teste',
  platform: 'android',
  storages: [DeviceStorage(storageId: 's0', name: 'Armazenamento interno')],
);
const iphone = DeviceInfo(
  deviceId: 'wpd:iphone',
  friendlyName: 'iPhone de Ana',
  platform: 'iphone',
  status: 'unauthorized',
);

SourceView phoneSource({String? status = 'ok', String platform = 'android'}) => SourceView(
  id: 'p1',
  name: 'Pixel',
  kind: 'phone',
  rootRelPath: '',
  state: status == null ? SourceState.disconnected : SourceState.connected,
  devicePlatform: platform,
  deviceStatus: status,
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
  });

  testWidgets('adicionar celular: lista, avisos do iPhone e cadastro', (tester) async {
    final backend = FakeBackend()..fakeDevices = [(pixel, null), (iphone, null)];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.text('Adicionar celular').first);
    await tester.pumpAndSettle();

    expect(find.text('Qual celular você quer adicionar?'), findsOneWidget);
    expect(find.textContaining('Pronto · Armazenamento interno'), findsOneWidget);
    expect(find.textContaining('Falta permitir o acesso'), findsOneWidget);
    expect(find.text(unauthorizedMessage), findsOneWidget);
    expect(find.text(iphoneOriginalsHint), findsOneWidget);
    expect(find.textContaining('nada é gravado, movido ou apagado'), findsOneWidget);

    await tester.tap(find.text('Pixel de Teste'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('addPhone:wpd:pixel'));
    expect(find.textContaining('Celular adicionado'), findsOneWidget);
  });

  testWidgets('sem celular conectado: explica como conectar', (tester) async {
    await tester.pumpWidget(harness(FakeBackend()));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.text('Adicionar celular').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-phones')), findsOneWidget);
    expect(find.textContaining('Transferência de arquivos'), findsOneWidget);
  });

  testWidgets('celular já cadastrado aparece desabilitado', (tester) async {
    final backend = FakeBackend()..fakeDevices = [(pixel, 'p1')];
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    await tester.tap(find.text('Adicionar celular').first);
    await tester.pumpAndSettle();
    expect(find.text('Já cadastrado'), findsOneWidget);
    await tester.tap(find.text('Pixel de Teste'));
    await tester.pumpAndSettle();
    expect(backend.calls.where((c) => c.startsWith('addPhone')), isEmpty);
  });

  testWidgets('celular bloqueado: aviso e "Escanear" desabilitado', (tester) async {
    final backend = FakeBackend([phoneSource(status: 'locked')]);
    await tester.pumpWidget(harness(backend));
    await tester.pumpAndSettle();
    await openDevices(tester);
    expect(find.byKey(const ValueKey('phone-locked-p1')), findsOneWidget);
    expect(find.text(lockedMessage), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Escanear'), matching: find.bySubtype<ButtonStyleButton>()),
    );
    expect(button.onPressed, isNull);

    backend.emitSources([phoneSource()]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-locked-p1')), findsNothing);
    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('scan:p1'));
  });

  testWidgets('iPhone cadastrado lembra do "Manter originais"', (tester) async {
    await tester.pumpWidget(harness(FakeBackend([phoneSource(platform: 'iphone')])));
    await tester.pumpAndSettle();
    await openDevices(tester);
    expect(find.byKey(const ValueKey('iphone-originals-p1')), findsOneWidget);
    expect(find.textContaining('iPhone'), findsWidgets);
  });
}
