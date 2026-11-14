import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/shell.dart';

/// Quanto tempo os avisos "… Acompanhe em Tarefas." ficam na tela.
const taskNoticeDuration = Duration(seconds: 6);

/// Aviso de tarefa que começou, com o atalho "Ver em Tarefas". Some sozinho
/// depois de [taskNoticeDuration] (com uma ação, o SnackBar ficaria fixo por
/// padrão) e ao usar o atalho.
void showTaskStartedNotice(ScaffoldMessengerState messenger, WidgetRef ref, String message, {Key? key}) {
  // Lido agora: quem mostrou o aviso (ex.: a barra de seleção) pode sumir antes do clique.
  final navigation = ref.read(navigationIndexProvider.notifier);
  messenger.showSnackBar(
    SnackBar(
      key: key,
      content: Text(message),
      duration: taskNoticeDuration,
      persist: false,
      action: SnackBarAction(
        label: 'Ver em Tarefas',
        onPressed: () {
          messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
          navigation.select(tasksDestination);
        },
      ),
    ),
  );
}
