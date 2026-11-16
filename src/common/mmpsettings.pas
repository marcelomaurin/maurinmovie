unit mmpsettings;

{ Leitura centralizada e persistencia (exclusiva do MMenu) das configuracoes da suite.
  Sem dependencia LCL (compativel com modo headless e testes). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpjson, jsonparser,
  mmpcommon, ummpsha256;

type
  TMmpAiProviderCfg = record
    Id: string;
    Kind: string;      // text | image | voice | sfx | video | vision | asr
    LabelText: string;
    Adapter: string;   // mock | chatgpt-lib | openai-compatible | local-cli | http-generic
    BaseUrl: string;
    Model: string;
    SecretRef: string;
    Command: string;
    ArgsTemplate: string;
    TimeoutSec: Integer;
    MaxRetries: Integer;
    RateLimitPerMin: Integer;
    MaxConcurrency: Integer;
    CostPerUnit: Double;
    CostUnit: string;
    Enabled: Boolean;
    Temperature: Double;
    MaxTokens: Integer;
    Width: Integer;
    Height: Integer;
    Fps: Integer;
    MaxSegmentSec: Integer;
    LipSync: Boolean;
    SampleRate: Integer;
  end;

  TMmpAppSettingsCfg = record
    Providers: array of record
      Kind: string;
      ProviderId: string;
    end;
    SceneCount: Integer;
    IncludeDialogue: Boolean;
    SuggestObjects: Boolean;
    Creativity: Double;
    ApprovedRefsOnly: Boolean;
    VisualStyle: string;
    RatingScale: Integer;
    FragmentContextSec: Integer;
  end;

  TMMSettings = class
  private
    FProductionRoot: string;
    FMachineIniPath: string;
    FSecretsIniPath: string;
    FUpdatedAtStamp: string;
    FSettingsSha256: string;

    // Machine-level
    FUserName: string;
    FUserRole: string;
    FUserEmail: string;
    FAppExes: array[TMMApp] of string;
    FToolFfmpeg: string;
    FToolFfprobe: string;
    FToolMpv: string;
    FProductionsDir: string;
    FGlobalCacheDir: string;
    FSoundLibraryDir: string;
    FMusicLibraryDir: string;
    FProxyUrl: string;
    FProxyUser: string;
    FCABundle: string;
    FOfflineMode: Boolean;
    FUiLanguage: string;
    FFontScale: Integer;
    FUiTheme: string;
    FConfirmDestructive: Boolean;
    FLogLevel: string;
    FLogRetentionDays: Integer;

    // Production-level
    FLoadedProductionSettings: Boolean;
    FProdLanguage: string;
    FProdFps: Integer;
    FProdWidth: Integer;
    FProdHeight: Integer;
    FProdAspect: string;
    FProdAudioRate: Integer;
    FProdAudioChannels: Integer;
    FProdTargetDurationMs: Int64;
    FProdVisualStyle: string;
    FProdNameBase: string;
    FProdFormat: string;
    FProdRating: string;
    FProviders: array of TMmpAiProviderCfg;
    FDefaultProviders: array of record
      Kind: string;
      ProviderId: string;
    end;
    FAppConfigs: array[TMMApp] of TMmpAppSettingsCfg;

    // Policies
    FRequireApprovedRefsForBoard: Boolean;
    FRequireVoiceApprovalForScene: Boolean;
    FPolicyRatingScale: Integer;
    FBudgetTotal: Double;
    FBudgetCurrency: string;
    FAutosaveSec: Integer;
    FLockStaleMin: Integer;
    FMonitorIntervalSec: Integer;
    FMinFreeDiskGb: Integer;

    procedure LoadMachineIni;
    procedure LoadProductionJsonFiles;
    function ComputeCurrentStamp: string;
  public
    constructor Create;
    procedure Load(const ProductionRoot: string; App: TMMApp = maMMenu);
    function ReloadIfChanged(App: TMMApp = maMMenu): Boolean;

    function ResolveProvider(const Kind: string; App: TMMApp;
      out Prov: TMmpAiProviderCfg): Boolean;
    function FindProviderById(const Id: string; out Prov: TMmpAiProviderCfg): Boolean;
    procedure SetOrAddProvider(const Prov: TMmpAiProviderCfg; SetAsDefault: Boolean);
    procedure SetAppProvider(App: TMMApp; const Kind, ProviderId: string);
    function GetAppProviderId(App: TMMApp; const Kind: string): string;
    function GetDefaultProviderId(const Kind: string): string;
    function ResolveSecret(const SecretRef: string): string;

    function DetectToolPath(const ToolName: string): string;
    function DetectAppPath(App: TMMApp): string;
    function VerifyEnvironment(out Report: string): Boolean;

    // Exclusive MMenu writers
    function SaveMachineIni: Boolean;
    function SaveSecret(const SecretRef, SecretValue: string): Boolean;
    function SaveProductionSettings(out ErrorMsg: string): Boolean;

    class function WriteDefaultProductionSettings(
      const ProductionRoot, Title, NameBase, Language: string;
      out ErrorMsg: string): Boolean;

    property ProductionRoot: string read FProductionRoot;
    property MachineIniPath: string read FMachineIniPath;
    property SecretsIniPath: string read FSecretsIniPath;
    property SettingsSha256: string read FSettingsSha256;
    property LoadedProductionSettings: Boolean read FLoadedProductionSettings;

    // Machine properties
    property UserName: string read FUserName write FUserName;
    property UserRole: string read FUserRole write FUserRole;
    property UserEmail: string read FUserEmail write FUserEmail;
    property ToolFfmpeg: string read FToolFfmpeg write FToolFfmpeg;
    property ToolFfprobe: string read FToolFfprobe write FToolFfprobe;
    property ToolMpv: string read FToolMpv write FToolMpv;
    property ProductionsDir: string read FProductionsDir write FProductionsDir;
    property GlobalCacheDir: string read FGlobalCacheDir write FGlobalCacheDir;
    property SoundLibraryDir: string read FSoundLibraryDir write FSoundLibraryDir;
    property MusicLibraryDir: string read FMusicLibraryDir write FMusicLibraryDir;
    property ProxyUrl: string read FProxyUrl write FProxyUrl;
    property ProxyUser: string read FProxyUser write FProxyUser;
    property CABundle: string read FCABundle write FCABundle;
    property OfflineMode: Boolean read FOfflineMode write FOfflineMode;
    property UiLanguage: string read FUiLanguage write FUiLanguage;
    property FontScale: Integer read FFontScale write FFontScale;
    property UiTheme: string read FUiTheme write FUiTheme;
    property ConfirmDestructive: Boolean read FConfirmDestructive write FConfirmDestructive;
    property LogLevel: string read FLogLevel write FLogLevel;
    property LogRetentionDays: Integer read FLogRetentionDays write FLogRetentionDays;

    // Production properties
    property ProdLanguage: string read FProdLanguage write FProdLanguage;
    property ProdFps: Integer read FProdFps write FProdFps;
    property ProdWidth: Integer read FProdWidth write FProdWidth;
    property ProdHeight: Integer read FProdHeight write FProdHeight;
    property ProdAspect: string read FProdAspect write FProdAspect;
    property ProdAudioRate: Integer read FProdAudioRate write FProdAudioRate;
    property ProdAudioChannels: Integer read FProdAudioChannels write FProdAudioChannels;
    property ProdTargetDurationMs: Int64 read FProdTargetDurationMs write FProdTargetDurationMs;
    property ProdVisualStyle: string read FProdVisualStyle write FProdVisualStyle;
    property ProdNameBase: string read FProdNameBase write FProdNameBase;
    property ProdFormat: string read FProdFormat write FProdFormat;
    property ProdRating: string read FProdRating write FProdRating;

    // Policies
    property RequireApprovedRefsForBoard: Boolean read FRequireApprovedRefsForBoard write FRequireApprovedRefsForBoard;
    property RequireVoiceApprovalForScene: Boolean read FRequireVoiceApprovalForScene write FRequireVoiceApprovalForScene;
    property PolicyRatingScale: Integer read FPolicyRatingScale write FPolicyRatingScale;
    property BudgetTotal: Double read FBudgetTotal write FBudgetTotal;
    property BudgetCurrency: string read FBudgetCurrency write FBudgetCurrency;
    property AutosaveSec: Integer read FAutosaveSec write FAutosaveSec;
    property LockStaleMin: Integer read FLockStaleMin write FLockStaleMin;
    property MonitorIntervalSec: Integer read FMonitorIntervalSec write FMonitorIntervalSec;
    property MinFreeDiskGb: Integer read FMinFreeDiskGb write FMinFreeDiskGb;

    function GetAppExe(App: TMMApp): string;
    procedure SetAppExe(App: TMMApp; const Path: string);
    function ProviderCount: Integer;
    function GetProvider(Index: Integer): TMmpAiProviderCfg;
    function GetAppConfig(App: TMMApp): TMmpAppSettingsCfg;
    procedure SetAppConfig(App: TMMApp; const Cfg: TMmpAppSettingsCfg);
  end;

function SafeReadFileUtf8(const FilePath: string; out Content: string): Boolean;
function SafeWriteFileAtomic(const TargetPath, Content: string; KeepBackup: Boolean = True): Boolean;
function CurrentUtcIso: string;

implementation

uses
  DateUtils;

function CurrentUtcIso: string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', LocalTimeToUniversal(Now));
end;

function SafeReadFileUtf8(const FilePath: string; out Content: string): Boolean;
var
  FS: TFileStream;
  S: RawByteString;
begin
  Result := False;
  Content := '';
  if not FileExists(FilePath) then Exit;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
    try
      SetLength(S, FS.Size);
      if FS.Size > 0 then
        FS.ReadBuffer(S[1], FS.Size);
      Content := string(S);
      Result := True;
    finally
      FS.Free;
    end;
  except
    Result := False;
  end;
end;

function SafeWriteFileAtomic(const TargetPath, Content: string; KeepBackup: Boolean): Boolean;
var
  Dir, TempPath, BakPath: string;
  FS: TFileStream;
begin
  Result := False;
  Dir := ExtractFileDir(TargetPath);
  if (Dir <> '') and not ForceDirectories(Dir) then Exit;

  TempPath := TargetPath + '.tmp.' + IntToStr(GetTickCount64) + '.' + IntToStr(Random(10000));
  try
    FS := TFileStream.Create(TempPath, fmCreate);
    try
      if Length(Content) > 0 then
        FS.WriteBuffer(Content[1], Length(Content));
    finally
      FS.Free;
    end;

    if FileExists(TargetPath) then
    begin
      if KeepBackup then
      begin
        BakPath := TargetPath + '.bak';
        if FileExists(BakPath) then DeleteFile(BakPath);
        if not RenameFile(TargetPath, BakPath) then
        begin
          DeleteFile(TempPath);
          Exit(False);
        end;
      end
      else if not DeleteFile(TargetPath) then
      begin
        DeleteFile(TempPath);
        Exit(False);
      end;
    end;

    Result := RenameFile(TempPath, TargetPath);
    if not Result and KeepBackup and FileExists(TargetPath + '.bak') and not FileExists(TargetPath) then
      RenameFile(TargetPath + '.bak', TargetPath);
  except
    if FileExists(TempPath) then DeleteFile(TempPath);
    Result := False;
  end;
end;

function ParseJsonObj(const FilePath: string; out Obj: TJSONObject): Boolean;
var
  Content: string;
  Data: TJSONData;
begin
  Result := False;
  Obj := nil;
  if not SafeReadFileUtf8(FilePath, Content) then Exit;
  if Trim(Content) = '' then Exit;
  try
    Data := GetJSON(Content);
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      Result := True;
    end
    else
      Data.Free;
  except
    Obj := nil;
    Result := False;
  end;
end;

function DefaultProvider(const AId, AKind, ALabel, AAdapter, AModel: string): TMmpAiProviderCfg;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AId;
  Result.Kind := AKind;
  Result.LabelText := ALabel;
  Result.Adapter := AAdapter;
  Result.Model := AModel;
  Result.TimeoutSec := 120;
  if AKind = 'video' then Result.TimeoutSec := 1800;
  Result.MaxRetries := 3;
  Result.RateLimitPerMin := 0;
  Result.MaxConcurrency := 1;
  Result.CostUnit := 'unit';
  Result.Enabled := True;
  Result.Temperature := 0.7;
  Result.MaxTokens := 8000;
  Result.Width := 1024;
  Result.Height := 1024;
  if AKind = 'video' then
  begin
    Result.Width := 1920;
    Result.Height := 1080;
  end;
  Result.Fps := 24;
  Result.MaxSegmentSec := 10;
  Result.LipSync := True;
  Result.SampleRate := 48000;
end;

constructor TMMSettings.Create;
var
  CfgDir: string;
  A: TMMApp;
begin
  inherited Create;
  CfgDir := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'MaurinMovie' + PathDelim;
  FMachineIniPath := CfgDir + 'mmenu.ini';
  FSecretsIniPath := CfgDir + 'secrets.ini';

  FUserName := GetEnvironmentVariable('USERNAME');
  if FUserName = '' then FUserName := GetEnvironmentVariable('USER');
  FUserRole := 'diretor';
  FProductionsDir := ExpandFileName(
    ExtractFileDir(ParamStr(0)) + PathDelim + '..' + PathDelim + 'productions');
  FGlobalCacheDir := CfgDir + 'cache';
  FUiLanguage := 'pt-BR';
  FFontScale := 100;
  FUiTheme := 'claro';
  FConfirmDestructive := True;
  FLogLevel := 'info';
  FLogRetentionDays := 30;

  FProdLanguage := 'pt-BR';
  FProdFps := 24;
  FProdWidth := 1920;
  FProdHeight := 1080;
  FProdAspect := '16:9';
  FProdAudioRate := 48000;
  FProdAudioChannels := 2;
  FProdTargetDurationMs := 600000;
  FProdVisualStyle := 'realista cinematografico';
  FProdFormat := 'short';

  FRequireApprovedRefsForBoard := True;
  FRequireVoiceApprovalForScene := True;
  FPolicyRatingScale := 5;
  FBudgetCurrency := 'BRL';
  FAutosaveSec := 60;
  FLockStaleMin := 5;
  FMonitorIntervalSec := 5;
  FMinFreeDiskGb := 10;

  for A := Low(TMMApp) to High(TMMApp) do
  begin
    FAppConfigs[A].SceneCount := 5;
    FAppConfigs[A].IncludeDialogue := True;
    FAppConfigs[A].SuggestObjects := True;
    FAppConfigs[A].Creativity := 0.7;
    FAppConfigs[A].ApprovedRefsOnly := True;
    FAppConfigs[A].VisualStyle := FProdVisualStyle;
    FAppConfigs[A].RatingScale := 5;
    FAppConfigs[A].FragmentContextSec := 5;
  end;

  LoadMachineIni;
end;

procedure TMMSettings.LoadMachineIni;
var
  Ini: TIniFile;
  A: TMMApp;
  PDir: string;
begin
  if not FileExists(FMachineIniPath) then Exit;
  Ini := TIniFile.Create(FMachineIniPath);
  try
    FUserName := Ini.ReadString('User', 'Name', FUserName);
    FUserRole := Ini.ReadString('User', 'Role', FUserRole);
    FUserEmail := Ini.ReadString('User', 'Email', '');

    for A := maMScript to maMCut do
      FAppExes[A] := Ini.ReadString('Applications', MMAppNames[A], '');

    FToolFfmpeg := Ini.ReadString('Tools', 'ffmpeg', '');
    FToolFfprobe := Ini.ReadString('Tools', 'ffprobe', '');
    FToolMpv := Ini.ReadString('Tools', 'mpv', '');

    PDir := Ini.ReadString('Paths', 'ProductionsDir', '');
    if PDir <> '' then FProductionsDir := PDir;
    FGlobalCacheDir := Ini.ReadString('Paths', 'GlobalCacheDir', FGlobalCacheDir);
    FSoundLibraryDir := Ini.ReadString('Paths', 'SoundLibraryDir', '');
    FMusicLibraryDir := Ini.ReadString('Paths', 'MusicLibraryDir', '');

    FProxyUrl := Ini.ReadString('Network', 'Proxy', '');
    FProxyUser := Ini.ReadString('Network', 'ProxyUser', '');
    FCABundle := Ini.ReadString('Network', 'CABundle', '');
    FOfflineMode := Ini.ReadBool('Network', 'Offline', False);

    FUiLanguage := Ini.ReadString('Interface', 'Language', FUiLanguage);
    FFontScale := Ini.ReadInteger('Interface', 'FontScale', 100);
    FUiTheme := Ini.ReadString('Interface', 'Theme', FUiTheme);
    FConfirmDestructive := Ini.ReadBool('Interface', 'ConfirmDestructive', True);

    FLogLevel := Ini.ReadString('Logging', 'Level', FLogLevel);
    FLogRetentionDays := Ini.ReadInteger('Logging', 'RetentionDays', 30);
  finally
    Ini.Free;
  end;
end;

function TMMSettings.ComputeCurrentStamp: string;
var
  SetDir: string;
  SR: TSearchRec;
begin
  Result := '';
  if FProductionRoot = '' then Exit;
  SetDir := IncludeTrailingPathDelimiter(FProductionRoot) + 'settings';
  if not DirectoryExists(SetDir) then Exit;
  if FindFirst(SetDir + PathDelim + '*.json', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        Result := Result + SR.Name + ':' + IntToStr(SR.Time) + ';';
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure TMMSettings.LoadProductionJsonFiles;
var
  SetDir, AiStr, AppsStr: string;
  Obj, SubObj, ParamsObj, DefObj: TJSONObject;
  Arr: TJSONArray;
  I, J, N: Integer;
  A: TMMApp;
  KeyName: string;
begin
  FLoadedProductionSettings := False;
  if FProductionRoot = '' then Exit;
  SetDir := IncludeTrailingPathDelimiter(FProductionRoot) + 'settings' + PathDelim;

  // settings/production.json
  if ParseJsonObj(SetDir + 'production.json', Obj) then
  begin
    try
      FProdLanguage := Obj.Get('language', FProdLanguage);
      FProdFps := Obj.Get('fps', FProdFps);
      FProdAspect := Obj.Get('aspect', FProdAspect);
      FProdTargetDurationMs := Obj.Get('target_duration_ms', FProdTargetDurationMs);
      FProdVisualStyle := Obj.Get('visual_style', FProdVisualStyle);
      FProdNameBase := Obj.Get('name_base', Obj.Get('title', FProdNameBase));
      FProdFormat := Obj.Get('format', FProdFormat);
      FProdRating := Obj.Get('rating', FProdRating);
      if Obj.Find('frame_size') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('frame_size'));
        if Arr.Count >= 2 then
        begin
          FProdWidth := Arr.Integers[0];
          FProdHeight := Arr.Integers[1];
        end;
      end;
      if Obj.Find('audio') is TJSONObject then
      begin
        SubObj := TJSONObject(Obj.Find('audio'));
        FProdAudioRate := SubObj.Get('sample_rate', 48000);
        FProdAudioChannels := SubObj.Get('channels', 2);
      end;
    finally
      Obj.Free;
    end;
  end;

  // settings/ai-providers.json
  SetLength(FProviders, 0);
  SetLength(FDefaultProviders, 0);
  if ParseJsonObj(SetDir + 'ai-providers.json', Obj) then
  begin
    try
      if Obj.Find('providers') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('providers'));
        SetLength(FProviders, Arr.Count);
        for I := 0 to Arr.Count - 1 do
        begin
          if Arr.Items[I] is TJSONObject then
          begin
            SubObj := TJSONObject(Arr.Items[I]);
            FProviders[I] := DefaultProvider(
              SubObj.Get('id', ''),
              SubObj.Get('kind', 'text'),
              SubObj.Get('label', ''),
              SubObj.Get('adapter', 'mock'),
              SubObj.Get('model', ''));
            FProviders[I].BaseUrl := SubObj.Get('base_url', '');
            FProviders[I].SecretRef := SubObj.Get('secret_ref', '');
            FProviders[I].Command := SubObj.Get('command', '');
            FProviders[I].ArgsTemplate := SubObj.Get('args_template', '');
            FProviders[I].TimeoutSec := SubObj.Get('timeout_s', FProviders[I].TimeoutSec);
            FProviders[I].MaxRetries := SubObj.Get('max_retries', 3);
            FProviders[I].RateLimitPerMin := SubObj.Get('rate_limit_per_min', 0);
            FProviders[I].MaxConcurrency := SubObj.Get('max_concurrency', 1);
            FProviders[I].CostPerUnit := SubObj.Get('cost_per_unit', 0.0);
            FProviders[I].CostUnit := SubObj.Get('unit', 'unit');
            FProviders[I].Enabled := SubObj.Get('enabled', True);
            if SubObj.Find('params') is TJSONObject then
            begin
              ParamsObj := TJSONObject(SubObj.Find('params'));
              FProviders[I].Temperature := ParamsObj.Get('temperature', 0.7);
              FProviders[I].MaxTokens := ParamsObj.Get('max_tokens', 8000);
              FProviders[I].Width := ParamsObj.Get('width', FProviders[I].Width);
              FProviders[I].Height := ParamsObj.Get('height', FProviders[I].Height);
              FProviders[I].Fps := ParamsObj.Get('fps', 24);
              FProviders[I].MaxSegmentSec := ParamsObj.Get('max_segment_s', 10);
              FProviders[I].LipSync := ParamsObj.Get('lip_sync', True);
              FProviders[I].SampleRate := ParamsObj.Get('sample_rate', 48000);
            end;
          end;
        end;
      end;

      if Obj.Find('defaults') is TJSONObject then
      begin
        DefObj := TJSONObject(Obj.Find('defaults'));
        SetLength(FDefaultProviders, DefObj.Count);
        for I := 0 to DefObj.Count - 1 do
        begin
          FDefaultProviders[I].Kind := DefObj.Names[I];
          FDefaultProviders[I].ProviderId := DefObj.Items[I].AsString;
        end;
      end;
    finally
      Obj.Free;
    end;
  end;

  // Ensure default mock providers exist in memory if none present
  if Length(FProviders) = 0 then
  begin
    SetLength(FProviders, 5);
    FProviders[0] := DefaultProvider('text.default', 'text', 'Texto (Simulado)', 'mock', 'mock-script-v1');
    FProviders[1] := DefaultProvider('image.default', 'image', 'Imagem (Simulado)', 'mock', 'mock-image-v1');
    FProviders[2] := DefaultProvider('voice.default', 'voice', 'Voz (Simulado)', 'mock', 'mock-voice-v1');
    FProviders[3] := DefaultProvider('sfx.default', 'sfx', 'Efeitos (Simulado)', 'mock', 'mock-sfx-v1');
    FProviders[4] := DefaultProvider('video.default', 'video', 'Video (Simulado)', 'mock', 'mock-video-v1');
    SetLength(FDefaultProviders, 5);
    for I := 0 to 4 do
    begin
      FDefaultProviders[I].Kind := FProviders[I].Kind;
      FDefaultProviders[I].ProviderId := FProviders[I].Id;
    end;
  end;

  // settings/apps.json
  if ParseJsonObj(SetDir + 'apps.json', Obj) then
  begin
    try
      for A := maMScript to maMCut do
      begin
        if Obj.Find(MMAppNames[A]) is TJSONObject then
        begin
          SubObj := TJSONObject(Obj.Find(MMAppNames[A]));
          if SubObj.Find('providers') is TJSONObject then
          begin
            DefObj := TJSONObject(SubObj.Find('providers'));
            SetLength(FAppConfigs[A].Providers, DefObj.Count);
            for J := 0 to DefObj.Count - 1 do
            begin
              FAppConfigs[A].Providers[J].Kind := DefObj.Names[J];
              FAppConfigs[A].Providers[J].ProviderId := DefObj.Items[J].AsString;
            end;
          end;
          if SubObj.Find('defaults') is TJSONObject then
          begin
            ParamsObj := TJSONObject(SubObj.Find('defaults'));
            FAppConfigs[A].SceneCount := ParamsObj.Get('scene_count', 5);
            FAppConfigs[A].IncludeDialogue := ParamsObj.Get('include_dialogue', True);
            FAppConfigs[A].SuggestObjects := ParamsObj.Get('suggest_objects', True);
            FAppConfigs[A].Creativity := ParamsObj.Get('creativity', 0.7);
            FAppConfigs[A].ApprovedRefsOnly := ParamsObj.Get('approved_refs_only', True);
            FAppConfigs[A].VisualStyle := ParamsObj.Get('style', FProdVisualStyle);
            FAppConfigs[A].RatingScale := ParamsObj.Get('rating_scale', 5);
            FAppConfigs[A].FragmentContextSec := ParamsObj.Get('fragment_context_s', 5);
          end;
        end;
      end;
    finally
      Obj.Free;
    end;
  end;

  // settings/policies.json
  if ParseJsonObj(SetDir + 'policies.json', Obj) then
  begin
    try
      FRequireApprovedRefsForBoard := Obj.Get('require_approved_refs_for_board', True);
      FRequireVoiceApprovalForScene := Obj.Get('require_voice_approval_for_scene', True);
      FPolicyRatingScale := Obj.Get('rating_scale', 5);
      FBudgetTotal := Obj.Get('budget_total', 0.0);
      FBudgetCurrency := Obj.Get('currency', 'BRL');
      FAutosaveSec := Obj.Get('autosave_s', 60);
      FLockStaleMin := Obj.Get('lock_stale_minutes', 5);
      FMonitorIntervalSec := Obj.Get('monitor_interval_s', 5);
      FMinFreeDiskGb := Obj.Get('min_free_disk_gb', 10);
    finally
      Obj.Free;
    end;
  end;

  SafeReadFileUtf8(SetDir + 'ai-providers.json', AiStr);
  SafeReadFileUtf8(SetDir + 'apps.json', AppsStr);
  FSettingsSha256 := SHA256String(AiStr + #10 + AppsStr);
  FUpdatedAtStamp := ComputeCurrentStamp;
  FLoadedProductionSettings := True;
  KeyName := ''; N := Length(KeyName); if N > 0 then; // avoid hint
end;

procedure TMMSettings.Load(const ProductionRoot: string; App: TMMApp);
begin
  FProductionRoot := ExcludeTrailingPathDelimiter(ProductionRoot);
  LoadMachineIni;
  LoadProductionJsonFiles;
end;

function TMMSettings.ReloadIfChanged(App: TMMApp): Boolean;
var
  NewStamp: string;
begin
  Result := False;
  NewStamp := ComputeCurrentStamp;
  if NewStamp <> FUpdatedAtStamp then
  begin
    LoadProductionJsonFiles;
    Result := True;
  end;
end;

function TMMSettings.FindProviderById(const Id: string; out Prov: TMmpAiProviderCfg): Boolean;
var
  I: Integer;
begin
  Result := False;
  FillChar(Prov, SizeOf(Prov), 0);
  for I := 0 to High(FProviders) do
    if SameText(FProviders[I].Id, Id) then
    begin
      Prov := FProviders[I];
      Exit(True);
    end;
end;

function TMMSettings.GetDefaultProviderId(const Kind: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FDefaultProviders) do
    if SameText(FDefaultProviders[I].Kind, Kind) then
      Exit(FDefaultProviders[I].ProviderId);
  for I := 0 to High(FProviders) do
    if SameText(FProviders[I].Kind, Kind) and FProviders[I].Enabled then
      Exit(FProviders[I].Id);
end;

function TMMSettings.GetAppProviderId(App: TMMApp; const Kind: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FAppConfigs[App].Providers) do
    if SameText(FAppConfigs[App].Providers[I].Kind, Kind) then
      Exit(FAppConfigs[App].Providers[I].ProviderId);
  Result := GetDefaultProviderId(Kind);
end;

function TMMSettings.ResolveProvider(const Kind: string; App: TMMApp;
  out Prov: TMmpAiProviderCfg): Boolean;
var
  Pid: string;
begin
  Pid := GetAppProviderId(App, Kind);
  if (Pid <> '') and FindProviderById(Pid, Prov) then
  begin
    if FOfflineMode then Prov.Adapter := 'mock';
    Exit(True);
  end;
  Pid := GetDefaultProviderId(Kind);
  if (Pid <> '') and FindProviderById(Pid, Prov) then
  begin
    if FOfflineMode then Prov.Adapter := 'mock';
    Exit(True);
  end;
  Prov := DefaultProvider(Kind + '.default', Kind, Kind + ' (Simulado)', 'mock', 'mock-' + Kind);
  Result := True;
end;

procedure TMMSettings.SetOrAddProvider(const Prov: TMmpAiProviderCfg; SetAsDefault: Boolean);
var
  I, N: Integer;
  Found: Boolean;
begin
  Found := False;
  for I := 0 to High(FProviders) do
  begin
    if SameText(FProviders[I].Id, Prov.Id) then
    begin
      FProviders[I] := Prov;
      Found := True;
      Break;
    end;
  end;
  if not Found then
  begin
    N := Length(FProviders);
    SetLength(FProviders, N + 1);
    FProviders[N] := Prov;
  end;
  if SetAsDefault then
  begin
    Found := False;
    for I := 0 to High(FDefaultProviders) do
    begin
      if SameText(FDefaultProviders[I].Kind, Prov.Kind) then
      begin
        FDefaultProviders[I].ProviderId := Prov.Id;
        Found := True;
        Break;
      end;
    end;
    if not Found then
    begin
      N := Length(FDefaultProviders);
      SetLength(FDefaultProviders, N + 1);
      FDefaultProviders[N].Kind := Prov.Kind;
      FDefaultProviders[N].ProviderId := Prov.Id;
    end;
  end;
end;

procedure TMMSettings.SetAppProvider(App: TMMApp; const Kind, ProviderId: string);
var
  I, N: Integer;
begin
  for I := 0 to High(FAppConfigs[App].Providers) do
  begin
    if SameText(FAppConfigs[App].Providers[I].Kind, Kind) then
    begin
      FAppConfigs[App].Providers[I].ProviderId := ProviderId;
      Exit;
    end;
  end;
  N := Length(FAppConfigs[App].Providers);
  SetLength(FAppConfigs[App].Providers, N + 1);
  FAppConfigs[App].Providers[N].Kind := Kind;
  FAppConfigs[App].Providers[N].ProviderId := ProviderId;
end;

function TMMSettings.ResolveSecret(const SecretRef: string): string;
var
  Ini: TIniFile;
begin
  Result := '';
  if Trim(SecretRef) = '' then Exit;
  Result := GetEnvironmentVariable(SecretRef);
  if Result <> '' then Exit;
  if FileExists(FSecretsIniPath) then
  begin
    Ini := TIniFile.Create(FSecretsIniPath);
    try
      Result := Ini.ReadString('Secrets', SecretRef, '');
    finally
      Ini.Free;
    end;
  end;
end;

function TMMSettings.SaveSecret(const SecretRef, SecretValue: string): Boolean;
var
  Ini: TIniFile;
begin
  Result := False;
  if Trim(SecretRef) = '' then Exit;
  ForceDirectories(ExtractFileDir(FSecretsIniPath));
  Ini := TIniFile.Create(FSecretsIniPath);
  try
    Ini.WriteString('Secrets', SecretRef, SecretValue);
    Result := True;
  finally
    Ini.Free;
  end;
end;

function TMMSettings.DetectToolPath(const ToolName: string): string;
var
  ExeDir, Suffix, Candidate, EnvPath, PathItem: string;
  Parts: TStringList;
  I: Integer;
begin
  Result := '';
  {$IFDEF WINDOWS}
  Suffix := '.exe';
  {$ELSE}
  Suffix := '';
  {$ENDIF}
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  Candidate := IncludeTrailingPathDelimiter(ExeDir) + ToolName + Suffix;
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := IncludeTrailingPathDelimiter(ExeDir) + 'tools' + PathDelim + ToolName + Suffix;
  if FileExists(Candidate) then Exit(Candidate);

  EnvPath := GetEnvironmentVariable('PATH');
  Parts := TStringList.Create;
  try
    {$IFDEF WINDOWS}
    Parts.Delimiter := ';';
    {$ELSE}
    Parts.Delimiter := ':';
    {$ENDIF}
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := EnvPath;
    for I := 0 to Parts.Count - 1 do
    begin
      PathItem := Trim(Parts[I]);
      if PathItem = '' then Continue;
      Candidate := IncludeTrailingPathDelimiter(PathItem) + ToolName + Suffix;
      if FileExists(Candidate) then Exit(Candidate);
    end;
  finally
    Parts.Free;
  end;
end;

function TMMSettings.DetectAppPath(App: TMMApp): string;
var
  ExeDir, Suffix, Candidate: string;
begin
  Result := FAppExes[App];
  if (Result <> '') and FileExists(Result) then Exit(Result);

  {$IFDEF WINDOWS}
  Suffix := '.exe';
  {$ELSE}
  Suffix := '';
  {$ENDIF}
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  Candidate := IncludeTrailingPathDelimiter(ExeDir) + LowerCase(MMAppNames[App]) + Suffix;
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := ExpandFileName(ExeDir + PathDelim + '..' + PathDelim + 'bin' +
    PathDelim + LowerCase(MMAppNames[App]) + Suffix);
  if FileExists(Candidate) then Exit(Candidate);
  Result := '';
end;

function TMMSettings.VerifyEnvironment(out Report: string): Boolean;
var
  SL: TStringList;
  A: TMMApp;
  P, ExeDir: string;
  AllAppsOk: Boolean;
begin
  SL := TStringList.Create;
  try
    AllAppsOk := True;
    SL.Add('=== Verificacao de Ambiente (MaurinMovie ' + MAURINMOVIE_VERSION + ') ===');
    SL.Add('Usuario autor/revisor: ' + FUserName);
    if Trim(FUserName) = '' then
    begin
      SL.Add('[AVISO] Nome do usuario nao definido (aprovacoes bloqueadas).');
      AllAppsOk := False;
    end;

    SL.Add('');
    SL.Add('Aplicativos:');
    for A := maMScript to maMCut do
    begin
      P := DetectAppPath(A);
      if P <> '' then
        SL.Add('  [OK] ' + MMAppNames[A] + ': ' + P)
      else
      begin
        SL.Add('  [AUSENTE] ' + MMAppNames[A]);
        AllAppsOk := False;
      end;
    end;

    SL.Add('');
    SL.Add('Ferramentas externas e SSL:');
    ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
    {$IFDEF WINDOWS}
    if FileExists(IncludeTrailingPathDelimiter(ExeDir) + 'libssl-1_1-x64.dll') and
       FileExists(IncludeTrailingPathDelimiter(ExeDir) + 'libcrypto-1_1-x64.dll') then
      SL.Add('  [OK] OpenSSL Win64 ao lado do executavel')
    else
      SL.Add('  [AVISO] OpenSSL Win64 nao encontrada em ' + ExeDir);
    {$ENDIF}

    P := FToolFfmpeg; if (P = '') or not FileExists(P) then P := DetectToolPath('ffmpeg');
    if P <> '' then SL.Add('  [OK] ffmpeg: ' + P) else SL.Add('  [OPCIONAL/AUSENTE] ffmpeg');

    P := FToolFfprobe; if (P = '') or not FileExists(P) then P := DetectToolPath('ffprobe');
    if P <> '' then SL.Add('  [OK] ffprobe: ' + P) else SL.Add('  [OPCIONAL/AUSENTE] ffprobe');

    P := FToolMpv; if (P = '') or not FileExists(P) then P := DetectToolPath('mpv');
    if P <> '' then SL.Add('  [OK] mpv: ' + P) else SL.Add('  [OPCIONAL/AUSENTE] mpv');

    Report := SL.Text;
    Result := AllAppsOk;
  finally
    SL.Free;
  end;
end;

function TMMSettings.SaveMachineIni: Boolean;
var
  Ini: TIniFile;
  A: TMMApp;
begin
  ForceDirectories(ExtractFileDir(FMachineIniPath));
  Ini := TIniFile.Create(FMachineIniPath);
  try
    Ini.WriteString('User', 'Name', FUserName);
    Ini.WriteString('User', 'Role', FUserRole);
    Ini.WriteString('User', 'Email', FUserEmail);

    for A := maMScript to maMCut do
      Ini.WriteString('Applications', MMAppNames[A], FAppExes[A]);

    Ini.WriteString('Tools', 'ffmpeg', FToolFfmpeg);
    Ini.WriteString('Tools', 'ffprobe', FToolFfprobe);
    Ini.WriteString('Tools', 'mpv', FToolMpv);

    Ini.WriteString('Paths', 'ProductionsDir', FProductionsDir);
    Ini.WriteString('Paths', 'GlobalCacheDir', FGlobalCacheDir);
    Ini.WriteString('Paths', 'SoundLibraryDir', FSoundLibraryDir);
    Ini.WriteString('Paths', 'MusicLibraryDir', FMusicLibraryDir);

    Ini.WriteString('Network', 'Proxy', FProxyUrl);
    Ini.WriteString('Network', 'ProxyUser', FProxyUser);
    Ini.WriteString('Network', 'CABundle', FCABundle);
    Ini.WriteBool('Network', 'Offline', FOfflineMode);

    Ini.WriteString('Interface', 'Language', FUiLanguage);
    Ini.WriteInteger('Interface', 'FontScale', FFontScale);
    Ini.WriteString('Interface', 'Theme', FUiTheme);
    Ini.WriteBool('Interface', 'ConfirmDestructive', FConfirmDestructive);

    Ini.WriteString('Logging', 'Level', FLogLevel);
    Ini.WriteInteger('Logging', 'RetentionDays', FLogRetentionDays);
    Result := True;
  finally
    Ini.Free;
  end;
end;

function TMMSettings.SaveProductionSettings(out ErrorMsg: string): Boolean;
var
  SetDir, NowIso: string;
  Root, Sub, ParamsObj, DefObj: TJSONObject;
  Arr, FSize: TJSONArray;
  I, J: Integer;
  A: TMMApp;
begin
  Result := False;
  ErrorMsg := '';
  if FProductionRoot = '' then
  begin
    ErrorMsg := 'Nenhuma producao ativa para salvar configuracoes de producao.';
    Exit;
  end;
  SetDir := IncludeTrailingPathDelimiter(FProductionRoot) + 'settings' + PathDelim;
  ForceDirectories(SetDir);
  NowIso := CurrentUtcIso;

  // Validate providers
  for I := 0 to High(FProviders) do
  begin
    if Trim(FProviders[I].Model) = '' then
    begin
      ErrorMsg := 'Provedor "' + FProviders[I].Id + '" precisa ter um modelo definido.';
      Exit;
    end;
    if (FProviders[I].Adapter = 'openai-compatible') and (Trim(FProviders[I].BaseUrl) = '') then
    begin
      ErrorMsg := 'Provedor HTTP "' + FProviders[I].Id + '" precisa de base_url valida.';
      Exit;
    end;
  end;

  // 1. settings/production.json
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.production-settings/1');
    Root.Add('updated_at', NowIso);
    Root.Add('language', FProdLanguage);
    Root.Add('fps', FProdFps);
    FSize := TJSONArray.Create; FSize.Add(FProdWidth); FSize.Add(FProdHeight);
    Root.Add('frame_size', FSize);
    Root.Add('aspect', FProdAspect);
    Sub := TJSONObject.Create;
    Sub.Add('sample_rate', FProdAudioRate);
    Sub.Add('channels', FProdAudioChannels);
    Root.Add('audio', Sub);
    Root.Add('target_duration_ms', FProdTargetDurationMs);
    Root.Add('visual_style', FProdVisualStyle);
    Root.Add('name_base', FProdNameBase);
    Root.Add('format', FProdFormat);
    Root.Add('rating', FProdRating);
    if not SafeWriteFileAtomic(SetDir + 'production.json', Root.FormatJSON, True) then
    begin
      ErrorMsg := 'Falha ao gravar settings/production.json.';
      Exit;
    end;
  finally
    Root.Free;
  end;

  // 2. settings/ai-providers.json
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.ai-providers/1');
    Root.Add('updated_at', NowIso);
    Arr := TJSONArray.Create;
    for I := 0 to High(FProviders) do
    begin
      Sub := TJSONObject.Create;
      Sub.Add('id', FProviders[I].Id);
      Sub.Add('kind', FProviders[I].Kind);
      Sub.Add('label', FProviders[I].LabelText);
      Sub.Add('adapter', FProviders[I].Adapter);
      Sub.Add('base_url', FProviders[I].BaseUrl);
      Sub.Add('model', FProviders[I].Model);
      Sub.Add('secret_ref', FProviders[I].SecretRef);
      Sub.Add('timeout_s', FProviders[I].TimeoutSec);
      Sub.Add('max_retries', FProviders[I].MaxRetries);
      Sub.Add('rate_limit_per_min', FProviders[I].RateLimitPerMin);
      Sub.Add('max_concurrency', FProviders[I].MaxConcurrency);
      Sub.Add('cost_per_unit', FProviders[I].CostPerUnit);
      Sub.Add('unit', FProviders[I].CostUnit);
      Sub.Add('enabled', FProviders[I].Enabled);
      ParamsObj := TJSONObject.Create;
      ParamsObj.Add('temperature', FProviders[I].Temperature);
      ParamsObj.Add('max_tokens', FProviders[I].MaxTokens);
      ParamsObj.Add('width', FProviders[I].Width);
      ParamsObj.Add('height', FProviders[I].Height);
      ParamsObj.Add('fps', FProviders[I].Fps);
      ParamsObj.Add('max_segment_s', FProviders[I].MaxSegmentSec);
      ParamsObj.Add('lip_sync', FProviders[I].LipSync);
      ParamsObj.Add('sample_rate', FProviders[I].SampleRate);
      Sub.Add('params', ParamsObj);
      Arr.Add(Sub);
    end;
    Root.Add('providers', Arr);

    DefObj := TJSONObject.Create;
    for I := 0 to High(FDefaultProviders) do
      DefObj.Add(FDefaultProviders[I].Kind, FDefaultProviders[I].ProviderId);
    Root.Add('defaults', DefObj);
    if not SafeWriteFileAtomic(SetDir + 'ai-providers.json', Root.FormatJSON, True) then
    begin
      ErrorMsg := 'Falha ao gravar settings/ai-providers.json.';
      Exit;
    end;
  finally
    Root.Free;
  end;

  // 3. settings/apps.json
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.apps-settings/1');
    Root.Add('updated_at', NowIso);
    for A := maMScript to maMCut do
    begin
      Sub := TJSONObject.Create;
      DefObj := TJSONObject.Create;
      for J := 0 to High(FAppConfigs[A].Providers) do
        DefObj.Add(FAppConfigs[A].Providers[J].Kind, FAppConfigs[A].Providers[J].ProviderId);
      Sub.Add('providers', DefObj);

      ParamsObj := TJSONObject.Create;
      ParamsObj.Add('scene_count', FAppConfigs[A].SceneCount);
      ParamsObj.Add('include_dialogue', FAppConfigs[A].IncludeDialogue);
      ParamsObj.Add('suggest_objects', FAppConfigs[A].SuggestObjects);
      ParamsObj.Add('creativity', FAppConfigs[A].Creativity);
      ParamsObj.Add('approved_refs_only', FAppConfigs[A].ApprovedRefsOnly);
      ParamsObj.Add('style', FAppConfigs[A].VisualStyle);
      ParamsObj.Add('rating_scale', FAppConfigs[A].RatingScale);
      ParamsObj.Add('fragment_context_s', FAppConfigs[A].FragmentContextSec);
      Sub.Add('defaults', ParamsObj);
      Root.Add(MMAppNames[A], Sub);
    end;
    if not SafeWriteFileAtomic(SetDir + 'apps.json', Root.FormatJSON, True) then
    begin
      ErrorMsg := 'Falha ao gravar settings/apps.json.';
      Exit;
    end;
  finally
    Root.Free;
  end;

  // 4. settings/policies.json
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.policies/1');
    Root.Add('updated_at', NowIso);
    Root.Add('require_approved_refs_for_board', FRequireApprovedRefsForBoard);
    Root.Add('require_voice_approval_for_scene', FRequireVoiceApprovalForScene);
    Root.Add('rating_scale', FPolicyRatingScale);
    Root.Add('budget_total', FBudgetTotal);
    Root.Add('currency', FBudgetCurrency);
    Root.Add('autosave_s', FAutosaveSec);
    Root.Add('lock_stale_minutes', FLockStaleMin);
    Root.Add('monitor_interval_s', FMonitorIntervalSec);
    Root.Add('min_free_disk_gb', FMinFreeDiskGb);
    if not SafeWriteFileAtomic(SetDir + 'policies.json', Root.FormatJSON, True) then
    begin
      ErrorMsg := 'Falha ao gravar settings/policies.json.';
      Exit;
    end;
  finally
    Root.Free;
  end;

  LoadProductionJsonFiles;
  Result := True;
end;

class function TMMSettings.WriteDefaultProductionSettings(
  const ProductionRoot, Title, NameBase, Language: string;
  out ErrorMsg: string): Boolean;
var
  S: TMMSettings;
  SetDir, NowIso: string;
  Root, Sub: TJSONObject;
  Arr: TJSONArray;
begin
  S := TMMSettings.Create;
  try
    S.FProductionRoot := ExcludeTrailingPathDelimiter(ProductionRoot);
    S.FProdNameBase := NameBase;
    if Trim(S.FProdNameBase) = '' then S.FProdNameBase := Title;
    if Trim(Language) <> '' then S.FProdLanguage := Language;

    SetLength(S.FProviders, 5);
    S.FProviders[0] := DefaultProvider('text.default', 'text', 'Texto (Simulado)', 'mock', 'mock-script-v1');
    S.FProviders[1] := DefaultProvider('image.default', 'image', 'Imagem (Simulado)', 'mock', 'mock-image-v1');
    S.FProviders[2] := DefaultProvider('voice.default', 'voice', 'Voz (Simulado)', 'mock', 'mock-voice-v1');
    S.FProviders[3] := DefaultProvider('sfx.default', 'sfx', 'Efeitos (Simulado)', 'mock', 'mock-sfx-v1');
    S.FProviders[4] := DefaultProvider('video.default', 'video', 'Video (Simulado)', 'mock', 'mock-video-v1');

    SetLength(S.FDefaultProviders, 5);
    S.FDefaultProviders[0].Kind := 'text';  S.FDefaultProviders[0].ProviderId := 'text.default';
    S.FDefaultProviders[1].Kind := 'image'; S.FDefaultProviders[1].ProviderId := 'image.default';
    S.FDefaultProviders[2].Kind := 'voice'; S.FDefaultProviders[2].ProviderId := 'voice.default';
    S.FDefaultProviders[3].Kind := 'sfx';   S.FDefaultProviders[3].ProviderId := 'sfx.default';
    S.FDefaultProviders[4].Kind := 'video'; S.FDefaultProviders[4].ProviderId := 'video.default';

    S.SetAppProvider(maMScript, 'text', 'text.default');
    S.SetAppProvider(maMVisual, 'text', 'text.default');
    S.SetAppProvider(maMVisual, 'image', 'image.default');
    S.SetAppProvider(maMBoard, 'text', 'text.default');
    S.SetAppProvider(maMBoard, 'image', 'image.default');
    S.SetAppProvider(maMSound, 'text', 'text.default');
    S.SetAppProvider(maMSound, 'voice', 'voice.default');
    S.SetAppProvider(maMSound, 'sfx', 'sfx.default');
    S.SetAppProvider(maMScene, 'video', 'video.default');
    S.SetAppProvider(maMCut, 'text', 'text.default');

    Result := S.SaveProductionSettings(ErrorMsg);
    if not Result then Exit;

    // Also write media-profiles.json and presets.json
    SetDir := IncludeTrailingPathDelimiter(ProductionRoot) + 'settings' + PathDelim;
    NowIso := CurrentUtcIso;

    Root := TJSONObject.Create;
    try
      Root.Add('schema', 'mmp.media-profiles/1');
      Root.Add('updated_at', NowIso);
      Sub := TJSONObject.Create;
      Sub.Add('format', 'png'); Sub.Add('width', 1024); Sub.Add('height', 1024);
      Sub.Add('background', '#808080');
      Root.Add('image.reference', Sub);
      Sub := TJSONObject.Create;
      Sub.Add('format', 'wav'); Sub.Add('sample_rate', 48000); Sub.Add('bit_depth', 24);
      Root.Add('audio.work', Sub);
      Sub := TJSONObject.Create;
      Sub.Add('container', 'mp4'); Sub.Add('codec', 'h264'); Sub.Add('crf', 16);
      Root.Add('video.work', Sub);
      SafeWriteFileAtomic(SetDir + 'media-profiles.json', Root.FormatJSON, False);
    finally
      Root.Free;
    end;

    Root := TJSONObject.Create;
    try
      Root.Add('schema', 'mmp.presets/1');
      Root.Add('updated_at', NowIso);
      Arr := TJSONArray.Create;
      Arr.Add('realista cinematografico'); Arr.Add('storyboard colorido'); Arr.Add('esboco P&B');
      Root.Add('visual_styles', Arr);
      Arr := TJSONArray.Create;
      Arr.Add('corte seco'); Arr.Add('fade in'); Arr.Add('fade out'); Arr.Add('fade cruzado');
      Root.Add('transitions', Arr);
      SafeWriteFileAtomic(SetDir + 'presets.json', Root.FormatJSON, False);
    finally
      Root.Free;
    end;
  finally
    S.Free;
  end;
end;

function TMMSettings.GetAppExe(App: TMMApp): string;
begin
  Result := FAppExes[App];
end;

procedure TMMSettings.SetAppExe(App: TMMApp; const Path: string);
begin
  FAppExes[App] := Path;
end;

function TMMSettings.ProviderCount: Integer;
begin
  Result := Length(FProviders);
end;

function TMMSettings.GetProvider(Index: Integer): TMmpAiProviderCfg;
begin
  Result := FProviders[Index];
end;

function TMMSettings.GetAppConfig(App: TMMApp): TMmpAppSettingsCfg;
begin
  Result := FAppConfigs[App];
end;

procedure TMMSettings.SetAppConfig(App: TMMApp; const Cfg: TMmpAppSettingsCfg);
begin
  FAppConfigs[App] := Cfg;
end;

end.

