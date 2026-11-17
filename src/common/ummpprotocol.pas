unit ummpprotocol;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser,
  mmpcommon, mmpsettings, ummpsha256, ummpdb;

const
  MMP_EXECUTABLE_VERSION = MAURINMOVIE_VERSION;
  MMP_PRODUCTION_SCHEMA = MMP_SCHEMA_PRODUCTION;
  MMP_PROJECT_SCHEMA = MMP_SCHEMA_PROJECT;
  MMP_MANIFEST_SCHEMA = MMP_SCHEMA_MANIFEST;
  MMP_CATALOG_SCHEMA = MMP_SCHEMA_CATALOG;

  MMP_APP_COUNT = 7; // 0..6

  MmpAppNames: array[0..6] of string = (
    'MMenu', 'MScript', 'MVisual', 'MBoard', 'MSound', 'MScene', 'MCut'
  );

  MmpAppFolders: array[0..6] of string = (
    '00-mmenu', '01-mscript', '02-mvisual', '03-mboard',
    '04-msound', '05-mscene', '06-mcut'
  );

  MmpAppDescriptions: array[0..6] of string = (
    'Portal e integracao',
    'Roteiro e personagens',
    'Biblioteca visual',
    'Storyboard e sincronizacao',
    'Identidade vocal e efeitos',
    'Geracao e montagem de cenas',
    'Montagem final e exportacao'
  );

type
  TMmpSourceRef = record
    ProjectId: string;
    RevisionId: string;
    ManifestSha256: string;
    ResolvedApp: string;
    Status: string; // 'ok', 'missing', 'hash_mismatch'
  end;

  TMmpArtifactRef = record
    ArtifactId: string;
    AppName: string;
    ProjectId: string;
    RevisionId: string;
    Kind: string;
    SceneId: string;
    SegmentId: string;
    Uri: string;
    ResolvedPath: string;
    MimeType: string;
    Sha256: string;
    Bytes: Int64;
    Status: string;
    IntegrityStatus: string; // 'ok', 'missing', 'resolved_moved', 'hash_mismatch', 'invalid_path', 'no_hash'
  end;

  TMmpRevisionInfo = record
    RevisionId: string;
    ParentRevisionId: string;
    State: string;
    CreatedAt: string;
    ChangeEventId: string;
    ManifestPath: string;
    ManifestSha256: string;
    HasManifest: Boolean;
    Sources: array of TMmpSourceRef;
    Artifacts: array of TMmpArtifactRef;
  end;

  TMmpProjectRef = record
    SoftwareIndex: Integer; // 0..6
    AppName: string;
    ProjectId: string;
    SceneId: string;
    Schema: string;
    ProjectFilePath: string;
    ActiveRevision: string;
    Status: string;
    CreatedAt: string;
    UpdatedAt: string;
    ExistsOnDisk: Boolean;
    Relinked: Boolean;
    IntegrityMessage: string;
    RevisionHistory: array of string;
    Revisions: array of TMmpRevisionInfo;
  end;

  TMmpSyncJob = record
    EventId: string;
    TransactionId: string;
    ProductionId: string;
    OriginApp: string;
    TargetApp: string;
    ProjectId: string;
    SourceRevision: string;
    RequestedChange: string;
    Stage: string;
    Status: string; // queued, running, awaiting_review, approved, published, complete, in_progress, failed, cancelled
    ErrorText: string;
    CreatedAt: string;
    SourceFile: string;
  end;

  TMmpMissingLink = record
    Kind: string; // 'project', 'artifact', 'source_manifest', 'production'
    AppName: string;
    ProjectId: string;
    RevisionId: string;
    TargetId: string;
    ExpectedPath: string;
    ResolvedPath: string;
    ExpectedSha256: string;
    Status: string; // 'missing', 'resolved_by_id', 'resolved_by_hash', 'hash_mismatch', 'invalid_path'
    Detail: string;
  end;

  TMmpProduction = record
    RootDir: string;
    ProductionJsonPath: string;
    DbPath: string;
    Schema: string;
    ProductionId: string;
    Title: string;
    CreatedAt: string;
    Loaded: Boolean;
    ErrorMessage: string;
    HasFailures: Boolean;
    HasPendingWork: Boolean;
    OverallStatusText: string;
    Projects: array of TMmpProjectRef;
    SyncJobs: array of TMmpSyncJob;
    Artifacts: array of TMmpArtifactRef;
    MissingLinks: array of TMmpMissingLink;
  end;

function AppNameToIndex(const AppName: string): Integer;
function GenerateMmpId(const Prefix: string): string;
function SlugifyTitle(const Title: string): string;
function CurrentIsoUtc: string;
function NormalizeRelPath(const RelPath: string): string;
function IsSafeRelativePath(const RelPath: string): Boolean;
function ResolveSafePath(const BaseDir, RelPath: string; out FullPath: string): Boolean;
function ReadTextFileUtf8(const FilePath: string; out Content: string): Boolean;
function AtomicWriteTextFile(const TargetPath, Content: string; KeepBackup: Boolean = True): Boolean;

function CreateProduction(const ParentDir, Title: string;
  out CreatedRoot, ErrorMsg: string): Boolean;

function LoadProduction(const RootOrJsonPath: string; CheckFileHashes: Boolean;
  out Prod: TMmpProduction): Boolean;

function RebuildCatalog(const Prod: TMmpProduction; out ErrorMsg: string): Boolean;

function SaveRelinkOverride(const RootDir, Key, TargetProjectJsonPath: string;
  out ErrorMsg: string): Boolean;

function SaveArtifactRelinkToCatalog(const RootDir, ArtifactId, OldUri,
  NewFilePath, ExpectedSha256: string; out ErrorMsg: string): Boolean;

function CancelSyncTransaction(const JobFilePath: string; out ErrorMsg: string): Boolean;

function IsProjectLocked(const ProjectDir: string; out LockInfo: string): Boolean;
function AcquireProjectLock(const ProjectDir, AppName, Mode: string; out ErrorMsg: string): Boolean;
procedure ReleaseProjectLock(const ProjectDir: string);

procedure AppendJsonLogLine(const ProdRoot, AppName, Level, Msg: string);

function FindProductionByIdInDir(const SearchDir, ExpectedProductionId: string;
  out FoundRootDir: string): Boolean;

procedure BuildLaunchArgs(const RootDir, ProjectId, RevisionId: string;
  Args: TStrings; const ProductionId: string = '');

type
  TMmpStageStatus = record
    AppIndex: Integer;
    HasActivity: Boolean;
    CanOpen: Boolean;
    NeedsAdjustment: Boolean;
    ActiveRevision: string;
    StatusText: string;
    MissingPrereqs: string;
    StaleReason: string;
  end;

  TMmpHistoryEntry = record
    Timestamp: string;
    AppName: string;
    Kind: string; // 'Revisao', 'Log', 'Sincronizacao'
    RevisionId: string;
    State: string;
    Summary: string;
    Details: string;
  end;

  TMmpHistoryEntryArray = array of TMmpHistoryEntry;

function MmpProjectHasActivity(const Proj: TMmpProjectRef): Boolean;
function MmpEvaluateStageStatus(const Prod: TMmpProduction; AppIdx: Integer): TMmpStageStatus;
function MmpLoadProductionHistory(const Prod: TMmpProduction): TMmpHistoryEntryArray;
procedure MmpSyncProductionToSqlite(const Prod: TMmpProduction);

implementation

function AppNameToIndex(const AppName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to 6 do
    if SameText(Trim(AppName), MmpAppNames[I]) then
      Exit(I);
end;

function CurrentIsoUtc: string;
var
  UTC: TDateTime;
begin
  UTC := LocalTimeToUniversal(Now);
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', UTC);
end;

var
  IdSequenceCounter: QWord = 0;

function GenerateMmpId(const Prefix: string): string;
var
  Tick: QWord;
  R: DWord;
begin
  Inc(IdSequenceCounter);
  Tick := GetTickCount64;
  R := DWord(Random(65536));
  Result := Prefix + '_' + FormatDateTime('yyyymmddhhnnss', Now) +
    LowerCase(IntToHex(Tick and $FFFF, 4)) +
    LowerCase(IntToHex((IdSequenceCounter xor R) and $FFFF, 4));
end;

function SlugifyTitle(const Title: string): string;
var
  I: Integer;
  C: Char;
  LastDash: Boolean;
begin
  Result := '';
  LastDash := False;
  for I := 1 to Length(Title) do
  begin
    C := LowerCase(Title[I]);
    if (C in ['a'..'z', '0'..'9']) then
    begin
      Result := Result + C;
      LastDash := False;
    end
    else if not LastDash and (Result <> '') then
    begin
      Result := Result + '-';
      LastDash := True;
    end;
  end;
  while (Result <> '') and (Result[Length(Result)] = '-') do
    Delete(Result, Length(Result), 1);
  if Result = '' then
    Result := 'producao';
end;

function NormalizeRelPath(const RelPath: string): string;
var
  I: Integer;
begin
  Result := Trim(RelPath);
  for I := 1 to Length(Result) do
    if Result[I] = '\' then
      Result[I] := '/';
end;

function IsSafeRelativePath(const RelPath: string): Boolean;
var
  Norm: string;
  Parts: TStringList;
  I: Integer;
begin
  Result := False;
  Norm := NormalizeRelPath(RelPath);
  if Norm = '' then Exit;
  if (Norm[1] = '/') then Exit;
  if (Length(Norm) >= 2) and (Norm[2] = ':') then Exit;
  if Pos('://', Norm) > 0 then Exit;

  Parts := TStringList.Create;
  try
    Parts.Delimiter := '/';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Norm;
    for I := 0 to Parts.Count - 1 do
    begin
      if Parts[I] = '..' then
        Exit(False);
    end;
    Result := True;
  finally
    Parts.Free;
  end;
end;

function ResolveSafePath(const BaseDir, RelPath: string; out FullPath: string): Boolean;
var
  NormBase, NormRel, Candidate: string;
begin
  Result := False;
  FullPath := '';
  if not IsSafeRelativePath(RelPath) then Exit;

  NormBase := IncludeTrailingPathDelimiter(ExpandFileName(BaseDir));
  NormRel := StringReplace(NormalizeRelPath(RelPath), '/', PathDelim, [rfReplaceAll]);
  Candidate := ExpandFileName(NormBase + NormRel);

  // Confirm resolved path stays inside BaseDir
  {$IFDEF WINDOWS}
  if Pos(LowerCase(NormBase), LowerCase(Candidate)) <> 1 then
    if not SameText(ExcludeTrailingPathDelimiter(NormBase), Candidate) then
      Exit(False);
  {$ELSE}
  if Pos(NormBase, Candidate) <> 1 then
    if ExcludeTrailingPathDelimiter(NormBase) <> Candidate then
      Exit(False);
  {$ENDIF}

  FullPath := Candidate;
  Result := True;
end;

function ReadTextFileUtf8(const FilePath: string; out Content: string): Boolean;
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

function AtomicWriteTextFile(const TargetPath, Content: string; KeepBackup: Boolean): Boolean;
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
        if FileExists(BakPath) then
          DeleteFile(BakPath);
        if not RenameFile(TargetPath, BakPath) then
        begin
          DeleteFile(TempPath);
          Exit(False);
        end;
      end
      else
      begin
        if not DeleteFile(TargetPath) then
        begin
          DeleteFile(TempPath);
          Exit(False);
        end;
      end;
    end;

    Result := RenameFile(TempPath, TargetPath);
    if not Result and KeepBackup and FileExists(TargetPath + '.bak') and not FileExists(TargetPath) then
      RenameFile(TargetPath + '.bak', TargetPath);
  except
    if FileExists(TempPath) then
      DeleteFile(TempPath);
    Result := False;
  end;
end;

function ParseJsonFile(const FilePath: string; out Obj: TJSONObject): Boolean;
var
  Content: string;
  Data: TJSONData;
begin
  Result := False;
  Obj := nil;
  if not ReadTextFileUtf8(FilePath, Content) then Exit;
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

function CreateProduction(const ParentDir, Title: string;
  out CreatedRoot, ErrorMsg: string): Boolean;
var
  ProdId, Slug, NowIso, FolderPath, AppDir, RevDir, FoundRootDir: string;
  ProjectIds: array[0..6] of string;
  I: Integer;
  ProdJson, ActiveObj, AppEntry, ProjJson, ManifestJson, CatalogJson: TJSONObject;
  SettingsProd, RevHist, EmptyArr: TJSONArray;
  SettingsObj: TJSONObject;
  DbProjRow: TMmpDbProjectRow;
  DbRevRow: TMmpDbRevisionRow;
begin
  Result := False;
  CreatedRoot := '';
  ErrorMsg := '';

  if Trim(Title) = '' then
  begin
    ErrorMsg := 'Informe um titulo para a producao.';
    Exit;
  end;
  if not DirectoryExists(ParentDir) then
  begin
    if not ForceDirectories(ParentDir) then
    begin
      ErrorMsg := 'Nao foi possivel criar a pasta destino: ' + ParentDir;
      Exit;
    end;
  end;

  NowIso := CurrentIsoUtc;
  ProdId := GenerateMmpId('p');
  Slug := SlugifyTitle(Title);
  FolderPath := IncludeTrailingPathDelimiter(ExpandFileName(ParentDir)) +
    Slug + '__' + ProdId;

  if DirectoryExists(FolderPath) then
  begin
    ErrorMsg := 'A pasta da producao ja existe: ' + FolderPath;
    Exit;
  end;

  if not ForceDirectories(FolderPath) then
  begin
    ErrorMsg := 'Nao foi possivel criar a pasta da producao.';
    Exit;
  end;

  // Subdirectories per MMP v1 + specs 00-comum §5
  ForceDirectories(FolderPath + PathDelim + 'settings');
  ForceDirectories(FolderPath + PathDelim + 'projects');
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'imports');
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'cache');
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'temp');
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'logs');
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'sync');
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'events' + PathDelim + 'archive');
  for I := 0 to 6 do
    ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'events' +
      PathDelim + 'inbox' + PathDelim + MmpAppNames[I]);
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'transactions');
  ForceDirectories(FolderPath + PathDelim + 'shared' + PathDelim + 'blobs' + PathDelim + 'sha256');
  ForceDirectories(FolderPath + PathDelim + 'backups');

  for I := 0 to 6 do
    ProjectIds[I] := GenerateMmpId('pr_' + LowerCase(MmpAppNames[I]));

  // Centralized production settings (defaults with mock providers)
  if not TMMSettings.WriteDefaultProductionSettings(FolderPath, Trim(Title), Trim(Title), 'pt-BR', ErrorMsg) then
    Exit;

  // projects/00..06
  for I := 0 to 6 do
  begin
    AppDir := FolderPath + PathDelim + 'projects' + PathDelim + MmpAppFolders[I];
    RevDir := AppDir + PathDelim + 'revisions' + PathDelim + 'r0001';
    ForceDirectories(RevDir);
    ForceDirectories(AppDir + PathDelim + 'work');

    if I = 1 then ForceDirectories(RevDir + PathDelim + 'scripts');
    if I = 2 then
    begin
      ForceDirectories(RevDir + PathDelim + 'indexes');
      ForceDirectories(RevDir + PathDelim + 'images' + PathDelim + 'personagens');
      ForceDirectories(RevDir + PathDelim + 'images' + PathDelim + 'objetos');
      ForceDirectories(RevDir + PathDelim + 'images' + PathDelim + 'cenarios');
    end;
    if I = 3 then
    begin
      ForceDirectories(RevDir + PathDelim + 'storyboard');
      ForceDirectories(RevDir + PathDelim + 'images' + PathDelim + 'quadros');
    end;
    if I = 4 then
    begin
      ForceDirectories(RevDir + PathDelim + 'voices');
      ForceDirectories(RevDir + PathDelim + 'audio' + PathDelim + 'voices');
      ForceDirectories(RevDir + PathDelim + 'audio' + PathDelim + 'effects');
      ForceDirectories(RevDir + PathDelim + 'audio' + PathDelim + 'previews');
    end;
    if I = 5 then ForceDirectories(AppDir + PathDelim + 'scenes');
    if I = 6 then
    begin
      ForceDirectories(RevDir + PathDelim + 'timeline');
      ForceDirectories(RevDir + PathDelim + 'feedback');
      ForceDirectories(RevDir + PathDelim + 'analysis');
      ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'exports');
    end;

    ProjJson := TJSONObject.Create;
    try
      ProjJson.Add('schema', MMP_PROJECT_SCHEMA);
      ProjJson.Add('production_id', ProdId);
      ProjJson.Add('project_id', ProjectIds[I]);
      ProjJson.Add('application', MmpAppNames[I]);
      ProjJson.Add('name_base', Trim(Title));
      ProjJson.Add('active_revision', 'r0001');
      ProjJson.Add('status', 'initialized');
      ProjJson.Add('created_at', NowIso);
      ProjJson.Add('updated_at', NowIso);
      RevHist := TJSONArray.Create;
      RevHist.Add('r0001');
      ProjJson.Add('revision_history', RevHist);
      SettingsObj := TJSONObject.Create;
      SettingsObj.Add('r0001', FormatRevisionLabel(Trim(Title), AppIndexToEnum(I), 'r0001'));
      ProjJson.Add('revision_labels', SettingsObj);
      ProjJson.Add('settings', TJSONObject.Create);
      if not AtomicWriteTextFile(AppDir + PathDelim + 'project.json',
        ProjJson.FormatJSON, False) then
      begin
        ErrorMsg := 'Falha ao gravar project.json de ' + MmpAppNames[I];
        Exit;
      end;
    finally
      ProjJson.Free;
    end;

    ManifestJson := TJSONObject.Create;
    try
      ManifestJson.Add('schema', MMP_MANIFEST_SCHEMA);
      ManifestJson.Add('production_id', ProdId);
      ManifestJson.Add('project_id', ProjectIds[I]);
      ManifestJson.Add('application', MmpAppNames[I]);
      ManifestJson.Add('revision_id', 'r0001');
      ManifestJson.Add('parent_revision_id', '');
      ManifestJson.Add('state', 'draft');
      ManifestJson.Add('created_at', NowIso);
      ManifestJson.Add('sources', TJSONArray.Create);
      ManifestJson.Add('artifacts', TJSONArray.Create);
      ManifestJson.Add('change_event_id', '');
      if not AtomicWriteTextFile(RevDir + PathDelim + 'manifest.json',
        ManifestJson.FormatJSON, False) then
      begin
        ErrorMsg := 'Falha ao gravar manifest.json de ' + MmpAppNames[I];
        Exit;
      end;
    finally
      ManifestJson.Free;
    end;
  end;

  // production.json
  ProdJson := TJSONObject.Create;
  try
    ProdJson.Add('schema', MMP_PRODUCTION_SCHEMA);
    ProdJson.Add('production_id', ProdId);
    ProdJson.Add('title', Trim(Title));
    ProdJson.Add('created_at', NowIso);
    ActiveObj := TJSONObject.Create;
    for I := 0 to 6 do
    begin
      AppEntry := TJSONObject.Create;
      AppEntry.Add('project_id', ProjectIds[I]);
      AppEntry.Add('revision_id', 'r0001');
      ActiveObj.Add(MmpAppNames[I], AppEntry);
    end;
    ProdJson.Add('active_projects', ActiveObj);
    if not AtomicWriteTextFile(FolderPath + PathDelim + 'production.json',
      ProdJson.FormatJSON, False) then
    begin
      ErrorMsg := 'Falha ao gravar production.json.';
      Exit;
    end;
  finally
    ProdJson.Free;
  end;

  // catalog.json
  CatalogJson := TJSONObject.Create;
  try
    CatalogJson.Add('schema', MMP_CATALOG_SCHEMA);
    CatalogJson.Add('production_id', ProdId);
    CatalogJson.Add('rebuilt_at', NowIso);
    SettingsProd := TJSONArray.Create;
    for I := 0 to 6 do
    begin
      AppEntry := TJSONObject.Create;
      AppEntry.Add('application', MmpAppNames[I]);
      AppEntry.Add('project_id', ProjectIds[I]);
      AppEntry.Add('active_revision', 'r0001');
      AppEntry.Add('project_path', 'projects/' + MmpAppFolders[I] + '/project.json');
      SettingsProd.Add(AppEntry);
    end;
    CatalogJson.Add('projects', SettingsProd);
    EmptyArr := TJSONArray.Create;
    CatalogJson.Add('artifacts', EmptyArr);
    if not AtomicWriteTextFile(FolderPath + PathDelim + 'catalog.json',
      CatalogJson.FormatJSON, False) then
    begin
      ErrorMsg := 'Falha ao gravar catalog.json.';
      Exit;
    end;
  finally
    CatalogJson.Free;
  end;

  // SQLite: copiar banco zerado template (maurinmovie_empty.db -> maurinmovie.db) e popular registros iniciais
  MmpEnsureProductionMediaDirs(FolderPath);
  if not MmpInitProductionDbFromTemplate(FolderPath, '', FoundRootDir, ErrorMsg) then
    Exit;
  if not MmpDbUpsertProduction(FolderPath, ProdId, Trim(Title), Slug, Trim(Title),
    'pt-BR', 'initialized', NowIso, NowIso, '', ErrorMsg) then
    Exit;

  for I := 0 to 6 do
  begin
    FillChar(DbProjRow, SizeOf(DbProjRow), 0);
    DbProjRow.ProjectId := ProjectIds[I];
    DbProjRow.ProductionId := ProdId;
    DbProjRow.SoftwareIndex := I;
    DbProjRow.AppName := MmpAppNames[I];
    DbProjRow.SceneId := '';
    DbProjRow.NameBase := Trim(Title);
    DbProjRow.ActiveRevision := 'r0001';
    DbProjRow.Status := 'initialized';
    DbProjRow.CreatedAt := NowIso;
    DbProjRow.UpdatedAt := NowIso;
    DbProjRow.ProjectFilePath := 'projects/' + MmpAppFolders[I] + '/project.json';
    if not MmpDbUpsertProject(FolderPath, DbProjRow, ErrorMsg) then Exit;

    FillChar(DbRevRow, SizeOf(DbRevRow), 0);
    DbRevRow.ProjectId := ProjectIds[I];
    DbRevRow.RevisionId := 'r0001';
    DbRevRow.ParentRevisionId := '';
    DbRevRow.State := 'draft';
    DbRevRow.RevLabel := FormatRevisionLabel(Trim(Title), AppIndexToEnum(I), 'r0001');
    DbRevRow.ManifestPath := 'projects/' + MmpAppFolders[I] + '/revisions/r0001/manifest.json';
    DbRevRow.ManifestSha256 := '';
    DbRevRow.CreatedAt := NowIso;
    if not MmpDbUpsertRevision(FolderPath, ProdId, DbRevRow, ErrorMsg) then Exit;
  end;

  MmpDbAddCentralLog(MmpProductionDbPath(FolderPath), ProdId, 'info', 'MMenu', '',
    'create_production', 'r0001',
    'Producao criada com banco SQLite inicializado a partir do template zerado: ' + Trim(Title),
    'Pasta: ' + FolderPath + LineEnding + 'Banco: ' + MmpProductionDbPath(FolderPath));

  CreatedRoot := FolderPath;
  Result := True;
end;

function LoadRelinkOverrides(const RootDir: string): TJSONObject;
var
  RelinkPath: string;
begin
  Result := nil;
  RelinkPath := RootDir + PathDelim + 'projects' + PathDelim +
    MmpAppFolders[0] + PathDelim + 'relinks.json';
  if FileExists(RelinkPath) then
    ParseJsonFile(RelinkPath, Result);
end;

function SaveRelinkOverride(const RootDir, Key, TargetProjectJsonPath: string;
  out ErrorMsg: string): Boolean;
var
  RelinkPath, RelPath: string;
  Obj, MapObj: TJSONObject;
begin
  Result := False;
  ErrorMsg := '';
  if not FileExists(TargetProjectJsonPath) then
  begin
    ErrorMsg := 'Arquivo project.json selecionado nao existe.';
    Exit;
  end;

  RelinkPath := RootDir + PathDelim + 'projects' + PathDelim +
    MmpAppFolders[0] + PathDelim + 'relinks.json';

  RelPath := ExtractRelativepath(IncludeTrailingPathDelimiter(RootDir), TargetProjectJsonPath);
  if not IsSafeRelativePath(RelPath) then
    RelPath := TargetProjectJsonPath;

  Obj := LoadRelinkOverrides(RootDir);
  if Obj = nil then
  begin
    Obj := TJSONObject.Create;
    Obj.Add('schema', 'mmp.relinks/1');
    Obj.Add('overrides', TJSONObject.Create);
  end;
  try
    if Obj.Find('overrides') is TJSONObject then
      MapObj := TJSONObject(Obj.Find('overrides'))
    else
    begin
      MapObj := TJSONObject.Create;
      Obj.Add('overrides', MapObj);
    end;
    if MapObj.IndexOfName(Key) >= 0 then
      MapObj.Strings[Key] := RelPath
    else
      MapObj.Add(Key, RelPath);

    Result := AtomicWriteTextFile(RelinkPath, Obj.FormatJSON, True);
    if not Result then
      ErrorMsg := 'Falha ao salvar relinks.json no diretorio do MMenu.';
  finally
    Obj.Free;
  end;
end;

function FindProjectFileById(const SearchDir, ExpectedProjectId: string;
  out FoundPath: string): Boolean;
var
  SR: TSearchRec;
  SubPath: string;
  Obj: TJSONObject;
begin
  Result := False;
  FoundPath := '';
  if not DirectoryExists(SearchDir) then Exit;

  if FindFirst(IncludeTrailingPathDelimiter(SearchDir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        SubPath := IncludeTrailingPathDelimiter(SearchDir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if FindProjectFileById(SubPath, ExpectedProjectId, FoundPath) then
            Exit(True);
        end
        else if SameText(SR.Name, 'project.json') then
        begin
          if ParseJsonFile(SubPath, Obj) then
          begin
            try
              if SameText(Obj.Get('project_id', ''), ExpectedProjectId) then
              begin
                FoundPath := SubPath;
                Exit(True);
              end;
            finally
              Obj.Free;
            end;
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function FindArtifactMovedInDir(const SearchDir, ArtifactId, ExpectedSha256: string;
  CheckHashes: Boolean; out FoundPath, MatchMethod: string): Boolean;
var
  SR: TSearchRec;
  SubPath, FileHash: string;
begin
  Result := False;
  FoundPath := '';
  MatchMethod := '';
  if not DirectoryExists(SearchDir) then Exit;

  if FindFirst(IncludeTrailingPathDelimiter(SearchDir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if SameText(SR.Name, 'cache') or SameText(SR.Name, 'temp') or
           SameText(SR.Name, 'logs') or SameText(SR.Name, 'backups') then
          Continue;
        SubPath := IncludeTrailingPathDelimiter(SearchDir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if FindArtifactMovedInDir(SubPath, ArtifactId, ExpectedSha256,
            CheckHashes, FoundPath, MatchMethod) then
            Exit(True);
        end
        else
        begin
          if (ArtifactId <> '') and (Pos(LowerCase(ArtifactId), LowerCase(SR.Name)) > 0) then
          begin
            if (not CheckHashes) or (ExpectedSha256 = '') or
               SameText(SHA256File(SubPath), ExpectedSha256) then
            begin
              FoundPath := SubPath;
              MatchMethod := 'resolved_by_id';
              Exit(True);
            end;
          end;
          if CheckHashes and (ExpectedSha256 <> '') and (Length(ExpectedSha256) = 64) then
          begin
            FileHash := SHA256File(SubPath);
            if SameText(FileHash, ExpectedSha256) then
            begin
              FoundPath := SubPath;
              MatchMethod := 'resolved_by_hash';
              Exit(True);
            end;
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure AddMissingLink(var Prod: TMmpProduction; const Link: TMmpMissingLink);
var
  N: Integer;
begin
  N := Length(Prod.MissingLinks);
  SetLength(Prod.MissingLinks, N + 1);
  Prod.MissingLinks[N] := Link;
end;

procedure LoadRevisionManifest(const RevDir, RevId, AppName, ProjectId: string;
  out RevInfo: TMmpRevisionInfo);
var
  ManifestPath, KeyStr: string;
  Obj: TJSONObject;
  Arr: TJSONArray;
  Item: TJSONObject;
  I: Integer;
begin
  FillChar(RevInfo, SizeOf(RevInfo), 0);
  RevInfo.RevisionId := RevId;
  ManifestPath := IncludeTrailingPathDelimiter(RevDir) + 'manifest.json';
  RevInfo.ManifestPath := ManifestPath;
  if not FileExists(ManifestPath) then Exit;

  RevInfo.HasManifest := True;
  RevInfo.ManifestSha256 := SHA256File(ManifestPath);
  if not ParseJsonFile(ManifestPath, Obj) then
  begin
    RevInfo.State := 'manifest_invalido';
    Exit;
  end;
  try
    RevInfo.ParentRevisionId := Obj.Get('parent_revision_id', '');
    RevInfo.State := Obj.Get('state', 'draft');
    RevInfo.CreatedAt := Obj.Get('created_at', '');
    RevInfo.ChangeEventId := Obj.Get('change_event_id', '');

    if Obj.Find('sources') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('sources'));
      SetLength(RevInfo.Sources, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr.Items[I] is TJSONObject then
        begin
          Item := TJSONObject(Arr.Items[I]);
          RevInfo.Sources[I].ProjectId := Item.Get('project_id', '');
          RevInfo.Sources[I].RevisionId := Item.Get('revision_id', '');
          RevInfo.Sources[I].ManifestSha256 := Item.Get('manifest_sha256', '');
          RevInfo.Sources[I].Status := 'pendente';
        end;
      end;
    end;

    if Obj.Find('artifacts') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('artifacts'));
      SetLength(RevInfo.Artifacts, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr.Items[I] is TJSONObject then
        begin
          Item := TJSONObject(Arr.Items[I]);
          RevInfo.Artifacts[I].ArtifactId := Item.Get('artifact_id', '');
          RevInfo.Artifacts[I].AppName := AppName;
          RevInfo.Artifacts[I].ProjectId := ProjectId;
          RevInfo.Artifacts[I].RevisionId := RevId;
          RevInfo.Artifacts[I].Kind := Item.Get('kind', '');
          RevInfo.Artifacts[I].SceneId := Item.Get('scene_id', '');
          RevInfo.Artifacts[I].SegmentId := Item.Get('segment_id', '');
          RevInfo.Artifacts[I].Uri := Item.Get('uri', '');
          RevInfo.Artifacts[I].MimeType := Item.Get('mime_type', '');
          RevInfo.Artifacts[I].Sha256 := Item.Get('sha256', '');
          KeyStr := Item.Get('bytes', '0');
          if Item.Find('bytes') <> nil then
            RevInfo.Artifacts[I].Bytes := Item.Get('bytes', Int64(0))
          else
            RevInfo.Artifacts[I].Bytes := StrToInt64Def(KeyStr, 0);
          RevInfo.Artifacts[I].Status := Item.Get('status', 'draft');
        end;
      end;
    end;
  finally
    Obj.Free;
  end;
end;

procedure LoadProjectRecord(const ProdRoot, ProjectJsonPath: string;
  DefaultAppIndex: Integer; const ExpectedProjectId, SceneId: string;
  RelinkedFlag: Boolean; out Proj: TMmpProjectRef);
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  I, N: Integer;
  ProjDir, RevId, RevDir: string;
  SR: TSearchRec;
  FoundInHist: Boolean;
begin
  FillChar(Proj, SizeOf(Proj), 0);
  Proj.SoftwareIndex := DefaultAppIndex;
  if (DefaultAppIndex >= 0) and (DefaultAppIndex <= 6) then
    Proj.AppName := MmpAppNames[DefaultAppIndex]
  else
    Proj.AppName := 'Desconhecido';
  Proj.ProjectId := ExpectedProjectId;
  Proj.SceneId := SceneId;
  Proj.ProjectFilePath := ProjectJsonPath;
  Proj.Relinked := RelinkedFlag;

  if not FileExists(ProjectJsonPath) then
  begin
    Proj.ExistsOnDisk := False;
    Proj.Status := 'ausente';
    Proj.IntegrityMessage := 'project.json nao encontrado no caminho esperado.';
    Exit;
  end;

  Proj.ExistsOnDisk := True;
  if not ParseJsonFile(ProjectJsonPath, Obj) then
  begin
    Proj.Status := 'erro_json';
    Proj.IntegrityMessage := 'Falha ao ler/interpretar JSON de project.json.';
    Exit;
  end;

  try
    Proj.Schema := Obj.Get('schema', '');
    if Obj.Get('project_id', '') <> '' then
      Proj.ProjectId := Obj.Get('project_id', '');
    if Obj.Get('application', '') <> '' then
    begin
      Proj.AppName := Obj.Get('application', '');
      if AppNameToIndex(Proj.AppName) >= 0 then
        Proj.SoftwareIndex := AppNameToIndex(Proj.AppName);
    end;
    Proj.ActiveRevision := Obj.Get('active_revision', '');
    Proj.Status := Obj.Get('status', 'active');
    Proj.CreatedAt := Obj.Get('created_at', '');
    Proj.UpdatedAt := Obj.Get('updated_at', '');

    if Obj.Find('revision_history') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('revision_history'));
      SetLength(Proj.RevisionHistory, Arr.Count);
      for I := 0 to Arr.Count - 1 do
        Proj.RevisionHistory[I] := Arr.Strings[I];
    end;
  finally
    Obj.Free;
  end;

  ProjDir := ExtractFileDir(ProjectJsonPath);
  if DirectoryExists(ProjDir + PathDelim + 'revisions') then
  begin
    if FindFirst(ProjDir + PathDelim + 'revisions' + PathDelim + '*', faDirectory, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name = '.') or (SR.Name = '..') then Continue;
          if (SR.Attr and faDirectory) = 0 then Continue;
          FoundInHist := False;
          for I := 0 to High(Proj.RevisionHistory) do
            if SameText(Proj.RevisionHistory[I], SR.Name) then
            begin
              FoundInHist := True;
              Break;
            end;
          if not FoundInHist then
          begin
            N := Length(Proj.RevisionHistory);
            SetLength(Proj.RevisionHistory, N + 1);
            Proj.RevisionHistory[N] := SR.Name;
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
  end;

  SetLength(Proj.Revisions, Length(Proj.RevisionHistory));
  for I := 0 to High(Proj.RevisionHistory) do
  begin
    RevId := Proj.RevisionHistory[I];
    RevDir := ProjDir + PathDelim + 'revisions' + PathDelim + RevId;
    LoadRevisionManifest(RevDir, RevId, Proj.AppName, Proj.ProjectId, Proj.Revisions[I]);
  end;

  if (Proj.Schema <> '') and (Proj.Schema <> MMP_PROJECT_SCHEMA) then
    Proj.IntegrityMessage := 'Schema diferente do esperado: ' + Proj.Schema
  else if Proj.Relinked then
    Proj.IntegrityMessage := 'Revinculado manualmente'
  else
    Proj.IntegrityMessage := 'OK';
end;

procedure AddSyncJobFromObj(var Prod: TMmpProduction; Obj: TJSONObject;
  const SourceFile: string);
var
  N, J: Integer;
  Job: TMmpSyncJob;
  AffArr, StagesArr: TJSONArray;
  ReqData: TJSONData;
  StageObj, OrigObj: TJSONObject;
begin
  FillChar(Job, SizeOf(Job), 0);
  Job.EventId := Obj.Get('event_id', '');
  Job.TransactionId := Obj.Get('transaction_id', '');
  if Job.EventId = '' then Job.EventId := Job.TransactionId;
  Job.ProductionId := Obj.Get('production_id', '');
  Job.OriginApp := Obj.Get('origin_app', '');
  Job.TargetApp := Obj.Get('target_app', '');
  Job.ProjectId := Obj.Get('project_id', '');
  Job.SourceRevision := Obj.Get('source_revision', '');

  ReqData := Obj.Find('requested_change');
  if ReqData is TJSONObject then
    Job.RequestedChange := TJSONObject(ReqData).Get('type', 'patch')
  else if ReqData <> nil then
    Job.RequestedChange := ReqData.AsString;

  Job.Stage := Obj.Get('stage', '');
  Job.Status := Obj.Get('status', 'queued');
  Job.ErrorText := Obj.Get('error', '');
  Job.CreatedAt := Obj.Get('created_at', '');
  Job.SourceFile := SourceFile;

  // Handle mmp.transaction/1 structure
  if Obj.Find('origin') is TJSONObject then
  begin
    OrigObj := TJSONObject(Obj.Find('origin'));
    if Job.OriginApp = '' then Job.OriginApp := OrigObj.Get('application', '');
    if Job.ProjectId = '' then Job.ProjectId := OrigObj.Get('project_id', '');
    if Job.SourceRevision = '' then Job.SourceRevision := OrigObj.Get('revision_id', '');
  end;
  if Obj.Find('stages') is TJSONArray then
  begin
    StagesArr := TJSONArray(Obj.Find('stages'));
    for J := 0 to StagesArr.Count - 1 do
    begin
      if StagesArr.Items[J] is TJSONObject then
      begin
        StageObj := TJSONObject(StagesArr.Items[J]);
        if SameText(StageObj.Get('status', ''), 'failed') or
           SameText(StageObj.Get('status', ''), 'in_progress') or
           SameText(StageObj.Get('status', ''), 'pending') then
        begin
          Job.Stage := StageObj.Get('application', '');
          if Job.TargetApp = '' then Job.TargetApp := Job.Stage;
          Break;
        end;
      end;
    end;
  end;
  if (Job.ErrorText = '') and (Obj.Find('errors') is TJSONArray) then
  begin
    AffArr := TJSONArray(Obj.Find('errors'));
    if AffArr.Count > 0 then Job.ErrorText := AffArr.Items[0].AsString;
  end;

  if Job.Stage = '' then
    Job.Stage := Job.TargetApp;

  if (Job.TargetApp = '') and (Obj.Find('affected_projects') is TJSONArray) then
  begin
    AffArr := TJSONArray(Obj.Find('affected_projects'));
    if AffArr.Count > 0 then
      Job.TargetApp := AffArr.Strings[0];
  end;

  N := Length(Prod.SyncJobs);
  SetLength(Prod.SyncJobs, N + 1);
  Prod.SyncJobs[N] := Job;
end;

procedure LoadSyncJobsFromFile(var Prod: TMmpProduction; const FilePath: string);
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  if not FileExists(FilePath) then Exit;
  if not ParseJsonFile(FilePath, Obj) then Exit;
  try
    if Obj.Find('sync_jobs') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('sync_jobs'));
      for I := 0 to Arr.Count - 1 do
        if Arr.Items[I] is TJSONObject then
          AddSyncJobFromObj(Prod, TJSONObject(Arr.Items[I]), FilePath);
    end
    else if Obj.Find('events') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('events'));
      for I := 0 to Arr.Count - 1 do
        if Arr.Items[I] is TJSONObject then
          AddSyncJobFromObj(Prod, TJSONObject(Arr.Items[I]), FilePath);
    end
    else if (Obj.Get('event_id', '') <> '') or (Obj.Get('transaction_id', '') <> '') then
      AddSyncJobFromObj(Prod, Obj, FilePath);
  finally
    Obj.Free;
  end;
end;

procedure ScanJsonFilesInDir(var Prod: TMmpProduction; const DirPath: string);
var
  SR: TSearchRec;
begin
  if not DirectoryExists(DirPath) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(DirPath) + '*.json', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
          LoadSyncJobsFromFile(Prod, IncludeTrailingPathDelimiter(DirPath) + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure ScanSyncJobs(var Prod: TMmpProduction);
var
  I: Integer;
begin
  LoadSyncJobsFromFile(Prod, Prod.RootDir + PathDelim + 'projects' + PathDelim +
    MmpAppFolders[0] + PathDelim + 'sync_jobs.json');

  // Legacy shared/sync/
  ScanJsonFilesInDir(Prod, Prod.RootDir + PathDelim + 'shared' + PathDelim + 'sync');

  // Specs 00-comum §5 & §7: shared/transactions and shared/events/inbox/<App> + archive
  ScanJsonFilesInDir(Prod, Prod.RootDir + PathDelim + 'shared' + PathDelim + 'transactions');
  for I := 0 to 6 do
    ScanJsonFilesInDir(Prod, Prod.RootDir + PathDelim + 'shared' + PathDelim + 'events' +
      PathDelim + 'inbox' + PathDelim + MmpAppNames[I]);
  ScanJsonFilesInDir(Prod, Prod.RootDir + PathDelim + 'shared' + PathDelim + 'events' +
    PathDelim + 'archive');
end;

procedure AuditSourcesAndArtifacts(var Prod: TMmpProduction; CheckHashes: Boolean);
var
  I, J, K, M, ArtCount: Integer;
  RevDir, FullPath, MovedPath, MatchMethod, FileHash: string;
  FoundSource, HashMatch: Boolean;
  Link: TMmpMissingLink;
begin
  // Audit manifest sources[] against loaded projects/revisions
  for I := 0 to High(Prod.Projects) do
  begin
    if Prod.Projects[I].ExistsOnDisk and
       (SameText(Prod.Projects[I].Status, 'erro_json') or
        ((Prod.Projects[I].Schema <> '') and (Prod.Projects[I].Schema <> MMP_PROJECT_SCHEMA))) then
    begin
      FillChar(Link, SizeOf(Link), 0);
      Link.Kind := 'project';
      Link.AppName := Prod.Projects[I].AppName;
      Link.ProjectId := Prod.Projects[I].ProjectId;
      Link.ExpectedPath := Prod.Projects[I].ProjectFilePath;
      Link.Status := 'invalid_json';
      Link.Detail := Prod.Projects[I].IntegrityMessage;
      AddMissingLink(Prod, Link);
    end;

    for J := 0 to High(Prod.Projects[I].Revisions) do
    begin
      if (not Prod.Projects[I].Revisions[J].HasManifest) or
         SameText(Prod.Projects[I].Revisions[J].State, 'manifest_invalido') then
      begin
        FillChar(Link, SizeOf(Link), 0);
        Link.Kind := 'manifest';
        Link.AppName := Prod.Projects[I].AppName;
        Link.ProjectId := Prod.Projects[I].ProjectId;
        Link.RevisionId := Prod.Projects[I].Revisions[J].RevisionId;
        Link.ExpectedPath := Prod.Projects[I].Revisions[J].ManifestPath;
        Link.Status := 'invalid_manifest';
        if not Prod.Projects[I].Revisions[J].HasManifest then
          Link.Detail := 'manifest.json ausente na revisao ' + Prod.Projects[I].Revisions[J].RevisionId
        else
          Link.Detail := 'manifest.json corrompido na revisao ' + Prod.Projects[I].Revisions[J].RevisionId;
        AddMissingLink(Prod, Link);
      end;

      for K := 0 to High(Prod.Projects[I].Revisions[J].Sources) do
      begin
        FoundSource := False;
        HashMatch := True;
        for M := 0 to High(Prod.Projects) do
        begin
          if SameText(Prod.Projects[M].ProjectId,
            Prod.Projects[I].Revisions[J].Sources[K].ProjectId) then
          begin
            Prod.Projects[I].Revisions[J].Sources[K].ResolvedApp := Prod.Projects[M].AppName;
            for ArtCount := 0 to High(Prod.Projects[M].Revisions) do
            begin
              if SameText(Prod.Projects[M].Revisions[ArtCount].RevisionId,
                Prod.Projects[I].Revisions[J].Sources[K].RevisionId) and
                Prod.Projects[M].Revisions[ArtCount].HasManifest then
              begin
                FoundSource := True;
                if (Prod.Projects[I].Revisions[J].Sources[K].ManifestSha256 <> '') and
                   not SameText(Prod.Projects[I].Revisions[J].Sources[K].ManifestSha256,
                     Prod.Projects[M].Revisions[ArtCount].ManifestSha256) then
                  HashMatch := False;
                Break;
              end;
            end;
            Break;
          end;
        end;

        if not FoundSource then
        begin
          Prod.Projects[I].Revisions[J].Sources[K].Status := 'missing';
          FillChar(Link, SizeOf(Link), 0);
          Link.Kind := 'source_manifest';
          Link.AppName := Prod.Projects[I].AppName;
          Link.ProjectId := Prod.Projects[I].Revisions[J].Sources[K].ProjectId;
          Link.RevisionId := Prod.Projects[I].Revisions[J].Sources[K].RevisionId;
          Link.TargetId := Prod.Projects[I].Revisions[J].Sources[K].ProjectId + '@' +
            Prod.Projects[I].Revisions[J].Sources[K].RevisionId;
          Link.Status := 'missing';
          Link.Detail := Format('Fonte referenciada por %s (%s) nao encontrada.',
            [Prod.Projects[I].AppName, Prod.Projects[I].Revisions[J].RevisionId]);
          AddMissingLink(Prod, Link);
        end
        else if not HashMatch then
        begin
          Prod.Projects[I].Revisions[J].Sources[K].Status := 'hash_mismatch';
          FillChar(Link, SizeOf(Link), 0);
          Link.Kind := 'source_manifest';
          Link.AppName := Prod.Projects[I].AppName;
          Link.ProjectId := Prod.Projects[I].Revisions[J].Sources[K].ProjectId;
          Link.RevisionId := Prod.Projects[I].Revisions[J].Sources[K].RevisionId;
          Link.TargetId := Prod.Projects[I].Revisions[J].Sources[K].ProjectId + '@' +
            Prod.Projects[I].Revisions[J].Sources[K].RevisionId;
          Link.Status := 'hash_mismatch';
          Link.Detail := Format('SHA-256 do manifesto fonte diverge em %s (%s).',
            [Prod.Projects[I].AppName, Prod.Projects[I].Revisions[J].RevisionId]);
          AddMissingLink(Prod, Link);
        end
        else
          Prod.Projects[I].Revisions[J].Sources[K].Status := 'ok';
      end;
    end;
  end;

  // Audit artifacts in each revision
  SetLength(Prod.Artifacts, 0);
  for I := 0 to High(Prod.Projects) do
  begin
    for J := 0 to High(Prod.Projects[I].Revisions) do
    begin
      RevDir := ExtractFileDir(Prod.Projects[I].Revisions[J].ManifestPath);
      for K := 0 to High(Prod.Projects[I].Revisions[J].Artifacts) do
      begin
        with Prod.Projects[I].Revisions[J].Artifacts[K] do
        begin
          if Uri = '' then
          begin
            IntegrityStatus := 'missing';
            FillChar(Link, SizeOf(Link), 0);
            Link.Kind := 'artifact';
            Link.AppName := AppName;
            Link.ProjectId := ProjectId;
            Link.RevisionId := RevisionId;
            Link.TargetId := ArtifactId;
            Link.Status := 'missing';
            Link.Detail := 'Artefato sem URI no manifesto.';
            AddMissingLink(Prod, Link);
          end
          else if not ResolveSafePath(RevDir, Uri, FullPath) then
          begin
            IntegrityStatus := 'invalid_path';
            FillChar(Link, SizeOf(Link), 0);
            Link.Kind := 'artifact';
            Link.AppName := AppName;
            Link.ProjectId := ProjectId;
            Link.RevisionId := RevisionId;
            Link.TargetId := ArtifactId;
            Link.ExpectedPath := Uri;
            Link.Status := 'invalid_path';
            Link.Detail := 'Caminho invalido ou fora da raiz da revisao: ' + Uri;
            AddMissingLink(Prod, Link);
          end
          else if FileExists(FullPath) then
          begin
            ResolvedPath := FullPath;
            if CheckHashes and (Sha256 <> '') and (Length(Sha256) = 64) then
            begin
              FileHash := SHA256File(FullPath);
              if SameText(FileHash, Sha256) then
                IntegrityStatus := 'ok'
              else
              begin
                IntegrityStatus := 'hash_mismatch';
                FillChar(Link, SizeOf(Link), 0);
                Link.Kind := 'artifact';
                Link.AppName := AppName;
                Link.ProjectId := ProjectId;
                Link.RevisionId := RevisionId;
                Link.TargetId := ArtifactId;
                Link.ExpectedPath := FullPath;
                Link.ExpectedSha256 := Sha256;
                Link.Status := 'hash_mismatch';
                Link.Detail := 'Checksum SHA-256 divergente para ' + Uri;
                AddMissingLink(Prod, Link);
              end;
            end
            else if Sha256 = '' then
              IntegrityStatus := 'no_hash'
            else
              IntegrityStatus := 'ok';
          end
          else
          begin
            // Missing at expected path: try finding moved file inside production by ID or hash
            if FindArtifactMovedInDir(Prod.RootDir, ArtifactId, Sha256,
              CheckHashes, MovedPath, MatchMethod) then
            begin
              ResolvedPath := MovedPath;
              IntegrityStatus := 'resolved_moved';
              FillChar(Link, SizeOf(Link), 0);
              Link.Kind := 'artifact';
              Link.AppName := AppName;
              Link.ProjectId := ProjectId;
              Link.RevisionId := RevisionId;
              Link.TargetId := ArtifactId;
              Link.ExpectedPath := FullPath;
              Link.ResolvedPath := MovedPath;
              Link.ExpectedSha256 := Sha256;
              Link.Status := MatchMethod;
              Link.Detail := 'Arquivo movido localizado (' + MatchMethod + '); requer atualizacao pelo aplicativo responsavel.';
              AddMissingLink(Prod, Link);
            end
            else
            begin
              IntegrityStatus := 'missing';
              FillChar(Link, SizeOf(Link), 0);
              Link.Kind := 'artifact';
              Link.AppName := AppName;
              Link.ProjectId := ProjectId;
              Link.RevisionId := RevisionId;
              Link.TargetId := ArtifactId;
              Link.ExpectedPath := FullPath;
              Link.ExpectedSha256 := Sha256;
              Link.Status := 'missing';
              Link.Detail := 'Arquivo ausente: ' + Uri;
              AddMissingLink(Prod, Link);
            end;
          end;
        end;

        ArtCount := Length(Prod.Artifacts);
        SetLength(Prod.Artifacts, ArtCount + 1);
        Prod.Artifacts[ArtCount] := Prod.Projects[I].Revisions[J].Artifacts[K];
      end;
    end;
  end;
end;

function LoadProduction(const RootOrJsonPath: string; CheckFileHashes: Boolean;
  out Prod: TMmpProduction): Boolean;
var
  InputPath, JsonPath, RootDir, ExpectedPath, FoundPath, RelinkTarget: string;
  ProdObj, ActiveObj, AppEntry, RelinkObj, OverridesObj: TJSONObject;
  ExpectedIds: array[0..6] of string;
  I, N: Integer;
  Proj: TMmpProjectRef;
  Link: TMmpMissingLink;
  SR: TSearchRec;
  SceneProjPath, ScenesDir: string;
begin
  InputPath := RootOrJsonPath;
  Result := False;
  FillChar(Prod, SizeOf(Prod), 0);

  if DirectoryExists(InputPath) then
  begin
    RootDir := ExcludeTrailingPathDelimiter(ExpandFileName(InputPath));
    JsonPath := RootDir + PathDelim + 'production.json';
  end
  else if SameText(ExtractFileName(InputPath), MMP_DB_FILENAME) then
  begin
    RootDir := ExtractFileDir(ExpandFileName(InputPath));
    JsonPath := RootDir + PathDelim + 'production.json';
  end
  else
  begin
    JsonPath := ExpandFileName(InputPath);
    RootDir := ExtractFileDir(JsonPath);
  end;

  Prod.RootDir := RootDir;
  Prod.ProductionJsonPath := JsonPath;
  Prod.DbPath := MmpProductionDbPath(RootDir);

  if not FileExists(JsonPath) then
  begin
    Prod.ErrorMessage := 'production.json nao encontrado em: ' + RootDir;
    Prod.OverallStatusText := 'Producao nao encontrada';
    Exit;
  end;

  if not ParseJsonFile(JsonPath, ProdObj) then
  begin
    Prod.ErrorMessage := 'Falha ao interpretar production.json.';
    Prod.OverallStatusText := 'production.json invalido';
    Exit;
  end;

  try
    Prod.Schema := ProdObj.Get('schema', '');
    Prod.ProductionId := ProdObj.Get('production_id', '');
    Prod.Title := ProdObj.Get('title', '');
    Prod.CreatedAt := ProdObj.Get('created_at', '');
    if Prod.Title = '' then
      Prod.Title := ExtractFileName(RootDir);

    if (Prod.ProductionId = '') or
       ((Prod.Schema <> '') and (Prod.Schema <> MMP_PRODUCTION_SCHEMA)) then
    begin
      Prod.ErrorMessage := 'production.json invalido: schema "' + Prod.Schema +
        '" ou production_id ausente.';
      Prod.OverallStatusText := 'Producao corrompida/invalida';
      Exit;
    end;

    for I := 0 to 6 do
      ExpectedIds[I] := '';

    if ProdObj.Find('active_projects') is TJSONObject then
    begin
      ActiveObj := TJSONObject(ProdObj.Find('active_projects'));
      for I := 0 to 6 do
      begin
        if ActiveObj.Find(MmpAppNames[I]) is TJSONObject then
        begin
          AppEntry := TJSONObject(ActiveObj.Find(MmpAppNames[I]));
          ExpectedIds[I] := AppEntry.Get('project_id', '');
        end;
      end;
    end;
  finally
    ProdObj.Free;
  end;

  RelinkObj := LoadRelinkOverrides(RootDir);
  OverridesObj := nil;
  if (RelinkObj <> nil) and (RelinkObj.Find('overrides') is TJSONObject) then
    OverridesObj := TJSONObject(RelinkObj.Find('overrides'));

  try
    for I := 0 to 6 do
    begin
      ExpectedPath := RootDir + PathDelim + 'projects' + PathDelim +
        MmpAppFolders[I] + PathDelim + 'project.json';
      RelinkTarget := '';

      if OverridesObj <> nil then
      begin
        RelinkTarget := OverridesObj.Get(MmpAppNames[I], '');
        if (RelinkTarget = '') and (ExpectedIds[I] <> '') then
          RelinkTarget := OverridesObj.Get(ExpectedIds[I], '');
        if RelinkTarget <> '' then
        begin
          if not FileExists(RelinkTarget) then
            ResolveSafePath(RootDir, RelinkTarget, RelinkTarget);
        end;
      end;

      if (RelinkTarget <> '') and FileExists(RelinkTarget) then
        LoadProjectRecord(RootDir, RelinkTarget, I, ExpectedIds[I], '', True, Proj)
      else if FileExists(ExpectedPath) then
        LoadProjectRecord(RootDir, ExpectedPath, I, ExpectedIds[I], '', False, Proj)
      else if (ExpectedIds[I] <> '') and
        FindProjectFileById(RootDir + PathDelim + 'projects', ExpectedIds[I], FoundPath) then
      begin
        LoadProjectRecord(RootDir, FoundPath, I, ExpectedIds[I], '', False, Proj);
        Proj.IntegrityMessage := 'Localizado por ID em caminho diferente do padrao.';
        FillChar(Link, SizeOf(Link), 0);
        Link.Kind := 'project';
        Link.AppName := MmpAppNames[I];
        Link.ProjectId := ExpectedIds[I];
        Link.ExpectedPath := ExpectedPath;
        Link.ResolvedPath := FoundPath;
        Link.Status := 'resolved_by_id';
        Link.Detail := 'project.json localizado por ID em ' + FoundPath;
        AddMissingLink(Prod, Link);
      end
      else
      begin
        LoadProjectRecord(RootDir, ExpectedPath, I, ExpectedIds[I], '', False, Proj);
        FillChar(Link, SizeOf(Link), 0);
        Link.Kind := 'project';
        Link.AppName := MmpAppNames[I];
        Link.ProjectId := ExpectedIds[I];
        Link.TargetId := ExpectedIds[I];
        Link.ExpectedPath := ExpectedPath;
        Link.Status := 'missing';
        Link.Detail := 'project.json ausente para ' + MmpAppNames[I] + '. Use Revincular ou verifique a pasta.';
        AddMissingLink(Prod, Link);
      end;

      N := Length(Prod.Projects);
      SetLength(Prod.Projects, N + 1);
      Prod.Projects[N] := Proj;
    end;
  finally
    if RelinkObj <> nil then
      RelinkObj.Free;
  end;

  // Scan per-scene MScene projects in projects/05-mscene/scenes/<scene_id>/project.json
  ScenesDir := RootDir + PathDelim + 'projects' + PathDelim +
    MmpAppFolders[5] + PathDelim + 'scenes';
  if DirectoryExists(ScenesDir) then
  begin
    if FindFirst(ScenesDir + PathDelim + '*', faDirectory, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name = '.') or (SR.Name = '..') then Continue;
          if (SR.Attr and faDirectory) = 0 then Continue;
          SceneProjPath := ScenesDir + PathDelim + SR.Name + PathDelim + 'project.json';
          if FileExists(SceneProjPath) then
          begin
            LoadProjectRecord(RootDir, SceneProjPath, 5, '', SR.Name, False, Proj);
            N := Length(Prod.Projects);
            SetLength(Prod.Projects, N + 1);
            Prod.Projects[N] := Proj;
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
  end;

  ScanSyncJobs(Prod);
  AuditSourcesAndArtifacts(Prod, CheckFileHashes);

  Prod.HasFailures := False;
  Prod.HasPendingWork := False;

  for I := 0 to High(Prod.SyncJobs) do
  begin
    if SameText(Prod.SyncJobs[I].Status, 'failed') then
      Prod.HasFailures := True
    else if not SameText(Prod.SyncJobs[I].Status, 'published') and
            not SameText(Prod.SyncJobs[I].Status, 'approved') and
            not SameText(Prod.SyncJobs[I].Status, 'complete') and
            not SameText(Prod.SyncJobs[I].Status, 'cancelled') then
      Prod.HasPendingWork := True;
  end;

  for I := 0 to High(Prod.MissingLinks) do
  begin
    if (Prod.MissingLinks[I].Status = 'missing') or
       (Prod.MissingLinks[I].Status = 'hash_mismatch') or
       (Prod.MissingLinks[I].Status = 'invalid_path') or
       (Prod.MissingLinks[I].Status = 'invalid_json') or
       (Prod.MissingLinks[I].Status = 'invalid_manifest') then
      Prod.HasFailures := True
    else
      Prod.HasPendingWork := True;
  end;

  if Prod.HasFailures then
    Prod.OverallStatusText := 'Falhas/pendencias detectadas (nao concluido)'
  else if Prod.HasPendingWork then
    Prod.OverallStatusText := 'Sincronizacao ou revisao em andamento'
  else
    Prod.OverallStatusText := 'Integro (sem falhas de vinculacao)';

  // Garante banco SQLite local (copia do template zerado caso seja projeto legado sem .db) e sincroniza estado
  MmpEnsureProductionMediaDirs(RootDir);
  if not FileExists(Prod.DbPath) then
    MmpInitProductionDbFromTemplate(RootDir, '', SceneProjPath, ScenesDir);
  MmpSyncProductionToSqlite(Prod);
  Prod.Loaded := True;

  for I := 1 to 6 do
  begin
    if MmpEvaluateStageStatus(Prod, I).NeedsAdjustment then
    begin
      Prod.HasPendingWork := True;
      if not Prod.HasFailures then
        Prod.OverallStatusText := 'Etapa(s) posterior(es) precisa(m) reajuste';
      Break;
    end;
  end;

  Result := True;
end;

function RebuildCatalog(const Prod: TMmpProduction; out ErrorMsg: string): Boolean;
var
  CatObj, PObj, AObj: TJSONObject;
  PArr, AArr: TJSONArray;
  I: Integer;
  RelPath: string;
begin
  Result := False;
  ErrorMsg := '';
  if not Prod.Loaded then
  begin
    ErrorMsg := 'Nenhuma producao carregada.';
    Exit;
  end;

  CatObj := TJSONObject.Create;
  try
    CatObj.Add('schema', MMP_CATALOG_SCHEMA);
    CatObj.Add('production_id', Prod.ProductionId);
    CatObj.Add('rebuilt_at', CurrentIsoUtc);

    PArr := TJSONArray.Create;
    for I := 0 to High(Prod.Projects) do
    begin
      PObj := TJSONObject.Create;
      PObj.Add('application', Prod.Projects[I].AppName);
      PObj.Add('project_id', Prod.Projects[I].ProjectId);
      if Prod.Projects[I].SceneId <> '' then
        PObj.Add('scene_id', Prod.Projects[I].SceneId);
      PObj.Add('active_revision', Prod.Projects[I].ActiveRevision);
      PObj.Add('status', Prod.Projects[I].Status);
      RelPath := NormalizeRelPath(ExtractRelativepath(
        IncludeTrailingPathDelimiter(Prod.RootDir), Prod.Projects[I].ProjectFilePath));
      PObj.Add('project_path', RelPath);
      PObj.Add('exists_on_disk', Prod.Projects[I].ExistsOnDisk);
      PArr.Add(PObj);
    end;
    CatObj.Add('projects', PArr);

    AArr := TJSONArray.Create;
    for I := 0 to High(Prod.Artifacts) do
    begin
      AObj := TJSONObject.Create;
      AObj.Add('artifact_id', Prod.Artifacts[I].ArtifactId);
      AObj.Add('application', Prod.Artifacts[I].AppName);
      AObj.Add('project_id', Prod.Artifacts[I].ProjectId);
      AObj.Add('revision_id', Prod.Artifacts[I].RevisionId);
      AObj.Add('kind', Prod.Artifacts[I].Kind);
      AObj.Add('scene_id', Prod.Artifacts[I].SceneId);
      AObj.Add('segment_id', Prod.Artifacts[I].SegmentId);
      AObj.Add('uri', Prod.Artifacts[I].Uri);
      AObj.Add('sha256', Prod.Artifacts[I].Sha256);
      AObj.Add('bytes', Prod.Artifacts[I].Bytes);
      AObj.Add('status', Prod.Artifacts[I].Status);
      AObj.Add('integrity_status', Prod.Artifacts[I].IntegrityStatus);
      AArr.Add(AObj);
    end;
    CatObj.Add('artifacts', AArr);

    Result := AtomicWriteTextFile(Prod.RootDir + PathDelim + 'catalog.json',
      CatObj.FormatJSON, True);
    if not Result then
      ErrorMsg := 'Falha ao gravar catalog.json.';
  finally
    CatObj.Free;
  end;
end;

function FindProductionByIdInDir(const SearchDir, ExpectedProductionId: string;
  out FoundRootDir: string): Boolean;
var
  SR: TSearchRec;
  SubDir, JsonPath: string;
  Obj: TJSONObject;
begin
  Result := False;
  FoundRootDir := '';
  if not DirectoryExists(SearchDir) then Exit;

  JsonPath := IncludeTrailingPathDelimiter(SearchDir) + 'production.json';
  if FileExists(JsonPath) and ParseJsonFile(JsonPath, Obj) then
  begin
    try
      if SameText(Obj.Get('production_id', ''), ExpectedProductionId) then
      begin
        FoundRootDir := ExcludeTrailingPathDelimiter(ExpandFileName(SearchDir));
        Exit(True);
      end;
    finally
      Obj.Free;
    end;
  end;

  if FindFirst(IncludeTrailingPathDelimiter(SearchDir) + '*', faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) = 0 then Continue;
        SubDir := IncludeTrailingPathDelimiter(SearchDir) + SR.Name;
        JsonPath := SubDir + PathDelim + 'production.json';
        if FileExists(JsonPath) and ParseJsonFile(JsonPath, Obj) then
        begin
          try
            if SameText(Obj.Get('production_id', ''), ExpectedProductionId) then
            begin
              FoundRootDir := ExcludeTrailingPathDelimiter(ExpandFileName(SubDir));
              Exit(True);
            end;
          finally
            Obj.Free;
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure BuildLaunchArgs(const RootDir, ProjectId, RevisionId: string;
  Args: TStrings; const ProductionId: string);
begin
  Args.Clear;
  Args.Add('--launcher');
  Args.Add('mmenu');
  Args.Add('--mmenu-version');
  Args.Add(MAURINMOVIE_VERSION);
  if RootDir <> '' then
  begin
    Args.Add('--production');
    Args.Add(RootDir);
  end;
  if ProductionId <> '' then
  begin
    Args.Add('--production-id');
    Args.Add(ProductionId);
  end;
  if ProjectId <> '' then
  begin
    Args.Add('--project-id');
    Args.Add(ProjectId);
  end;
  if RevisionId <> '' then
  begin
    Args.Add('--revision');
    Args.Add(RevisionId);
  end;
end;

function SaveArtifactRelinkToCatalog(const RootDir, ArtifactId, OldUri,
  NewFilePath, ExpectedSha256: string; out ErrorMsg: string): Boolean;
var
  CatPath, ActualSha, RelUri: string;
  CatObj, EntryObj: TJSONObject;
  RelinksArr: TJSONArray;
begin
  Result := False;
  ErrorMsg := '';
  if not FileExists(NewFilePath) then
  begin
    ErrorMsg := 'Arquivo selecionado nao existe.';
    Exit;
  end;

  ActualSha := SHA256File(NewFilePath);
  if (ExpectedSha256 <> '') and not SameText(ActualSha, ExpectedSha256) then
  begin
    ErrorMsg := 'Arquivo diferente do registrado (hash SHA-256 divergente). Revinculacao recusada.';
    Exit;
  end;

  CatPath := IncludeTrailingPathDelimiter(RootDir) + 'catalog.json';
  if not ParseJsonFile(CatPath, CatObj) then
  begin
    CatObj := TJSONObject.Create;
    CatObj.Add('schema', MMP_CATALOG_SCHEMA);
    CatObj.Add('projects', TJSONArray.Create);
    CatObj.Add('artifacts', TJSONArray.Create);
  end;
  try
    if CatObj.Find('relinks') is TJSONArray then
      RelinksArr := TJSONArray(CatObj.Find('relinks'))
    else
    begin
      RelinksArr := TJSONArray.Create;
      CatObj.Add('relinks', RelinksArr);
    end;

    RelUri := NormalizeRelPath(ExtractRelativepath(IncludeTrailingPathDelimiter(RootDir), NewFilePath));
    if not IsSafeRelativePath(RelUri) then RelUri := NewFilePath;

    EntryObj := TJSONObject.Create;
    EntryObj.Add('artifact_id', ArtifactId);
    EntryObj.Add('old_uri', OldUri);
    EntryObj.Add('new_uri', RelUri);
    EntryObj.Add('sha256_verified', ExpectedSha256 <> '');
    EntryObj.Add('at', CurrentIsoUtc);
    RelinksArr.Add(EntryObj);

    Result := AtomicWriteTextFile(CatPath, CatObj.FormatJSON, True);
    if not Result then
      ErrorMsg := 'Falha ao gravar catalog.json.';
  finally
    CatObj.Free;
  end;
end;

function CancelSyncTransaction(const JobFilePath: string; out ErrorMsg: string): Boolean;
var
  Obj: TJSONObject;
begin
  Result := False;
  ErrorMsg := '';
  if not ParseJsonFile(JobFilePath, Obj) then
  begin
    ErrorMsg := 'Nao foi possivel abrir arquivo da transacao/evento.';
    Exit;
  end;
  try
    if Obj.IndexOfName('status') >= 0 then
      Obj.Strings['status'] := 'cancelled'
    else
      Obj.Add('status', 'cancelled');
    if Obj.IndexOfName('updated_at') >= 0 then
      Obj.Strings['updated_at'] := CurrentIsoUtc
    else
      Obj.Add('updated_at', CurrentIsoUtc);
    Result := AtomicWriteTextFile(JobFilePath, Obj.FormatJSON, True);
    if not Result then
      ErrorMsg := 'Falha ao atualizar status da transacao.';
  finally
    Obj.Free;
  end;
end;

function IsProjectLocked(const ProjectDir: string; out LockInfo: string): Boolean;
var
  LockPath: string;
  Obj: TJSONObject;
begin
  Result := False;
  LockInfo := '';
  LockPath := IncludeTrailingPathDelimiter(ProjectDir) + '.lock';
  if not FileExists(LockPath) then Exit;
  Result := True;
  if ParseJsonFile(LockPath, Obj) then
  begin
    try
      LockInfo := Format('%s (PID %s, %s)',
        [Obj.Get('application', ''), Obj.Get('pid', '?'), Obj.Get('started_at', '')]);
    finally
      Obj.Free;
    end;
  end
  else
    LockInfo := LockPath;
end;

function AcquireProjectLock(const ProjectDir, AppName, Mode: string;
  out ErrorMsg: string): Boolean;
var
  LockPath: string;
  Obj: TJSONObject;
begin
  Result := False;
  ErrorMsg := '';
  LockPath := IncludeTrailingPathDelimiter(ProjectDir) + '.lock';
  if FileExists(LockPath) then
  begin
    ErrorMsg := 'Projeto ja possui lock ativo: ' + LockPath;
    Exit;
  end;
  Obj := TJSONObject.Create;
  try
    Obj.Add('pid', IntToStr(GetProcessID));
    Obj.Add('host', GetEnvironmentVariable('COMPUTERNAME'));
    Obj.Add('application', AppName);
    Obj.Add('mode', Mode);
    Obj.Add('started_at', CurrentIsoUtc);
    Result := AtomicWriteTextFile(LockPath, Obj.FormatJSON, False);
    if not Result then
      ErrorMsg := 'Nao foi possivel criar .lock do projeto.';
  finally
    Obj.Free;
  end;
end;

procedure ReleaseProjectLock(const ProjectDir: string);
var
  LockPath: string;
begin
  LockPath := IncludeTrailingPathDelimiter(ProjectDir) + '.lock';
  if FileExists(LockPath) then
    DeleteFile(LockPath);
end;

procedure AppendJsonLogLine(const ProdRoot, AppName, Level, Msg: string);
var
  LogDir, LogFile, Line, DbTarget: string;
  Obj: TJSONObject;
  FS: TFileStream;
begin
  // Grava sempre no banco SQLite centralizado (da producao ou global do MMenu)
  if Trim(ProdRoot) <> '' then
  begin
    DbTarget := MmpProductionDbPath(ProdRoot);
    if FileExists(DbTarget) then
      MmpDbAddCentralLog(DbTarget, '', Level, AppName, '', '', '', Msg, '');
  end
  else
    MmpDbAddCentralLog(MmpGlobalCentralLogDbPath, '', Level, AppName, '', '', '', Msg, '');

  if (ProdRoot = '') or not DirectoryExists(ProdRoot) then Exit;
  LogDir := IncludeTrailingPathDelimiter(ProdRoot) + 'shared' + PathDelim +
    'logs' + PathDelim + LowerCase(AppName);
  ForceDirectories(LogDir);
  LogFile := LogDir + PathDelim + FormatDateTime('yyyy-mm-dd', Now) + '.jsonl';

  Obj := TJSONObject.Create;
  try
    Obj.Add('ts', CurrentIsoUtc);
    Obj.Add('level', Level);
    Obj.Add('app', AppName);
    Obj.Add('pid', IntToStr(GetProcessID));
    Obj.Add('msg', Msg);
    Line := Obj.AsJSON + LineEnding;
  finally
    Obj.Free;
  end;

  try
    if FileExists(LogFile) then
      FS := TFileStream.Create(LogFile, fmOpenReadWrite or fmShareDenyNone)
    else
      FS := TFileStream.Create(LogFile, fmCreate);
    try
      FS.Seek(0, soFromEnd);
      if Length(Line) > 0 then
        FS.WriteBuffer(Line[1], Length(Line));
    finally
      FS.Free;
    end;
  except
    // Logging must never crash caller
  end;
end;

function MmpProjectHasActivity(const Proj: TMmpProjectRef): Boolean;
var
  I: Integer;
begin
  if Proj.SoftwareIndex = 0 then
    Exit(True); // Registro principal da producao (MMenu): sempre 1 registro ao criar
  if (Proj.Status <> '') and (not SameText(Proj.Status, 'initialized')) then
    Exit(True);
  if Length(Proj.Revisions) > 1 then
    Exit(True);
  for I := 0 to High(Proj.Revisions) do
    if Length(Proj.Revisions[I].Artifacts) > 0 then
      Exit(True);
  Result := False;
end;

procedure MmpSyncProductionToSqlite(const Prod: TMmpProduction);
var
  I, J, K: Integer;
  ErrMsg, RelMedia: string;
  DbProj: TMmpDbProjectRow;
  DbRev: TMmpDbRevisionRow;
  DbSrcs: array of TMmpDbSourceRow;
  DbArt: TMmpDbMediaAssetRow;
  DbSync: TMmpDbSyncJobRow;
begin
  if (Trim(Prod.RootDir) = '') or (Trim(Prod.ProductionId) = '') then Exit;
  if not FileExists(MmpProductionDbPath(Prod.RootDir)) then Exit;

  MmpDbUpsertProduction(Prod.RootDir, Prod.ProductionId, Prod.Title,
    SlugifyTitle(Prod.Title), Prod.Title, 'pt-BR',
    Prod.OverallStatusText, Prod.CreatedAt, CurrentIsoUtc, '', ErrMsg);

  for I := 0 to High(Prod.Projects) do
  begin
    FillChar(DbProj, SizeOf(DbProj), 0);
    DbProj.ProjectId := Prod.Projects[I].ProjectId;
    DbProj.ProductionId := Prod.ProductionId;
    DbProj.SoftwareIndex := Prod.Projects[I].SoftwareIndex;
    DbProj.AppName := Prod.Projects[I].AppName;
    DbProj.SceneId := Prod.Projects[I].SceneId;
    DbProj.NameBase := Prod.Title;
    DbProj.ActiveRevision := Prod.Projects[I].ActiveRevision;
    DbProj.Status := Prod.Projects[I].Status;
    DbProj.CreatedAt := Prod.Projects[I].CreatedAt;
    DbProj.UpdatedAt := Prod.Projects[I].UpdatedAt;
    if Prod.Projects[I].ProjectFilePath <> '' then
      DbProj.ProjectFilePath := NormalizeRelPath(ExtractRelativepath(
        IncludeTrailingPathDelimiter(Prod.RootDir), Prod.Projects[I].ProjectFilePath));
    if DbProj.ProjectId <> '' then
      MmpDbUpsertProject(Prod.RootDir, DbProj, ErrMsg);

    for J := 0 to High(Prod.Projects[I].Revisions) do
    begin
      FillChar(DbRev, SizeOf(DbRev), 0);
      DbRev.ProjectId := DbProj.ProjectId;
      DbRev.RevisionId := Prod.Projects[I].Revisions[J].RevisionId;
      DbRev.ParentRevisionId := Prod.Projects[I].Revisions[J].ParentRevisionId;
      DbRev.State := Prod.Projects[I].Revisions[J].State;
      DbRev.RevLabel := FormatRevisionLabel(Prod.Title, AppIndexToEnum(DbProj.SoftwareIndex), DbRev.RevisionId);
      if Prod.Projects[I].Revisions[J].ManifestPath <> '' then
        DbRev.ManifestPath := NormalizeRelPath(ExtractRelativepath(
          IncludeTrailingPathDelimiter(Prod.RootDir), Prod.Projects[I].Revisions[J].ManifestPath));
      DbRev.ManifestSha256 := Prod.Projects[I].Revisions[J].ManifestSha256;
      DbRev.CreatedAt := Prod.Projects[I].Revisions[J].CreatedAt;
      MmpDbUpsertRevision(Prod.RootDir, Prod.ProductionId, DbRev, ErrMsg);

      SetLength(DbSrcs, Length(Prod.Projects[I].Revisions[J].Sources));
      for K := 0 to High(Prod.Projects[I].Revisions[J].Sources) do
      begin
        DbSrcs[K].ProjectId := DbProj.ProjectId;
        DbSrcs[K].RevisionId := DbRev.RevisionId;
        DbSrcs[K].SourceProjectId := Prod.Projects[I].Revisions[J].Sources[K].ProjectId;
        DbSrcs[K].SourceRevisionId := Prod.Projects[I].Revisions[J].Sources[K].RevisionId;
        DbSrcs[K].SourceManifestSha256 := Prod.Projects[I].Revisions[J].Sources[K].ManifestSha256;
      end;
      MmpDbReplaceRevisionSources(Prod.RootDir, DbProj.ProjectId, DbRev.RevisionId, DbSrcs, ErrMsg);

      for K := 0 to High(Prod.Projects[I].Revisions[J].Artifacts) do
      begin
        FillChar(DbArt, SizeOf(DbArt), 0);
        DbArt.ArtifactId := Prod.Projects[I].Revisions[J].Artifacts[K].ArtifactId;
        DbArt.ProductionId := Prod.ProductionId;
        DbArt.ProjectId := DbProj.ProjectId;
        DbArt.RevisionId := DbRev.RevisionId;
        DbArt.AppName := DbProj.AppName;
        DbArt.Kind := Prod.Projects[I].Revisions[J].Artifacts[K].Kind;
        DbArt.MimeType := Prod.Projects[I].Revisions[J].Artifacts[K].MimeType;
        DbArt.LegacyUri := Prod.Projects[I].Revisions[J].Artifacts[K].Uri;
        DbArt.MediaCategory := MmpDetectMediaCategory(DbArt.Kind, DbArt.MimeType, DbArt.LegacyUri);
        DbArt.SceneId := Prod.Projects[I].Revisions[J].Artifacts[K].SceneId;
        DbArt.SegmentId := Prod.Projects[I].Revisions[J].Artifacts[K].SegmentId;
        DbArt.Sha256 := Prod.Projects[I].Revisions[J].Artifacts[K].Sha256;
        DbArt.Bytes := Prod.Projects[I].Revisions[J].Artifacts[K].Bytes;
        DbArt.Status := Prod.Projects[I].Revisions[J].Artifacts[K].Status;
        DbArt.CreatedAt := DbRev.CreatedAt;

        RelMedia := DbArt.LegacyUri;
        if (DbArt.MediaCategory <> 'other') and
           (Prod.Projects[I].Revisions[J].Artifacts[K].ResolvedPath <> '') and
           FileExists(Prod.Projects[I].Revisions[J].Artifacts[K].ResolvedPath) then
        begin
          MmpEnsureAssetStoredInMediaDir(
            Prod.RootDir,
            Prod.Projects[I].Revisions[J].Artifacts[K].ResolvedPath,
            DbArt.AppName, DbArt.SceneId, DbRev.RevisionId,
            DbArt.Kind, DbArt.MimeType, DbArt.LegacyUri, RelMedia);
        end;
        DbArt.RelativePath := RelMedia;
        if DbArt.ArtifactId <> '' then
          MmpDbUpsertMediaAsset(Prod.RootDir, DbArt, ErrMsg);
      end;
    end;
  end;

  for I := 0 to High(Prod.SyncJobs) do
  begin
    FillChar(DbSync, SizeOf(DbSync), 0);
    DbSync.EventId := Prod.SyncJobs[I].EventId;
    DbSync.TransactionId := Prod.SyncJobs[I].TransactionId;
    DbSync.ProductionId := Prod.ProductionId;
    DbSync.OriginApp := Prod.SyncJobs[I].OriginApp;
    DbSync.TargetApp := Prod.SyncJobs[I].TargetApp;
    DbSync.ProjectId := Prod.SyncJobs[I].ProjectId;
    DbSync.SourceRevision := Prod.SyncJobs[I].SourceRevision;
    DbSync.RequestedChange := Prod.SyncJobs[I].RequestedChange;
    DbSync.Stage := Prod.SyncJobs[I].Stage;
    DbSync.Status := Prod.SyncJobs[I].Status;
    DbSync.ErrorText := Prod.SyncJobs[I].ErrorText;
    DbSync.CreatedAt := Prod.SyncJobs[I].CreatedAt;
    DbSync.UpdatedAt := CurrentIsoUtc;
    DbSync.SourceFile := Prod.SyncJobs[I].SourceFile;
    if DbSync.EventId <> '' then
      MmpDbUpsertSyncJob(Prod.RootDir, DbSync, ErrMsg);
  end;
end;

function FindProjByAppIdx(const Prod: TMmpProduction; AppIdx: Integer;
  out Proj: TMmpProjectRef): Boolean;
var
  I: Integer;
begin
  Result := False;
  FillChar(Proj, SizeOf(Proj), 0);
  for I := 0 to High(Prod.Projects) do
    if (Prod.Projects[I].SoftwareIndex = AppIdx) and (Prod.Projects[I].SceneId = '') then
    begin
      Proj := Prod.Projects[I];
      Exit(True);
    end;
  for I := 0 to High(Prod.Projects) do
    if Prod.Projects[I].SoftwareIndex = AppIdx then
    begin
      Proj := Prod.Projects[I];
      Exit(True);
    end;
end;

function FindRevShaInProj(const Proj: TMmpProjectRef; const RevId: string): string;
var
  R: Integer;
begin
  Result := '';
  for R := 0 to High(Proj.Revisions) do
    if SameText(Proj.Revisions[R].RevisionId, RevId) then
      Exit(Proj.Revisions[R].ManifestSha256);
end;

function MmpEvaluateStageStatus(const Prod: TMmpProduction; AppIdx: Integer): TMmpStageStatus;
var
  Proj, UpProj: TMmpProjectRef;
  K, R, S: Integer;
  ActiveRevInfo: TMmpRevisionInfo;
  HasAppRev, FoundInSources: Boolean;
  UpSha: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.AppIndex := AppIdx;
  if (not Prod.Loaded) or (AppIdx < 1) or (AppIdx > 6) then
  begin
    Result.CanOpen := False;
    Result.StatusText := 'sem producao';
    Exit;
  end;

  if not FindProjByAppIdx(Prod, AppIdx, Proj) then
  begin
    Result.CanOpen := False;
    Result.StatusText := 'projeto ausente';
    Result.MissingPrereqs := 'Projeto nao encontrado na producao';
    Exit;
  end;

  Result.HasActivity := MmpProjectHasActivity(Proj);
  Result.ActiveRevision := Proj.ActiveRevision;
  Result.StatusText := Proj.Status;

  for K := 1 to AppIdx - 1 do
  begin
    if not FindProjByAppIdx(Prod, K, UpProj) or (not MmpProjectHasActivity(UpProj)) then
    begin
      if Result.MissingPrereqs <> '' then
        Result.MissingPrereqs := Result.MissingPrereqs + ', ';
      Result.MissingPrereqs := Result.MissingPrereqs + IntToStr(K) + ' - ' + MmpAppNames[K];
    end;
  end;

  Result.CanOpen := (Result.MissingPrereqs = '');
  if not Result.CanOpen then Exit;

  if not Result.HasActivity then Exit;

  HasAppRev := False;
  FillChar(ActiveRevInfo, SizeOf(ActiveRevInfo), 0);
  for R := 0 to High(Proj.Revisions) do
    if SameText(Proj.Revisions[R].RevisionId, Proj.ActiveRevision) then
    begin
      ActiveRevInfo := Proj.Revisions[R];
      HasAppRev := True;
      Break;
    end;

  for K := 1 to AppIdx - 1 do
  begin
    if not FindProjByAppIdx(Prod, K, UpProj) then Continue;
    FoundInSources := False;
    if HasAppRev then
    begin
      for S := 0 to High(ActiveRevInfo.Sources) do
      begin
        if SameText(ActiveRevInfo.Sources[S].ProjectId, UpProj.ProjectId) then
        begin
          FoundInSources := True;
          if (UpProj.ActiveRevision <> '') and
             (not SameText(ActiveRevInfo.Sources[S].RevisionId, UpProj.ActiveRevision)) then
          begin
            Result.NeedsAdjustment := True;
            Result.StaleReason := MmpAppNames[K] + ' refeito (' +
              ActiveRevInfo.Sources[S].RevisionId + ' -> ' + UpProj.ActiveRevision + ')';
            Exit;
          end;
          UpSha := FindRevShaInProj(UpProj, UpProj.ActiveRevision);
          if (UpSha <> '') and (ActiveRevInfo.Sources[S].ManifestSha256 <> '') and
             (not SameText(ActiveRevInfo.Sources[S].ManifestSha256, UpSha)) then
          begin
            Result.NeedsAdjustment := True;
            Result.StaleReason := MmpAppNames[K] + ' alterado em ' + UpProj.ActiveRevision;
            Exit;
          end;
        end;
      end;
    end;

    if (not FoundInSources) and (UpProj.UpdatedAt <> '') and (Proj.UpdatedAt <> '') and
       (UpProj.UpdatedAt > Proj.UpdatedAt) then
    begin
      Result.NeedsAdjustment := True;
      Result.StaleReason := MmpAppNames[K] + ' atualizado apos ' + MmpAppNames[AppIdx];
      Exit;
    end;
  end;
end;

procedure AppendHistoryEntry(var Arr: TMmpHistoryEntryArray;
  const Timestamp, AppName, Kind, RevisionId, State, Summary, Details: string);
var
  N: Integer;
begin
  N := Length(Arr);
  SetLength(Arr, N + 1);
  Arr[N].Timestamp := Timestamp;
  Arr[N].AppName := AppName;
  Arr[N].Kind := Kind;
  Arr[N].RevisionId := RevisionId;
  Arr[N].State := State;
  Arr[N].Summary := Summary;
  Arr[N].Details := Details;
end;

function FindRoteiroPathInRev(const Proj: TMmpProjectRef;
  const Rev: TMmpRevisionInfo): string;
var
  A: Integer;
  RevDir, Candidate: string;
begin
  Result := '';
  for A := 0 to High(Rev.Artifacts) do
    if Pos('roteiro.json', LowerCase(Rev.Artifacts[A].Uri)) > 0 then
      if (Rev.Artifacts[A].ResolvedPath <> '') and FileExists(Rev.Artifacts[A].ResolvedPath) then
        Exit(Rev.Artifacts[A].ResolvedPath);
  if Rev.ManifestPath <> '' then
  begin
    RevDir := ExtractFilePath(Rev.ManifestPath);
    Candidate := RevDir + 'scripts' + PathDelim + 'roteiro.json';
    if FileExists(Candidate) then Exit(Candidate);
    Candidate := RevDir + 'roteiro.json';
    if FileExists(Candidate) then Exit(Candidate);
  end;
  if Proj.ProjectFilePath <> '' then
  begin
    RevDir := IncludeTrailingPathDelimiter(ExtractFilePath(Proj.ProjectFilePath)) +
      'revisions' + PathDelim + Rev.RevisionId + PathDelim;
    Candidate := RevDir + 'scripts' + PathDelim + 'roteiro.json';
    if FileExists(Candidate) then Exit(Candidate);
  end;
end;

procedure BuildRevisionHistoryEntry(const Proj: TMmpProjectRef;
  const Rev: TMmpRevisionInfo; out Entry: TMmpHistoryEntry);
var
  VerNum, A, ScenesCnt, CharsCnt, DurSec: Integer;
  RotPath, RotTitle, RotGenre, RotSynopsis, DurStr, ArtNames: string;
  RotObj: TJSONObject;
  ArrData: TJSONData;
  Dtl: TStringList;
begin
  Entry.Timestamp := Rev.CreatedAt;
  if Entry.Timestamp = '' then Entry.Timestamp := Proj.UpdatedAt;
  Entry.AppName := Proj.AppName;
  Entry.Kind := 'Revisao';
  Entry.RevisionId := Rev.RevisionId;
  Entry.State := Rev.State;
  VerNum := RevisionVersionNumber(Rev.RevisionId);

  ArtNames := '';
  for A := 0 to High(Rev.Artifacts) do
  begin
    if ArtNames <> '' then ArtNames := ArtNames + ', ';
    ArtNames := ArtNames + Rev.Artifacts[A].Kind + ' (' + ExtractFileName(Rev.Artifacts[A].Uri) + ')';
  end;

  Dtl := TStringList.Create;
  try
    Dtl.Add('Etapa: ' + Proj.AppName + ' (' + Proj.ProjectId + ')');
    Dtl.Add('Revisao: ' + Rev.RevisionId + ' (Versao ' + IntToStr(VerNum) + ') | Estado: ' + Rev.State);
    if Rev.ParentRevisionId <> '' then Dtl.Add('Revisao anterior: ' + Rev.ParentRevisionId);
    if Rev.CreatedAt <> '' then Dtl.Add('Data/Hora: ' + Rev.CreatedAt);
    Dtl.Add('Artefatos: ' + IntToStr(Length(Rev.Artifacts)));
    if ArtNames <> '' then Dtl.Add('Lista: ' + ArtNames);

    if SameText(Proj.AppName, 'MScript') then
    begin
      RotPath := FindRoteiroPathInRev(Proj, Rev);
      if (RotPath <> '') and ParseJsonFile(RotPath, RotObj) then
      try
        RotTitle := RotObj.Get('titulo', RotObj.Get('title', ''));
        RotGenre := RotObj.Get('genero', RotObj.Get('genre', ''));
        DurSec := RotObj.Get('duracao_alvo', RotObj.Get('duration_sec', 0));
        RotSynopsis := RotObj.Get('sinopse', RotObj.Get('synopsis', ''));
        ScenesCnt := 0;
        ArrData := RotObj.Find('cenas');
        if ArrData = nil then ArrData := RotObj.Find('scenes');
        if ArrData is TJSONArray then ScenesCnt := TJSONArray(ArrData).Count;
        CharsCnt := 0;
        ArrData := RotObj.Find('personagens');
        if ArrData = nil then ArrData := RotObj.Find('characters');
        if ArrData is TJSONArray then CharsCnt := TJSONArray(ArrData).Count;

        DurStr := MmpFormatDurationHms(DurSec);
        Entry.Summary := 'Versao ' + IntToStr(VerNum) + ': "' + RotTitle + '"';
        if RotGenre <> '' then Entry.Summary := Entry.Summary + ' [' + RotGenre + ']';
        Entry.Summary := Entry.Summary + ' - ' + IntToStr(ScenesCnt) + ' cena(s), ' +
          IntToStr(CharsCnt) + ' personagem(ns), duracao ' + DurStr;

        Dtl.Add('');
        Dtl.Add('--- Dados do Roteiro ---');
        if RotTitle <> '' then Dtl.Add('Titulo: ' + RotTitle);
        if RotGenre <> '' then Dtl.Add('Genero: ' + RotGenre);
        Dtl.Add('Duracao-alvo: ' + DurStr);
        Dtl.Add('Cenas: ' + IntToStr(ScenesCnt) + ' | Personagens: ' + IntToStr(CharsCnt));
        if Trim(RotSynopsis) <> '' then
        begin
          Dtl.Add('Sinopse:');
          Dtl.Add(Trim(RotSynopsis));
        end;
      finally
        RotObj.Free;
      end
      else
        Entry.Summary := 'Versao ' + IntToStr(VerNum) + ' publicada (' +
          IntToStr(Length(Rev.Artifacts)) + ' artefato(s))';
    end
    else
    begin
      Entry.Summary := 'Versao ' + IntToStr(VerNum) + ' (' + Rev.RevisionId + ') - ' +
        IntToStr(Length(Rev.Artifacts)) + ' artefato(s)';
      if ArtNames <> '' then Entry.Summary := Entry.Summary + ': ' + ArtNames;
    end;

    Entry.Details := TrimRight(Dtl.Text);
  finally
    Dtl.Free;
  end;
end;

procedure LoadLogFilesFromDir(const LogAppDir: string;
  var Entries: TMmpHistoryEntryArray);
var
  SR: TSearchRec;
  Lines: TStringList;
  I: Integer;
  FilePath, LineStr, Ts, Lvl, AppN, Pid, Msg: string;
  Data: TJSONData;
  Obj: TJSONObject;
begin
  if FindFirst(IncludeTrailingPathDelimiter(LogAppDir) + '*.jsonl', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        FilePath := IncludeTrailingPathDelimiter(LogAppDir) + SR.Name;
        Lines := TStringList.Create;
        try
          try
            Lines.LoadFromFile(FilePath);
          except
            Lines.Clear;
          end;
          for I := 0 to Lines.Count - 1 do
          begin
            LineStr := Trim(Lines[I]);
            if LineStr = '' then Continue;
            Data := nil;
            try
              Data := GetJSON(LineStr);
              if Data is TJSONObject then
              begin
                Obj := TJSONObject(Data);
                Ts := Obj.Get('ts', '');
                Lvl := Obj.Get('level', 'info');
                AppN := Obj.Get('app', ExtractFileName(ExcludeTrailingPathDelimiter(LogAppDir)));
                Pid := Obj.Get('pid', '');
                Msg := Obj.Get('msg', '');
                AppendHistoryEntry(Entries, Ts, AppN, 'Log', '-', Lvl, Msg,
                  'Timestamp: ' + Ts + LineEnding +
                  'Aplicativo: ' + AppN + ' (PID: ' + Pid + ')' + LineEnding +
                  'Nivel: ' + Lvl + LineEnding +
                  'Arquivo: ' + FilePath + LineEnding +
                  'Mensagem: ' + Msg);
              end;
            except
            end;
            Data.Free;
          end;
        finally
          Lines.Free;
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function MmpLoadProductionHistory(const Prod: TMmpProduction): TMmpHistoryEntryArray;
var
  I, R: Integer;
  Entry, Tmp: TMmpHistoryEntry;
  LogsRoot, SyncSummary, SyncDtl, DbPath: string;
  SR: TSearchRec;
  Swapped: Boolean;
  DbLogs: TMmpCentralLogArray;
begin
  SetLength(Result, 0);
  if Trim(Prod.RootDir) = '' then Exit;

  for I := 0 to High(Prod.Projects) do
  begin
    if not MmpProjectHasActivity(Prod.Projects[I]) then Continue;
    for R := 0 to High(Prod.Projects[I].Revisions) do
    begin
      if (Prod.Projects[I].Revisions[R].ParentRevisionId = '') and
         (Length(Prod.Projects[I].Revisions[R].Artifacts) = 0) and
         SameText(Prod.Projects[I].Revisions[R].RevisionId, 'r0001') and
         SameText(Prod.Projects[I].Revisions[R].State, 'draft') then
        Continue;
      BuildRevisionHistoryEntry(Prod.Projects[I], Prod.Projects[I].Revisions[R], Entry);
      AppendHistoryEntry(Result, Entry.Timestamp, Entry.AppName, Entry.Kind,
        Entry.RevisionId, Entry.State, Entry.Summary, Entry.Details);
    end;
  end;

  DbPath := MmpProductionDbPath(Prod.RootDir);
  if FileExists(DbPath) then
  begin
    DbLogs := MmpDbListCentralLogs(DbPath, '', '', '', -1, 500);
    for I := 0 to High(DbLogs) do
    begin
      SyncDtl := 'Timestamp: ' + DbLogs[I].Timestamp + LineEnding +
        'Aplicativo: ' + DbLogs[I].AppName + LineEnding +
        'Nivel: ' + DbLogs[I].Level + LineEnding +
        'Usuario: ' + DbLogs[I].UserName + LineEnding +
        'Revisao: ' + DbLogs[I].RevisionId + LineEnding +
        'Mensagem: ' + DbLogs[I].Message;
      if DbLogs[I].Details <> '' then
        SyncDtl := SyncDtl + LineEnding + 'Detalhes: ' + DbLogs[I].Details;
      if DbLogs[I].Resolved then
        SyncDtl := SyncDtl + LineEnding + 'Corrigido por ' + DbLogs[I].ResolvedBy +
          ' em ' + DbLogs[I].ResolvedAt + ': ' + DbLogs[I].ResolutionNote;
      AppendHistoryEntry(Result, DbLogs[I].Timestamp, DbLogs[I].AppName, 'Log',
        DbLogs[I].RevisionId, DbLogs[I].Level, DbLogs[I].Message, SyncDtl);
    end;
  end;

  if Length(DbLogs) = 0 then
  begin
    LogsRoot := IncludeTrailingPathDelimiter(Prod.RootDir) + 'shared' + PathDelim + 'logs';
    if DirectoryExists(LogsRoot) then
    begin
      if FindFirst(IncludeTrailingPathDelimiter(LogsRoot) + '*', faDirectory, SR) = 0 then
      try
        repeat
          if ((SR.Attr and faDirectory) <> 0) and (SR.Name <> '.') and (SR.Name <> '..') then
            LoadLogFilesFromDir(IncludeTrailingPathDelimiter(LogsRoot) + SR.Name, Result);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
  end;

  for I := 0 to High(Prod.SyncJobs) do
  begin
    SyncSummary := Prod.SyncJobs[I].OriginApp + ' -> ' + Prod.SyncJobs[I].TargetApp +
      ': ' + Prod.SyncJobs[I].RequestedChange;
    SyncDtl := 'Evento: ' + Prod.SyncJobs[I].EventId + LineEnding +
      'Origem -> Alvo: ' + Prod.SyncJobs[I].OriginApp + ' -> ' + Prod.SyncJobs[I].TargetApp + LineEnding +
      'Revisao origem: ' + Prod.SyncJobs[I].SourceRevision + LineEnding +
      'Etapa/Estado: ' + Prod.SyncJobs[I].Stage + ' / ' + Prod.SyncJobs[I].Status + LineEnding +
      'Solicitacao: ' + Prod.SyncJobs[I].RequestedChange;
    if Prod.SyncJobs[I].ErrorText <> '' then
      SyncDtl := SyncDtl + LineEnding + 'Erro: ' + Prod.SyncJobs[I].ErrorText;
    AppendHistoryEntry(Result, Prod.SyncJobs[I].CreatedAt,
      Prod.SyncJobs[I].OriginApp, 'Sincronizacao',
      Prod.SyncJobs[I].SourceRevision, Prod.SyncJobs[I].Status,
      SyncSummary, SyncDtl);
  end;

  if Length(Result) > 1 then
  begin
    repeat
      Swapped := False;
      for I := 0 to High(Result) - 1 do
      begin
        if Result[I].Timestamp < Result[I + 1].Timestamp then
        begin
          Tmp := Result[I];
          Result[I] := Result[I + 1];
          Result[I + 1] := Tmp;
          Swapped := True;
        end;
      end;
    until not Swapped;
  end;
end;

end.
