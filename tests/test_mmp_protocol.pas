program test_mmp_protocol;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  mmpcommon, mmpsettings, ummpsha256, ummpdb, ummpprotocol;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure AssertTrue(Cond: Boolean; const Name: string);
begin
  if Cond then
  begin
    Inc(PassCount);
    WriteLn('[PASS] ', Name);
  end
  else
  begin
    Inc(FailCount);
    WriteLn('[FAIL] ', Name);
  end;
end;

procedure AssertEq(const Got, Expected, Name: string);
begin
  if Got = Expected then
  begin
    Inc(PassCount);
    WriteLn('[PASS] ', Name);
  end
  else
  begin
    Inc(FailCount);
    WriteLn('[FAIL] ', Name, ' | got="', Got, '" expected="', Expected, '"');
  end;
end;

procedure RemoveDirRecursive(const Dir: string);
var
  SR: TSearchRec;
  Full: string;
begin
  if not DirectoryExists(Dir) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        Full := IncludeTrailingPathDelimiter(Dir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          RemoveDirRecursive(Full)
        else
          DeleteFile(Full);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  RemoveDir(Dir);
end;

procedure TestSHA256;
var
  TmpFile: string;
begin
  AssertEq(SHA256String(''),
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'SHA256 empty string');
  AssertEq(SHA256String('abc'),
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'SHA256 "abc"');
  AssertEq(SHA256String('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    'SHA256 448-bit NIST vector');

  TmpFile := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_sha_test.txt';
  AssertTrue(AtomicWriteTextFile(TmpFile, 'abc', False), 'Write temp file for SHA256File');
  AssertEq(SHA256File(TmpFile),
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'SHA256File("abc")');
  DeleteFile(TmpFile);
end;

procedure TestPathSafety;
var
  Full: string;
begin
  AssertTrue(IsSafeRelativePath('scripts/roteiro.json'), 'Safe relative path');
  AssertTrue(not IsSafeRelativePath('../outside.txt'), 'Reject parent traversal');
  AssertTrue(not IsSafeRelativePath('a/../../outside.txt'), 'Reject nested traversal');
  AssertTrue(not IsSafeRelativePath('/etc/passwd'), 'Reject leading slash');
  AssertTrue(not IsSafeRelativePath('C:\Windows\win.ini'), 'Reject drive path');
  AssertTrue(ResolveSafePath(GetTempDir, 'sub/file.txt', Full), 'ResolveSafePath inside base');
  AssertTrue(not ResolveSafePath(GetTempDir, '../escape.txt', Full), 'ResolveSafePath rejects escape');
end;

procedure TestProductionLifecycleAndAudit;
var
  TestRoot, ProdRoot, MovedRoot, ErrMsg, FoundDir: string;
  ScriptRevDir, ScriptFile, MovedFile, SyncDir, ManifestPath, ScriptProjBefore, ScriptProjAfter: string;
  FileHash: string;
  Prod: TMmpProduction;
  I: Integer;
  UniqueCheck: TStringList;
  ManifestObj, ArtObj, SyncObj: TJSONObject;
  ArtArr: TJSONArray;
  Args: TStringList;
  FoundCorrupt, FoundMoved: Boolean;
begin
  TestRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_test_suite';
  RemoveDirRecursive(TestRoot);
  ForceDirectories(TestRoot);
  try
    if not CreateProduction(TestRoot, 'Filme de Teste', ProdRoot, ErrMsg) then
      WriteLn('DEBUG CreateProduction ErrMsg: ', ErrMsg);
    AssertTrue(ProdRoot <> '', 'CreateProduction succeeds: ' + ErrMsg);
    AssertTrue(FileExists(ProdRoot + PathDelim + 'production.json'), 'production.json exists');
    AssertTrue(FileExists(ProdRoot + PathDelim + 'catalog.json'), 'catalog.json exists');
    AssertTrue(FileExists(ProdRoot + PathDelim + 'settings' + PathDelim + 'ai-providers.json'),
      'ai-providers.json exists');

    AssertTrue(LoadProduction(ProdRoot, True, Prod), 'LoadProduction initial');
    AssertEq(IntToStr(Length(Prod.Projects)), '7', 'All 7 projects loaded');
    AssertTrue(MmpProjectHasActivity(Prod.Projects[0]), 'MMenu has initial activity (1 visible record on create)');
    for I := 1 to 6 do
      AssertTrue(not MmpProjectHasActivity(Prod.Projects[I]),
        'Unused app ' + Prod.Projects[I].AppName + ' hidden until first revision');
    AssertTrue(not Prod.HasFailures, 'No initial failures');
    AssertEq(IntToStr(Length(Prod.MissingLinks)), '0', 'No initial missing links');

    UniqueCheck := TStringList.Create;
    try
      UniqueCheck.Sorted := True;
      UniqueCheck.Duplicates := dupIgnore;
      for I := 0 to High(Prod.Projects) do
        UniqueCheck.Add(Prod.Projects[I].ProjectId);
      AssertEq(IntToStr(UniqueCheck.Count), '7', 'All 7 project_ids are unique');
    finally
      UniqueCheck.Free;
    end;

    // Add a valid artifact and a moved artifact to MScript manifest to test audit
    ScriptRevDir := ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' +
      PathDelim + 'revisions' + PathDelim + 'r0001';
    ScriptFile := ScriptRevDir + PathDelim + 'scripts' + PathDelim + 'roteiro.md';
    AssertTrue(AtomicWriteTextFile(ScriptFile, '# Cena 1', False), 'Write roteiro.md');
    FileHash := SHA256File(ScriptFile);

    MovedFile := ProdRoot + PathDelim + 'shared' + PathDelim + 'imports' +
      PathDelim + 'a_moved01_backup.txt';
    AssertTrue(AtomicWriteTextFile(MovedFile, 'conteudo movido', False), 'Write moved artifact');

    ManifestPath := ScriptRevDir + PathDelim + 'manifest.json';
    AssertTrue(ReadTextFileUtf8(ManifestPath, ScriptProjBefore), 'Read manifest');
    ManifestObj := TJSONObject(GetJSON(ScriptProjBefore));
    try
      ArtArr := TJSONArray(ManifestObj.Find('artifacts'));

      ArtObj := TJSONObject.Create;
      ArtObj.Add('artifact_id', 'a_script01');
      ArtObj.Add('kind', 'script.scene');
      ArtObj.Add('scene_id', 'sc_0001');
      ArtObj.Add('uri', 'scripts/roteiro.md');
      ArtObj.Add('mime_type', 'text/markdown');
      ArtObj.Add('sha256', FileHash);
      ArtObj.Add('bytes', 8);
      ArtObj.Add('status', 'approved');
      ArtArr.Add(ArtObj);

      ArtObj := TJSONObject.Create;
      ArtObj.Add('artifact_id', 'a_moved01');
      ArtObj.Add('kind', 'script.dialogue');
      ArtObj.Add('scene_id', 'sc_0001');
      ArtObj.Add('uri', 'scripts/moved_missing.txt');
      ArtObj.Add('mime_type', 'text/plain');
      ArtObj.Add('sha256', SHA256File(MovedFile));
      ArtObj.Add('bytes', 15);
      ArtObj.Add('status', 'approved');
      ArtArr.Add(ArtObj);

      AssertTrue(AtomicWriteTextFile(ManifestPath, ManifestObj.FormatJSON, False),
        'Update test manifest');
    finally
      ManifestObj.Free;
    end;

    // Corrupt roteiro.md after recording original hash
    AssertTrue(AtomicWriteTextFile(ScriptFile, '# Cena 1 ALTERADA', False),
      'Tamper roteiro.md to test SHA256 mismatch');

    // Add a failed sync job
    SyncDir := ProdRoot + PathDelim + 'shared' + PathDelim + 'sync';
    SyncObj := TJSONObject.Create;
    try
      SyncObj.Add('event_id', 'evt_001');
      SyncObj.Add('production_id', Prod.ProductionId);
      SyncObj.Add('origin_app', 'MBoard');
      SyncObj.Add('target_app', 'MScene');
      SyncObj.Add('project_id', Prod.Projects[5].ProjectId);
      SyncObj.Add('source_revision', 'r0001');
      SyncObj.Add('stage', 'MScene');
      SyncObj.Add('status', 'failed');
      SyncObj.Add('error', 'Falha ao gerar segmento sg_0001');
      AssertTrue(AtomicWriteTextFile(SyncDir + PathDelim + 'evt_001.json',
        SyncObj.FormatJSON, False), 'Write failed sync job');
    finally
      SyncObj.Free;
    end;

    AssertTrue(ReadTextFileUtf8(
      ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' + PathDelim + 'project.json',
      ScriptProjBefore), 'Read MScript project.json before MMenu actions');

    AssertTrue(LoadProduction(ProdRoot, True, Prod), 'Reload production with audit');
    AssertTrue(Prod.HasFailures, 'HasFailures is True when hash mismatches and sync failed');
    AssertTrue(Pos('nao concluido', LowerCase(Prod.OverallStatusText)) > 0,
      'OverallStatusText does not falsely declare completion');
    AssertEq(IntToStr(Length(Prod.SyncJobs)), '1', 'Sync job loaded');
    AssertEq(Prod.SyncJobs[0].Stage, 'MScene', 'Failed sync stage preserved');

    FoundCorrupt := False;
    FoundMoved := False;
    for I := 0 to High(Prod.MissingLinks) do
    begin
      if (Prod.MissingLinks[I].TargetId = 'a_script01') and
         (Prod.MissingLinks[I].Status = 'hash_mismatch') then
        FoundCorrupt := True;
      if (Prod.MissingLinks[I].TargetId = 'a_moved01') and
         (Prod.MissingLinks[I].Status = 'resolved_by_id') then
        FoundMoved := True;
    end;
    AssertTrue(FoundCorrupt, 'Corrupted artifact detected via SHA-256 mismatch');
    AssertTrue(FoundMoved, 'Moved artifact resolved by ID without silent overwrite');

    AssertTrue(RebuildCatalog(Prod, ErrMsg), 'RebuildCatalog succeeds: ' + ErrMsg);
    AssertTrue(FileExists(ProdRoot + PathDelim + 'catalog.json.bak'),
      'RebuildCatalog preserves backup');

    AssertTrue(ReadTextFileUtf8(
      ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' + PathDelim + 'project.json',
      ScriptProjAfter), 'Read MScript project.json after MMenu actions');
    AssertEq(ScriptProjAfter, ScriptProjBefore,
      'MMenu never overwrites MScript project.json');

    // Test locating moved production folder by production_id
    MovedRoot := TestRoot + PathDelim + 'pasta_movida';
    AssertTrue(RenameFile(ProdRoot, MovedRoot), 'Move production folder');
    AssertTrue(FindProductionByIdInDir(TestRoot, Prod.ProductionId, FoundDir),
      'FindProductionByIdInDir locates moved production');
    AssertEq(ExcludeTrailingPathDelimiter(FoundDir),
      ExcludeTrailingPathDelimiter(MovedRoot), 'Located path matches moved folder');

    // Test launch args builder with MMenu context and version
    Args := TStringList.Create;
    try
      BuildLaunchArgs(MovedRoot, 'pr_script_01', 'r0002', Args, 'p_test_01');
      AssertEq(IntToStr(Args.Count), '12', 'BuildLaunchArgs emits 12 tokens with launcher context');
      AssertEq(Args[0], '--launcher', 'Arg 0 is --launcher');
      AssertEq(Args[1], 'mmenu', 'Arg 1 is mmenu');
      AssertEq(Args[2], '--mmenu-version', 'Arg 2 is --mmenu-version');
      AssertEq(Args[3], MAURINMOVIE_VERSION, 'Arg 3 is version');
      AssertEq(Args[4], '--production', 'Arg 4 is --production');
      AssertEq(Args[5], MovedRoot, 'Arg 5 is root dir');
      AssertEq(Args[6], '--production-id', 'Arg 6 is --production-id');
      AssertEq(Args[7], 'p_test_01', 'Arg 7 is production_id');
      AssertEq(Args[8], '--project-id', 'Arg 8 is --project-id');
      AssertEq(Args[9], 'pr_script_01', 'Arg 9 is project_id');
      AssertEq(Args[10], '--revision', 'Arg 10 is --revision');
      AssertEq(Args[11], 'r0002', 'Arg 11 is revision_id');
    finally
      Args.Free;
    end;
  finally
    RemoveDirRecursive(TestRoot);
  end;
end;

procedure TestSpecs020;
var
  TestRoot, ProdRoot, ErrMsg, LockInfo, SampleFile, SampleHash, BadFile: string;
  Settings: TMMSettings;
  Prov: TMmpAiProviderCfg;
  Prod: TMmpProduction;
  TxObj, EvtObj: TJSONObject;
begin
  AssertTrue(IsValidRevisionId('r0001'), 'IsValidRevisionId r0001');
  AssertTrue(not IsValidRevisionId('r1'), 'IsValidRevisionId rejects r1');

  TestRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_specs_020_test';
  RemoveDirRecursive(TestRoot);
  ForceDirectories(TestRoot);
  try
    AssertTrue(CreateProduction(TestRoot, 'Filme Specs 020', ProdRoot, ErrMsg),
      'CreateProduction with centralized settings: ' + ErrMsg);
    AssertTrue(FileExists(ProdRoot + PathDelim + 'settings' + PathDelim + 'apps.json'),
      'settings/apps.json created');
    AssertTrue(FileExists(ProdRoot + PathDelim + 'settings' + PathDelim + 'policies.json'),
      'settings/policies.json created');
    AssertTrue(FileExists(ProdRoot + PathDelim + 'settings' + PathDelim + 'media-profiles.json'),
      'settings/media-profiles.json created');
    AssertTrue(FileExists(ProdRoot + PathDelim + 'settings' + PathDelim + 'presets.json'),
      'settings/presets.json created');
    AssertTrue(DirectoryExists(ProdRoot + PathDelim + 'shared' + PathDelim + 'events' + PathDelim + 'inbox' + PathDelim + 'MScript'),
      'shared/events/inbox/MScript created');
    AssertTrue(DirectoryExists(ProdRoot + PathDelim + 'shared' + PathDelim + 'transactions'),
      'shared/transactions created');

    Settings := TMMSettings.Create;
    try
      Settings.Load(ProdRoot, maMScript);
      AssertTrue(Settings.ResolveProvider('text', maMScript, Prov), 'ResolveProvider text for MScript');
      AssertEq(Prov.Adapter, 'mock', 'Default provider adapter is mock');
      AssertTrue(Settings.SettingsSha256 <> '', 'SettingsSha256 computed');
    finally
      Settings.Free;
    end;

    // Test lock
    AssertTrue(AcquireProjectLock(ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript',
      'MScript', 'gui', ErrMsg), 'AcquireProjectLock succeeds');
    AssertTrue(IsProjectLocked(ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript', LockInfo),
      'IsProjectLocked detects active lock');
    ReleaseProjectLock(ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript');
    AssertTrue(not IsProjectLocked(ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript', LockInfo),
      'ReleaseProjectLock clears lock');

    // Test transaction + inbox event scanning
    TxObj := TJSONObject.Create;
    try
      TxObj.Add('schema', MMP_SCHEMA_TX);
      TxObj.Add('transaction_id', 'tx_test_01');
      TxObj.Add('status', 'failed');
      AtomicWriteTextFile(ProdRoot + PathDelim + 'shared' + PathDelim + 'transactions' +
        PathDelim + 'tx_test_01.json', TxObj.FormatJSON, False);
    finally
      TxObj.Free;
    end;
    EvtObj := TJSONObject.Create;
    try
      EvtObj.Add('schema', MMP_SCHEMA_EVENT);
      EvtObj.Add('event_id', 'evt_test_01');
      EvtObj.Add('origin_app', 'MBoard');
      EvtObj.Add('target_app', 'MScript');
      EvtObj.Add('status', 'queued');
      AtomicWriteTextFile(ProdRoot + PathDelim + 'shared' + PathDelim + 'events' +
        PathDelim + 'inbox' + PathDelim + 'MScript' + PathDelim + 'evt_test_01.json',
        EvtObj.FormatJSON, False);
    finally
      EvtObj.Free;
    end;

    AssertTrue(LoadProduction(ProdRoot, False, Prod), 'LoadProduction scans transactions and inbox');
    AssertEq(IntToStr(Length(Prod.SyncJobs)), '2', 'Both transaction and inbox event loaded');
    AssertTrue(Prod.HasFailures, 'Failed transaction sets HasFailures');

    // Test SHA-256 verified catalog relink
    SampleFile := ProdRoot + PathDelim + 'shared' + PathDelim + 'imports' + PathDelim + 'real.txt';
    BadFile := ProdRoot + PathDelim + 'shared' + PathDelim + 'imports' + PathDelim + 'wrong.txt';
    AtomicWriteTextFile(SampleFile, 'conteudo original', False);
    AtomicWriteTextFile(BadFile, 'conteudo diferente', False);
    SampleHash := SHA256File(SampleFile);

    AssertTrue(not SaveArtifactRelinkToCatalog(ProdRoot, 'a_rel_1', 'old/uri.txt',
      BadFile, SampleHash, ErrMsg), 'SaveArtifactRelinkToCatalog rejects wrong SHA-256');
    AssertTrue(SaveArtifactRelinkToCatalog(ProdRoot, 'a_rel_1', 'old/uri.txt',
      SampleFile, SampleHash, ErrMsg), 'SaveArtifactRelinkToCatalog accepts matching SHA-256');
  finally
    RemoveDirRecursive(TestRoot);
  end;
end;

procedure TestGenreAndDurationHms;
var
  Genres: TStringList;
  Sec: Int64;
begin
  Genres := TStringList.Create;
  try
    MmpPopulateGenreCombo(Genres);
    AssertTrue(Genres.Count >= 10, 'MmpPopulateGenreCombo populates standard genres');
    AssertTrue(Genres.IndexOf('Comercial / Publicitario') >= 0, 'Genres include Comercial / Publicitario');
  finally
    Genres.Free;
  end;

  AssertEq(MmpFormatDurationHms(0), '00:00:00', 'Format 0s');
  AssertEq(MmpFormatDurationHms(30), '00:00:30', 'Format 30s');
  AssertEq(MmpFormatDurationHms(600), '00:10:00', 'Format 600s');
  AssertEq(MmpFormatDurationHms(3661), '01:01:01', 'Format 3661s');
  AssertEq(MmpFormatDurationHms(-5), '00:00:00', 'Negative duration clamps to 00:00:00');

  AssertTrue(MmpTryParseDurationHms('00:00:30', Sec) and (Sec = 30), 'Parse 00:00:30');
  AssertTrue(MmpTryParseDurationHms('0:5:9', Sec) and (Sec = 309), 'Parse 0:5:9');
  AssertTrue(MmpTryParseDurationHms('02:30:00', Sec) and (Sec = 9000), 'Parse 02:30:00');
  AssertTrue(not MmpTryParseDurationHms('', Sec), 'Reject empty duration');
  AssertTrue(not MmpTryParseDurationHms('10', Sec), 'Reject minutes-only integer');
  AssertTrue(not MmpTryParseDurationHms('00:60:00', Sec), 'Reject MM >= 60');
  AssertTrue(not MmpTryParseDurationHms('00:10:60', Sec), 'Reject SS >= 60');
  AssertTrue(not MmpTryParseDurationHms('-01:00:00', Sec), 'Reject negative hours');
  AssertTrue(not MmpTryParseDurationHms('aa:bb:cc', Sec), 'Reject non-numeric duration');

  AssertEq(IntToStr(MmpParseDurationSecHms('00:00:45', 600)), '45', 'MmpParseDurationSecHms valid');
  AssertEq(IntToStr(MmpParseDurationSecHms('invalido', 600)), '600', 'MmpParseDurationSecHms fallback');

  AssertEq(IntToStr(RevisionVersionNumber('r0001')), '1', 'RevisionVersionNumber r0001 -> 1');
  AssertEq(IntToStr(RevisionVersionNumber('r0002')), '2', 'RevisionVersionNumber r0002 -> 2');
  AssertEq(IntToStr(RevisionVersionNumber('r0012')), '12', 'RevisionVersionNumber r0012 -> 12');
end;

procedure TestSharedSettingsDir;
var
  S: TMMSettings;
begin
  S := TMMSettings.Create;
  try
    AssertTrue(Pos('test_mmp_protocol', LowerCase(S.MachineIniPath)) = 0,
      'MachineIniPath is shared (not scoped to executable name)');
    AssertTrue(Pos('test_mmp_protocol', LowerCase(S.SecretsIniPath)) = 0,
      'SecretsIniPath is shared (not scoped to executable name)');
    AssertTrue(Pos('maurinmovie', LowerCase(S.SecretsIniPath)) > 0,
      'SecretsIniPath resides under MaurinMovie directory');
  finally
    S.Free;
  end;
end;

procedure TestIntegrityValidationOnOpen;
var
  TestRoot, ProdRoot, ErrMsg, BadJsonPath: string;
  Prod: TMmpProduction;
begin
  TestRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_integrity_open_test';
  RemoveDirRecursive(TestRoot);
  ForceDirectories(TestRoot);
  try
    AssertTrue(CreateProduction(TestRoot, 'Filme Integridade', ProdRoot, ErrMsg),
      'CreateProduction for integrity test');

    // Corrupt manifest.json in r0001 of MScript
    BadJsonPath := ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' +
      PathDelim + 'revisions' + PathDelim + 'r0001' + PathDelim + 'manifest.json';
    AtomicWriteTextFile(BadJsonPath, '{broken json', False);
    AssertTrue(LoadProduction(ProdRoot, True, Prod), 'LoadProduction loads with manifest error');
    AssertTrue(Prod.HasFailures, 'Corrupted manifest.json sets HasFailures');

    // Corrupt project.json of MVisual
    BadJsonPath := ProdRoot + PathDelim + 'projects' + PathDelim + '02-mvisual' +
      PathDelim + 'project.json';
    AtomicWriteTextFile(BadJsonPath, '{broken project', False);
    AssertTrue(LoadProduction(ProdRoot, True, Prod), 'LoadProduction detects broken project.json');
    AssertTrue(Prod.HasFailures, 'Corrupted project.json sets HasFailures');

    // Corrupt production.json schema/id -> LoadProduction returns False
    AtomicWriteTextFile(ProdRoot + PathDelim + 'production.json',
      '{"schema":"wrong/1","title":"X"}', False);
    AssertTrue(not LoadProduction(ProdRoot, True, Prod),
      'Invalid production.json schema/id rejected on open');
  finally
    RemoveDirRecursive(TestRoot);
  end;
end;

procedure TestStageDependenciesAndStaleness;
var
  TestRoot, ProdRoot, ErrMsg, ScriptProjPath, VisualProjPath, VisualRevDir: string;
  ScriptProjStr, VisualProjStr, ScriptManPath, VisualManPath, ScriptSha: string;
  Prod: TMmpProduction;
  Eval: TMmpStageStatus;
  PObj, MObj, SrcObj: TJSONObject;
  Arr: TJSONArray;
begin
  TestRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_stage_deps_test';
  RemoveDirRecursive(TestRoot);
  ForceDirectories(TestRoot);
  try
    AssertTrue(CreateProduction(TestRoot, 'Filme Etapas', ProdRoot, ErrMsg),
      'CreateProduction for stage deps test');
    AssertTrue(LoadProduction(ProdRoot, False, Prod), 'Load initial stage deps prod');

    Eval := MmpEvaluateStageStatus(Prod, 1);
    AssertTrue(Eval.CanOpen and (not Eval.HasActivity), 'MScript openable on fresh production');
    Eval := MmpEvaluateStageStatus(Prod, 2);
    AssertTrue(not Eval.CanOpen, 'MVisual blocked until MScript created');
    Eval := MmpEvaluateStageStatus(Prod, 6);
    AssertTrue(not Eval.CanOpen, 'MCut blocked until previous stages created');

    // Simulate MScript creating r0001 (status draft)
    ScriptProjPath := ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' + PathDelim + 'project.json';
    ReadTextFileUtf8(ScriptProjPath, ScriptProjStr);
    PObj := TJSONObject(GetJSON(ScriptProjStr));
    try
      PObj.Strings['status'] := 'draft';
      AtomicWriteTextFile(ScriptProjPath, PObj.FormatJSON, False);
    finally
      PObj.Free;
    end;

    ScriptManPath := ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' +
      PathDelim + 'revisions' + PathDelim + 'r0001' + PathDelim + 'manifest.json';
    ScriptSha := SHA256File(ScriptManPath);

    AssertTrue(LoadProduction(ProdRoot, False, Prod), 'Reload after MScript r0001');
    AssertTrue(MmpEvaluateStageStatus(Prod, 1).HasActivity, 'MScript has activity');
    AssertTrue(MmpEvaluateStageStatus(Prod, 2).CanOpen, 'MVisual unlocked after MScript');
    AssertTrue(not MmpEvaluateStageStatus(Prod, 3).CanOpen, 'MBoard still blocked before MVisual');

    // Simulate MVisual creating r0001 referencing MScript @ r0001
    VisualProjPath := ProdRoot + PathDelim + 'projects' + PathDelim + '02-mvisual' + PathDelim + 'project.json';
    ReadTextFileUtf8(VisualProjPath, VisualProjStr);
    PObj := TJSONObject(GetJSON(VisualProjStr));
    try
      PObj.Strings['status'] := 'draft';
      AtomicWriteTextFile(VisualProjPath, PObj.FormatJSON, False);
    finally
      PObj.Free;
    end;
    VisualRevDir := ProdRoot + PathDelim + 'projects' + PathDelim + '02-mvisual' +
      PathDelim + 'revisions' + PathDelim + 'r0001';
    VisualManPath := VisualRevDir + PathDelim + 'manifest.json';
    ReadTextFileUtf8(VisualManPath, ScriptProjStr);
    MObj := TJSONObject(GetJSON(ScriptProjStr));
    try
      Arr := TJSONArray(MObj.Find('sources'));
      SrcObj := TJSONObject.Create;
      SrcObj.Add('project_id', Prod.Projects[1].ProjectId);
      SrcObj.Add('revision_id', 'r0001');
      SrcObj.Add('manifest_sha256', ScriptSha);
      Arr.Add(SrcObj);
      AtomicWriteTextFile(VisualManPath, MObj.FormatJSON, False);
    finally
      MObj.Free;
    end;

    AssertTrue(LoadProduction(ProdRoot, False, Prod), 'Reload after MVisual r0001');
    AssertTrue(not MmpEvaluateStageStatus(Prod, 2).NeedsAdjustment,
      'MVisual up to date with MScript r0001');
    AssertTrue(MmpEvaluateStageStatus(Prod, 3).CanOpen,
      'MBoard unlocked after MScript + MVisual');

    // Now redo MScript -> r0002
    ReadTextFileUtf8(ScriptProjPath, ScriptProjStr);
    PObj := TJSONObject(GetJSON(ScriptProjStr));
    try
      PObj.Strings['active_revision'] := 'r0002';
      TJSONArray(PObj.Find('revision_history')).Add('r0002');
      AtomicWriteTextFile(ScriptProjPath, PObj.FormatJSON, False);
    finally
      PObj.Free;
    end;
    ForceDirectories(ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' +
      PathDelim + 'revisions' + PathDelim + 'r0002');
    AtomicWriteTextFile(ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' +
      PathDelim + 'revisions' + PathDelim + 'r0002' + PathDelim + 'manifest.json',
      '{"schema":"mmp.manifest/1","revision_id":"r0002","state":"draft","sources":[],"artifacts":[]}',
      False);

    AssertTrue(LoadProduction(ProdRoot, False, Prod), 'Reload after MScript redone to r0002');
    Eval := MmpEvaluateStageStatus(Prod, 2);
    AssertTrue(Eval.NeedsAdjustment, 'MVisual marked NeedsAdjustment when MScript redone to r0002');
    AssertTrue(Prod.HasPendingWork, 'Prod.HasPendingWork set when downstream stage needs adjustment');
  finally
    RemoveDirRecursive(TestRoot);
  end;
end;

procedure TestSceneVideoUnlocksCut;
var
  Prod: TMmpProduction;
  SceneFile: string;
  I: Integer;
begin
  WriteLn('== TestSceneVideoUnlocksCut ==');
  SceneFile := IncludeTrailingPathDelimiter(GetTempDir) + GenerateMmpId('mmp_stage_video');
  AssertTrue(AtomicWriteTextFile(SceneFile, 'fixture for file existence', False),
    'Create on-disk artifact fixture');
  try
    Prod.Loaded := True;
    SetLength(Prod.Projects, 7);
    for I := 0 to 5 do
    begin
      Prod.Projects[I].SoftwareIndex := I + 1;
      Prod.Projects[I].Status := 'approved';
    end;
    Prod.Projects[4].Status := 'initialized';
    Prod.Projects[6].SoftwareIndex := 5;
    Prod.Projects[6].SceneId := 'sc_demo';
    Prod.Projects[6].ActiveRevision := 'r0002';
    SetLength(Prod.Projects[6].Revisions, 1);
    with Prod.Projects[6].Revisions[0] do
    begin
      RevisionId := 'r0002';
      SetLength(Artifacts, 1);
      with Artifacts[0] do
      begin
        Kind := 'video.scene';
        Status := 'approved';
        MimeType := 'application/json';
        Sha256 := SHA256File(SceneFile);
        ResolvedPath := SceneFile;
      end;
      AssertTrue(not MmpEvaluateStageStatus(Prod, 6).CanOpen,
        'Legacy JSON scene cannot unlock MCut');
      Artifacts[0].MimeType := 'video/mp4';
      Artifacts[0].Status := 'generated';
      AssertTrue(not MmpEvaluateStageStatus(Prod, 6).CanOpen,
        'Unapproved scene video cannot unlock MCut');
      Artifacts[0].Status := 'approved';
      AssertTrue(MmpEvaluateStageStatus(Prod, 6).CanOpen,
        'An approved video in a per-scene project unlocks MCut');
      DeleteFile(SceneFile);
      AssertTrue(not MmpEvaluateStageStatus(Prod, 6).CanOpen,
        'Missing approved video cannot unlock MCut');
    end;
  finally
    if FileExists(SceneFile) then DeleteFile(SceneFile);
  end;
end;

procedure TestProductionHistory;
var
  TestRoot, ProdRoot, ErrMsg, ScriptProjPath, ScriptProjStr, Rev2Dir, RotPath: string;
  Prod: TMmpProduction;
  Hist: TMmpHistoryEntryArray;
  PObj: TJSONObject;
  I: Integer;
  FoundRev, FoundLog, FoundSync: Boolean;
begin
  WriteLn('== TestProductionHistory ==');
  TestRoot := GetTempDir(False) + 'mmp_test_hist_' + IntToStr(Random(100000));
  ForceDirectories(TestRoot);
  try
    AssertTrue(CreateProduction(TestRoot, 'Historia Teste', ProdRoot, ErrMsg),
      'CreateProduction for history test: ' + ErrMsg);
    AssertTrue(LoadProduction(ProdRoot, False, Prod), 'LoadProduction initial');
    Hist := MmpLoadProductionHistory(Prod);
    AssertTrue(Length(Hist) = 1, 'Fresh production has initial MMenu creation log entry');
    if Length(Hist) > 0 then
      AssertTrue(SameText(Hist[0].AppName, 'MMenu') and SameText(Hist[0].Kind, 'Log'),
        'Initial entry is MMenu creation log');

    // Add MScript r0002 with roteiro.json
    ScriptProjPath := ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' + PathDelim + 'project.json';
    ReadTextFileUtf8(ScriptProjPath, ScriptProjStr);
    PObj := TJSONObject(GetJSON(ScriptProjStr));
    try
      PObj.Strings['status'] := 'published';
      PObj.Strings['active_revision'] := 'r0002';
      TJSONArray(PObj.Find('revision_history')).Add('r0002');
      AtomicWriteTextFile(ScriptProjPath, PObj.FormatJSON, False);
    finally
      PObj.Free;
    end;

    Rev2Dir := ProdRoot + PathDelim + 'projects' + PathDelim + '01-mscript' +
      PathDelim + 'revisions' + PathDelim + 'r0002';
    ForceDirectories(Rev2Dir + PathDelim + 'scripts');
    RotPath := Rev2Dir + PathDelim + 'scripts' + PathDelim + 'roteiro.json';
    AtomicWriteTextFile(RotPath,
      '{"titulo":"Viagem ao Sul","genero":"Drama","duracao_alvo":125,"sinopse":"Jornada longa.","cenas":[{},{"x":1}],"personagens":[{}]}',
      False);
    AtomicWriteTextFile(Rev2Dir + PathDelim + 'manifest.json',
      '{"schema":"mmp.manifest/1","revision_id":"r0002","parent_revision_id":"r0001","state":"published","created_at":"2026-11-17T12:00:00Z","sources":[],"artifacts":[{"artifact_id":"art_r2","kind":"script","uri":"scripts/roteiro.json","status":"published"}]}',
      False);

    AppendJsonLogLine(ProdRoot, 'MScript', 'info', 'Sinopse salva em rascunho');
    ForceDirectories(ProdRoot + PathDelim + 'shared' + PathDelim + 'sync');
    AtomicWriteTextFile(ProdRoot + PathDelim + 'shared' + PathDelim + 'sync' + PathDelim + 'tx_hist.json',
      '{"event_id":"evt_hist","transaction_id":"tx_hist","origin_app":"MScript","target_app":"MVisual","source_revision":"r0002","stage":"awaiting_review","status":"in_progress","requested_change":"Atualizar visual","created_at":"2026-11-17T12:05:00Z"}',
      False);

    AssertTrue(LoadProduction(ProdRoot, False, Prod), 'Reload production with history');
    Hist := MmpLoadProductionHistory(Prod);
    AssertTrue(Length(Hist) >= 3, 'History aggregates revision, log and sync entries');

    FoundRev := False;
    FoundLog := False;
    FoundSync := False;
    for I := 0 to High(Hist) do
    begin
      if SameText(Hist[I].Kind, 'Revisao') and SameText(Hist[I].RevisionId, 'r0002') then
      begin
        FoundRev := True;
        AssertTrue(Pos('Viagem ao Sul', Hist[I].Summary) > 0, 'Revision summary includes roteiro title');
        AssertTrue(Pos('2 cena(s)', Hist[I].Summary) > 0, 'Revision summary includes scene count');
      end;
      if SameText(Hist[I].Kind, 'Log') and (Pos('Sinopse salva', Hist[I].Summary) > 0) then
        FoundLog := True;
      if SameText(Hist[I].Kind, 'Sincronizacao') and (Pos('Atualizar visual', Hist[I].Summary) > 0) then
        FoundSync := True;
      if I < High(Hist) then
        AssertTrue(Hist[I].Timestamp >= Hist[I + 1].Timestamp, 'History sorted newest-first');
    end;
    AssertTrue(FoundRev, 'Found enriched revision entry');
    AssertTrue(FoundLog, 'Found JSONL log entry');
    AssertTrue(FoundSync, 'Found sync entry');
  finally
    RemoveDirRecursive(TestRoot);
  end;
end;

procedure TestAccessControl;
var
  TestRoot, AccessFile, ErrMsg: string;
  S: TMMSettings;
  Users: TMmpAccessUserArray;
  Matched: TMmpAccessUser;
  I: Integer;
  HasDefaultUser: Boolean;
begin
  WriteLn('== TestAccessControl ==');
  TestRoot := GetTempDir(False) + 'mmp_test_acc_' + IntToStr(Random(100000));
  ForceDirectories(TestRoot);
  AccessFile := TestRoot + PathDelim + 'access-control.json';
  S := TMMSettings.Create;
  try
    S.LoadAccessControl(AccessFile);
    AssertTrue(S.AccessMode = amOpen, 'Default access mode is amOpen');
    Users := S.GetAccessUsers;
    AssertTrue(Length(Users) = 1, 'Only default ADMIN user exists initially');
    HasDefaultUser := False;
    for I := 0 to High(Users) do
      if Users[I].Profile = upUser then
        HasDefaultUser := True;
    AssertTrue(not HasDefaultUser, 'No default User profile user exists');

    AssertTrue(S.AuthenticateUser('ADMIN', '123456', Matched, ErrMsg), 'Default ADMIN/123456 authenticates');
    AssertTrue(Matched.Profile = upAdministrador, 'ADMIN profile is Administrador');
    AssertTrue(not S.AuthenticateUser('ADMIN', 'wrong', Matched, ErrMsg), 'Wrong password rejected');

    AssertTrue(not S.RemoveAccessUser('ADMIN', ErrMsg), 'Cannot remove last active Administrador');
    AssertTrue(S.AddOrUpdateAccessUser('operador1', upUser, 'senha1', True, False, ErrMsg),
      'Create User account operador1: ' + ErrMsg);
    AssertTrue(S.AuthenticateUser('operador1', 'senha1', Matched, ErrMsg), 'User operador1 authenticates');
    AssertTrue(Matched.Profile = upUser, 'operador1 profile is User');

    S.AccessMode := amRestricted;
    AssertTrue(S.SaveAccessControl(ErrMsg, AccessFile), 'Save restricted mode & users: ' + ErrMsg);

    S.LoadAccessControl(AccessFile);
    AssertTrue(S.AccessMode = amRestricted, 'Reloaded access mode is amRestricted');
    AssertTrue(Length(S.GetAccessUsers) = 2, 'Reloaded 2 users');
  finally
    S.Free;
    RemoveDirRecursive(TestRoot);
  end;
end;

procedure TestMachineAiSettingsPersistence;
var
  S: TMMSettings;
  Prov, OldTextProv: TMmpAiProviderCfg;
  ErrMsg: string;
  HadOld: Boolean;
begin
  WriteLn('== TestMachineAiSettingsPersistence ==');
  S := TMMSettings.Create;
  try
    HadOld := S.ResolveProvider('text', maMMenu, OldTextProv);
    FillChar(Prov, SizeOf(Prov), 0);
    Prov.Id := 'text.default';
    Prov.Kind := 'text';
    Prov.LabelText := 'OpenAI GPT Test';
    Prov.Adapter := 'chatgpt-lib';
    Prov.BaseUrl := 'https://api.openai.com/v1';
    Prov.Model := 'gpt-4o-mini';
    Prov.SecretRef := 'MAURINMOVIE_TEXT_KEY';
    Prov.Enabled := True;
    Prov.Temperature := 0.5;
    Prov.MaxTokens := 4096;
    S.SetOrAddProvider(Prov, True);
    AssertTrue(S.SaveMachineAiSettings(ErrMsg), 'SaveMachineAiSettings without active production: ' + ErrMsg);
  finally
    S.Free;
  end;

  S := TMMSettings.Create;
  try
    AssertTrue(S.ResolveProvider('text', maMScript, Prov), 'ResolveProvider picks persisted machine text AI');
    AssertEq('chatgpt-lib', Prov.Adapter, 'Persisted machine adapter matches chatgpt-lib');
    AssertEq('gpt-4o-mini', Prov.Model, 'Persisted machine model matches gpt-4o-mini');
    if HadOld then
    begin
      S.SetOrAddProvider(OldTextProv, True);
      S.SaveMachineAiSettings(ErrMsg);
    end;
  finally
    S.Free;
  end;
end;

procedure TestSqliteTemplateMediaAndCentralLogs;
var
  TestRoot, ProdRoot, ErrMsg, TplPath, SrcImg, RelMedia: string;
  Prod: TMmpProduction;
  Projs: TMmpDbProjectArray;
  DbArt: TMmpDbMediaAssetRow;
  Assets: TMmpDbMediaAssetArray;
  Logs: TMmpCentralLogArray;
  EmptyProjs: TMmpDbProjectArray;
begin
  WriteLn('== TestSqliteTemplateMediaAndCentralLogs ==');
  TestRoot := GetTempDir(False) + 'mmp_test_db_' + IntToStr(Random(100000));
  ForceDirectories(TestRoot);
  try
    AssertTrue(MmpEnsureEmptyTemplateDb(TplPath, ErrMsg), 'Ensure empty template DB: ' + ErrMsg);
    AssertTrue(FileExists(TplPath), 'Blank template DB file exists');
    AssertTrue(DbFileSizeBytes(TplPath) >= 4096, 'Blank template DB has valid SQLite schema pages');

    AssertTrue(CreateProduction(TestRoot, 'Projeto SQLite', ProdRoot, ErrMsg),
      'CreateProduction with SQLite template: ' + ErrMsg);
    AssertTrue(FileExists(MmpProductionDbPath(ProdRoot)), 'maurinmovie.db copied to local production repo');
    AssertTrue(DirectoryExists(ProdRoot + PathDelim + 'media' + PathDelim + 'images'), 'media/images folder created');
    AssertTrue(DirectoryExists(ProdRoot + PathDelim + 'media' + PathDelim + 'voices'), 'media/voices folder created');
    AssertTrue(DirectoryExists(ProdRoot + PathDelim + 'media' + PathDelim + 'audios'), 'media/audios folder created');
    AssertTrue(DirectoryExists(ProdRoot + PathDelim + 'media' + PathDelim + 'videos'), 'media/videos folder created');

    Projs := MmpDbListProjects(ProdRoot);
    AssertTrue(Length(Projs) = 7, 'SQLite projects table populated with all 7 apps');

    // Store a component in media/images and register pointer in media_assets
    SrcImg := TestRoot + PathDelim + 'sample_hero.png';
    AtomicWriteTextFile(SrcImg, 'PNGFAKE', False);
    AssertTrue(MmpEnsureAssetStoredInMediaDir(
      ProdRoot, SrcImg, 'MVisual', '', 'r0002', 'character_sheet', 'image/png',
      'images/personagens/sample_hero.png', RelMedia), 'Copy asset into media/images');
    AssertTrue(Pos('media/images/', RelMedia) = 1, 'Relative path resides in media/images/');

    FillChar(DbArt, SizeOf(DbArt), 0);
    DbArt.ArtifactId := 'art_img_1';
    DbArt.ProductionId := Projs[0].ProductionId;
    DbArt.ProjectId := Projs[2].ProjectId;
    DbArt.RevisionId := 'r0002';
    DbArt.AppName := 'MVisual';
    DbArt.MediaCategory := 'images';
    DbArt.Kind := 'character_sheet';
    DbArt.RelativePath := RelMedia;
    DbArt.MimeType := 'image/png';
    DbArt.Status := 'draft';
    AssertTrue(MmpDbUpsertMediaAsset(ProdRoot, DbArt, ErrMsg), 'Upsert media asset in SQLite: ' + ErrMsg);

    Assets := MmpDbListMediaAssets(ProdRoot, 'images');
    AssertTrue(Length(Assets) = 1, 'Query media_assets by images category returns 1 row');
    AssertEq(RelMedia, Assets[0].RelativePath, 'SQLite points to project media/images/ file');

    // Centralized logging + resolution across apps
    AssertTrue(MmpDbAddCentralLog(MmpProductionDbPath(ProdRoot), Projs[0].ProductionId,
      'error', 'MScript', 'ADMIN', 'generate', 'r0002', 'Falha simulada teste', 'Detalhe x'),
      'Insert central log error');
    Logs := MmpDbListCentralLogs(MmpProductionDbPath(ProdRoot), 'MScript', 'error', '', 0, 50);
    AssertTrue(Length(Logs) = 1, 'Filter unresolved error logs for MScript');
    AssertTrue(MmpDbResolveCentralLog(MmpProductionDbPath(ProdRoot), Logs[0].Id,
      'ADMIN', 'Corrigido via teste', True), 'Mark central log as resolved');
    Logs := MmpDbListCentralLogs(MmpProductionDbPath(ProdRoot), 'MScript', 'error', '', 1, 50);
    AssertTrue(Length(Logs) = 1, 'Query resolved log entry');
    AssertTrue(Logs[0].Resolved, 'Resolved flag persisted');
    AssertEq('Corrigido via teste', Logs[0].ResolutionNote, 'Resolution note persisted');

    // Verify LoadProduction opens maurinmovie.db directly
    AssertTrue(LoadProduction(MmpProductionDbPath(ProdRoot), False, Prod), 'LoadProduction via maurinmovie.db');
    AssertEq(Projs[0].ProductionId, Prod.ProductionId, 'ProductionId matches from .db');
    if Length(EmptyProjs) > 0 then;
  finally
    RemoveDirRecursive(TestRoot);
  end;
end;

begin
  Randomize;
  TestSHA256;
  TestPathSafety;
  TestProductionLifecycleAndAudit;
  TestSpecs020;
  TestGenreAndDurationHms;
  TestSharedSettingsDir;
  TestIntegrityValidationOnOpen;
  TestStageDependenciesAndStaleness;
  TestSceneVideoUnlocksCut;
  TestProductionHistory;
  TestAccessControl;
  TestMachineAiSettingsPersistence;
  TestSqliteTemplateMediaAndCentralLogs;
  WriteLn('---');
  WriteLn(Format('Total: %d passed, %d failed.', [PassCount, FailCount]));
  if FailCount > 0 then
    Halt(1);
end.
