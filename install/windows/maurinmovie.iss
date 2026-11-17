#ifndef MyAppName
  #define MyAppName "MaurinMovie"
#endif
#include "..\..\dist\version.iss"
#ifndef SetupSeq
  #define SetupSeq "001"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "Maurinsoft"
#endif
#ifndef MyAppExeName
  #define MyAppExeName "mmenu.exe"
#endif
#ifndef OutputExeName
  #define OutputExeName "setup_maurinmovie_" + SetupSeq
#endif

[Setup]
AppId={{D4B8C17F-8A12-4F55-B6D9-4E3B7C9F2A10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyBinaryVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\MaurinMovie
DefaultGroupName=MaurinMovie
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename={#OutputExeName}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
WizardImageFile=..\..\dist\installer-images\welcome.bmp
WizardSizePercent=120
UninstallDisplayIcon={app}\mmenu.exe
CloseApplications=yes
ChangesAssociations=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Types]
Name: "full"; Description: "Instalacao Completa (Todos os 7 aplicativos, OpenSSL e documentacao)"
Name: "compact"; Description: "Instalacao Basica (MMenu, MScript e OpenSSL)"
Name: "custom"; Description: "Instalacao Personalizada (Escolher os modulos desejados)"; Flags: iscustom

[Components]
Name: "tools"; Description: "Aplicativos da Suite MaurinMovie"; Types: full compact custom; Flags: fixed
Name: "tools\mmenu"; Description: "MMenu - Portal e Lancador da Suite"; Types: full compact custom; Flags: fixed
Name: "tools\mscript"; Description: "MScript - Sinopse, Roteiro e Personagens"; Types: full compact custom
Name: "tools\mvisual"; Description: "MVisual - Biblioteca Visual e Continuidade"; Types: full custom
Name: "tools\mboard"; Description: "MBoard - Storyboard e Sincronizacao em Cascata"; Types: full custom
Name: "tools\msound"; Description: "MSound - Identidade Vocal, Efeitos e Ensaio"; Types: full custom
Name: "tools\mscene"; Description: "MScene - Geracao de Video e Montagem de Cenas"; Types: full custom
Name: "tools\mcut"; Description: "MCut - Montagem Final, Publico e Exportacao"; Types: full custom
Name: "extra"; Description: "Bibliotecas e Documentacao"; Types: full compact custom
Name: "extra\ssl"; Description: "Bibliotecas OpenSSL Win64 (libssl / libcrypto para HTTPS/IA)"; Types: full compact custom; Flags: fixed
Name: "extra\docs"; Description: "Documentacao Funcional e Protocolo MMP v1"; Types: full compact custom

[Dirs]
Name: "{userdocs}\MaurinMovie Productions"

[Files]
Source: "..\..\dist\app\build-manifest.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\dist\app\mmenu.exe"; DestDir: "{app}"; Components: tools\mmenu; Flags: ignoreversion
Source: "..\..\dist\app\mscript.exe"; DestDir: "{app}"; Components: tools\mscript; Flags: ignoreversion
Source: "..\..\dist\app\mvisual.exe"; DestDir: "{app}"; Components: tools\mvisual; Flags: ignoreversion
Source: "..\..\dist\app\mboard.exe"; DestDir: "{app}"; Components: tools\mboard; Flags: ignoreversion
Source: "..\..\dist\app\msound.exe"; DestDir: "{app}"; Components: tools\msound; Flags: ignoreversion
Source: "..\..\dist\app\mscene.exe"; DestDir: "{app}"; Components: tools\mscene; Flags: ignoreversion
Source: "..\..\dist\app\mcut.exe"; DestDir: "{app}"; Components: tools\mcut; Flags: ignoreversion

; SQLite3 Win64 e Banco Template Zerado
Source: "..\..\dist\app\sqlite3.dll"; DestDir: "{app}"; Components: tools\mmenu; Flags: ignoreversion
Source: "..\..\dist\app\templates\maurinmovie_empty.db"; DestDir: "{app}\templates"; Components: tools\mmenu; Flags: ignoreversion

; Bibliotecas OpenSSL Win64 ao lado dos executaveis
Source: "..\..\dist\app\libssl-1_1-x64.dll"; DestDir: "{app}"; Components: extra\ssl; Flags: ignoreversion
Source: "..\..\dist\app\libcrypto-1_1-x64.dll"; DestDir: "{app}"; Components: extra\ssl; Flags: ignoreversion
Source: "..\..\dist\app\libssl-3-x64.dll"; DestDir: "{app}"; Components: extra\ssl; Flags: ignoreversion
Source: "..\..\dist\app\libcrypto-3-x64.dll"; DestDir: "{app}"; Components: extra\ssl; Flags: ignoreversion
Source: "..\..\dist\app\legacy.dll"; DestDir: "{app}"; Components: extra\ssl; Flags: ignoreversion

; Documentacao
Source: "..\..\dist\app\docs\*"; DestDir: "{app}\docs"; Components: extra\docs; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "..\..\dist\installer-images\slide*.bmp"; Flags: dontcopy

[Tasks]
Name: "desktopicon_mmenu"; Description: "Criar atalho do MMenu na area de trabalho"; GroupDescription: "Atalhos da Area de Trabalho:"; Components: tools\mmenu; Flags: checkedonce
Name: "desktopicon_apps"; Description: "Criar atalhos para todos os aplicativos instalados na area de trabalho"; GroupDescription: "Atalhos da Area de Trabalho:"; Flags: unchecked

[Icons]
Name: "{autodesktop}\MaurinMovie (MMenu)"; Filename: "{app}\mmenu.exe"; Tasks: desktopicon_mmenu; Components: tools\mmenu
Name: "{autoprograms}\MaurinMovie\MMenu"; Filename: "{app}\mmenu.exe"; Components: tools\mmenu
Name: "{autoprograms}\MaurinMovie\MScript"; Filename: "{app}\mscript.exe"; Components: tools\mscript
Name: "{autoprograms}\MaurinMovie\MVisual"; Filename: "{app}\mvisual.exe"; Components: tools\mvisual
Name: "{autoprograms}\MaurinMovie\MBoard"; Filename: "{app}\mboard.exe"; Components: tools\mboard
Name: "{autoprograms}\MaurinMovie\MSound"; Filename: "{app}\msound.exe"; Components: tools\msound
Name: "{autoprograms}\MaurinMovie\MScene"; Filename: "{app}\mscene.exe"; Components: tools\mscene
Name: "{autoprograms}\MaurinMovie\MCut"; Filename: "{app}\mcut.exe"; Components: tools\mcut
Name: "{autoprograms}\MaurinMovie\Documentacao"; Filename: "{app}\docs\README.md"; Components: extra\docs
Name: "{autodesktop}\MaurinMovie\MScript"; Filename: "{app}\mscript.exe"; Tasks: desktopicon_apps; Components: tools\mscript
Name: "{autodesktop}\MaurinMovie\MVisual"; Filename: "{app}\mvisual.exe"; Tasks: desktopicon_apps; Components: tools\mvisual
Name: "{autodesktop}\MaurinMovie\MBoard"; Filename: "{app}\mboard.exe"; Tasks: desktopicon_apps; Components: tools\mboard
Name: "{autodesktop}\MaurinMovie\MSound"; Filename: "{app}\msound.exe"; Tasks: desktopicon_apps; Components: tools\msound
Name: "{autodesktop}\MaurinMovie\MScene"; Filename: "{app}\mscene.exe"; Tasks: desktopicon_apps; Components: tools\mscene
Name: "{autodesktop}\MaurinMovie\MCut"; Filename: "{app}\mcut.exe"; Tasks: desktopicon_apps; Components: tools\mcut

[Run]
Filename: "{app}\mmenu.exe"; Description: "Iniciar o MMenu (Portal MaurinMovie)"; Flags: nowait postinstall skipifsilent; Components: tools\mmenu

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/im mmenu.exe /f"; Flags: runhidden; RunOnceId: "FecharMMenu"

[Code]
var
  ProjectImage: TBitmapImage;
  ProjectCaption: TNewStaticText;
  CurrentSlide: Integer;

procedure ShowProjectSlide(Index: Integer);
var
  CaptionText: String;
begin
  if Index = CurrentSlide then Exit;
  CurrentSlide := Index;
  ProjectImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\slide' + IntToStr(Index) + '.bmp'));
  case Index of
    0: CaptionText := 'MMenu - Portal central, controle de revisoes e integridade MMP v1';
    1: CaptionText := 'MScript - Sinopse, roteiro estruturado com IA e mapa de personagens';
    2: CaptionText := 'MVisual - Biblioteca visual, vistas padronizadas e continuidade';
    3: CaptionText := 'MBoard - Storyboard, segmentos e sincronizacao em cascata';
    4: CaptionText := 'MSound - Identidade vocal, efeitos e ensaio sonoro';
    5: CaptionText := 'MScene - Geracao sequencial e montagem por cena';
    6: CaptionText := 'MCut - Montagem final, sessoes de publico e exportacao';
  end;
  ProjectCaption.Caption := CaptionText;
end;

procedure InitializeWizard;
var
  I, ImageTop: Integer;
begin
  for I := 0 to 6 do
    ExtractTemporaryFile('slide' + IntToStr(I) + '.bmp');
  CurrentSlide := -1;
  ImageTop := WizardForm.ProgressGauge.Top + WizardForm.ProgressGauge.Height + ScaleY(18);
  ProjectImage := TBitmapImage.Create(WizardForm);
  ProjectImage.Parent := WizardForm.InstallingPage;
  ProjectImage.SetBounds(0, ImageTop, WizardForm.InstallingPage.ClientWidth,
    WizardForm.InstallingPage.ClientHeight - ImageTop - ScaleY(24));
  ProjectImage.Stretch := True;
  ProjectCaption := TNewStaticText.Create(WizardForm);
  ProjectCaption.Parent := WizardForm.InstallingPage;
  ProjectCaption.SetBounds(0, ProjectImage.Top + ProjectImage.Height + ScaleY(4),
    WizardForm.InstallingPage.ClientWidth, ScaleY(20));
  ShowProjectSlide(0);
end;

procedure CurInstallProgressChanged(CurProgress, MaxProgress: Integer);
var
  Slide: Integer;
begin
  if MaxProgress <= 0 then Exit;
  Slide := Trunc((CurProgress * 1.0 / MaxProgress) * 7);
  if Slide > 6 then Slide := 6;
  ShowProjectSlide(Slide);
end;

