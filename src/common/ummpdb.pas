unit ummpdb;

{ Camada SQLite centralizada do MaurinMovie:
  - Banco zerado template (maurinmovie_empty.db) copiado para cada nova producao (maurinmovie.db)
  - Tabelas de producao, projetos, revisoes, fontes, ativos de midia (apontando para pastas media/),
    sincronizacoes e log centralizado com marcacao de correcao/resolucao.
  Sem dependencia LCL (compativel com testes e headless). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, sqlite3conn, sqldb, sqlite3dyn, db,
  mmpcommon, mmpsettings, ummpsha256;

const
  MMP_DB_FILENAME = 'maurinmovie.db';
  MMP_EMPTY_DB_FILENAME = 'maurinmovie_empty.db';
  MMP_GLOBAL_LOG_DB_FILENAME = 'mmenu_central_logs.db';
  MMP_DB_SCHEMA_VERSION = '2';

type
  TMmpCentralLogEntry = record
    Id: Int64;
    ProductionId: string;
    Timestamp: string;
    Level: string;
    AppName: string;
    UserName: string;
    Action: string;
    RevisionId: string;
    Message: string;
    Details: string;
    Resolved: Boolean;
    ResolvedBy: string;
    ResolvedAt: string;
    ResolutionNote: string;
  end;
  TMmpCentralLogArray = array of TMmpCentralLogEntry;

  TMmpDbProjectRow = record
    ProjectId: string;
    ProductionId: string;
    SoftwareIndex: Integer;
    AppName: string;
    SceneId: string;
    NameBase: string;
    ActiveRevision: string;
    Status: string;
    CreatedAt: string;
    UpdatedAt: string;
    ProjectFilePath: string;
  end;
  TMmpDbProjectArray = array of TMmpDbProjectRow;

  TMmpDbRevisionRow = record
    ProjectId: string;
    RevisionId: string;
    ParentRevisionId: string;
    State: string;
    RevLabel: string;
    ManifestPath: string;
    ManifestSha256: string;
    CreatedAt: string;
  end;
  TMmpDbRevisionArray = array of TMmpDbRevisionRow;

  TMmpDbSourceRow = record
    ProjectId: string;
    RevisionId: string;
    SourceProjectId: string;
    SourceRevisionId: string;
    SourceManifestSha256: string;
  end;
  TMmpDbSourceArray = array of TMmpDbSourceRow;

  TMmpDbMediaAssetRow = record
    ArtifactId: string;
    ProductionId: string;
    ProjectId: string;
    RevisionId: string;
    AppName: string;
    MediaCategory: string; // 'images' | 'voices' | 'audios' | 'videos' | 'other'
    Kind: string;
    SceneId: string;
    SegmentId: string;
    RelativePath: string;
    LegacyUri: string;
    MimeType: string;
    Sha256: string;
    Bytes: Int64;
    Status: string;
    CreatedAt: string;
  end;
  TMmpDbMediaAssetArray = array of TMmpDbMediaAssetRow;

  TMmpDbSyncJobRow = record
    EventId: string;
    TransactionId: string;
    ProductionId: string;
    OriginApp: string;
    TargetApp: string;
    ProjectId: string;
    SourceRevision: string;
    RequestedChange: string;
    Stage: string;
    Status: string;
    ErrorText: string;
    CreatedAt: string;
    UpdatedAt: string;
    SourceFile: string;
  end;
  TMmpDbSyncJobArray = array of TMmpDbSyncJobRow;

function MmpInitSqliteLibrary: Boolean;
function DbFileSizeBytes(const FilePath: string): Int64;
function MmpProductionDbPath(const ProdRoot: string): string;
function MmpGlobalCentralLogDbPath: string;
function MmpFindEmptyTemplateDbPath: string;
function MmpCreateEmptyTemplateDbAt(const DestPath: string; out ErrMsg: string): Boolean;
function MmpEnsureEmptyTemplateDb(out TemplatePath, ErrMsg: string): Boolean;
function MmpInitProductionDbFromTemplate(const ProdRoot, CustomTemplatePath: string;
  out DbPath, ErrMsg: string): Boolean;

procedure MmpEnsureProductionMediaDirs(const ProdRoot: string);
function MmpDetectMediaCategory(const Kind, MimeType, Uri: string): string;
function MmpResolveMediaStorageRelPath(const Category, AppName, SceneId, RevId, OriginalUri: string): string;
function MmpEnsureAssetStoredInMediaDir(const ProdRoot, SrcFilePath, AppName, SceneId,
  RevId, Kind, MimeType, OriginalUri: string; out RelPath: string): Boolean;

function MmpDbUpsertProduction(const ProdRoot, ProductionId, Title, Slug, NameBase,
  Language, Status, CreatedAt, UpdatedAt, SettingsJson: string; out ErrMsg: string): Boolean;
function MmpDbReadProductionHeader(const ProdRoot: string; out ProductionId, Title,
  Slug, Status, CreatedAt, UpdatedAt: string): Boolean;

function MmpDbUpsertProject(const ProdRoot: string; const Row: TMmpDbProjectRow;
  out ErrMsg: string): Boolean;
function MmpDbListProjects(const ProdRoot: string): TMmpDbProjectArray;

function MmpDbUpsertRevision(const ProdRoot, ProductionId: string; const Row: TMmpDbRevisionRow;
  out ErrMsg: string): Boolean;
function MmpDbListRevisions(const ProdRoot, ProjectId: string): TMmpDbRevisionArray;

function MmpDbReplaceRevisionSources(const ProdRoot, ProjectId, RevisionId: string;
  const Sources: array of TMmpDbSourceRow; out ErrMsg: string): Boolean;
function MmpDbListRevisionSources(const ProdRoot, ProjectId, RevisionId: string): TMmpDbSourceArray;

function MmpDbUpsertMediaAsset(const ProdRoot: string; const Row: TMmpDbMediaAssetRow;
  out ErrMsg: string): Boolean;
function MmpDbListMediaAssets(const ProdRoot: string; const MediaCategory: string = '';
  const ProjectId: string = ''; const RevisionId: string = ''): TMmpDbMediaAssetArray;

function MmpDbSetVisualEntityApproval(const ProdRoot, ProjectId, RevisionId,
  EntityId, ApprovalStatus: string; out ErrMsg: string): Boolean;
function MmpDbGetVisualEntityApproval(const ProdRoot, ProjectId, RevisionId,
  EntityId: string; out ApprovalStatus: string): Boolean;

function MmpDbUpsertSyncJob(const ProdRoot: string; const Row: TMmpDbSyncJobRow;
  out ErrMsg: string): Boolean;
function MmpDbListSyncJobs(const ProdRoot: string): TMmpDbSyncJobArray;

function MmpDbAddCentralLog(const DbPath, ProductionId, Level, AppName, UserName,
  Action, RevisionId, Msg, Details: string): Boolean;
function MmpDbListCentralLogs(const DbPath: string; const FilterApp: string = '';
  const FilterLevel: string = ''; const FilterSearch: string = '';
  ResolvedFilter: Integer = -1; MaxRows: Integer = 500): TMmpCentralLogArray;
function MmpDbResolveCentralLog(const DbPath: string; LogId: Int64;
  const ResolvedBy, Note: string; ResolvedFlag: Boolean = True): Boolean;

implementation

var
  GSqliteInitialized: Boolean = False;

function DbNowIsoUtc: string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', LocalTimeToUniversal(Now));
end;

function CopyBinaryFile(const SrcPath, DstPath: string; out ErrMsg: string): Boolean;
var
  Src, Dst: TFileStream;
  DstDir: string;
begin
  Result := False;
  ErrMsg := '';
  if not FileExists(SrcPath) then
  begin
    ErrMsg := 'Arquivo origem nao encontrado: ' + SrcPath;
    Exit;
  end;
  DstDir := ExtractFileDir(DstPath);
  if (DstDir <> '') and not DirectoryExists(DstDir) then
    ForceDirectories(DstDir);
  try
    Src := TFileStream.Create(SrcPath, fmOpenRead or fmShareDenyWrite);
    try
      Dst := TFileStream.Create(DstPath, fmCreate);
      try
        if Src.Size > 0 then
          Dst.CopyFrom(Src, Src.Size);
        Result := True;
      finally
        Dst.Free;
      end;
    finally
      Src.Free;
    end;
  except
    on E: Exception do
    begin
      ErrMsg := 'Falha ao copiar banco: ' + E.Message;
      Result := False;
    end;
  end;
end;

function MmpInitSqliteLibrary: Boolean;
var
  ExeDir, Candidate: string;
  Candidates: TStringList;
  I: Integer;
begin
  if GSqliteInitialized then Exit(True);
  ExeDir := IncludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0))));
  Candidates := TStringList.Create;
  try
    {$IFDEF WINDOWS}
    Candidates.Add(ExeDir + 'sqlite3.dll');
    Candidates.Add(ExpandFileName(ExeDir + '..' + PathDelim + 'bin' + PathDelim + 'sqlite3.dll'));
    Candidates.Add(ExpandFileName(ExeDir + '..' + PathDelim + '..' + PathDelim + 'bin' + PathDelim + 'sqlite3.dll'));
    Candidates.Add('sqlite3.dll');
    Candidates.Add('winsqlite3.dll');
    {$ELSE}
      {$IFDEF DARWIN}
      Candidates.Add(ExeDir + 'libsqlite3.dylib');
      Candidates.Add('libsqlite3.dylib');
      {$ELSE}
      Candidates.Add(ExeDir + 'libsqlite3.so.0');
      Candidates.Add('libsqlite3.so.0');
      Candidates.Add('libsqlite3.so');
      {$ENDIF}
    {$ENDIF}
    for I := 0 to Candidates.Count - 1 do
    begin
      Candidate := Candidates[I];
      if (ExtractFilePath(Candidate) <> '') and not FileExists(Candidate) then Continue;
      SQLiteDefaultLibrary := Candidate;
      try
        if TryInitializeSqlite(UnicodeString(Candidate)) > 0 then
        begin
          GSqliteInitialized := True;
          Exit(True);
        end;
      except
        // Tentar a próxima biblioteca.
      end;
    end;
  finally
    Candidates.Free;
  end;
  Result := False;
end;

function OpenConn(const DbPath: string; out Conn: TSQLite3Connection;
  out Tr: TSQLTransaction; out ErrMsg: string): Boolean;
begin
  Result := False;
  ErrMsg := '';
  Conn := nil;
  Tr := nil;
  MmpInitSqliteLibrary;
  try
    if ExtractFileDir(DbPath) <> '' then
      ForceDirectories(ExtractFileDir(DbPath));
    Conn := TSQLite3Connection.Create(nil);
    Tr := TSQLTransaction.Create(nil);
    Conn.DatabaseName := DbPath;
    Conn.Transaction := Tr;
    Conn.Open;
    if Conn.Handle <> nil then
    begin
      sqlite3_busy_timeout(Conn.Handle, 15000);
      sqlite3_exec(Conn.Handle,
        'PRAGMA busy_timeout=15000; PRAGMA journal_mode=WAL; PRAGMA foreign_keys=OFF; PRAGMA synchronous=NORMAL;',
        nil, nil, nil);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      ErrMsg := E.Message;
      if Tr <> nil then FreeAndNil(Tr);
      if Conn <> nil then FreeAndNil(Conn);
      Result := False;
    end;
  end;
end;

procedure CloseConn(var Conn: TSQLite3Connection; var Tr: TSQLTransaction);
begin
  try
    if (Tr <> nil) and Tr.Active then
      Tr.Commit;
  except
    // ignore commit cleanup errors
  end;
  if Conn <> nil then
  begin
    try
      if Conn.Connected then Conn.Close;
    except
    end;
    FreeAndNil(Conn);
  end;
  if Tr <> nil then
    FreeAndNil(Tr);
end;

procedure EnsureSchemaOnConn(Conn: TSQLite3Connection; Tr: TSQLTransaction);
const
  DDL: array[0..13] of string = (
    'CREATE TABLE IF NOT EXISTS schema_meta (' +
      'key TEXT PRIMARY KEY, ' +
      'value TEXT NOT NULL);',

    'CREATE TABLE IF NOT EXISTS productions (' +
      'production_id TEXT PRIMARY KEY, ' +
      'title TEXT NOT NULL, ' +
      'slug TEXT, ' +
      'root_dir TEXT, ' +
      'name_base TEXT, ' +
      'language TEXT, ' +
      'status TEXT, ' +
      'created_at TEXT, ' +
      'updated_at TEXT, ' +
      'settings_json TEXT);',

    'CREATE TABLE IF NOT EXISTS projects (' +
      'project_id TEXT PRIMARY KEY, ' +
      'production_id TEXT NOT NULL, ' +
      'software_index INTEGER NOT NULL, ' +
      'app_name TEXT NOT NULL, ' +
      'scene_id TEXT, ' +
      'name_base TEXT, ' +
      'active_revision TEXT, ' +
      'status TEXT, ' +
      'created_at TEXT, ' +
      'updated_at TEXT, ' +
      'project_file_path TEXT);',

    'CREATE TABLE IF NOT EXISTS revisions (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'production_id TEXT NOT NULL, ' +
      'project_id TEXT NOT NULL, ' +
      'revision_id TEXT NOT NULL, ' +
      'parent_revision_id TEXT, ' +
      'state TEXT, ' +
      'rev_label TEXT, ' +
      'manifest_path TEXT, ' +
      'manifest_sha256 TEXT, ' +
      'created_at TEXT, ' +
      'UNIQUE(project_id, revision_id));',

    'CREATE TABLE IF NOT EXISTS revision_sources (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'project_id TEXT NOT NULL, ' +
      'revision_id TEXT NOT NULL, ' +
      'source_project_id TEXT NOT NULL, ' +
      'source_revision_id TEXT NOT NULL, ' +
      'source_manifest_sha256 TEXT);',

    'CREATE TABLE IF NOT EXISTS media_assets (' +
      'artifact_id TEXT PRIMARY KEY, ' +
      'production_id TEXT NOT NULL, ' +
      'project_id TEXT NOT NULL, ' +
      'revision_id TEXT NOT NULL, ' +
      'app_name TEXT NOT NULL, ' +
      'media_category TEXT NOT NULL, ' +
      'kind TEXT NOT NULL, ' +
      'scene_id TEXT, ' +
      'segment_id TEXT, ' +
      'relative_path TEXT NOT NULL, ' +
      'legacy_uri TEXT, ' +
      'mime_type TEXT, ' +
      'sha256 TEXT, ' +
      'bytes INTEGER DEFAULT 0, ' +
      'status TEXT, ' +
      'created_at TEXT);',

    'CREATE TABLE IF NOT EXISTS sync_jobs (' +
      'event_id TEXT PRIMARY KEY, ' +
      'transaction_id TEXT, ' +
      'production_id TEXT, ' +
      'origin_app TEXT, ' +
      'target_app TEXT, ' +
      'project_id TEXT, ' +
      'source_revision TEXT, ' +
      'requested_change TEXT, ' +
      'stage TEXT, ' +
      'status TEXT, ' +
      'error_text TEXT, ' +
      'created_at TEXT, ' +
      'updated_at TEXT, ' +
      'source_file TEXT);',

    'CREATE TABLE IF NOT EXISTS central_logs (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'production_id TEXT, ' +
      'ts TEXT NOT NULL, ' +
      'level TEXT NOT NULL, ' +
      'app_name TEXT NOT NULL, ' +
      'user_name TEXT, ' +
      'action TEXT, ' +
      'revision_id TEXT, ' +
      'message TEXT NOT NULL, ' +
      'details TEXT, ' +
      'resolved INTEGER DEFAULT 0, ' +
      'resolved_by TEXT, ' +
      'resolved_at TEXT, ' +
      'resolution_note TEXT);',

    'CREATE TABLE IF NOT EXISTS visual_entity_approvals (' +
      'project_id TEXT NOT NULL, ' +
      'revision_id TEXT NOT NULL, ' +
      'entity_id TEXT NOT NULL, ' +
      'approval_status TEXT NOT NULL, ' +
      'updated_at TEXT NOT NULL, ' +
      'PRIMARY KEY(project_id, revision_id, entity_id));',
    'CREATE INDEX IF NOT EXISTS idx_visual_approvals_revision ON visual_entity_approvals(project_id, revision_id);',
    'CREATE INDEX IF NOT EXISTS idx_media_prod_cat ON media_assets(production_id, media_category);',
    'CREATE INDEX IF NOT EXISTS idx_media_proj_rev ON media_assets(project_id, revision_id);',
    'CREATE INDEX IF NOT EXISTS idx_logs_ts ON central_logs(ts DESC, id DESC);',
    'CREATE INDEX IF NOT EXISTS idx_logs_filter ON central_logs(app_name, level, resolved);'
  );
var
  I: Integer;
  Q: TSQLQuery;
  NeedSchema: Boolean;
begin
  NeedSchema := True;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text := 'SELECT value FROM schema_meta WHERE key=''schema_version'' LIMIT 1;';
      Q.Open;
      if (not Q.EOF) and (Q.Fields[0].AsString = MMP_DB_SCHEMA_VERSION) then
        NeedSchema := False;
      Q.Close;
    finally
      Q.Free;
    end;
    if Tr.Active then Tr.Commit;
  except
    if Tr.Active then Tr.Rollback;
    NeedSchema := True;
  end;
  if not NeedSchema then Exit;

  try
    if not Tr.Active then Tr.StartTransaction;
    for I := 0 to High(DDL) do
      Conn.ExecuteDirect(DDL[I]);
    Conn.ExecuteDirect(
      'INSERT OR REPLACE INTO schema_meta(key, value) VALUES(''schema_version'', ''' +
      MMP_DB_SCHEMA_VERSION + ''');');
    Tr.Commit;
  except
    on E: Exception do
    begin
      if Tr.Active then Tr.Rollback;
      raise Exception.Create('Falha na migracao do banco SQLite: ' + E.Message);
    end;
  end;
end;

function MmpProductionDbPath(const ProdRoot: string): string;
begin
  if Trim(ProdRoot) = '' then
    Result := ''
  else
    Result := IncludeTrailingPathDelimiter(ExcludeTrailingPathDelimiter(ProdRoot)) + MMP_DB_FILENAME;
end;

function MmpGlobalCentralLogDbPath: string;
var
  Dummy: string;
begin
  Result := GetSharedMaurinMovieConfigDir(Dummy) + MMP_GLOBAL_LOG_DB_FILENAME;
end;

function DbFileSizeBytes(const FilePath: string): Int64;
var
  SR: TSearchRec;
begin
  Result := -1;
  if FindFirst(FilePath, faAnyFile, SR) = 0 then
  try
    Result := SR.Size;
  finally
    FindClose(SR);
  end;
end;

function MmpFindEmptyTemplateDbPath: string;
var
  ExeDir, C: string;
  Paths: array[0..4] of string;
  I: Integer;
begin
  Result := '';
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  Paths[0] := IncludeTrailingPathDelimiter(ExeDir) + 'templates' + PathDelim + MMP_EMPTY_DB_FILENAME;
  Paths[1] := ExpandFileName(IncludeTrailingPathDelimiter(ExeDir) + '..' + PathDelim + 'db' + PathDelim + MMP_EMPTY_DB_FILENAME);
  Paths[2] := ExpandFileName(IncludeTrailingPathDelimiter(ExeDir) + '..' + PathDelim + '..' + PathDelim + 'db' + PathDelim + MMP_EMPTY_DB_FILENAME);
  Paths[3] := ExpandFileName(IncludeTrailingPathDelimiter(ExeDir) + '..' + PathDelim + 'bin' + PathDelim + 'templates' + PathDelim + MMP_EMPTY_DB_FILENAME);
  Paths[4] := IncludeTrailingPathDelimiter(ExeDir) + MMP_EMPTY_DB_FILENAME;
  for I := 0 to High(Paths) do
  begin
    C := Paths[I];
    if FileExists(C) and (DbFileSizeBytes(C) >= 4096) then Exit(C);
  end;
end;

function MmpCreateEmptyTemplateDbAt(const DestPath: string; out ErrMsg: string): Boolean;
var
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  BakFile: string;
begin
  Result := False;
  ErrMsg := '';
  try
    if FileExists(DestPath) then DeleteFile(DestPath);
    if FileExists(DestPath + '-wal') then DeleteFile(DestPath + '-wal');
    if FileExists(DestPath + '-shm') then DeleteFile(DestPath + '-shm');
  except
  end;
  if not OpenConn(DestPath, Conn, Tr, ErrMsg) then Exit;
  try
    try
      EnsureSchemaOnConn(Conn, Tr);
      if Conn.Handle <> nil then
        sqlite3_exec(Conn.Handle, 'PRAGMA journal_mode=DELETE;', nil, nil, nil);
      Result := True;
    except
      on E: Exception do
      begin
        ErrMsg := 'Falha ao inicializar schema do banco template: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    CloseConn(Conn, Tr);
  end;
  BakFile := DestPath + '-journal';
  if FileExists(BakFile) then DeleteFile(BakFile);
end;

function MmpEnsureEmptyTemplateDb(out TemplatePath, ErrMsg: string): Boolean;
var
  ExeDir: string;
begin
  Result := False;
  ErrMsg := '';
  TemplatePath := MmpFindEmptyTemplateDbPath;
  if TemplatePath <> '' then Exit(True);

  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  TemplatePath := IncludeTrailingPathDelimiter(ExeDir) + 'templates' + PathDelim + MMP_EMPTY_DB_FILENAME;
  Result := MmpCreateEmptyTemplateDbAt(TemplatePath, ErrMsg);
end;

function MmpInitProductionDbFromTemplate(const ProdRoot, CustomTemplatePath: string;
  out DbPath, ErrMsg: string): Boolean;
var
  TemplatePath: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
begin
  Result := False;
  ErrMsg := '';
  DbPath := MmpProductionDbPath(ProdRoot);
  if DbPath = '' then
  begin
    ErrMsg := 'Pasta da producao invalida para inicializar SQLite.';
    Exit;
  end;

  if Trim(CustomTemplatePath) <> '' then
    TemplatePath := CustomTemplatePath
  else if not MmpEnsureEmptyTemplateDb(TemplatePath, ErrMsg) then
    Exit;

  if not FileExists(TemplatePath) then
  begin
    ErrMsg := 'Banco zerado template nao encontrado: ' + TemplatePath;
    Exit;
  end;

  if not CopyBinaryFile(TemplatePath, DbPath, ErrMsg) then Exit;

  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    try
      EnsureSchemaOnConn(Conn, Tr);
      Result := True;
    except
      on E: Exception do
        ErrMsg := E.Message;
    end;
  finally
    CloseConn(Conn, Tr);
  end;
end;

procedure MmpEnsureProductionMediaDirs(const ProdRoot: string);
var
  BaseMedia: string;
begin
  if Trim(ProdRoot) = '' then Exit;
  BaseMedia := IncludeTrailingPathDelimiter(ExcludeTrailingPathDelimiter(ProdRoot)) + 'media' + PathDelim;
  ForceDirectories(BaseMedia + 'images' + PathDelim + 'personagens');
  ForceDirectories(BaseMedia + 'images' + PathDelim + 'objetos');
  ForceDirectories(BaseMedia + 'images' + PathDelim + 'cenarios');
  ForceDirectories(BaseMedia + 'images' + PathDelim + 'quadros');
  ForceDirectories(BaseMedia + 'voices');
  ForceDirectories(BaseMedia + 'audios' + PathDelim + 'effects');
  ForceDirectories(BaseMedia + 'audios' + PathDelim + 'music');
  ForceDirectories(BaseMedia + 'audios' + PathDelim + 'previews');
  ForceDirectories(BaseMedia + 'videos' + PathDelim + 'segments');
  ForceDirectories(BaseMedia + 'videos' + PathDelim + 'assembled');
  ForceDirectories(BaseMedia + 'videos' + PathDelim + 'exports');
  ForceDirectories(BaseMedia + 'other');
end;

function MmpDetectMediaCategory(const Kind, MimeType, Uri: string): string;
var
  KL, ML, UL: string;
begin
  KL := LowerCase(Trim(Kind));
  ML := LowerCase(Trim(MimeType));
  UL := LowerCase(Trim(Uri));

  if (Pos('voice', KL) > 0) or (Pos('voices/', UL) > 0) or (Pos('voz', KL) > 0) then
    Exit('voices');
  if (Pos('image/', ML) = 1) or (Pos('image', KL) > 0) or (Pos('frame', KL) > 0) or
     (Pos('storyboard', KL) > 0) or (Pos('.png', UL) > 0) or (Pos('.bmp', UL) > 0) or
     (Pos('.jpg', UL) > 0) or (Pos('.jpeg', UL) > 0) or (Pos('.webp', UL) > 0) then
    Exit('images');
  if (Pos('video/', ML) = 1) or (Pos('video', KL) > 0) or (Pos('.mp4', UL) > 0) or
     (Pos('.mkv', UL) > 0) or (Pos('.mov', UL) > 0) or (Pos('.webm', UL) > 0) then
    Exit('videos');
  if (Pos('audio/', ML) = 1) or (Pos('audio', KL) > 0) or (Pos('sfx', KL) > 0) or
     (Pos('sound', KL) > 0) or (Pos('.wav', UL) > 0) or (Pos('.mp3', UL) > 0) or
     (Pos('.ogg', UL) > 0) then
    Exit('audios');
  Result := 'other';
end;

function MmpResolveMediaStorageRelPath(const Category, AppName, SceneId, RevId,
  OriginalUri: string): string;
var
  FName, Sub: string;
begin
  FName := ExtractFileName(StringReplace(OriginalUri, '/', PathDelim, [rfReplaceAll]));
  if FName = '' then FName := 'asset.bin';
  if Category = 'images' then
  begin
    if Pos('quadro', LowerCase(OriginalUri)) > 0 then Sub := 'quadros'
    else if Pos('personag', LowerCase(OriginalUri)) > 0 then Sub := 'personagens'
    else if Pos('objeto', LowerCase(OriginalUri)) > 0 then Sub := 'objetos'
    else if Pos('cenario', LowerCase(OriginalUri)) > 0 then Sub := 'cenarios'
    else Sub := LowerCase(AppName);
  end
  else if Category = 'voices' then
    Sub := LowerCase(AppName)
  else if Category = 'audios' then
  begin
    if Pos('effect', LowerCase(OriginalUri)) > 0 then Sub := 'effects'
    else if Pos('preview', LowerCase(OriginalUri)) > 0 then Sub := 'previews'
    else Sub := LowerCase(AppName);
  end
  else if Category = 'videos' then
  begin
    if Pos('export', LowerCase(OriginalUri)) > 0 then Sub := 'exports'
    else if Pos('assembled', LowerCase(OriginalUri)) > 0 then Sub := 'assembled'
    else if Trim(SceneId) <> '' then Sub := 'segments/' + SceneId
    else Sub := 'segments';
  end
  else
    Sub := LowerCase(AppName);

  if Trim(RevId) <> '' then
    Result := 'media/' + Category + '/' + Sub + '/' + RevId + '/' + FName
  else
    Result := 'media/' + Category + '/' + Sub + '/' + FName;
end;

function MmpEnsureAssetStoredInMediaDir(const ProdRoot, SrcFilePath, AppName, SceneId,
  RevId, Kind, MimeType, OriginalUri: string; out RelPath: string): Boolean;
var
  Cat, DstFull, Err: string;
begin
  Result := False;
  RelPath := OriginalUri;
  Cat := MmpDetectMediaCategory(Kind, MimeType, OriginalUri);
  if (Cat = 'other') or (Trim(ProdRoot) = '') then Exit;
  if not FileExists(SrcFilePath) then Exit;

  MmpEnsureProductionMediaDirs(ProdRoot);
  RelPath := MmpResolveMediaStorageRelPath(Cat, AppName, SceneId, RevId, OriginalUri);
  DstFull := IncludeTrailingPathDelimiter(ExcludeTrailingPathDelimiter(ProdRoot)) +
    StringReplace(RelPath, '/', PathDelim, [rfReplaceAll]);
  if SameText(ExpandFileName(SrcFilePath), ExpandFileName(DstFull)) then
    Exit(True);
  Result := CopyBinaryFile(SrcFilePath, DstFull, Err);
end;

procedure BindStr(Q: TSQLQuery; const ParamName, Val: string);
begin
  Q.Params.ParamByName(ParamName).AsString := Val;
end;

function MmpDbUpsertProduction(const ProdRoot, ProductionId, Title, Slug, NameBase,
  Language, Status, CreatedAt, UpdatedAt, SettingsJson: string; out ErrMsg: string): Boolean;
var
  DbPath: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  DbPath := MmpProductionDbPath(ProdRoot);
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'INSERT OR REPLACE INTO productions(' +
        'production_id, title, slug, root_dir, name_base, language, status, created_at, updated_at, settings_json) ' +
        'VALUES(:id, :title, :slug, :root, :nb, :lang, :st, :ca, :ua, :sj);';
      BindStr(Q, 'id', ProductionId);
      BindStr(Q, 'title', Title);
      BindStr(Q, 'slug', Slug);
      BindStr(Q, 'root', ExcludeTrailingPathDelimiter(ProdRoot));
      BindStr(Q, 'nb', NameBase);
      BindStr(Q, 'lang', Language);
      BindStr(Q, 'st', Status);
      BindStr(Q, 'ca', CreatedAt);
      BindStr(Q, 'ua', UpdatedAt);
      BindStr(Q, 'sj', SettingsJson);
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      on E: Exception do ErrMsg := E.Message;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbReadProductionHeader(const ProdRoot: string; out ProductionId, Title,
  Slug, Status, CreatedAt, UpdatedAt: string): Boolean;
var
  DbPath, ErrMsg: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  ProductionId := ''; Title := ''; Slug := ''; Status := ''; CreatedAt := ''; UpdatedAt := '';
  DbPath := MmpProductionDbPath(ProdRoot);
  if not FileExists(DbPath) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text := 'SELECT production_id, title, slug, status, created_at, updated_at FROM productions LIMIT 1;';
      Q.Open;
      if not Q.EOF then
      begin
        ProductionId := Q.FieldByName('production_id').AsString;
        Title := Q.FieldByName('title').AsString;
        Slug := Q.FieldByName('slug').AsString;
        Status := Q.FieldByName('status').AsString;
        CreatedAt := Q.FieldByName('created_at').AsString;
        UpdatedAt := Q.FieldByName('updated_at').AsString;
        Result := ProductionId <> '';
      end;
      Q.Close;
    except
      Result := False;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbUpsertProject(const ProdRoot: string; const Row: TMmpDbProjectRow;
  out ErrMsg: string): Boolean;
var
  DbPath: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  DbPath := MmpProductionDbPath(ProdRoot);
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'INSERT OR REPLACE INTO projects(' +
        'project_id, production_id, software_index, app_name, scene_id, name_base, ' +
        'active_revision, status, created_at, updated_at, project_file_path) ' +
        'VALUES(:pid, :prodid, :sidx, :app, :sc, :nb, :arev, :st, :ca, :ua, :pfp);';
      BindStr(Q, 'pid', Row.ProjectId);
      BindStr(Q, 'prodid', Row.ProductionId);
      Q.Params.ParamByName('sidx').AsInteger := Row.SoftwareIndex;
      BindStr(Q, 'app', Row.AppName);
      BindStr(Q, 'sc', Row.SceneId);
      BindStr(Q, 'nb', Row.NameBase);
      BindStr(Q, 'arev', Row.ActiveRevision);
      BindStr(Q, 'st', Row.Status);
      BindStr(Q, 'ca', Row.CreatedAt);
      BindStr(Q, 'ua', Row.UpdatedAt);
      BindStr(Q, 'pfp', Row.ProjectFilePath);
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      on E: Exception do ErrMsg := E.Message;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbListProjects(const ProdRoot: string): TMmpDbProjectArray;
var
  DbPath, ErrMsg: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  N: Integer;
begin
  SetLength(Result, 0);
  DbPath := MmpProductionDbPath(ProdRoot);
  if not FileExists(DbPath) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'SELECT project_id, production_id, software_index, app_name, scene_id, name_base, ' +
        'active_revision, status, created_at, updated_at, project_file_path ' +
        'FROM projects ORDER BY software_index ASC, scene_id ASC;';
      Q.Open;
      while not Q.EOF do
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N].ProjectId := Q.FieldByName('project_id').AsString;
        Result[N].ProductionId := Q.FieldByName('production_id').AsString;
        Result[N].SoftwareIndex := Q.FieldByName('software_index').AsInteger;
        Result[N].AppName := Q.FieldByName('app_name').AsString;
        Result[N].SceneId := Q.FieldByName('scene_id').AsString;
        Result[N].NameBase := Q.FieldByName('name_base').AsString;
        Result[N].ActiveRevision := Q.FieldByName('active_revision').AsString;
        Result[N].Status := Q.FieldByName('status').AsString;
        Result[N].CreatedAt := Q.FieldByName('created_at').AsString;
        Result[N].UpdatedAt := Q.FieldByName('updated_at').AsString;
        Result[N].ProjectFilePath := Q.FieldByName('project_file_path').AsString;
        Q.Next;
      end;
      Q.Close;
    except
      SetLength(Result, 0);
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbUpsertRevision(const ProdRoot, ProductionId: string;
  const Row: TMmpDbRevisionRow; out ErrMsg: string): Boolean;
var
  DbPath: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  DbPath := MmpProductionDbPath(ProdRoot);
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'INSERT OR REPLACE INTO revisions(' +
        'production_id, project_id, revision_id, parent_revision_id, state, rev_label, ' +
        'manifest_path, manifest_sha256, created_at) ' +
        'VALUES(:prodid, :pid, :rid, :prid, :st, :lbl, :mp, :sha, :ca);';
      BindStr(Q, 'prodid', ProductionId);
      BindStr(Q, 'pid', Row.ProjectId);
      BindStr(Q, 'rid', Row.RevisionId);
      BindStr(Q, 'prid', Row.ParentRevisionId);
      BindStr(Q, 'st', Row.State);
      BindStr(Q, 'lbl', Row.RevLabel);
      BindStr(Q, 'mp', Row.ManifestPath);
      BindStr(Q, 'sha', Row.ManifestSha256);
      BindStr(Q, 'ca', Row.CreatedAt);
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      on E: Exception do ErrMsg := E.Message;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbListRevisions(const ProdRoot, ProjectId: string): TMmpDbRevisionArray;
var
  DbPath, ErrMsg: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  N: Integer;
begin
  SetLength(Result, 0);
  DbPath := MmpProductionDbPath(ProdRoot);
  if not FileExists(DbPath) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'SELECT project_id, revision_id, parent_revision_id, state, rev_label, ' +
        'manifest_path, manifest_sha256, created_at ' +
        'FROM revisions WHERE project_id = :pid ORDER BY revision_id ASC;';
      BindStr(Q, 'pid', ProjectId);
      Q.Open;
      while not Q.EOF do
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N].ProjectId := Q.FieldByName('project_id').AsString;
        Result[N].RevisionId := Q.FieldByName('revision_id').AsString;
        Result[N].ParentRevisionId := Q.FieldByName('parent_revision_id').AsString;
        Result[N].State := Q.FieldByName('state').AsString;
        Result[N].RevLabel := Q.FieldByName('rev_label').AsString;
        Result[N].ManifestPath := Q.FieldByName('manifest_path').AsString;
        Result[N].ManifestSha256 := Q.FieldByName('manifest_sha256').AsString;
        Result[N].CreatedAt := Q.FieldByName('created_at').AsString;
        Q.Next;
      end;
      Q.Close;
    except
      SetLength(Result, 0);
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbReplaceRevisionSources(const ProdRoot, ProjectId, RevisionId: string;
  const Sources: array of TMmpDbSourceRow; out ErrMsg: string): Boolean;
var
  DbPath: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  I: Integer;
begin
  Result := False;
  DbPath := MmpProductionDbPath(ProdRoot);
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text := 'DELETE FROM revision_sources WHERE project_id = :pid AND revision_id = :rid;';
      BindStr(Q, 'pid', ProjectId);
      BindStr(Q, 'rid', RevisionId);
      Q.ExecSQL;

      Q.SQL.Text :=
        'INSERT INTO revision_sources(project_id, revision_id, source_project_id, ' +
        'source_revision_id, source_manifest_sha256) ' +
        'VALUES(:pid, :rid, :spid, :srid, :ssha);';
      for I := 0 to High(Sources) do
      begin
        BindStr(Q, 'pid', ProjectId);
        BindStr(Q, 'rid', RevisionId);
        BindStr(Q, 'spid', Sources[I].SourceProjectId);
        BindStr(Q, 'srid', Sources[I].SourceRevisionId);
        BindStr(Q, 'ssha', Sources[I].SourceManifestSha256);
        Q.ExecSQL;
      end;
      Tr.Commit;
      Result := True;
    except
      on E: Exception do ErrMsg := E.Message;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbListRevisionSources(const ProdRoot, ProjectId, RevisionId: string): TMmpDbSourceArray;
var
  DbPath, ErrMsg: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  N: Integer;
begin
  SetLength(Result, 0);
  DbPath := MmpProductionDbPath(ProdRoot);
  if not FileExists(DbPath) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'SELECT project_id, revision_id, source_project_id, source_revision_id, source_manifest_sha256 ' +
        'FROM revision_sources WHERE project_id = :pid AND revision_id = :rid;';
      BindStr(Q, 'pid', ProjectId);
      BindStr(Q, 'rid', RevisionId);
      Q.Open;
      while not Q.EOF do
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N].ProjectId := Q.FieldByName('project_id').AsString;
        Result[N].RevisionId := Q.FieldByName('revision_id').AsString;
        Result[N].SourceProjectId := Q.FieldByName('source_project_id').AsString;
        Result[N].SourceRevisionId := Q.FieldByName('source_revision_id').AsString;
        Result[N].SourceManifestSha256 := Q.FieldByName('source_manifest_sha256').AsString;
        Q.Next;
      end;
      Q.Close;
    except
      SetLength(Result, 0);
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbUpsertMediaAsset(const ProdRoot: string; const Row: TMmpDbMediaAssetRow;
  out ErrMsg: string): Boolean;
var
  DbPath, CreatedStr: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  DbPath := MmpProductionDbPath(ProdRoot);
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  CreatedStr := Row.CreatedAt;
  if CreatedStr = '' then CreatedStr := DbNowIsoUtc;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'INSERT OR REPLACE INTO media_assets(' +
        'artifact_id, production_id, project_id, revision_id, app_name, media_category, ' +
        'kind, scene_id, segment_id, relative_path, legacy_uri, mime_type, sha256, bytes, status, created_at) ' +
        'VALUES(:aid, :prodid, :pid, :rid, :app, :cat, :kind, :sc, :seg, :rp, :luri, :mime, :sha, :bytes, :st, :ca);';
      BindStr(Q, 'aid', Row.ArtifactId);
      BindStr(Q, 'prodid', Row.ProductionId);
      BindStr(Q, 'pid', Row.ProjectId);
      BindStr(Q, 'rid', Row.RevisionId);
      BindStr(Q, 'app', Row.AppName);
      BindStr(Q, 'cat', Row.MediaCategory);
      BindStr(Q, 'kind', Row.Kind);
      BindStr(Q, 'sc', Row.SceneId);
      BindStr(Q, 'seg', Row.SegmentId);
      BindStr(Q, 'rp', Row.RelativePath);
      BindStr(Q, 'luri', Row.LegacyUri);
      BindStr(Q, 'mime', Row.MimeType);
      BindStr(Q, 'sha', Row.Sha256);
      Q.Params.ParamByName('bytes').AsLargeInt := Row.Bytes;
      BindStr(Q, 'st', Row.Status);
      BindStr(Q, 'ca', CreatedStr);
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      on E: Exception do ErrMsg := E.Message;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbListMediaAssets(const ProdRoot: string; const MediaCategory: string;
  const ProjectId: string; const RevisionId: string): TMmpDbMediaAssetArray;
var
  DbPath, ErrMsg, Sql: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  N: Integer;
begin
  SetLength(Result, 0);
  DbPath := MmpProductionDbPath(ProdRoot);
  if not FileExists(DbPath) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Sql :=
        'SELECT artifact_id, production_id, project_id, revision_id, app_name, media_category, ' +
        'kind, scene_id, segment_id, relative_path, legacy_uri, mime_type, sha256, bytes, status, created_at ' +
        'FROM media_assets WHERE 1=1 ';
      if Trim(MediaCategory) <> '' then Sql := Sql + 'AND media_category = :cat ';
      if Trim(ProjectId) <> '' then Sql := Sql + 'AND project_id = :pid ';
      if Trim(RevisionId) <> '' then Sql := Sql + 'AND revision_id = :rid ';
      Sql := Sql + 'ORDER BY app_name ASC, revision_id ASC, artifact_id ASC;';
      Q.SQL.Text := Sql;
      if Trim(MediaCategory) <> '' then BindStr(Q, 'cat', MediaCategory);
      if Trim(ProjectId) <> '' then BindStr(Q, 'pid', ProjectId);
      if Trim(RevisionId) <> '' then BindStr(Q, 'rid', RevisionId);
      Q.Open;
      while not Q.EOF do
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N].ArtifactId := Q.FieldByName('artifact_id').AsString;
        Result[N].ProductionId := Q.FieldByName('production_id').AsString;
        Result[N].ProjectId := Q.FieldByName('project_id').AsString;
        Result[N].RevisionId := Q.FieldByName('revision_id').AsString;
        Result[N].AppName := Q.FieldByName('app_name').AsString;
        Result[N].MediaCategory := Q.FieldByName('media_category').AsString;
        Result[N].Kind := Q.FieldByName('kind').AsString;
        Result[N].SceneId := Q.FieldByName('scene_id').AsString;
        Result[N].SegmentId := Q.FieldByName('segment_id').AsString;
        Result[N].RelativePath := Q.FieldByName('relative_path').AsString;
        Result[N].LegacyUri := Q.FieldByName('legacy_uri').AsString;
        Result[N].MimeType := Q.FieldByName('mime_type').AsString;
        Result[N].Sha256 := Q.FieldByName('sha256').AsString;
        Result[N].Bytes := Q.FieldByName('bytes').AsLargeInt;
        Result[N].Status := Q.FieldByName('status').AsString;
        Result[N].CreatedAt := Q.FieldByName('created_at').AsString;
        Q.Next;
      end;
      Q.Close;
    except
      SetLength(Result, 0);
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbSetVisualEntityApproval(const ProdRoot, ProjectId, RevisionId,
  EntityId, ApprovalStatus: string; out ErrMsg: string): Boolean;
var
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  ErrMsg := '';
  if (Trim(ProjectId) = '') or (Trim(RevisionId) = '') or (Trim(EntityId) = '') then
  begin
    ErrMsg := 'Projeto, revisao ou entidade invalida.';
    Exit;
  end;
  if not (SameText(ApprovalStatus, 'approved') or SameText(ApprovalStatus, 'rejected') or
    SameText(ApprovalStatus, 'pending')) then
  begin
    ErrMsg := 'Status de aprovacao invalido.';
    Exit;
  end;
  if not OpenConn(MmpProductionDbPath(ProdRoot), Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text := 'INSERT OR REPLACE INTO visual_entity_approvals ' +
        '(project_id, revision_id, entity_id, approval_status, updated_at) ' +
        'VALUES (:pid, :rid, :eid, :status, :updated);';
      BindStr(Q, 'pid', ProjectId);
      BindStr(Q, 'rid', RevisionId);
      BindStr(Q, 'eid', EntityId);
      BindStr(Q, 'status', ApprovalStatus);
      BindStr(Q, 'updated', DbNowIsoUtc);
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        ErrMsg := E.Message;
        if Tr.Active then Tr.Rollback;
      end;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbGetVisualEntityApproval(const ProdRoot, ProjectId, RevisionId,
  EntityId: string; out ApprovalStatus: string): Boolean;
var
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  ErrMsg: string;
begin
  Result := False;
  ApprovalStatus := '';
  if not FileExists(MmpProductionDbPath(ProdRoot)) then Exit;
  if not OpenConn(MmpProductionDbPath(ProdRoot), Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text := 'SELECT approval_status FROM visual_entity_approvals ' +
        'WHERE project_id=:pid AND revision_id=:rid AND entity_id=:eid LIMIT 1;';
      BindStr(Q, 'pid', ProjectId);
      BindStr(Q, 'rid', RevisionId);
      BindStr(Q, 'eid', EntityId);
      Q.Open;
      if not Q.EOF then
      begin
        ApprovalStatus := Q.Fields[0].AsString;
        Result := True;
      end;
      Q.Close;
    except
      Result := False;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbUpsertSyncJob(const ProdRoot: string; const Row: TMmpDbSyncJobRow;
  out ErrMsg: string): Boolean;
var
  DbPath: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  DbPath := MmpProductionDbPath(ProdRoot);
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'INSERT OR REPLACE INTO sync_jobs(' +
        'event_id, transaction_id, production_id, origin_app, target_app, project_id, ' +
        'source_revision, requested_change, stage, status, error_text, created_at, updated_at, source_file) ' +
        'VALUES(:eid, :tid, :prodid, :oa, :ta, :pid, :sr, :rc, :stg, :st, :err, :ca, :ua, :sf);';
      BindStr(Q, 'eid', Row.EventId);
      BindStr(Q, 'tid', Row.TransactionId);
      BindStr(Q, 'prodid', Row.ProductionId);
      BindStr(Q, 'oa', Row.OriginApp);
      BindStr(Q, 'ta', Row.TargetApp);
      BindStr(Q, 'pid', Row.ProjectId);
      BindStr(Q, 'sr', Row.SourceRevision);
      BindStr(Q, 'rc', Row.RequestedChange);
      BindStr(Q, 'stg', Row.Stage);
      BindStr(Q, 'st', Row.Status);
      BindStr(Q, 'err', Row.ErrorText);
      BindStr(Q, 'ca', Row.CreatedAt);
      BindStr(Q, 'ua', Row.UpdatedAt);
      BindStr(Q, 'sf', Row.SourceFile);
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      on E: Exception do ErrMsg := E.Message;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbListSyncJobs(const ProdRoot: string): TMmpDbSyncJobArray;
var
  DbPath, ErrMsg: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  N: Integer;
begin
  SetLength(Result, 0);
  DbPath := MmpProductionDbPath(ProdRoot);
  if not FileExists(DbPath) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'SELECT event_id, transaction_id, production_id, origin_app, target_app, project_id, ' +
        'source_revision, requested_change, stage, status, error_text, created_at, updated_at, source_file ' +
        'FROM sync_jobs ORDER BY created_at DESC;';
      Q.Open;
      while not Q.EOF do
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N].EventId := Q.FieldByName('event_id').AsString;
        Result[N].TransactionId := Q.FieldByName('transaction_id').AsString;
        Result[N].ProductionId := Q.FieldByName('production_id').AsString;
        Result[N].OriginApp := Q.FieldByName('origin_app').AsString;
        Result[N].TargetApp := Q.FieldByName('target_app').AsString;
        Result[N].ProjectId := Q.FieldByName('project_id').AsString;
        Result[N].SourceRevision := Q.FieldByName('source_revision').AsString;
        Result[N].RequestedChange := Q.FieldByName('requested_change').AsString;
        Result[N].Stage := Q.FieldByName('stage').AsString;
        Result[N].Status := Q.FieldByName('status').AsString;
        Result[N].ErrorText := Q.FieldByName('error_text').AsString;
        Result[N].CreatedAt := Q.FieldByName('created_at').AsString;
        Result[N].UpdatedAt := Q.FieldByName('updated_at').AsString;
        Result[N].SourceFile := Q.FieldByName('source_file').AsString;
        Q.Next;
      end;
      Q.Close;
    except
      SetLength(Result, 0);
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbAddCentralLog(const DbPath, ProductionId, Level, AppName, UserName,
  Action, RevisionId, Msg, Details: string): Boolean;
var
  ErrMsg, TsNow: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  if Trim(DbPath) = '' then Exit;
  TsNow := DbNowIsoUtc;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    EnsureSchemaOnConn(Conn, Tr);
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'INSERT INTO central_logs(' +
        'production_id, ts, level, app_name, user_name, action, revision_id, message, details, resolved) ' +
        'VALUES(:prodid, :ts, :lvl, :app, :usr, :act, :rev, :msg, :dtl, 0);';
      BindStr(Q, 'prodid', ProductionId);
      BindStr(Q, 'ts', TsNow);
      BindStr(Q, 'lvl', LowerCase(Trim(Level)));
      BindStr(Q, 'app', AppName);
      BindStr(Q, 'usr', UserName);
      BindStr(Q, 'act', Action);
      BindStr(Q, 'rev', RevisionId);
      BindStr(Q, 'msg', Msg);
      BindStr(Q, 'dtl', Details);
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      Result := False;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbListCentralLogs(const DbPath: string; const FilterApp: string;
  const FilterLevel: string; const FilterSearch: string;
  ResolvedFilter: Integer; MaxRows: Integer): TMmpCentralLogArray;
var
  ErrMsg, Sql, LikePat: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
  N: Integer;
begin
  SetLength(Result, 0);
  if (Trim(DbPath) = '') or (not FileExists(DbPath)) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Sql :=
        'SELECT id, production_id, ts, level, app_name, user_name, action, revision_id, ' +
        'message, details, resolved, resolved_by, resolved_at, resolution_note ' +
        'FROM central_logs WHERE 1=1 ';
      if Trim(FilterApp) <> '' then
        Sql := Sql + 'AND LOWER(app_name) = LOWER(:app) ';
      if Trim(FilterLevel) <> '' then
        Sql := Sql + 'AND LOWER(level) = LOWER(:lvl) ';
      if ResolvedFilter = 0 then
        Sql := Sql + 'AND resolved = 0 '
      else if ResolvedFilter = 1 then
        Sql := Sql + 'AND resolved = 1 ';
      if Trim(FilterSearch) <> '' then
        Sql := Sql + 'AND (LOWER(message) LIKE :q OR LOWER(details) LIKE :q OR LOWER(action) LIKE :q OR LOWER(user_name) LIKE :q) ';
      Sql := Sql + 'ORDER BY ts DESC, id DESC LIMIT ' + IntToStr(MaxRows) + ';';

      Q.SQL.Text := Sql;
      if Trim(FilterApp) <> '' then BindStr(Q, 'app', Trim(FilterApp));
      if Trim(FilterLevel) <> '' then BindStr(Q, 'lvl', Trim(FilterLevel));
      if Trim(FilterSearch) <> '' then
      begin
        LikePat := '%' + LowerCase(Trim(FilterSearch)) + '%';
        BindStr(Q, 'q', LikePat);
      end;

      Q.Open;
      while not Q.EOF do
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N].Id := Q.FieldByName('id').AsLargeInt;
        Result[N].ProductionId := Q.FieldByName('production_id').AsString;
        Result[N].Timestamp := Q.FieldByName('ts').AsString;
        Result[N].Level := Q.FieldByName('level').AsString;
        Result[N].AppName := Q.FieldByName('app_name').AsString;
        Result[N].UserName := Q.FieldByName('user_name').AsString;
        Result[N].Action := Q.FieldByName('action').AsString;
        Result[N].RevisionId := Q.FieldByName('revision_id').AsString;
        Result[N].Message := Q.FieldByName('message').AsString;
        Result[N].Details := Q.FieldByName('details').AsString;
        Result[N].Resolved := Q.FieldByName('resolved').AsInteger <> 0;
        Result[N].ResolvedBy := Q.FieldByName('resolved_by').AsString;
        Result[N].ResolvedAt := Q.FieldByName('resolved_at').AsString;
        Result[N].ResolutionNote := Q.FieldByName('resolution_note').AsString;
        Q.Next;
      end;
      Q.Close;
    except
      SetLength(Result, 0);
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

function MmpDbResolveCentralLog(const DbPath: string; LogId: Int64;
  const ResolvedBy, Note: string; ResolvedFlag: Boolean): Boolean;
var
  ErrMsg: string;
  Conn: TSQLite3Connection;
  Tr: TSQLTransaction;
  Q: TSQLQuery;
begin
  Result := False;
  if (Trim(DbPath) = '') or (not FileExists(DbPath)) then Exit;
  if not OpenConn(DbPath, Conn, Tr, ErrMsg) then Exit;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.Transaction := Tr;
      Q.SQL.Text :=
        'UPDATE central_logs SET resolved = :res, resolved_by = :rby, ' +
        'resolved_at = :rat, resolution_note = :note WHERE id = :id;';
      if ResolvedFlag then
      begin
        Q.Params.ParamByName('res').AsInteger := 1;
        BindStr(Q, 'rby', ResolvedBy);
        BindStr(Q, 'rat', DbNowIsoUtc);
      end
      else
      begin
        Q.Params.ParamByName('res').AsInteger := 0;
        BindStr(Q, 'rby', '');
        BindStr(Q, 'rat', '');
      end;
      BindStr(Q, 'note', Note);
      Q.Params.ParamByName('id').AsLargeInt := LogId;
      Q.ExecSQL;
      Tr.Commit;
      Result := True;
    except
      Result := False;
    end;
    Q.Free;
  finally
    CloseConn(Conn, Tr);
  end;
end;

initialization
  MmpInitSqliteLibrary;

end.
