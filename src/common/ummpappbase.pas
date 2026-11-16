unit ummpappbase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, fpjson, jsonparser,
  mmpcommon, ummpsha256, ummpprotocol;

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
procedure ParseAppLaunchParams(out ProductionRoot, ProjectId, RevisionId: string);

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
  out EventId: string): Boolean;

function StripMarkdownJsonFence(const Raw: string): string;

function SavePlaceholderBitmap(const FilePath, Title, Subtitle, Footer: string;
  BgColor: TColor; WidthPx: Integer = 640; HeightPx: Integer = 360): Boolean;

implementation

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

procedure ParseAppLaunchParams(out ProductionRoot, ProjectId, RevisionId: string);
var
  Args: TMMLaunchArgs;
begin
  Args := ParseLaunchArgs;
  ProductionRoot := Args.Production;
  ProjectId := Args.ProjectId;
  RevisionId := Args.Revision;
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
  NameBaseStr, SceneIdStr: string;
begin
  Result := False;
  NewRevId := '';
  ErrMsg := '';

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
        if Artifacts[I].ArtifactId <> '' then
          ArtObj.Add('artifact_id', Artifacts[I].ArtifactId)
        else
          ArtObj.Add('artifact_id', GenerateMmpId('a'));
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

    HistArr.Add(NewRevId);
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
    if not Result then
      ErrMsg := 'Falha ao atualizar project.json.';
  finally
    ProjObj.Free;
  end;
end;

function EmitSyncEvent(
  const ProdRoot, OriginApp, TargetApp, TargetProjectId,
  SourceRevision, RequestedChange, Stage, Status, ErrText: string;
  out EventId: string): Boolean;
var
  InboxDir, TxDir, EvtPath, TxPath, TxId, NowIso: string;
  Obj, ReqObj, TxObj, OrigObj, StageObj: TJSONObject;
  StagesArr, ErrArr: TJSONArray;
  AppIdx: Integer;
begin
  Result := False;
  NowIso := CurrentIsoUtc;
  EventId := GenerateMmpId('evt');
  TxId := GenerateMmpId('tx');

  InboxDir := IncludeTrailingPathDelimiter(ProdRoot) + 'shared' + PathDelim +
    'events' + PathDelim + 'inbox' + PathDelim + TargetApp;
  ForceDirectories(InboxDir);
  EvtPath := InboxDir + PathDelim + EventId + '.json';

  Obj := TJSONObject.Create;
  try
    Obj.Add('schema', MMP_SCHEMA_EVENT);
    Obj.Add('event_id', EventId);
    Obj.Add('transaction_id', TxId);
    Obj.Add('root_event_id', EventId);
    Obj.Add('origin_app', OriginApp);
    Obj.Add('target_app', TargetApp);
    Obj.Add('project_id', TargetProjectId);
    Obj.Add('source_revision', SourceRevision);
    ReqObj := TJSONObject.Create;
    ReqObj.Add('type', 'editorial_patch');
    ReqObj.Add('summary', RequestedChange);
    Obj.Add('requested_change', ReqObj);
    Obj.Add('stage', Stage);
    Obj.Add('idempotency_key', EventId + ':' + TargetApp);
    Obj.Add('status', Status);
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
    OrigObj := TJSONObject.Create;
    OrigObj.Add('application', OriginApp);
    OrigObj.Add('project_id', TargetProjectId);
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
    StagesArr.Add(StageObj);
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
  Bmp: TBitmap;
  Dir: string;
begin
  Result := False;
  Dir := ExtractFileDir(FilePath);
  if Dir <> '' then ForceDirectories(Dir);

  Bmp := TBitmap.Create;
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

end.
