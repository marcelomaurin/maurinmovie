program test_mmp_protocol;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  mmpcommon, mmpsettings, ummpsha256, ummpprotocol;

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
    AssertTrue(CreateProduction(TestRoot, 'Filme de Teste', ProdRoot, ErrMsg),
      'CreateProduction succeeds: ' + ErrMsg);
    AssertTrue(FileExists(ProdRoot + PathDelim + 'production.json'), 'production.json exists');
    AssertTrue(FileExists(ProdRoot + PathDelim + 'catalog.json'), 'catalog.json exists');
    AssertTrue(FileExists(ProdRoot + PathDelim + 'settings' + PathDelim + 'ai-providers.json'),
      'ai-providers.json exists');

    AssertTrue(LoadProduction(ProdRoot, True, Prod), 'LoadProduction initial');
    AssertEq(IntToStr(Length(Prod.Projects)), '7', 'All 7 projects loaded');
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

    // Test launch args builder
    Args := TStringList.Create;
    try
      BuildLaunchArgs(MovedRoot, 'pr_script_01', 'r0002', Args);
      AssertEq(IntToStr(Args.Count), '6', 'BuildLaunchArgs emits 6 tokens');
      AssertEq(Args[0], '--production', 'Arg 0 is --production');
      AssertEq(Args[1], MovedRoot, 'Arg 1 is root dir');
      AssertEq(Args[2], '--project-id', 'Arg 2 is --project-id');
      AssertEq(Args[3], 'pr_script_01', 'Arg 3 is project_id');
      AssertEq(Args[4], '--revision', 'Arg 4 is --revision');
      AssertEq(Args[5], 'r0002', 'Arg 5 is revision_id');
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

begin
  Randomize;
  TestSHA256;
  TestPathSafety;
  TestProductionLifecycleAndAudit;
  TestSpecs020;
  WriteLn('---');
  WriteLn(Format('Total: %d passed, %d failed.', [PassCount, FailCount]));
  if FailCount > 0 then
    Halt(1);
end.
