unit ummpcascade;

{$mode objfpc}{$H+}

interface

uses
  ummpprotocol;

function IsEditorialCascade(const TxPath: string): Boolean;
function AdvanceEditorialCascade(const Prod: TMmpProduction; const TxPath, ScriptExe: string;
  out NextApp: Integer; out Detail: string): Boolean;

implementation

uses
  Classes, SysUtils, Process, fpjson, jsonparser, mmpcommon, ummpappbase, ummpsha256;

function ReadObject(const FilePath: string): TJSONObject;
var
  Content: string;
  Data: TJSONData;
begin
  Result := nil;
  if not ReadTextFileUtf8(FilePath, Content) then Exit;
  try
    Data := GetJSON(Content);
    if Data is TJSONObject then Result := TJSONObject(Data) else Data.Free;
  except
    on EJSON do Exit;
  end;
end;

function IsEditorialCascade(const TxPath: string): Boolean;
var
  Tx: TJSONObject;
begin
  Tx := ReadObject(TxPath);
  try
    Result := Assigned(Tx) and (Tx.Get('workflow', '') = 'board.editorial_patch');
  finally
    Tx.Free;
  end;
end;

function HasExactSource(const Rev: TMmpRevisionInfo; const Project: TMmpProjectRef;
  const SourceRev: TMmpRevisionInfo): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Rev.Sources) do
    with Rev.Sources[I] do
      if (ProjectId = Project.ProjectId) and (RevisionId = SourceRev.RevisionId) and
        (ManifestSha256 <> '') and SameText(ManifestSha256, SourceRev.ManifestSha256) then Exit(True);
  Result := False;
end;

function HasVerifiedArtifact(const Rev: TMmpRevisionInfo; const ArtifactKind: string): Boolean;
var
  I: Integer;
  Found: Boolean;
begin
  Found := False;
  for I := 0 to High(Rev.Artifacts) do
    with Rev.Artifacts[I] do
      if Kind = ArtifactKind then
      begin
        if (Sha256 = '') or not FileExists(ResolvedPath) or
          not SameText(SHA256File(ResolvedPath), Sha256) then Exit(False);
        Found := True;
      end;
  Result := Found;
end;

function AdvanceEditorialCascade(const Prod: TMmpProduction; const TxPath, ScriptExe: string;
  out NextApp: Integer; out Detail: string): Boolean;
var
  Tx, Stage: TJSONObject;
  Stages: TJSONArray;
  ScriptProject, VisualProject, BoardProject: TMmpProjectRef;
  ScriptRev, VisualRev, BoardRev: TMmpRevisionInfo;
  Current: TMmpProduction;
  EventId, EventFile, Output: string;
  LaunchArgs: TStringList;
  Args: array of string;
  I: Integer;

  function FindScriptResult: Boolean;
  var
    R: Integer;
  begin
    for R := 0 to High(ScriptProject.Revisions) do
      if SameText(ScriptProject.Revisions[R].ChangeEventId, EventId) then
      begin
        ScriptRev := ScriptProject.Revisions[R];
        Exit(True);
      end;
    Result := False;
  end;

  procedure SetStage(Index: Integer; const Status, Revision: string);
  begin
    Stage := Stages.Objects[Index];
    Stage.Strings['status'] := Status;
    Stage.Strings['revision_id'] := Revision;
  end;

  function SaveStatus(const Status, ErrorText: string): Boolean;
  var
    Errors: TJSONArray;
  begin
    Tx.Strings['status'] := Status;
    Tx.Strings['updated_at'] := CurrentIsoUtc;
    Tx.Delete('errors');
    Errors := TJSONArray.Create;
    if ErrorText <> '' then Errors.Add(ErrorText);
    Tx.Add('errors', Errors);
    Result := AtomicWriteTextFile(TxPath, Tx.FormatJSON, True);
    if not Result then Detail := 'Não foi possível gravar o estado da transação.';
  end;

begin
  Result := False;
  NextApp := 0;
  Detail := '';
  Tx := ReadObject(TxPath);
  try
    if (Tx = nil) or (Tx.Get('workflow', '') <> 'board.editorial_patch') or
      not (Tx.Find('stages') is TJSONArray) or (TJSONArray(Tx.Find('stages')).Count <> 3) then
    begin
      Detail := 'Transação editorial inválida.';
      Exit;
    end;
    if (Tx.Get('status', '') = 'cancelled') or (Tx.Get('status', '') = 'complete') then
    begin
      Detail := 'A transação já está encerrada: ' + Tx.Get('status', '');
      Exit(True);
    end;
    Stages := TJSONArray(Tx.Find('stages'));
    EventId := Tx.Get('root_event_id', '');
    if not ResolveSafePath(Prod.RootDir, 'shared/events/inbox/MScript/' + EventId + '.json', EventFile) or
      (EventId = '') or (ExtractFileName(EventId) <> EventId) or
      not FindProjectByApp(Prod, 1, ScriptProject) then
    begin
      Detail := 'Não foi possível localizar o evento ou o projeto do roteiro.';
      Exit;
    end;

    Current := Prod;
    if not FindScriptResult then
    begin
      if not FileExists(EventFile) or (ScriptExe = '') then
        Detail := 'Evento ou executável do MScript não encontrado.'
      else if IsAppInstanceRunning(maMScript) then
        Detail := 'Feche o MScript para aplicar a correção sem sobrescrever edições abertas.'
      else
      begin
        LaunchArgs := TStringList.Create;
        try
          BuildLaunchArgs(Prod.RootDir, ScriptProject.ProjectId, ScriptProject.ActiveRevision,
            LaunchArgs, Prod.ProductionId);
          LaunchArgs.Add('--headless');
          LaunchArgs.Add('--event');
          LaunchArgs.Add(EventFile);
          SetLength(Args, LaunchArgs.Count);
          for I := 0 to LaunchArgs.Count - 1 do Args[I] := LaunchArgs[I];
          try
            if not RunCommand(ScriptExe, Args, Output, [poStderrToOutput, poNoConsole]) then
            begin
              Detail := Trim(Output);
              if Detail = '' then Detail := 'O MScript recusou a operação editorial.';
            end;
          except
            on E: Exception do Detail := E.Message;
          end;
        finally
          LaunchArgs.Free;
        end;
        if (Detail = '') and (not LoadProduction(Prod.RootDir, False, Current) or
          not FindProjectByApp(Current, 1, ScriptProject) or not FindScriptResult) then
          Detail := 'O MScript não publicou uma revisão vinculada ao evento.';
      end;
      if Detail <> '' then
      begin
        SetStage(0, 'failed', '');
        SaveStatus('failed', Detail);
        Exit;
      end;
    end;
    if (ScriptProject.ActiveRevision <> ScriptRev.RevisionId) or
      not HasVerifiedArtifact(ScriptRev, 'script.scene') then
    begin
      Detail := 'A revisão do roteiro aplicada nesta transação deixou de ser a ativa ou está inválida.';
      SetStage(0, 'failed', ScriptRev.RevisionId);
      SaveStatus('failed', Detail);
      Exit;
    end;
    SetStage(0, 'complete', ScriptRev.RevisionId);
    if not FindProjectByApp(Current, 2, VisualProject) or
      not FindRevisionInProject(VisualProject, VisualProject.ActiveRevision, VisualRev) or
      (VisualRev.State <> 'approved') or not HasExactSource(VisualRev, ScriptProject, ScriptRev) or
      not HasVerifiedArtifact(VisualRev, 'visual.entity.index') then
    begin
      SetStage(1, 'in_progress', '');
      NextApp := 2;
      Detail := 'Revise e publique a biblioteca no MVisual usando o roteiro ' + ScriptRev.RevisionId +
        '. Depois retome a transação no MMenu.';
      Exit(SaveStatus('in_progress', ''));
    end;
    SetStage(1, 'complete', VisualRev.RevisionId);
    if not FindProjectByApp(Current, 3, BoardProject) or
      not FindRevisionInProject(BoardProject, BoardProject.ActiveRevision, BoardRev) or
      (BoardRev.State <> 'approved') or not HasExactSource(BoardRev, ScriptProject, ScriptRev) or
      not HasExactSource(BoardRev, VisualProject, VisualRev) or
      not HasVerifiedArtifact(BoardRev, 'storyboard.segment') or
      not HasVerifiedArtifact(BoardRev, 'storyboard.frame') then
    begin
      SetStage(2, 'in_progress', '');
      NextApp := 3;
      Detail := 'Atualize e publique o storyboard no MBoard usando o roteiro ' + ScriptRev.RevisionId +
        ' e o visual ' + VisualRev.RevisionId + '. Depois retome a transação no MMenu.';
      Exit(SaveStatus('in_progress', ''));
    end;
    SetStage(2, 'complete', BoardRev.RevisionId);
    Detail := 'Sincronização concluída no storyboard ' + BoardRev.RevisionId + '.';
    Result := SaveStatus('complete', '');
  finally
    Tx.Free;
  end;
end;

end.
