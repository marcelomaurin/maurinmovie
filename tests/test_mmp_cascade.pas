program test_mmp_cascade;

{$mode objfpc}{$H+}

uses
  Interfaces, SysUtils, fpjson, jsonparser, ummpprotocol, ummpappbase, ummpcascade, ummpeditorial;

procedure Check(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, Msg);
    Halt(1);
  end;
end;

var
  Root, ProdRoot, ErrorMsg, Detail, ScriptExe, EventId, TxPath, Content, ScriptId, NewScript: string;
  Prod: TMmpProduction;
  Script: TMmpProjectRef;
  Ops: TJSONArray;
  Srcs: array[0..1] of TMmpSourceRef;
  NextApp, I, CountBefore: Integer;
  Data: TJSONData;

procedure PublishFixture(AppIndex: Integer; const Kinds, Uris, Contents: array of string;
  const Sources: array of TMmpSourceRef);
var
  Proj: TMmpProjectRef;
  Arts: array of TMmpArtifactInput;
  Prepared, RevDir, NewRev: string;
  K: Integer;
begin
  Check(FindProjectByApp(Prod, AppIndex, Proj), 'Projeto não encontrado');
  Check(PrepareNextRevisionDir(Proj.ProjectFilePath, Prepared, RevDir), 'Reserva de revisão');
  SetLength(Arts, Length(Kinds));
  for K := 0 to High(Kinds) do
  begin
    Arts[K].Kind := Kinds[K];
    Arts[K].RelUri := Uris[K];
    Arts[K].MimeType := 'application/json';
    Arts[K].Status := 'approved';
    Check(AtomicWriteTextFile(RevDir + PathDelim + Uris[K], Contents[K], False), 'Escrita da fixture');
  end;
  Check(PublishProjectRevision(Prod.ProductionId, Proj.ProjectFilePath, Proj.AppName,
    Proj.ActiveRevision, 'approved', '', Sources, Arts, NewRev, ErrorMsg, Prepared), ErrorMsg);
  Check(LoadProduction(ProdRoot, False, Prod), 'Falha ao recarregar a produção.');
end;

function LinkedSource(AppIndex: Integer): TMmpSourceRef;
var
  Proj: TMmpProjectRef;
  Rev: TMmpRevisionInfo;
begin
  Check(FindProjectByApp(Prod, AppIndex, Proj), 'Fonte não encontrada');
  Check(FindRevisionInProject(Proj, Proj.ActiveRevision, Rev), 'Revisão não encontrada');
  Result := Default(TMmpSourceRef);
  Result.ProjectId := Proj.ProjectId;
  Result.RevisionId := Proj.ActiveRevision;
  Result.ManifestSha256 := Rev.ManifestSha256;
end;

begin
  Check(ParamCount = 2, 'Uso: test_mmp_cascade mscript pasta-vazia');
  Data := GetJSON('{"scenes":[{"scene_id":"a","action":"antes"}]}');
  Ops := TJSONArray(GetJSON('[{"scene_id":"a","operation":"set","from":"antes","to":"depois"},' +
    '{"scene_id":"ausente","operation":"set","from":"","to":"não pode"}]'));
  try
    Check(not ApplyEditorialOperations(TJSONObject(Data), Ops, ErrorMsg), 'Aceitou correção inválida.');
    Check(Data.FindPath('scenes[0].action').AsString = 'antes', 'Uma correção falha alterou o roteiro.');
  finally
    Ops.Free;
    Data.Free;
  end;
  ScriptExe := ExpandFileName(ParamStr(1));
  Root := ExpandFileName(ParamStr(2));
  Check(CreateProduction(Root, 'Teste de cascata editorial', ProdRoot, ErrorMsg), ErrorMsg);
  Check(LoadProduction(ProdRoot, False, Prod), 'Falha ao carregar a produção.');
  PublishFixture(1, ['script.scene'], ['scripts/roteiro.json'],
    ['{"scenes":[{"scene_id":"sc_a","action":"Entra.","dialogue_text":""},'+
    '{"scene_id":"sc_b","action":"Entra."}]}'], []);
  Check(FindProjectByApp(Prod, 1, Script), 'Roteiro não encontrado');
  ScriptId := Script.ProjectId;
  CountBefore := Length(Script.Revisions);
  Ops := TJSONArray(GetJSON('[{"scene_id":"sc_a","field":"dialogue_text","operation":"set","from":"",'+
    '"to":"Ana: Olá."}]'));
  try
    Check(EmitSyncEvent(ProdRoot, 'MBoard', 'MScript', ScriptId, Script.ActiveRevision,
      'Revisar diálogo', 'MScript', 'queued', '', EventId, Ops), 'Evento não emitido');
    Check(LoadProduction(ProdRoot, False, Prod), 'Transação não encontrada');
  finally
    Ops.Free;
  end;
  TxPath := '';
  for I := 0 to High(Prod.SyncJobs) do
    if IsEditorialCascade(Prod.SyncJobs[I].SourceFile) then TxPath := Prod.SyncJobs[I].SourceFile;
  Check(TxPath <> '', 'Caminho da transação não listado');
  Check(AdvanceEditorialCascade(Prod, TxPath, ScriptExe, NextApp, Detail), Detail);
  Check(NextApp = 2, 'Aguardando revisão visual após aplicar roteiro');
  Check(LoadProduction(ProdRoot, False, Prod), 'Não abriu após roteiro');
  Check(FindProjectByApp(Prod, 1, Script), 'Roteiro não encontrado após aplicação');
  NewScript := Script.ActiveRevision;
  Check(ReadTextFileUtf8(ExtractFileDir(Script.ProjectFilePath) + '/revisions/' + NewScript +
    '/scripts/roteiro.json', Content), 'Roteiro atualizado não encontrado');
  Data := GetJSON(Content);
  try
    Check(Data.FindPath('scenes[0].dialogue_text').AsString = 'Ana: Olá.', 'Fala não aplicada');
    Check(Data.FindPath('scenes[1].action').AsString = 'Entra.', 'Cena vizinha sofreu alteração');
  finally
    Data.Free;
  end;
  Check(AdvanceEditorialCascade(Prod, TxPath, ScriptExe, NextApp, Detail), Detail);
  Check(NextApp = 2, 'Repetição deveria manter a revisão visual pendente');
  Check(LoadProduction(ProdRoot, False, Prod), 'Não abriu após retomar');
  Check(FindProjectByApp(Prod, 1, Script) and (Length(Script.Revisions) = CountBefore + 1),
    'Retomar publicou roteiro em duplicidade');
  Srcs[0] := LinkedSource(1);
  PublishFixture(2, ['visual.entity.index'], ['indexes/entities.json'], ['{}'], Slice(Srcs, 1));
  Check(AdvanceEditorialCascade(Prod, TxPath, ScriptExe, NextApp, Detail), Detail);
  Check(NextApp = 3, 'Storyboard deveria aguardar aprovação');
  Srcs[1] := LinkedSource(2);
  PublishFixture(3, ['storyboard.segment'], ['scenes.json'], ['{}'], Srcs);
  Check(AdvanceEditorialCascade(Prod, TxPath, ScriptExe, NextApp, Detail), Detail);
  Check(NextApp = 3, 'Storyboard sem quadros não deveria encerrar a cascata');
  PublishFixture(3, ['storyboard.segment', 'storyboard.frame'],
    ['scenes.json', 'frame.txt'], ['{}', 'frame fixture'], Srcs);
  Check(AdvanceEditorialCascade(Prod, TxPath, ScriptExe, NextApp, Detail), Detail);
  Check(NextApp = 0, 'Cascata deveria estar concluída');
  Check(ReadTextFileUtf8(TxPath, Content) and (Pos('"complete"', Content) > 0), 'Estado não persistido');
  WriteLn('OK: execução real do MScript, escopo por cena, retomada idempotente e revisão das fontes.');
end.
