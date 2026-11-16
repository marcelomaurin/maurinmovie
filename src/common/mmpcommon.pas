unit mmpcommon;

{ Definicoes compartilhadas do protocolo MMP v1 (docs/11, docs/12 e docs/specs/00-comum.md). }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes{$IFDEF WINDOWS}, Windows{$ENDIF};

type
  TMMApp = (maMMenu, maMScript, maMVisual, maMBoard, maMSound, maMScene, maMCut);

  TMmpResolutionPreset = record
    Code: string;
    LabelText: string;
    Width: Integer;
    Height: Integer;
    Aspect: string;
  end;

  { Argumentos padronizados do protocolo MMP v1 }
  TMMLaunchArgs = record
    Production: string;
    ProductionId: string;
    ProjectId: string;
    Revision: string;
    SceneId: string;
    FocusId: string;
    Launcher: string;
    MMenuVersion: string;
    NewProject: Boolean;
    Headless: Boolean;
    EventFile: string;
    ResumeTxId: string;
    LogLevel: string;
    OpenSettings: Boolean;
    SettingsTab: string;
    CheckIntegrity: Boolean;
    ShowVersion: Boolean;
    ShowHelp: Boolean;
    RenderMode: Boolean;
  end;

const
  MAURINMOVIE_VERSION = '0.2.0';

  MMP_SCHEMA_PRODUCTION = 'mmp.production/1';
  MMP_SCHEMA_PROJECT    = 'mmp.project/1';
  MMP_SCHEMA_MANIFEST   = 'mmp.manifest/1';
  MMP_SCHEMA_CATALOG    = 'mmp.catalog/1';
  MMP_SCHEMA_EVENT      = 'mmp.event/1';
  MMP_SCHEMA_TX         = 'mmp.transaction/1';

  MMP_PRODUCTION_FILE = 'production.json';
  MMP_PROJECT_FILE    = 'project.json';
  MMP_MANIFEST_FILE   = 'manifest.json';

  EXIT_OK               = 0;
  EXIT_UNEXPECTED_ERROR = 1;
  EXIT_INVALID_ARGS     = 2;
  EXIT_NOT_FOUND        = 3;
  EXIT_INTEGRITY_ERROR  = 4;
  EXIT_LOCKED           = 5;
  EXIT_EVENT_RETRYABLE  = 6;
  EXIT_EVENT_AMBIGUOUS  = 7;
  EXIT_CANCELLED        = 10;

  MMAppNames: array[TMMApp] of string =
    ('MMenu', 'MScript', 'MVisual', 'MBoard', 'MSound', 'MScene', 'MCut');

  { Subpasta de cada aplicativo dentro de projects/ da producao }
  MMAppProjectDirs: array[TMMApp] of string =
    ('00-mmenu', '01-mscript', '02-mvisual', '03-mboard',
     '04-msound', '05-mscene', '06-mcut');

  MMAppLabelSuffixes: array[TMMApp] of string =
    ('Portal', 'Roteiro', 'Visual', 'Storyboard', 'Sonoro', 'Video', 'Filme');

  MMP_RESOLUTION_PRESETS: array[0..5] of TMmpResolutionPreset = (
    (Code: 'vga';     LabelText: 'VGA (640x480 - 4:3)';      Width: 640;  Height: 480;  Aspect: '4:3'),
    (Code: 'hd';      LabelText: 'HD (1280x720 - 16:9)';     Width: 1280; Height: 720;  Aspect: '16:9'),
    (Code: 'fullhd';  LabelText: 'Full HD (1920x1080 - 16:9)'; Width: 1920; Height: 1080; Aspect: '16:9'),
    (Code: '2k';      LabelText: '2K (2560x1440 - 16:9)';    Width: 2560; Height: 1440; Aspect: '16:9'),
    (Code: '4k';      LabelText: '4K (3840x2160 - 16:9)';    Width: 3840; Height: 2160; Aspect: '16:9'),
    (Code: '8k';      LabelText: '8K (7680x4320 - 16:9)';    Width: 7680; Height: 4320; Aspect: '16:9')
  );

procedure MmpPopulateResolutionCombo(Items: TStrings);
function MmpFindResolutionPresetIndex(W, H: Integer): Integer;
function MmpGetResolutionPreset(Idx: Integer; out W, H: Integer; out Aspect: string): Boolean;

function ParseLaunchArgs: TMMLaunchArgs;
function IsValidRevisionId(const ARev: string): Boolean;
function RevisionDirName(ANumber: Integer): string;
function FormatRevisionLabel(const ANameBase: string; AApp: TMMApp;
  const ARevId: string; const ASceneId: string = ''): string;
function ProjectFilePath(const AProductionRoot: string; AApp: TMMApp): string;
function AppIndexToEnum(Idx: Integer): TMMApp;
procedure WriteCliLine(const Msg: string);
procedure PrintCliHelp(const AppName: string);

implementation

function IsValidRevisionId(const ARev: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(ARev) <> 5 then Exit;
  if (ARev[1] <> 'r') and (ARev[1] <> 'R') then Exit;
  for I := 2 to 5 do
    if not (ARev[I] in ['0'..'9']) then Exit;
  Result := True;
end;

function ParseLaunchArgs: TMMLaunchArgs;
var
  I, EqPos: Integer;
  Arg, Key, Val: string;

  function TakeValue(var Idx: Integer): string;
  begin
    if EqPos > 0 then
    begin
      Result := Val;
      Inc(Idx);
    end
    else if Idx < ParamCount then
    begin
      Result := ParamStr(Idx + 1);
      Inc(Idx, 2);
    end
    else
    begin
      Result := '';
      Inc(Idx);
    end;
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  Result.LogLevel := 'info';
  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    EqPos := Pos('=', Arg);
    if EqPos > 0 then
    begin
      Key := LowerCase(Copy(Arg, 1, EqPos - 1));
      Val := Copy(Arg, EqPos + 1, Length(Arg));
    end
    else
    begin
      Key := LowerCase(Arg);
      Val := '';
    end;

    if Key = '--production' then
      Result.Production := TakeValue(I)
    else if Key = '--production-id' then
      Result.ProductionId := TakeValue(I)
    else if Key = '--project-id' then
      Result.ProjectId := TakeValue(I)
    else if Key = '--revision' then
      Result.Revision := TakeValue(I)
    else if Key = '--scene-id' then
      Result.SceneId := TakeValue(I)
    else if Key = '--focus' then
      Result.FocusId := TakeValue(I)
    else if Key = '--launcher' then
      Result.Launcher := TakeValue(I)
    else if Key = '--mmenu-version' then
      Result.MMenuVersion := TakeValue(I)
    else if Key = '--event' then
      Result.EventFile := TakeValue(I)
    else if Key = '--resume-transaction' then
      Result.ResumeTxId := TakeValue(I)
    else if Key = '--log-level' then
      Result.LogLevel := TakeValue(I)
    else if Key = '--tab' then
      Result.SettingsTab := TakeValue(I)
    else if Key = '--new' then
    begin
      Result.NewProject := True;
      Inc(I);
    end
    else if Key = '--headless' then
    begin
      Result.Headless := True;
      Inc(I);
    end
    else if Key = '--settings' then
    begin
      Result.OpenSettings := True;
      Inc(I);
    end
    else if Key = '--check-integrity' then
    begin
      Result.CheckIntegrity := True;
      Inc(I);
    end
    else if Key = '--render' then
    begin
      Result.RenderMode := True;
      Inc(I);
    end
    else if (Key = '--version') or (Key = '-v') then
    begin
      Result.ShowVersion := True;
      Inc(I);
    end
    else if (Key = '--help') or (Key = '-h') then
    begin
      Result.ShowHelp := True;
      Inc(I);
    end
    else
      Inc(I);
  end;
end;

function RevisionDirName(ANumber: Integer): string;
begin
  Result := 'r' + Format('%.4d', [ANumber]);
end;

function FormatRevisionLabel(const ANameBase: string; AApp: TMMApp;
  const ARevId: string; const ASceneId: string): string;
var
  Num: Integer;
  Base: string;
begin
  Base := Trim(ANameBase);
  if Base = '' then Base := 'Producao';
  Num := StrToIntDef(Copy(ARevId, 2, Length(ARevId)), 1);
  if (AApp = maMScene) and (ASceneId <> '') then
    Result := Format('%s_Cena_%s_Video_R%.3d', [Base, ASceneId, Num])
  else
    Result := Format('%s_%s_R%.3d', [Base, MMAppLabelSuffixes[AApp], Num]);
end;

function ProjectFilePath(const AProductionRoot: string; AApp: TMMApp): string;
begin
  Result := IncludeTrailingPathDelimiter(AProductionRoot) + 'projects' +
    PathDelim + MMAppProjectDirs[AApp] + PathDelim + MMP_PROJECT_FILE;
end;

function AppIndexToEnum(Idx: Integer): TMMApp;
begin
  if (Idx < 0) or (Idx > 6) then
    Result := maMMenu
  else
    Result := TMMApp(Idx);
end;

{$IFDEF WINDOWS}
var
  CliConsoleChecked: Boolean = False;

function WinAttachConsole(dwProcessId: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'AttachConsole';
{$ENDIF}

procedure WriteCliLine(const Msg: string);
{$IFDEF WINDOWS}
const
  ATTACH_PARENT_PROCESS = DWORD(-1);
var
  HOut: THandle;
  LineUtf8: RawByteString;
  Written: DWORD;
begin
  HOut := GetStdHandle(STD_OUTPUT_HANDLE);
  if ((HOut = 0) or (HOut = INVALID_HANDLE_VALUE)) and (not CliConsoleChecked) then
  begin
    CliConsoleChecked := True;
    WinAttachConsole(ATTACH_PARENT_PROCESS);
    HOut := GetStdHandle(STD_OUTPUT_HANDLE);
  end;
  if (HOut <> 0) and (HOut <> INVALID_HANDLE_VALUE) then
  begin
    LineUtf8 := UTF8Encode(Msg + LineEnding);
    if Length(LineUtf8) > 0 then
    begin
      Written := 0;
      WriteFile(HOut, LineUtf8[1], Length(LineUtf8), Written, nil);
    end;
  end;
end;
{$ELSE}
begin
  WriteLn(Msg);
end;
{$ENDIF}

procedure PrintCliHelp(const AppName: string);
begin
  WriteCliLine(AppName + ' ' + MAURINMOVIE_VERSION + ' - MaurinMovie (MMP v1)');
  WriteCliLine('Uso:');
  WriteCliLine('  ' + LowerCase(AppName) + ' --launcher mmenu --mmenu-version ' + MAURINMOVIE_VERSION +
    ' --production <pasta> --project-id <id> [--revision <rNNNN>]');
  WriteCliLine('  [--production-id <id>] [--scene-id <id>] [--focus <id>] [--headless --event <arquivo>]');
  WriteCliLine('  [--resume-transaction <tx_id>] [--log-level debug|info|warn|error] [--version] [--help]');
  if not SameText(AppName, 'MMenu') then
    WriteCliLine('Observacao: este modulo deve ser iniciado exclusivamente pelo MMenu.');
end;

procedure MmpPopulateResolutionCombo(Items: TStrings);
var
  I: Integer;
begin
  if Items = nil then Exit;
  Items.Clear;
  for I := Low(MMP_RESOLUTION_PRESETS) to High(MMP_RESOLUTION_PRESETS) do
    Items.Add(MMP_RESOLUTION_PRESETS[I].LabelText);
end;

function MmpFindResolutionPresetIndex(W, H: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(MMP_RESOLUTION_PRESETS) to High(MMP_RESOLUTION_PRESETS) do
    if (MMP_RESOLUTION_PRESETS[I].Width = W) and (MMP_RESOLUTION_PRESETS[I].Height = H) then
      Exit(I);
end;

function MmpGetResolutionPreset(Idx: Integer; out W, H: Integer; out Aspect: string): Boolean;
begin
  Result := (Idx >= Low(MMP_RESOLUTION_PRESETS)) and (Idx <= High(MMP_RESOLUTION_PRESETS));
  if not Result then Exit;
  W := MMP_RESOLUTION_PRESETS[Idx].Width;
  H := MMP_RESOLUTION_PRESETS[Idx].Height;
  Aspect := MMP_RESOLUTION_PRESETS[Idx].Aspect;
end;

end.
