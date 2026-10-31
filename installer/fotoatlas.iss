; Instalador do FotoAtlas (Inno Setup 6). ADR 0019.
; Não rode o ISCC à mão: use tools\scripts\build-installer.ps1, que prepara a
; pasta com o app, o helper, o ExifTool e o FFmpeg e passa as definições abaixo.
;
; Regras (spec §2 e ADR 0019):
; - O instalador só grava na pasta do programa ({app}), nos atalhos e no
;   registro de desinstalação. O catálogo e as configurações ficam em
;   {userappdata}\FotoAtlas e o cache em {localappdata}\FotoAtlas: instalar e
;   atualizar nunca mexem neles.
; - Não atualiza nem desinstala com o app aberto (AppMutex; o app cria o mutex
;   em app\windows\runner\main.cpp). Nunca fecha o app à força.
; - Desinstalar pergunta antes de tocar no catálogo; a resposta padrão (e a do
;   modo silencioso) é "Não". Se a resposta for "Sim", as pastas vão para a
;   Lixeira, nunca são apagadas de vez.

#ifndef AppVersion
  #error Defina AppVersion (use tools\scripts\build-installer.ps1)
#endif
#ifndef SourceDir
  #error Defina SourceDir (use tools\scripts\build-installer.ps1)
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

[Setup]
; Nunca mude o AppId: é por ele que uma versão nova reconhece a instalada.
AppId={{6B0E5A52-3C4D-4F7B-9E21-8A1D2F0C7B3E}
AppName=FotoAtlas
AppVersion={#AppVersion}
AppVerName=FotoAtlas {#AppVersion}
AppPublisher=Lucca Bueno
AppPublisherURL=https://github.com/LuccaBueno/fotoatlas
AppSupportURL=https://github.com/LuccaBueno/fotoatlas/issues
AppCopyright=Copyright (C) 2026 Lucca Bueno Cuzzolin. Licença MIT.
VersionInfoVersion={#AppVersion}
VersionInfoDescription=Instalador do FotoAtlas
; Só para o usuário atual: sem pedir permissão de administrador, e o catálogo
; (que é por usuário) é o do mesmo usuário que instalou.
PrivilegesRequired=lowest
DefaultDirName={autopf}\FotoAtlas
DisableProgramGroupPage=yes
DefaultGroupName=FotoAtlas
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
AppMutex=FotoAtlas.App.Aberto
CloseApplications=no
RestartApplications=no
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\fotoatlas.exe
UninstallDisplayName=FotoAtlas
WizardStyle=modern
OutputDir={#OutputDir}
OutputBaseFilename=FotoAtlas-{#AppVersion}-instalador
Compression=lzma2/max
SolidCompression=yes
ShowLanguageDialog=no

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Messages]
ConfirmUninstall=Remover o %1 deste computador?%n%nSuas fotos e vídeos não são tocados. O catálogo e as configurações não são apagados agora: no fim, o desinstalador pergunta o que fazer com eles.
SetupAppRunningError=O %1 está aberto.%n%nFeche o FotoAtlas (se houver uma tarefa em andamento, ele guarda onde parou) e clique em OK para continuar, ou em Cancelar para sair.
UninstallAppRunningError=O %1 está aberto.%n%nFeche o FotoAtlas e clique em OK para continuar, ou em Cancelar para sair.

[Tasks]
Name: "desktopicon"; Description: "Criar um atalho na área de trabalho"; GroupDescription: "Atalhos:"

[InstallDelete]
; Atualização: tira da pasta do programa o que é só da versão anterior (ex.:
; arquivos de uma ExifTool antiga). Só dentro de {app}.
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\tools"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\FotoAtlas"; Filename: "{app}\fotoatlas.exe"; WorkingDir: "{app}"; Comment: "Organize fotos e vídeos sem perder nada"
Name: "{autodesktop}\FotoAtlas"; Filename: "{app}\fotoatlas.exe"; WorkingDir: "{app}"; Comment: "Organize fotos e vídeos sem perder nada"; Tasks: desktopicon

[Run]
Filename: "{app}\fotoatlas.exe"; Description: "Abrir o FotoAtlas"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[Code]
// Manda uma pasta para a Lixeira (recuperável). Devolve True se ela sumiu.
function RecycleFolder(const Path: String): Boolean;
var
  ResultCode: Integer;
  Quoted: String;
begin
  Result := True;
  if not DirExists(Path) then
    Exit;
  Quoted := Path;
  StringChangeEx(Quoted, '''', '''''', True);
  Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName Microsoft.VisualBasic; ' +
    '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(''' + Quoted + ''', ''OnlyErrorDialogs'', ''SendToRecycleBin'')"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := not DirExists(Path);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Catalog, Cache: String;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;
  Catalog := ExpandConstant('{userappdata}\FotoAtlas');
  Cache := ExpandConstant('{localappdata}\FotoAtlas');
  if not DirExists(Catalog) and not DirExists(Cache) then
    Exit;
  // Padrão "Não" (também no modo silencioso): o catálogo fica.
  if SuppressibleMsgBox(
      'O FotoAtlas foi removido. O catálogo (o que o FotoAtlas sabe sobre suas fotos: dispositivos, ' +
      'conferências, momentos, datas corrigidas) e as configurações continuam guardados em:' + #13#10#13#10 +
      Catalog + #13#10#13#10 +
      'Se instalar o FotoAtlas de novo, ele continua de onde parou. Suas fotos e vídeos não estão nessa pasta ' +
      'e não são tocados.' + #13#10#13#10 +
      'Quer apagar também o catálogo, as configurações e as miniaturas? Eles vão para a Lixeira.',
      mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) <> IDYES then
    Exit;
  if RecycleFolder(Catalog) and RecycleFolder(Cache) then
    SuppressibleMsgBox('O catálogo, as configurações e as miniaturas foram para a Lixeira.',
      mbInformation, MB_OK, IDOK)
  else
    SuppressibleMsgBox('Não deu para mandar tudo para a Lixeira. O que sobrou continua em:' + #13#10#13#10 +
      Catalog + #13#10 + Cache, mbError, MB_OK, IDOK);
end;
