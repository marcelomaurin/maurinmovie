unit ummpappbase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, Forms, LCLType, fpjson, jsonparser, Process,
  mmpcommon, mmpsettings, ummpsha256, ummpprotocol, ummpdb;

type
  TMmpArtifactInput = record
    ArtifactId: string;
    Kind: string;
    SceneId: string;
    SegmentId: string;
    RelUri: string;
    MimeType: string;
    Status: string;
  end;

function HandleStandardCliEarlyExit(App: TMMApp): Boolean;
function IsVersionCompatibleWithMMenu(const LauncherVer: string): Boolean;
function ValidateMMenuLaunchContext(App: TMMApp; out Args: TMMLaunchArgs;
  out ErrMsg: string): Boolean;
function RequireMMenuLaunch(App: TMMApp; out Args: TMMLaunchArgs): Boolean;
function IsAppInstanceRunning(App: TMMApp): Boolean;
function FocusAppInstanceWindow(App: TMMApp): Boolean;
function RequireSingleAppInstance(App: TMMApp; IsHeadless: Boolean = False): Boolean;
procedure ReleaseSingleAppInstance;
procedure ParseAppLaunchParams(out ProductionRoot, ProjectId, RevisionId: string);
procedure ParseAppLaunchContext(out ProductionRoot, ProjectId, RevisionId,
  MMenuVersion, ProductionId: string);

function ResolveAppProject(const ProdRoot: string; AppIdx: Integer;
  const PreferredProjId, PreferredRevId: string;
  out Prod: TMmpProduction; out Proj: TMmpProjectRef;
  out ProjectDir, SelectedRevId, ErrMsg: string): Boolean;

function FindProjectByApp(const Prod: TMmpProduction; AppIdx: Integer;
  out Proj: TMmpProjectRef): Boolean;

function FindRevisionInProject(const Proj: TMmpProjectRef; const RevId: string;
  out RevInfo: TMmpRevisionInfo): Boolean;

function ComputeNextRevisionId(const ProjectDir: string;
  const RevisionHistory: array of string): string;

function PrepareNextRevisionDir(const ProjectJsonPath: string;
  out NextRevId, RevDir: string): Boolean;

function PublishProjectRevision(
  const ProductionId, ProjectJsonPath, AppName, ParentRevId, NewState,
  ChangeEventId: string;
  const Sources: array of TMmpSourceRef;
  const Artifacts: array of TMmpArtifactInput;
  out NewRevId, ErrMsg: string;
  const PreparedRevId: string = ''): Boolean;

function EmitSyncEvent(
  const ProdRoot, OriginApp, TargetApp, TargetProjectId,
  SourceRevision, RequestedChange, Stage, Status, ErrText: string;
  out EventId: string; const OperationsJson: string = '';
  const AffectedIdsCsv: string = ''; const OriginProjectId: string = '';
  const OriginRevision: string = ''; const ApprovedBy: string = ''): Boolean;

{ Igual a EmitSyncEvent, devolvendo tambem o ID da transacao criada.
  ExtraStagesCsv lista os estagios seguintes da cascata (ex.: 'MVisual,MBoard'),
  registrados como pendentes para que a transacao nunca seja dada como completa
  antes de todos eles publicarem (docs/specs/00-comum 7.3). }
function EmitSyncEventEx(
  const ProdRoot, OriginApp, TargetApp, TargetProjectId,
  SourceRevision, RequestedChange, Stage, Status, ErrText: string;
  out EventId, TransactionId: string; const OperationsJson: string = '';
  const AffectedIdsCsv: string = ''; const OriginProjectId: string = '';
  const OriginRevision: string = ''; const ApprovedBy: string = '';
  const ExtraStagesCsv: string = ''): Boolean;

{ Atualiza um estagio da transacao e recalcula o estado geral:
  failed se algum estagio falhou, complete so se todos completaram. }
function MmpUpdateTransactionStage(const ProdRoot, TransactionId, StageApp,
  StageStatus, RevisionAfter, ErrText: string): Boolean;

{ Localiza o executavel de um aplicativo: caminho configurado no MMenu,
  pasta do executavel atual e ../bin. }
function MmpFindAppExecutable(App: TMMApp): string;

{ Executa <app> --headless --event <arquivo> e devolve o codigo de saida
  (docs/specs/00-comum 4); -1 se o executavel nao foi encontrado/iniciado. }
function MmpRunHeadlessEvent(App: TMMApp; const ProdRoot, ProjectId, EventFile: string;
  out ErrText: string): Integer;

{ Area de rascunho mutavel do projeto (docs/specs/00-comum 5.1): projects/NN-app/work/draft.
  Revisoes publicadas em revisions/rNNNN sao imutaveis; todo arquivo gerado ou
  editado antes de publicar deve ir para esta pasta. }
{ Abre um arquivo de mídia no reprodutor configurado (mpv) ou no programa padrão. }
function MmpOpenMedia(const FileName, Player: string): Boolean;

function MmpDraftDir(const ProjectDir: string): string;
function MmpDraftFilePath(const ProjectDir, RelUri: string): string;
{ Resolve um arquivo relativo: primeiro no rascunho, depois na revisao indicada. }
function MmpResolveDraftOrRevisionFile(const ProjectDir, RevId, RelUri: string): string;
function MmpHasDraft(const ProjectDir: string): Boolean;
procedure MmpClearDraftDir(const ProjectDir: string);
{ Remove um diretorio de revisao preparado mas nao publicado (sem manifest.json),
  para nao deixar revisoes "fantasmas" que a auditoria acusaria como corrompidas. }
procedure MmpDiscardUnpublishedRevisionDir(const RevDir: string);

procedure MmpLogAppOperation(const ProdRoot, ProdId, AppName, Msg: string;
  const RevId: string = ''; const ActionName: string = 'operation';
  const UserName: string = '');

function StripMarkdownJsonFence(const Raw: string): string;

function SavePlaceholderBitmap(const FilePath, Title, Subtitle, Footer: string;
  BgColor: TColor; WidthPx: Integer = 640; HeightPx: Integer = 360): Boolean;

{ Telas montadas em codigo: o LCL calcula a ancora akRight/akBottom de um
  controle pelo tamanho que o pai tem no momento do SetBounds. Sem handle, um
  painel alinhado ainda tem o tamanho padrao (ex.: 170x50) e, quando o
  alinhamento acontece, os controles ancorados a direita/abaixo "fogem" para
  fora da janela (no GTK2 os botoes do cabecalho e das abas sumiam).
  MmpPrepareAligned da ao controle alinhado o tamanho que ele tera, simulando o
  alinhamento entre os irmaos ja criados; chame logo apos definir Align.
  MmpPrepareTabSheet faz o mesmo para uma aba de TPageControl. }
procedure MmpPrepareAligned(C: TControl);
procedure MmpPrepareTabSheet(Tab: TControl);

implementation

uses
  {$IFDEF WINDOWS}Windows{$ELSE}BaseUnix, Unix{$ENDIF}, LCLIntf;

function MmpOpenMedia(const FileName, Player: string): Boolean;
var P: TProcess;
begin
  Result := False;
  if not FileExists(FileName) then Exit;
  if (Player <> '') and FileExists(Player) then
  begin
    P := TProcess.Create(nil);
    try
      P.Executable := Player;
      P.Parameters.Add(FileName);
      P.Options := [];
      try
        P.Execute;
        Exit(True);
      except
      end;
    finally
      P.Free;
    end;
  end;
  Result := OpenDocument(FileName);
end;

function HandleStandardCliEarlyExit(App: TMMApp): Boolean;
var
  Args: TMMLaunchArgs;
begin
  Result := False;
  Args := ParseLaunchArgs;
  if Args.ShowVersion then
  begin
    WriteCliLine(MMAppNames[App] + ' ' + MAURINMOVIE_VERSION);
    Result := True;
    Exit;
  end;
  if Args.ShowHelp then
  begin
    PrintCliHelp(MMAppNames[App]);
    Result := True;
    Exit;
  end;
end;

function IsVersionCompatibleWithMMenu(const LauncherVer: string): Boolean;
var
  P1, P2: TStringArray;
begin
  Result := False;
  if Trim(LauncherVer) = '' then Exit;
  P1 := Trim(LauncherVer).Split(['.']);
  P2 := MAURINMOVIE_VERSION.Split(['.']);
  if (Length(P1) < 2) or (Length(P2) < 2) then Exit;
  Result := (P1[0] = P2[0]) and (P1[1] = P2[1]);
end;

function ValidateMMenuLaunchContext(App: TMMApp; out Args: TMMLaunchArgs;
  out ErrMsg: string): Boolean;
begin
  Result := False;
  ErrMsg := '';
  Args := ParseLaunchArgs;
  if App = maMMenu then
    Exit(True);

  if not SameText(Trim(Args.Launcher), 'mmenu') then
  begin
    ErrMsg := MMAppNames[App] + ' nao pode ser executado sozinho.' + LineEnding + LineEnding +
      'Inicie este aplicativo atraves do MMenu (Portal MaurinMovie), ' +
      'que fornece o contexto da producao, projeto, revisao e versao.';
    Exit;
  end;

  if Trim(Args.MMenuVersion) = '' then
  begin
    ErrMsg := 'Contexto invalido: versao do MMenu nao informada (--mmenu-version).';
    Exit;
  end;

  if not IsVersionCompatibleWithMMenu(Args.MMenuVersion) then
  begin
    ErrMsg := Format('Versao incompativel: MMenu v%s nao corresponde a %s v%s.',
      [Args.MMenuVersion, MMAppNames[App], MAURINMOVIE_VERSION]);
    Exit;
  end;

  if (Trim(Args.Production) = '') or
     (not FileExists(IncludeTrailingPathDelimiter(Args.Production) + MMP_PRODUCTION_FILE)) then
  begin
    ErrMsg := 'Contexto da producao nao encontrado. Abra a producao no MMenu antes de iniciar ' +
      MMAppNames[App] + '.';
    Exit;
  end;

  if (not Args.Headless) and (Trim(Args.ProjectId) = '') then
  begin
    ErrMsg := 'Contexto incompleto: o MMenu nao informou qual projeto abrir (--project-id).';
    Exit;
  end;

  Result := True;
end;

function RequireMMenuLaunch(App: TMMApp; out Args: TMMLaunchArgs): Boolean;
var
  ErrMsg: string;
begin
  Result := ValidateMMenuLaunchContext(App, Args, ErrMsg);
  if Result then Exit;

  if Args.Headless then
    WriteCliLine('[ERRO] ' + StringReplace(ErrMsg, LineEnding, ' ', [rfReplaceAll]))
  else
  begin
    Application.Scaled := True;
    Application.Initialize;
    Application.MessageBox(
      PChar(ErrMsg),
      PChar(MMAppNames[App] + ' - Execucao Restrita ao MMenu'),
      MB_OK or MB_ICONWARNING);
  end;
end;

procedure ParseAppLaunchParams(out ProductionRoot, ProjectId, RevisionId: string);
var
  Args: TMMLaunchArgs;
begin
  Args := ParseLaunchArgs;
  ProductionRoot := Args.Production;
  ProjectId := Args.ProjectId;
  RevisionId := Args.Revision;
end;

procedure ParseAppLaunchContext(out ProductionRoot, ProjectId, RevisionId,
  MMenuVersion, ProductionId: string);
var
  Args: TMMLaunchArgs;
begin
  Args := ParseLaunchArgs;
  ProductionRoot := Args.Production;
  ProjectId := Args.ProjectId;
  RevisionId := Args.Revision;
  MMenuVersion := Args.MMenuVersion;
  ProductionId := Args.ProductionId;
end;

function FindProjectByApp(const Prod: TMmpProduction; AppIdx: Integer;
  out Proj: TMmpProjectRef): Boolean;
var
  I: Integer;
begin
  Result := False;
  FillChar(Proj, SizeOf(Proj), 0);
  if not Prod.Loaded then Exit;
  for I := 0 to High(Prod.Projects) do
  begin
    if (Prod.Projects[I].SoftwareIndex = AppIdx) and
       (Prod.Projects[I].SceneId = '') then
    begin
      Proj := Prod.Projects[I];
      Exit(True);
    end;
  end;
end;

function FindRevisionInProject(const Proj: TMmpProjectRef; const RevId: string;
  out RevInfo: TMmpRevisionInfo): Boolean;
var
  I: Integer;
begin
  Result := False;
  FillChar(RevInfo, SizeOf(RevInfo), 0);
  for I := 0 to High(Proj.Revisions) do
  begin
    if SameText(Proj.Revisions[I].RevisionId, RevId) then
    begin
      RevInfo := Proj.Revisions[I];
      Exit(True);
    end;
  end;
end;

function ResolveAppProject(const ProdRoot: string; AppIdx: Integer;
  const PreferredProjId, PreferredRevId: string;
  out Prod: TMmpProduction; out Proj: TMmpProjectRef;
  out ProjectDir, SelectedRevId, ErrMsg: string): Boolean;
var
  I: Integer;
  Found: Boolean;
begin
  Result := False;
  ProjectDir := '';
  SelectedRevId := '';
  ErrMsg := '';
  FillChar(Proj, SizeOf(Proj), 0);

  if not LoadProduction(ProdRoot, False, Prod) then
  begin
    ErrMsg := Prod.ErrorMessage;
    Exit;
  end;

  Found := False;
  if PreferredProjId <> '' then
  begin
    for I := 0 to High(Prod.Projects) do
    begin
      if SameText(Prod.Projects[I].ProjectId, PreferredProjId) and
         (Prod.Projects[I].SoftwareIndex = AppIdx) then
      begin
        Proj := Prod.Projects[I];
        Found := True;
        Break;
      end;
    end;
  end;

  if not Found then
    Found := FindProjectByApp(Prod, AppIdx, Proj);

  if not Found then
  begin
    ErrMsg := 'Projeto de ' + MmpAppNames[AppIdx] + ' nao encontrado na producao.';
    Exit;
  end;

  ProjectDir := ExtractFileDir(Proj.ProjectFilePath);
  if PreferredRevId <> '' then
    SelectedRevId := PreferredRevId
  else
    SelectedRevId := Proj.ActiveRevision;
  if SelectedRevId = '' then
    SelectedRevId := 'r0001';

  Result := True;
end;

function ComputeNextRevisionId(const ProjectDir: string;
  const RevisionHistory: array of string): string;
var
  MaxNum, Num, I: Integer;
  S: string;
begin
  MaxNum := 0;
  for I := 0 to High(RevisionHistory) do
  begin
    S := RevisionHistory[I];
    if (Length(S) >= 2) and ((S[1] = 'r') or (S[1] = 'R')) then
    begin
      Num := StrToIntDef(Copy(S, 2, Length(S) - 1), 0);
      if Num > MaxNum then MaxNum := Num;
    end;
  end;

  repeat
    Inc(MaxNum);
    Result := Format('r%.4d', [MaxNum]);
  until not DirectoryExists(IncludeTrailingPathDelimiter(ProjectDir) +
    'revisions' + PathDelim + Result);
end;

function FileSizeBytes(const FilePath: string): Int64;
var
  FS: TFileStream;
begin
  Result := 0;
  if not FileExists(FilePath) then Exit;
  FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    Result := FS.Size;
  finally
    FS.Free;
  end;
end;

function PrepareNextRevisionDir(const ProjectJsonPath: string;
  out NextRevId, RevDir: string): Boolean;
var
  Content, ProjDir: string;
  Data: TJSONData;
  ProjObj: TJSONObject;
  HistArr: TJSONArray;
  Hist: array of string;
  I: Integer;
begin
  Result := False;
  NextRevId := '';
  RevDir := '';
  if not ReadTextFileUtf8(ProjectJsonPath, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  ProjObj := TJSONObject(Data);
  try
    ProjDir := ExtractFileDir(ProjectJsonPath);
    if ProjObj.Find('revision_history') is TJSONArray then
    begin
      HistArr := TJSONArray(ProjObj.Find('revision_history'));
      SetLength(Hist, HistArr.Count);
      for I := 0 to HistArr.Count - 1 do
        Hist[I] := HistArr.Strings[I];
    end
    else
      SetLength(Hist, 0);
    NextRevId := ComputeNextRevisionId(ProjDir, Hist);
    RevDir := IncludeTrailingPathDelimiter(ProjDir) + 'revisions' + PathDelim + NextRevId;
    Result := ForceDirectories(RevDir);
  finally
    ProjObj.Free;
  end;
end;

function PublishProjectRevision(
  const ProductionId, ProjectJsonPath, AppName, ParentRevId, NewState,
  ChangeEventId: string;
  const Sources: array of TMmpSourceRef;
  const Artifacts: array of TMmpArtifactInput;
  out NewRevId, ErrMsg: string;
  const PreparedRevId: string = ''): Boolean;
var
  ProjectDir, RevDir, Content, NowIso, FullArtPath, ProjId: string;
  ProjObj, ManifestObj, SrcObj, ArtObj, LabelsObj: TJSONObject;
  HistArr, SrcArr, ArtArr: TJSONArray;
  Hist: array of string;
  I, AppIdx: Integer;
  Data: TJSONData;
  NameBaseStr, SceneIdStr, FoundProdRoot, RelMedia, DbErr, ArtSha: string;
  ArtBytes: Int64;
  DbProjRow: TMmpDbProjectRow;
  DbRevRow: TMmpDbRevisionRow;
  DbSrcs: array of TMmpDbSourceRow;
  DbArt: TMmpDbMediaAssetRow;
  ArtIds: array of string;
begin
  Result := False;
  NewRevId := '';
  ErrMsg := '';

  { O artifact_id gravado no manifesto e o registrado no SQLite precisam ser o
    mesmo; antes cada um chamava GenerateMmpId e os IDs divergiam. }
  SetLength(ArtIds, Length(Artifacts));
  for I := 0 to High(Artifacts) do
    if Artifacts[I].ArtifactId <> '' then
      ArtIds[I] := Artifacts[I].ArtifactId
    else
      ArtIds[I] := GenerateMmpId('a');

  if not FileExists(ProjectJsonPath) then
  begin
    ErrMsg := 'project.json nao encontrado: ' + ProjectJsonPath;
    Exit;
  end;
  if not ReadTextFileUtf8(ProjectJsonPath, Content) then
  begin
    ErrMsg := 'Nao foi possivel ler project.json.';
    Exit;
  end;

  Data := GetJSON(Content);
  if not (Data is TJSONObject) then
  begin
    Data.Free;
    ErrMsg := 'project.json invalido.';
    Exit;
  end;
  ProjObj := TJSONObject(Data);
  try
    ProjId := ProjObj.Get('project_id', '');
    ProjectDir := ExtractFileDir(ProjectJsonPath);

    if ProjObj.Find('revision_history') is TJSONArray then
    begin
      HistArr := TJSONArray(ProjObj.Find('revision_history'));
      SetLength(Hist, HistArr.Count);
      for I := 0 to HistArr.Count - 1 do
        Hist[I] := HistArr.Strings[I];
    end
    else
    begin
      SetLength(Hist, 0);
      HistArr := TJSONArray.Create;
      ProjObj.Add('revision_history', HistArr);
    end;

    if PreparedRevId <> '' then
      NewRevId := PreparedRevId
    else
      NewRevId := ComputeNextRevisionId(ProjectDir, Hist);
    RevDir := IncludeTrailingPathDelimiter(ProjectDir) + 'revisions' + PathDelim + NewRevId;
    if not ForceDirectories(RevDir) then
    begin
      ErrMsg := 'Nao foi possivel criar diretorio da nova revisao: ' + RevDir;
      Exit;
    end;

    NowIso := CurrentIsoUtc;
    ManifestObj := TJSONObject.Create;
    try
      ManifestObj.Add('schema', MMP_MANIFEST_SCHEMA);
      ManifestObj.Add('production_id', ProductionId);
      ManifestObj.Add('project_id', ProjId);
      ManifestObj.Add('application', AppName);
      ManifestObj.Add('revision_id', NewRevId);
      ManifestObj.Add('parent_revision_id', ParentRevId);
      ManifestObj.Add('state', NewState);
      ManifestObj.Add('created_at', NowIso);

      SrcArr := TJSONArray.Create;
      for I := 0 to High(Sources) do
      begin
        SrcObj := TJSONObject.Create;
        if Sources[I].ResolvedApp <> '' then
          SrcObj.Add('application', Sources[I].ResolvedApp);
        SrcObj.Add('project_id', Sources[I].ProjectId);
        SrcObj.Add('revision_id', Sources[I].RevisionId);
        SrcObj.Add('manifest_sha256', Sources[I].ManifestSha256);
        SrcArr.Add(SrcObj);
      end;
      ManifestObj.Add('sources', SrcArr);

      ArtArr := TJSONArray.Create;
      for I := 0 to High(Artifacts) do
      begin
        ArtObj := TJSONObject.Create;
        ArtObj.Add('artifact_id', ArtIds[I]);
        ArtObj.Add('kind', Artifacts[I].Kind);
        ArtObj.Add('scene_id', Artifacts[I].SceneId);
        ArtObj.Add('segment_id', Artifacts[I].SegmentId);
        ArtObj.Add('uri', NormalizeRelPath(Artifacts[I].RelUri));
        ArtObj.Add('mime_type', Artifacts[I].MimeType);

        if ResolveSafePath(RevDir, Artifacts[I].RelUri, FullArtPath) and
           FileExists(FullArtPath) then
        begin
          ArtObj.Add('sha256', SHA256File(FullArtPath));
          ArtObj.Add('bytes', FileSizeBytes(FullArtPath));
        end
        else
        begin
          ArtObj.Add('sha256', '');
          ArtObj.Add('bytes', Int64(0));
        end;
        ArtObj.Add('status', Artifacts[I].Status);
        ArtArr.Add(ArtObj);
      end;
      ManifestObj.Add('artifacts', ArtArr);
      ManifestObj.Add('change_event_id', ChangeEventId);

      if not AtomicWriteTextFile(RevDir + PathDelim + 'manifest.json',
        ManifestObj.FormatJSON, False) then
      begin
        ErrMsg := 'Falha ao gravar manifest.json.';
        Exit;
      end;
    finally
      ManifestObj.Free;
    end;

    if not (
      (Length(Hist) > 0) and
      SameText(Hist[High(Hist)], NewRevId)
    ) then
    begin
      AppIdx := 0;
      for I := 0 to HistArr.Count - 1 do
        if SameText(HistArr.Strings[I], NewRevId) then
        begin
          AppIdx := 1;
          Break;
        end;
      if AppIdx = 0 then
        HistArr.Add(NewRevId);
    end;
    if ProjObj.IndexOfName('active_revision') >= 0 then
      ProjObj.Strings['active_revision'] := NewRevId
    else
      ProjObj.Add('active_revision', NewRevId);

    if ProjObj.IndexOfName('status') >= 0 then
      ProjObj.Strings['status'] := NewState
    else
      ProjObj.Add('status', NewState);

    if ProjObj.IndexOfName('updated_at') >= 0 then
      ProjObj.Strings['updated_at'] := NowIso
    else
      ProjObj.Add('updated_at', NowIso);

    NameBaseStr := ProjObj.Get('name_base', 'Producao');
    SceneIdStr := ProjObj.Get('scene_id', '');
    AppIdx := AppNameToIndex(AppName);
    if AppIdx < 0 then AppIdx := 0;
    if ProjObj.Find('revision_labels') is TJSONObject then
      LabelsObj := TJSONObject(ProjObj.Find('revision_labels'))
    else
    begin
      LabelsObj := TJSONObject.Create;
      ProjObj.Add('revision_labels', LabelsObj);
    end;
    if LabelsObj.IndexOfName(NewRevId) < 0 then
      LabelsObj.Add(NewRevId, FormatRevisionLabel(NameBaseStr, AppIndexToEnum(AppIdx), NewRevId, SceneIdStr));

    Result := AtomicWriteTextFile(ProjectJsonPath, ProjObj.FormatJSON, True);
    if Result then
    begin
      // Walk up from project.json to find production root, sync SQLite DB & copy media to media/<cat>/
      FoundProdRoot := '';
      RelMedia := ExtractFileDir(ExcludeTrailingPathDelimiter(ProjectJsonPath));
      for AppIdx := 1 to 5 do
      begin
        if FileExists(IncludeTrailingPathDelimiter(RelMedia) + MMP_DB_FILENAME) or
           FileExists(IncludeTrailingPathDelimiter(RelMedia) + MMP_PRODUCTION_FILE) then
        begin
          FoundProdRoot := RelMedia;
          Break;
        end;
        RelMedia := ExtractFileDir(ExcludeTrailingPathDelimiter(RelMedia));
        if RelMedia = '' then Break;
      end;

      if FoundProdRoot <> '' then
      begin
        if not FileExists(MmpProductionDbPath(FoundProdRoot)) then
          MmpInitProductionDbFromTemplate(FoundProdRoot, '', RelMedia, DbErr);
        MmpEnsureProductionMediaDirs(FoundProdRoot);

        AppIdx := AppNameToIndex(AppName);
        if AppIdx < 0 then AppIdx := 0;

        FillChar(DbProjRow, SizeOf(DbProjRow), 0);
        DbProjRow.ProjectId := ProjId;
        DbProjRow.ProductionId := ProductionId;
        DbProjRow.SoftwareIndex := AppIdx;
        DbProjRow.AppName := AppName;
        DbProjRow.SceneId := SceneIdStr;
        DbProjRow.NameBase := NameBaseStr;
        DbProjRow.ActiveRevision := NewRevId;
        DbProjRow.Status := NewState;
        DbProjRow.CreatedAt := ProjObj.Get('created_at', NowIso);
        DbProjRow.UpdatedAt := NowIso;
        DbProjRow.ProjectFilePath := NormalizeRelPath(ExtractRelativepath(
          IncludeTrailingPathDelimiter(FoundProdRoot), ProjectJsonPath));
        MmpDbUpsertProject(FoundProdRoot, DbProjRow, DbErr);

        FillChar(DbRevRow, SizeOf(DbRevRow), 0);
        DbRevRow.ProjectId := ProjId;
        DbRevRow.RevisionId := NewRevId;
        DbRevRow.ParentRevisionId := ParentRevId;
        DbRevRow.State := NewState;
        DbRevRow.RevLabel := FormatRevisionLabel(NameBaseStr, AppIndexToEnum(AppIdx), NewRevId, SceneIdStr);
        DbRevRow.ManifestPath := NormalizeRelPath(ExtractRelativepath(
          IncludeTrailingPathDelimiter(FoundProdRoot), RevDir + PathDelim + 'manifest.json'));
        DbRevRow.ManifestSha256 := SHA256File(RevDir + PathDelim + 'manifest.json');
        DbRevRow.CreatedAt := NowIso;
        MmpDbUpsertRevision(FoundProdRoot, ProductionId, DbRevRow, DbErr);

        SetLength(DbSrcs, Length(Sources));
        for I := 0 to High(Sources) do
        begin
          DbSrcs[I].ProjectId := ProjId;
          DbSrcs[I].RevisionId := NewRevId;
          DbSrcs[I].SourceProjectId := Sources[I].ProjectId;
          DbSrcs[I].SourceRevisionId := Sources[I].RevisionId;
          DbSrcs[I].SourceManifestSha256 := Sources[I].ManifestSha256;
        end;
        MmpDbReplaceRevisionSources(FoundProdRoot, ProjId, NewRevId, DbSrcs, DbErr);

        for I := 0 to High(Artifacts) do
        begin
          FillChar(DbArt, SizeOf(DbArt), 0);
          DbArt.ArtifactId := ArtIds[I];
          DbArt.ProductionId := ProductionId;
          DbArt.ProjectId := ProjId;
          DbArt.RevisionId := NewRevId;
          DbArt.AppName := AppName;
          DbArt.Kind := Artifacts[I].Kind;
          DbArt.MimeType := Artifacts[I].MimeType;
          DbArt.LegacyUri := NormalizeRelPath(Artifacts[I].RelUri);
          DbArt.MediaCategory := MmpDetectMediaCategory(DbArt.Kind, DbArt.MimeType, DbArt.LegacyUri);
          DbArt.SceneId := Artifacts[I].SceneId;
          DbArt.SegmentId := Artifacts[I].SegmentId;
          DbArt.Status := Artifacts[I].Status;
          DbArt.CreatedAt := NowIso;

          ArtSha := '';
          ArtBytes := 0;
          RelMedia := DbArt.LegacyUri;
          if ResolveSafePath(RevDir, Artifacts[I].RelUri, FullArtPath) and FileExists(FullArtPath) then
          begin
            ArtSha := SHA256File(FullArtPath);
            ArtBytes := FileSizeBytes(FullArtPath);
            if DbArt.MediaCategory <> 'other' then
              MmpEnsureAssetStoredInMediaDir(
                FoundProdRoot, FullArtPath, AppName, DbArt.SceneId,
                NewRevId, DbArt.Kind, DbArt.MimeType, DbArt.LegacyUri, RelMedia);
          end;
          DbArt.RelativePath := RelMedia;
          DbArt.Sha256 := ArtSha;
          DbArt.Bytes := ArtBytes;
          MmpDbUpsertMediaAsset(FoundProdRoot, DbArt, DbErr);
        end;

        AppendJsonLogLine(FoundProdRoot, AppName, 'info',
          'Publicada Versao ' + IntToStr(RevisionVersionNumber(NewRevId)) +
          ' (' + NewRevId + ', estado=' + NewState + ', ' +
          IntToStr(Length(Artifacts)) + ' artefato(s))');
      end;
    end
    else
      ErrMsg := 'Falha ao atualizar project.json.';
  finally
    ProjObj.Free;
  end;
end;

function ReadProductionIdFromRoot(const ProdRoot: string): string;
var
  Content: string;
  Data: TJSONData;
begin
  Result := '';
  if not ReadTextFileUtf8(IncludeTrailingPathDelimiter(ProdRoot) + MMP_PRODUCTION_FILE, Content) then
    Exit;
  try
    Data := GetJSON(Content);
    try
      if Data is TJSONObject then
        Result := TJSONObject(Data).Get('production_id', '');
    finally
      Data.Free;
    end;
  except
    Result := '';
  end;
end;

function EmitSyncEvent(
  const ProdRoot, OriginApp, TargetApp, TargetProjectId,
  SourceRevision, RequestedChange, Stage, Status, ErrText: string;
  out EventId: string; const OperationsJson: string;
  const AffectedIdsCsv: string; const OriginProjectId: string;
  const OriginRevision: string; const ApprovedBy: string): Boolean;
var
  TxId: string;
begin
  Result := EmitSyncEventEx(ProdRoot, OriginApp, TargetApp, TargetProjectId,
    SourceRevision, RequestedChange, Stage, Status, ErrText, EventId, TxId,
    OperationsJson, AffectedIdsCsv, OriginProjectId, OriginRevision, ApprovedBy, '');
end;

function EmitSyncEventEx(
  const ProdRoot, OriginApp, TargetApp, TargetProjectId,
  SourceRevision, RequestedChange, Stage, Status, ErrText: string;
  out EventId, TransactionId: string; const OperationsJson: string;
  const AffectedIdsCsv: string; const OriginProjectId: string;
  const OriginRevision: string; const ApprovedBy: string;
  const ExtraStagesCsv: string): Boolean;
var
  InboxDir, TxDir, EvtPath, TxPath, TxId, NowIso, DbErr, ProdId, Part: string;
  StageOrder: Integer;
  Obj, ReqObj, TxObj, OrigObj, StageObj, ResObj: TJSONObject;
  StagesArr, ErrArr, AffArr: TJSONArray;
  OpsData: TJSONData;
  Parts: TStringArray;
  AppIdx: Integer;
  DbSync: TMmpDbSyncJobRow;
begin
  Result := False;
  NowIso := CurrentIsoUtc;
  EventId := GenerateMmpId('evt');
  TxId := GenerateMmpId('tx');
  TransactionId := TxId;
  ProdId := ReadProductionIdFromRoot(ProdRoot);

  InboxDir := IncludeTrailingPathDelimiter(ProdRoot) + 'shared' + PathDelim +
    'events' + PathDelim + 'inbox' + PathDelim + TargetApp;
  ForceDirectories(InboxDir);
  EvtPath := InboxDir + PathDelim + EventId + '.json';

  { Envelope obrigatorio de docs/11 4 + extras de docs/specs/00-comum 7.1. }
  Obj := TJSONObject.Create;
  try
    Obj.Add('schema', MMP_SCHEMA_EVENT);
    Obj.Add('event_id', EventId);
    Obj.Add('transaction_id', TxId);
    Obj.Add('root_event_id', EventId);
    Obj.Add('production_id', ProdId);
    Obj.Add('origin_app', OriginApp);
    Obj.Add('target_app', TargetApp);
    Obj.Add('project_id', TargetProjectId);
    Obj.Add('source_revision', SourceRevision);
    ReqObj := TJSONObject.Create;
    if Trim(OperationsJson) <> '' then
      ReqObj.Add('type', 'script.patch')
    else
      ReqObj.Add('type', 'editorial_patch');
    ReqObj.Add('summary', RequestedChange);
    if Trim(OperationsJson) <> '' then
    begin
      try
        OpsData := GetJSON(OperationsJson);
        if OpsData is TJSONArray then
          ReqObj.Add('operations', OpsData)
        else
          OpsData.Free;
      except
        // operacoes invalidas: o destino recusa o evento (codigo 7)
      end;
    end;
    Obj.Add('requested_change', ReqObj);
    AffArr := TJSONArray.Create;
    if Trim(AffectedIdsCsv) <> '' then
    begin
      Parts := AffectedIdsCsv.Split([',']);
      for Part in Parts do
        if Trim(Part) <> '' then
          AffArr.Add(Trim(Part));
    end;
    Obj.Add('affected_ids', AffArr);
    if ApprovedBy <> '' then
    begin
      Obj.Add('approved_by', ApprovedBy);
      Obj.Add('approved_at', NowIso);
    end;
    Obj.Add('stage', Stage);
    Obj.Add('idempotency_key', EventId + ':' + TargetApp);
    Obj.Add('status', Status);
    Obj.Add('attempts', 0);
    ResObj := TJSONObject.Create;
    ResObj.Add('new_revision', '');
    ResObj.Add('error', ErrText);
    Obj.Add('result', ResObj);
    Obj.Add('error', ErrText);
    Obj.Add('created_at', NowIso);
    Result := AtomicWriteTextFile(EvtPath, Obj.FormatJSON, False);
  finally
    Obj.Free;
  end;

  if not Result then Exit;

  TxDir := IncludeTrailingPathDelimiter(ProdRoot) + 'shared' + PathDelim + 'transactions';
  ForceDirectories(TxDir);
  TxPath := TxDir + PathDelim + TxId + '.json';
  TxObj := TJSONObject.Create;
  try
    TxObj.Add('schema', MMP_SCHEMA_TX);
    TxObj.Add('transaction_id', TxId);
    TxObj.Add('root_event_id', EventId);
    TxObj.Add('production_id', ProdId);
    OrigObj := TJSONObject.Create;
    OrigObj.Add('application', OriginApp);
    { A origem e o projeto/revisao de quem aprovou a mudanca, nao o destino. }
    if OriginProjectId <> '' then
      OrigObj.Add('project_id', OriginProjectId)
    else
      OrigObj.Add('project_id', TargetProjectId);
    if OriginRevision <> '' then
      OrigObj.Add('revision_id', OriginRevision)
    else
      OrigObj.Add('revision_id', SourceRevision);
    TxObj.Add('origin', OrigObj);

    StagesArr := TJSONArray.Create;
    StageObj := TJSONObject.Create;
    StageObj.Add('order', 1);
    StageObj.Add('application', TargetApp);
    StageObj.Add('event_id', EventId);
    if SameText(Status, 'failed') then
      StageObj.Add('status', 'failed')
    else
      StageObj.Add('status', 'pending');
    StageObj.Add('revision_before', SourceRevision);
    StageObj.Add('revision_after', '');
    StagesArr.Add(StageObj);
    StageOrder := 1;
    if Trim(ExtraStagesCsv) <> '' then
    begin
      Parts := ExtraStagesCsv.Split([',']);
      for Part in Parts do
      begin
        if Trim(Part) = '' then Continue;
        Inc(StageOrder);
        StageObj := TJSONObject.Create;
        StageObj.Add('order', StageOrder);
        StageObj.Add('application', Trim(Part));
        StageObj.Add('event_id', '');
        StageObj.Add('status', 'pending');
        StageObj.Add('revision_before', '');
        StageObj.Add('revision_after', '');
        StagesArr.Add(StageObj);
      end;
    end;
    TxObj.Add('stages', StagesArr);

    if SameText(Status, 'failed') then
      TxObj.Add('status', 'failed')
    else
      TxObj.Add('status', 'in_progress');

    ErrArr := TJSONArray.Create;
    if ErrText <> '' then ErrArr.Add(ErrText);
    TxObj.Add('errors', ErrArr);
    TxObj.Add('created_at', NowIso);
    TxObj.Add('updated_at', NowIso);
    AtomicWriteTextFile(TxPath, TxObj.FormatJSON, False);
  finally
    TxObj.Free;
  end;

  AppIdx := AppNameToIndex(OriginApp);
  if AppIdx >= 0 then
    AppendJsonLogLine(ProdRoot, OriginApp, 'info',
      'Evento ' + EventId + ' / Transacao ' + TxId + ' emitida para ' + TargetApp);

  if FileExists(MmpProductionDbPath(ProdRoot)) then
  begin
    FillChar(DbSync, SizeOf(DbSync), 0);
    DbSync.EventId := EventId;
    DbSync.TransactionId := TxId;
    DbSync.ProductionId := ProdId;
    DbSync.OriginApp := OriginApp;
    DbSync.TargetApp := TargetApp;
    DbSync.ProjectId := TargetProjectId;
    DbSync.SourceRevision := SourceRevision;
    DbSync.RequestedChange := RequestedChange;
    DbSync.Stage := Stage;
    DbSync.Status := Status;
    DbSync.ErrorText := ErrText;
    DbSync.CreatedAt := NowIso;
    DbSync.UpdatedAt := NowIso;
    DbSync.SourceFile := EvtPath;
    MmpDbUpsertSyncJob(ProdRoot, DbSync, DbErr);
  end;
end;

function MmpUpdateTransactionStage(const ProdRoot, TransactionId, StageApp,
  StageStatus, RevisionAfter, ErrText: string): Boolean;
var
  TxPath, Content, Overall: string;
  Data: TJSONData;
  TxObj, StageObj: TJSONObject;
  Arr, ErrArr: TJSONArray;
  I: Integer;
  AllComplete, AnyFailed: Boolean;
begin
  Result := False;
  TxPath := IncludeTrailingPathDelimiter(ProdRoot) + 'shared' + PathDelim +
    'transactions' + PathDelim + TransactionId + '.json';
  if not ReadTextFileUtf8(TxPath, Content) then Exit;
  try
    Data := GetJSON(Content);
  except
    Exit;
  end;
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  TxObj := TJSONObject(Data);
  try
    if not (TxObj.Find('stages') is TJSONArray) then Exit;
    Arr := TJSONArray(TxObj.Find('stages'));
    AllComplete := Arr.Count > 0;
    AnyFailed := False;
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      StageObj := TJSONObject(Arr.Items[I]);
      if SameText(StageObj.Get('application', ''), StageApp) then
      begin
        if StageObj.IndexOfName('status') >= 0 then StageObj.Delete('status');
        StageObj.Add('status', StageStatus);
        if RevisionAfter <> '' then
        begin
          if StageObj.IndexOfName('revision_after') >= 0 then StageObj.Delete('revision_after');
          StageObj.Add('revision_after', RevisionAfter);
        end;
      end;
      if SameText(StageObj.Get('status', ''), 'failed') then AnyFailed := True;
      if not SameText(StageObj.Get('status', ''), 'complete') then AllComplete := False;
    end;
    if AnyFailed then Overall := 'failed'
    else if AllComplete then Overall := 'complete'
    else Overall := 'in_progress';
    if TxObj.IndexOfName('status') >= 0 then TxObj.Delete('status');
    TxObj.Add('status', Overall);
    if ErrText <> '' then
    begin
      if TxObj.Find('errors') is TJSONArray then
        ErrArr := TJSONArray(TxObj.Find('errors'))
      else
      begin
        ErrArr := TJSONArray.Create;
        TxObj.Add('errors', ErrArr);
      end;
      ErrArr.Add(StageApp + ': ' + ErrText);
    end;
    if TxObj.IndexOfName('updated_at') >= 0 then TxObj.Delete('updated_at');
    TxObj.Add('updated_at', CurrentIsoUtc);
    Result := AtomicWriteTextFile(TxPath, TxObj.FormatJSON, True);
  finally
    TxObj.Free;
  end;
end;

function MmpFindAppExecutable(App: TMMApp): string;
var
  Suffix, ExeDir, Candidate: string;
  S: TMMSettings;
begin
  Result := '';
  {$IFDEF WINDOWS}
  Suffix := '.exe';
  {$ELSE}
  Suffix := '';
  {$ENDIF}
  S := TMMSettings.Create;
  try
    Candidate := S.GetAppExe(App);
    if (Candidate <> '') and FileExists(Candidate) then Exit(Candidate);
  finally
    S.Free;
  end;
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  Candidate := IncludeTrailingPathDelimiter(ExeDir) + LowerCase(MMAppNames[App]) + Suffix;
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := ExpandFileName(IncludeTrailingPathDelimiter(ExeDir) + '..' + PathDelim + 'bin' +
    PathDelim + LowerCase(MMAppNames[App]) + Suffix);
  if FileExists(Candidate) then Exit(Candidate);
end;

function MmpRunHeadlessEvent(App: TMMApp; const ProdRoot, ProjectId, EventFile: string;
  out ErrText: string): Integer;
var
  Exe: string;
  P: TProcess;
begin
  Result := -1;
  ErrText := '';
  Exe := MmpFindAppExecutable(App);
  if Exe = '' then
  begin
    ErrText := 'Executavel de ' + MMAppNames[App] + ' nao encontrado.';
    Exit;
  end;
  P := TProcess.Create(nil);
  try
    P.Executable := Exe;
    P.Parameters.Add('--launcher');
    P.Parameters.Add('mmenu');
    P.Parameters.Add('--mmenu-version');
    P.Parameters.Add(MAURINMOVIE_VERSION);
    P.Parameters.Add('--production');
    P.Parameters.Add(ProdRoot);
    if ProjectId <> '' then
    begin
      P.Parameters.Add('--project-id');
      P.Parameters.Add(ProjectId);
    end;
    P.Parameters.Add('--headless');
    P.Parameters.Add('--event');
    P.Parameters.Add(EventFile);
    P.Options := [poWaitOnExit, poNoConsole];
    try
      P.Execute;
      Result := P.ExitStatus;
    except
      on E: Exception do
      begin
        ErrText := 'Falha ao iniciar ' + MMAppNames[App] + ': ' + E.Message;
        Result := -1;
      end;
    end;
  finally
    P.Free;
  end;
end;

function MmpDraftDir(const ProjectDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ProjectDir) + 'work' + PathDelim + 'draft';
end;

function MmpDraftFilePath(const ProjectDir, RelUri: string): string;
begin
  Result := MmpDraftDir(ProjectDir) + PathDelim +
    StringReplace(NormalizeRelPath(RelUri), '/', PathDelim, [rfReplaceAll]);
end;

function MmpResolveDraftOrRevisionFile(const ProjectDir, RevId, RelUri: string): string;
var
  Candidate: string;
begin
  Result := '';
  if (Trim(RelUri) = '') or (not IsSafeRelativePath(RelUri)) then Exit;
  Candidate := MmpDraftFilePath(ProjectDir, RelUri);
  if FileExists(Candidate) then Exit(Candidate);
  if RevId <> '' then
  begin
    Candidate := IncludeTrailingPathDelimiter(ProjectDir) + 'revisions' + PathDelim + RevId +
      PathDelim + StringReplace(NormalizeRelPath(RelUri), '/', PathDelim, [rfReplaceAll]);
    if FileExists(Candidate) then Exit(Candidate);
  end;
end;

function MmpHasDraft(const ProjectDir: string): Boolean;
begin
  Result := DirectoryExists(MmpDraftDir(ProjectDir));
end;

procedure DeleteTreeSafe(const Dir: string);
var
  SR: TSearchRec;
  Path: string;
begin
  if not DirectoryExists(Dir) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        Path := IncludeTrailingPathDelimiter(Dir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          DeleteTreeSafe(Path)
        else
          DeleteFile(Path);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  RemoveDir(Dir);
end;

procedure MmpClearDraftDir(const ProjectDir: string);
begin
  if Trim(ProjectDir) = '' then Exit;
  DeleteTreeSafe(MmpDraftDir(ProjectDir));
end;

procedure MmpDiscardUnpublishedRevisionDir(const RevDir: string);
begin
  if (Trim(RevDir) = '') or (not DirectoryExists(RevDir)) then Exit;
  if FileExists(IncludeTrailingPathDelimiter(RevDir) + MMP_MANIFEST_FILE) then Exit;
  DeleteTreeSafe(RevDir);
end;

procedure MmpLogAppOperation(const ProdRoot, ProdId, AppName, Msg: string;
  const RevId: string; const ActionName: string; const UserName: string);
var
  Up, UpClean, Lvl, DbTarget: string;
begin
  if Trim(Msg) = '' then Exit;
  Up := UpperCase(Msg);
  UpClean := StringReplace(Up, 'SEM FALHAS', '', [rfReplaceAll]);
  UpClean := StringReplace(UpClean, 'SEM FALHA', '', [rfReplaceAll]);
  UpClean := StringReplace(UpClean, 'SEM ERROS', '', [rfReplaceAll]);
  UpClean := StringReplace(UpClean, 'SEM ERRO', '', [rfReplaceAll]);
  UpClean := StringReplace(UpClean, 'NENHUMA FALHA', '', [rfReplaceAll]);
  UpClean := StringReplace(UpClean, 'NENHUM ERRO', '', [rfReplaceAll]);
  UpClean := StringReplace(UpClean, '0 FALHA', '', [rfReplaceAll]);
  UpClean := StringReplace(UpClean, '0 ERRO', '', [rfReplaceAll]);

  if (Pos('ERRO', UpClean) > 0) or (Pos('FALHA', UpClean) > 0) then
    Lvl := 'error'
  else if (Pos('AVISO', UpClean) > 0) or (Pos('PENDENCIA', UpClean) > 0) or (Pos('SIMULADO', UpClean) > 0) then
    Lvl := 'warn'
  else
    Lvl := 'info';

  if (Trim(ProdRoot) <> '') and FileExists(MmpProductionDbPath(ProdRoot)) then
    DbTarget := MmpProductionDbPath(ProdRoot)
  else
    DbTarget := MmpGlobalCentralLogDbPath;

  MmpDbAddCentralLog(DbTarget, ProdId, Lvl, AppName, UserName, ActionName, RevId, Msg, '');
end;

function StripMarkdownJsonFence(const Raw: string): string;
var
  S: string;
  P1, P2: SizeInt;
begin
  S := Trim(Raw);
  if Copy(S, 1, 3) = '```' then
  begin
    P1 := Pos(#10, S);
    if P1 > 0 then
      Delete(S, 1, P1);
    P2 := LastDelimiter('`', S);
    if (P2 > 3) and (Copy(S, P2 - 2, 3) = '```') then
      S := Copy(S, 1, P2 - 3);
  end;
  Result := Trim(S);
end;

function SavePlaceholderBitmap(const FilePath, Title, Subtitle, Footer: string;
  BgColor: TColor; WidthPx: Integer; HeightPx: Integer): Boolean;
var
  Bmp: Graphics.TBitmap;
  Dir: string;
begin
  Result := False;
  Dir := ExtractFileDir(FilePath);
  if Dir <> '' then ForceDirectories(Dir);

  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.SetSize(WidthPx, HeightPx);
    Bmp.Canvas.Brush.Color := BgColor;
    Bmp.Canvas.FillRect(0, 0, WidthPx, HeightPx);

    Bmp.Canvas.Pen.Color := clWhite;
    Bmp.Canvas.Pen.Width := 2;
    Bmp.Canvas.Brush.Style := bsClear;
    Bmp.Canvas.Rectangle(12, 12, WidthPx - 12, HeightPx - 12);

    Bmp.Canvas.Font.Color := clWhite;
    Bmp.Canvas.Font.Size := 16;
    Bmp.Canvas.Font.Style := [fsBold];
    Bmp.Canvas.TextOut(28, 30, Title);

    Bmp.Canvas.Font.Size := 11;
    Bmp.Canvas.Font.Style := [];
    Bmp.Canvas.Font.Color := $00E0E0E0;
    Bmp.Canvas.TextOut(28, 72, Copy(Subtitle, 1, 80));

    Bmp.Canvas.Font.Size := 9;
    Bmp.Canvas.Font.Color := $00B0D8FF;
    Bmp.Canvas.TextOut(28, HeightPx - 42, Footer);

    Bmp.SaveToFile(FilePath);
    Result := FileExists(FilePath);
  finally
    Bmp.Free;
  end;
end;

procedure MmpPrepareAligned(C: TControl);
var
  P: TWinControl;
  R: TRect;
  I: Integer;
  Sib: TControl;
begin
  if (C = nil) or (C.Parent = nil) or (C.Align = alNone) or (C.Align = alCustom) then Exit;
  P := C.Parent;
  R := Rect(0, 0, P.ClientWidth, P.ClientHeight);
  for I := 0 to P.ControlCount - 1 do
  begin
    Sib := P.Controls[I];
    if Sib = C then Break;
    if not Sib.Visible then Continue;
    case Sib.Align of
      alTop: Inc(R.Top, Sib.Height);
      alBottom: Dec(R.Bottom, Sib.Height);
      alLeft: Inc(R.Left, Sib.Width);
      alRight: Dec(R.Right, Sib.Width);
    else
    end;
  end;
  if R.Right < R.Left then R.Right := R.Left;
  if R.Bottom < R.Top then R.Bottom := R.Top;
  case C.Align of
    alTop: C.SetBounds(R.Left, R.Top, R.Right - R.Left, C.Height);
    alBottom: C.SetBounds(R.Left, R.Bottom - C.Height, R.Right - R.Left, C.Height);
    alLeft: C.SetBounds(R.Left, R.Top, C.Width, R.Bottom - R.Top);
    alRight: C.SetBounds(R.Right - C.Width, R.Top, C.Width, R.Bottom - R.Top);
    alClient: C.SetBounds(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
  else
  end;
end;

procedure MmpPrepareTabSheet(Tab: TControl);
const
  TAB_HEADER = 28;
  TAB_BORDER = 4;
var
  P: TWinControl;
begin
  if (Tab = nil) or (Tab.Parent = nil) then Exit;
  P := Tab.Parent;
  Tab.SetBounds(TAB_BORDER, TAB_HEADER, P.Width - 2 * TAB_BORDER,
    P.Height - TAB_HEADER - TAB_BORDER);
end;

{$IFDEF WINDOWS}
var
  GSingleInstanceMutex: THandle = 0;
  GEnumTargetPrefix: string = '';
  GEnumFoundWnd: HWND = 0;

function SingleInstanceMutexName(App: TMMApp): string;
begin
  Result := 'Local\MaurinMovie_' + LowerCase(MMAppNames[App]) + '_SingleInstance';
end;

function EnumAppWindowProc(Wnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  Buf: array[0..511] of Char;
  Title: string;
begin
  Result := True;
  if not IsWindowVisible(Wnd) then Exit;
  Buf[0] := #0;
  if GetWindowTextA(Wnd, @Buf[0], SizeOf(Buf)) > 0 then
  begin
    Title := LowerCase(StrPas(@Buf[0]));
    if (Pos(GEnumTargetPrefix, Title) = 1) and (Pos('maurinmovie', Title) > 0) then
    begin
      GEnumFoundWnd := Wnd;
      Result := False;
    end;
  end;
  if lParam <> 0 then;
end;

function IsAppInstanceRunning(App: TMMApp): Boolean;
var
  H: THandle;
begin
  H := OpenMutexA(SYNCHRONIZE, False, PChar(SingleInstanceMutexName(App)));
  if H <> 0 then
  begin
    CloseHandle(H);
    Result := True;
  end
  else
    Result := False;
end;

function FocusAppInstanceWindow(App: TMMApp): Boolean;
begin
  Result := False;
  GEnumTargetPrefix := LowerCase(MMAppNames[App]) + ' - ';
  GEnumFoundWnd := 0;
  EnumWindows(@EnumAppWindowProc, 0);
  if GEnumFoundWnd <> 0 then
  begin
    if IsIconic(GEnumFoundWnd) then
      ShowWindow(GEnumFoundWnd, SW_RESTORE);
    SetForegroundWindow(GEnumFoundWnd);
    Result := True;
  end;
end;

function RequireSingleAppInstance(App: TMMApp; IsHeadless: Boolean): Boolean;
var
  H: THandle;
  LastErr: DWORD;
  Focused: Boolean;
  Msg: string;
begin
  if GSingleInstanceMutex <> 0 then
    Exit(True);

  H := CreateMutexA(nil, False, PChar(SingleInstanceMutexName(App)));
  LastErr := GetLastError;
  if H = 0 then
    Exit(True);

  if LastErr = ERROR_ALREADY_EXISTS then
  begin
    CloseHandle(H);
    Focused := False;
    if not IsHeadless then
      Focused := FocusAppInstanceWindow(App);
    Msg := 'O aplicativo ' + MMAppNames[App] + ' ja esta em execucao (permitida apenas 1 instancia).';
    if IsHeadless then
      WriteCliLine('[ERRO] ' + Msg)
    else if not Focused then
    begin
      Application.Scaled := True;
      Application.Initialize;
      Application.MessageBox(
        PChar(Msg),
        PChar(MMAppNames[App] + ' - Instancia Unica'),
        MB_OK or MB_ICONINFORMATION);
    end;
    Exit(False);
  end;

  GSingleInstanceMutex := H;
  Result := True;
end;

procedure ReleaseSingleAppInstance;
begin
  if GSingleInstanceMutex <> 0 then
  begin
    CloseHandle(GSingleInstanceMutex);
    GSingleInstanceMutex := 0;
  end;
end;
{$ELSE}
var
  GSingleInstanceFd: cint = -1;

function SingleInstanceLockPath(App: TMMApp): string;
begin
  Result := '/tmp/maurinmovie_' + LowerCase(MMAppNames[App]) + '.instance.lock';
end;

function IsAppInstanceRunning(App: TMMApp): Boolean;
var
  Fd: cint;
begin
  Result := False;
  Fd := FpOpen(SingleInstanceLockPath(App), O_RDONLY);
  if Fd < 0 then Exit;
  try
    if FpFlock(Fd, LOCK_EX or LOCK_NB) <> 0 then
      Result := True
    else
      FpFlock(Fd, LOCK_UN);
  finally
    FpClose(Fd);
  end;
end;

function FocusAppInstanceWindow(App: TMMApp): Boolean;
begin
  if App = maMMenu then;
  Result := False;
end;

function RequireSingleAppInstance(App: TMMApp; IsHeadless: Boolean): Boolean;
var
  Fd: cint;
  Msg: string;
begin
  if GSingleInstanceFd >= 0 then
    Exit(True);
  Fd := FpOpen(SingleInstanceLockPath(App), O_CREAT or O_RDWR, &644);
  if Fd < 0 then
    Exit(True);
  if FpFlock(Fd, LOCK_EX or LOCK_NB) <> 0 then
  begin
    FpClose(Fd);
    Msg := 'O aplicativo ' + MMAppNames[App] + ' ja esta em execucao (permitida apenas 1 instancia).';
    if IsHeadless then
      WriteCliLine('[ERRO] ' + Msg)
    else
    begin
      Application.Scaled := True;
      Application.Initialize;
      Application.MessageBox(
        PChar(Msg),
        PChar(MMAppNames[App] + ' - Instancia Unica'),
        MB_OK or MB_ICONINFORMATION);
    end;
    Exit(False);
  end;
  GSingleInstanceFd := Fd;
  Result := True;
end;

procedure ReleaseSingleAppInstance;
begin
  if GSingleInstanceFd >= 0 then
  begin
    FpFlock(GSingleInstanceFd, LOCK_UN);
    FpClose(GSingleInstanceFd);
    GSingleInstanceFd := -1;
  end;
end;
{$ENDIF}

initialization

finalization
  ReleaseSingleAppInstance;

end.
