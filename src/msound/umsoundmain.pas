unit umsoundmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser,
  aivoicesynthesizer, aiaudioplayback,
  ummpprotocol, ummpappbase, ummpaibridge, ummpvideo, ummpdialogue,
  mmpcommon, mmpsettings, FileUtil, Math;

type
  TSoundProfileItem = record
    AssetId: string;
    Kind: string; // voice | effect
    EntityId: string;
    EntityName: string;
    Timbre: string;
    RateVal: Integer;
    VolumeVal: Integer;
    Permission: string;
    Status: string; // pending | approved | rejected
    PreviewUri: string;
  end;

  TSoundTimelineEvent = record
    SceneId, SegmentId: string;
    StartMs, EndMs, SceneDurationMs, SegmentStartMs, SegmentEndMs: Integer;
    AssetId: string;
    TextOrCue: string;
  end;

  TSoundPreview = record
    SceneId, SegmentId, RelUri, FilePath: string;
  end;

  TMsoundMainForm = class(TForm)
  private
    FAi: TMmpAiBridge;
    FSynth: TAIVoiceSynthesizer;
    FPlayer: TAIAudioPlayer;
    FProd: TMmpProduction;
    FProj: TMmpProjectRef;
    FScriptProj, FVisualProj, FBoardProj: TMmpProjectRef;
    FProjectDir: string;
    FCurrentRevId: string;
    FScriptRev, FBoardRev, FVisualRev: string;
    FPreviews: array of TSoundPreview;
    FProfiles: array of TSoundProfileItem;
    FEvents: array of TSoundTimelineEvent;
    FSelectedProfile: Integer;

    FHeaderProdLabel: TLabel;
    FHeaderSourceLabel: TLabel;
    FProfilesGrid: TStringGrid;
    FEventsGrid: TStringGrid;
    FTimbreEdit: TEdit;
    FRateEdit: TEdit;
    FVolEdit: TEdit;
    FPermEdit: TEdit;
    FTestPhraseEdit: TEdit;
    FLogMemo: TMemo;
    FStatusLabel: TLabel;

    procedure BuildUI;
    procedure LogMsg(const Msg: string);
    procedure LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
    procedure LoadSoundFromRevision(const RevId: string);
    procedure RefreshProfilesGrid;
    procedure RefreshEventsGrid;
    procedure LoadProfileToEditor(Idx: Integer);
    function ProfilesToJson: string;
    function ProfilePath(const RelUri: string): string;
    procedure AddPreview(const SceneId, SegmentId, FilePath: string);
    procedure InvalidatePreviews(const SceneId: string = '');
    procedure WriteToneWav(const FilePath: string; FreqHz, DurationMs: Integer);

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnBuildBankClick(Sender: TObject);
    procedure OnTestIsolatedClick(Sender: TObject);
    procedure OnStopAudioClick(Sender: TObject);
    procedure OnSaveProfileClick(Sender: TObject);
    procedure OnApproveProfileClick(Sender: TObject);
    procedure OnRehearseSceneClick(Sender: TObject);
    procedure OnPlayPreviewClick(Sender: TObject);
    procedure OnEditTimingClick(Sender: TObject);
    procedure OnAddEffectClick(Sender: TObject);
    procedure OnPublishClick(Sender: TObject);
    procedure OnProfilesGridSelection(Sender: TObject; aCol, aRow: Integer);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  msoundMainForm: TMsoundMainForm;

implementation

constructor TMsoundMainForm.Create(TheOwner: TComponent);
var
  ProdRoot, ProjId, RevId, MMenuVer, ProdId: string;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MSound - Identidade Vocal, Efeitos e Ensaio (MaurinMovie)';
  Width := 1200;
  Height := 760;
  Position := poScreenCenter;
  Constraints.MinWidth := 920;
  Constraints.MinHeight := 620;

  FAi := TMmpAiBridge.Create('MSound');
  FSynth := TAIVoiceSynthesizer.Create(Self);
  FPlayer := TAIAudioPlayer.Create(Self);
  FSelectedProfile := -1;
  BuildUI;

  ParseAppLaunchContext(ProdRoot, ProjId, RevId, MMenuVer, ProdId);
  LogMsg('MSound v' + MMP_EXECUTABLE_VERSION + ' iniciado (openai_voice + TAIUnifiedSound) | MMenu v' +
    MMenuVer + ' | Projeto: ' + ProjId);
  if ProdRoot <> '' then
    LoadProductionAndRevision(ProdRoot, ProjId, RevId);
end;

destructor TMsoundMainForm.Destroy;
begin
  FSynth.Stop;
  FPlayer.Stop;
  FAi.Free;
  inherited Destroy;
end;

procedure TMsoundMainForm.BuildUI;
var
  Head, Sidebar, Bottom, EditPanel, RehearsalActions: TPanel;
  PC: TPageControl;
  TabBank, TabRehearsal, TabLog: TTabSheet;
  BtnOpen, BtnAiCfg, BtnBuild, BtnTest, BtnStop, BtnSaveProf, BtnApprove, BtnRehearse, BtnPublish, BtnPlay, BtnTiming, BtnEffect: TButton;
  L: TLabel;
begin
  Head := TPanel.Create(Self); Head.Parent := Self; Head.Align := alTop; Head.Height := 68;
  Head.BevelOuter := bvNone; Head.Color := $003A3028; Head.ParentBackground := False;

  L := TLabel.Create(Self); L.Parent := Head; L.Caption := 'MaurinMovie  |  4 - MSound';
  L.Font.Size := 16; L.Font.Style := [fsBold]; L.Font.Color := clWhite; L.SetBounds(16, 10, 320, 26);

  FHeaderProdLabel := TLabel.Create(Self); FHeaderProdLabel.Parent := Head;
  FHeaderProdLabel.Caption := 'Nenhuma producao carregada'; FHeaderProdLabel.Font.Color := clWhite;
  FHeaderProdLabel.Font.Style := [fsBold]; FHeaderProdLabel.SetBounds(340, 12, 460, 20);

  FHeaderSourceLabel := TLabel.Create(Self); FHeaderSourceLabel.Parent := Head;
  FHeaderSourceLabel.Caption := 'Fontes 1..3: -'; FHeaderSourceLabel.Font.Color := $0099E6FF;
  FHeaderSourceLabel.SetBounds(340, 36, 520, 18);

  BtnAiCfg := TButton.Create(Self); BtnAiCfg.Parent := Head; BtnAiCfg.Caption := 'Alterar no MMenu...';
  BtnAiCfg.Anchors := [akTop, akRight]; BtnAiCfg.SetBounds(1062, 17, 122, 34);
  BtnAiCfg.OnClick := @OnAiConfigClick;

  BtnPublish := TButton.Create(Self); BtnPublish.Parent := Head; BtnPublish.Caption := 'Publicar Revisao';
  BtnPublish.Anchors := [akTop, akRight]; BtnPublish.SetBounds(914, 17, 140, 34);
  BtnPublish.OnClick := @OnPublishClick;

  Bottom := TPanel.Create(Self); Bottom.Parent := Self; Bottom.Align := alBottom; Bottom.Height := 34;
  Bottom.BevelOuter := bvLowered;
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Bottom; FStatusLabel.SetBounds(12, 9, 1100, 18);
  FStatusLabel.Caption := 'Pronto.';

  Sidebar := TPanel.Create(Self); Sidebar.Parent := Self; Sidebar.Align := alLeft; Sidebar.Width := 255;
  Sidebar.BevelOuter := bvNone; Sidebar.Color := $00EFEFEF; Sidebar.ParentBackground := False;

  BtnOpen := TButton.Create(Self); BtnOpen.Parent := Sidebar; BtnOpen.Caption := 'Abrir producao...';
  BtnOpen.SetBounds(12, 14, 231, 34); BtnOpen.OnClick := @OnOpenProdClick;

  BtnBuild := TButton.Create(Self); BtnBuild.Parent := Sidebar; BtnBuild.Caption := 'Etapa 1: Criar Banco Sonoro';
  BtnBuild.SetBounds(12, 58, 231, 34); BtnBuild.OnClick := @OnBuildBankClick;

  BtnApprove := TButton.Create(Self); BtnApprove.Parent := Sidebar; BtnApprove.Caption := 'Etapa 2: Aprovar Item Isolado';
  BtnApprove.SetBounds(12, 100, 231, 34); BtnApprove.OnClick := @OnApproveProfileClick;

  BtnRehearse := TButton.Create(Self); BtnRehearse.Parent := Sidebar; BtnRehearse.Caption := 'Gerar Prévia WAV da Cena';
  BtnRehearse.SetBounds(12, 142, 231, 34); BtnRehearse.OnClick := @OnRehearseSceneClick;

  BtnStop := TButton.Create(Self); BtnStop.Parent := Sidebar; BtnStop.Caption := 'Parar Audio';
  BtnStop.SetBounds(12, 184, 231, 32); BtnStop.OnClick := @OnStopAudioClick;

  PC := TPageControl.Create(Self); PC.Parent := Self; PC.Align := alClient;
  TabBank := TTabSheet.Create(PC); TabBank.PageControl := PC; TabBank.Caption := 'Etapa 1 & 2: Vozes e Efeitos';
  TabRehearsal := TTabSheet.Create(PC); TabRehearsal.PageControl := PC; TabRehearsal.Caption := 'Etapa 3: Ensaio Sincronizado';
  TabLog := TTabSheet.Create(PC); TabLog.PageControl := PC; TabLog.Caption := 'Log Operacional';

  FProfilesGrid := TStringGrid.Create(Self); FProfilesGrid.Parent := TabBank; FProfilesGrid.Align := alClient;
  FProfilesGrid.FixedCols := 0; FProfilesGrid.FixedRows := 1; FProfilesGrid.ColCount := 7; FProfilesGrid.RowCount := 2;
  FProfilesGrid.Options := FProfilesGrid.Options + [goRowSelect, goColSizing];
  FProfilesGrid.Cells[0, 0] := 'Asset ID'; FProfilesGrid.Cells[1, 0] := 'Tipo';
  FProfilesGrid.Cells[2, 0] := 'Entidade'; FProfilesGrid.Cells[3, 0] := 'Timbre / Perfil';
  FProfilesGrid.Cells[4, 0] := 'Permissao'; FProfilesGrid.Cells[5, 0] := 'Status';
  FProfilesGrid.Cells[6, 0] := 'Previa';
  FProfilesGrid.ColWidths[0] := 125; FProfilesGrid.ColWidths[1] := 65; FProfilesGrid.ColWidths[2] := 155;
  FProfilesGrid.ColWidths[3] := 170; FProfilesGrid.ColWidths[4] := 115; FProfilesGrid.ColWidths[5] := 90;
  FProfilesGrid.ColWidths[6] := 180;
  FProfilesGrid.OnSelection := @OnProfilesGridSelection;

  EditPanel := TPanel.Create(Self); EditPanel.Parent := TabBank; EditPanel.Align := alBottom;
  EditPanel.Height := 165; EditPanel.BevelOuter := bvLowered;

  L := TLabel.Create(Self); L.Parent := EditPanel; L.Caption := 'Timbre/Sotaque:'; L.SetBounds(12, 14, 110, 18);
  FTimbreEdit := TEdit.Create(Self); FTimbreEdit.Parent := EditPanel; FTimbreEdit.SetBounds(126, 10, 260, 24);
  L := TLabel.Create(Self); L.Parent := EditPanel; L.Caption := 'Ritmo (-10..10):'; L.SetBounds(400, 14, 105, 18);
  FRateEdit := TEdit.Create(Self); FRateEdit.Parent := EditPanel; FRateEdit.SetBounds(508, 10, 60, 24); FRateEdit.Text := '0';
  L := TLabel.Create(Self); L.Parent := EditPanel; L.Caption := 'Volume:'; L.SetBounds(580, 14, 60, 18);
  FVolEdit := TEdit.Create(Self); FVolEdit.Parent := EditPanel; FVolEdit.SetBounds(642, 10, 60, 24); FVolEdit.Text := '100';

  L := TLabel.Create(Self); L.Parent := EditPanel; L.Caption := 'Licenca/Permissao:'; L.SetBounds(12, 48, 125, 18);
  FPermEdit := TEdit.Create(Self); FPermEdit.Parent := EditPanel; FPermEdit.SetBounds(140, 44, 246, 24);
  FPermEdit.Text := 'sintetica_autorizada';

  L := TLabel.Create(Self); L.Parent := EditPanel; L.Caption := 'Frase de teste (isolado):'; L.SetBounds(12, 82, 160, 18);
  FTestPhraseEdit := TEdit.Create(Self); FTestPhraseEdit.Parent := EditPanel; FTestPhraseEdit.SetBounds(176, 78, 526, 24);
  FTestPhraseEdit.Text := 'Teste de identidade vocal no MaurinMovie.';

  BtnSaveProf := TButton.Create(Self); BtnSaveProf.Parent := EditPanel; BtnSaveProf.Caption := 'Aplicar Ajustes';
  BtnSaveProf.SetBounds(12, 116, 150, 32); BtnSaveProf.OnClick := @OnSaveProfileClick;

  BtnTest := TButton.Create(Self); BtnTest.Parent := EditPanel; BtnTest.Caption := 'Escutar Item Isolado (Etapa 2)';
  BtnTest.SetBounds(174, 116, 230, 32); BtnTest.OnClick := @OnTestIsolatedClick;

  RehearsalActions := TPanel.Create(Self);
  RehearsalActions.Parent := TabRehearsal;
  RehearsalActions.Align := alTop;
  RehearsalActions.Height := 44;
  BtnPlay := TButton.Create(Self); BtnPlay.Parent := RehearsalActions;
  BtnPlay.Caption := 'Tocar prévia da cena'; BtnPlay.SetBounds(8, 6, 154, 32);
  BtnPlay.OnClick := @OnPlayPreviewClick;
  BtnTiming := TButton.Create(Self); BtnTiming.Parent := RehearsalActions;
  BtnTiming.Caption := 'Editar tempos'; BtnTiming.SetBounds(170, 6, 122, 32);
  BtnTiming.OnClick := @OnEditTimingClick;
  BtnEffect := TButton.Create(Self); BtnEffect.Parent := RehearsalActions;
  BtnEffect.Caption := 'Adicionar efeito'; BtnEffect.SetBounds(300, 6, 130, 32);
  BtnEffect.OnClick := @OnAddEffectClick;

  FEventsGrid := TStringGrid.Create(Self); FEventsGrid.Parent := TabRehearsal; FEventsGrid.Align := alClient;
  FEventsGrid.FixedCols := 0; FEventsGrid.FixedRows := 1; FEventsGrid.ColCount := 6; FEventsGrid.RowCount := 2;
  FEventsGrid.Options := FEventsGrid.Options + [goRowSelect, goColSizing];
  FEventsGrid.Cells[0, 0] := 'Cena ID'; FEventsGrid.Cells[1, 0] := 'Início (ms)';
  FEventsGrid.Cells[2, 0] := 'Fim (ms)'; FEventsGrid.Cells[3, 0] := 'Asset ID';
  FEventsGrid.Cells[4, 0] := 'Fala / Evento'; FEventsGrid.Cells[5, 0] := 'Segmento';
  FEventsGrid.ColWidths[0] := 130; FEventsGrid.ColWidths[1] := 80; FEventsGrid.ColWidths[2] := 80;
  FEventsGrid.ColWidths[3] := 140; FEventsGrid.ColWidths[4] := 300;
  FEventsGrid.ColWidths[5] := 130;

  FLogMemo := TMemo.Create(Self); FLogMemo.Parent := TabLog; FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True; FLogMemo.ScrollBars := ssBoth;
end;

procedure TMsoundMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
  if FProd.Loaded then
    MmpLogAppOperation(FProd.RootDir, FProd.ProductionId, 'MSound', Msg, FCurrentRevId);
end;

procedure TMsoundMainForm.WriteToneWav(const FilePath: string; FreqHz, DurationMs: Integer);
var
  FS: TFileStream;
  SampleRate, ByteRate, DataSize, ChunkSize, SubChunk1Size: DWord;
  NumChannels, BitsPerSample, BlockAlign: Word;
  SampleCount, I: Integer;
  Sample: SmallInt;
  Riff: array[0..3] of AnsiChar;
begin
  ForceDirectories(ExtractFileDir(FilePath));
  SampleRate := 22050;
  NumChannels := 1;
  BitsPerSample := 16;
  BlockAlign := NumChannels * (BitsPerSample div 8);
  ByteRate := SampleRate * BlockAlign;
  SampleCount := (Int64(SampleRate) * DurationMs) div 1000;
  DataSize := DWord(SampleCount * BlockAlign);
  SubChunk1Size := 16;
  ChunkSize := 36 + DataSize;

  FS := TFileStream.Create(FilePath, fmCreate);
  try
    Riff := 'RIFF'; FS.WriteBuffer(Riff, 4);
    FS.WriteBuffer(ChunkSize, 4);
    Riff := 'WAVE'; FS.WriteBuffer(Riff, 4);
    Riff := 'fmt '; FS.WriteBuffer(Riff, 4);
    FS.WriteBuffer(SubChunk1Size, 4);
    FS.WriteBuffer(NumChannels, 2); // PCM format = 1 happens to equal NumChannels=1
    FS.WriteBuffer(NumChannels, 2);
    FS.WriteBuffer(SampleRate, 4);
    FS.WriteBuffer(ByteRate, 4);
    FS.WriteBuffer(BlockAlign, 2);
    FS.WriteBuffer(BitsPerSample, 2);
    Riff := 'data'; FS.WriteBuffer(Riff, 4);
    FS.WriteBuffer(DataSize, 4);
    for I := 0 to SampleCount - 1 do
    begin
      Sample := Round(8000 * Sin(2 * Pi * FreqHz * I / SampleRate));
      FS.WriteBuffer(Sample, 2);
    end;
  finally
    FS.Free;
  end;
end;

procedure TMsoundMainForm.LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
var
  ErrMsg: string;
begin
  if not ResolveAppProject(ProdRoot, 4, ProjId, RevId, FProd, FProj,
    FProjectDir, FCurrentRevId, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  FAi.LoadForProduction(FProd.RootDir);
  FindProjectByApp(FProd, 1, FScriptProj);
  FindProjectByApp(FProd, 2, FVisualProj);
  FindProjectByApp(FProd, 3, FBoardProj);
  FScriptRev := FScriptProj.ActiveRevision;
  FBoardRev := FBoardProj.ActiveRevision;
  FVisualRev := FVisualProj.ActiveRevision;

  FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
  FHeaderSourceLabel.Caption := Format('Fontes: MScript (%s) | MVisual (%s) | MBoard (%s) | MSound: %s',
    [FScriptProj.ActiveRevision, FVisualProj.ActiveRevision, FBoardProj.ActiveRevision, FCurrentRevId]);

  LoadSoundFromRevision(FCurrentRevId);
  RefreshProfilesGrid;
  RefreshEventsGrid;
  LogMsg('Producao carregada em MSound.');
end;

procedure TMsoundMainForm.LoadSoundFromRevision(const RevId: string);
var
  Path, Content: string;
  Data: TJSONData;
  Obj, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  SetLength(FProfiles, 0);
  SetLength(FEvents, 0);
  SetLength(FPreviews, 0);
  Path := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
    RevId + PathDelim + 'voices' + PathDelim + 'profiles.json';
  if not FileExists(Path) then Exit;
  if not ReadTextFileUtf8(Path, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  try
    FScriptRev := Obj.Get('script_revision', FScriptRev);
    FBoardRev := Obj.Get('board_revision', FBoardRev);
    FVisualRev := Obj.Get('visual_revision', FVisualRev);
    if Obj.Find('profiles') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('profiles'));
      SetLength(FProfiles, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := TJSONObject(Arr.Items[I]);
        FProfiles[I].AssetId := Item.Get('asset_id', '');
        FProfiles[I].Kind := Item.Get('kind', 'voice');
        FProfiles[I].EntityId := Item.Get('entity_id', '');
        FProfiles[I].EntityName := Item.Get('entity_name', '');
        FProfiles[I].Timbre := Item.Get('timbre', '');
        FProfiles[I].RateVal := Item.Get('rate', 0);
        FProfiles[I].VolumeVal := Item.Get('volume', 100);
        FProfiles[I].Permission := Item.Get('permission', 'sintetica_autorizada');
        FProfiles[I].Status := Item.Get('status', 'pending');
        FProfiles[I].PreviewUri := Item.Get('preview_uri', '');
      end;
    end;
    if Obj.Find('timeline_events') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('timeline_events'));
      SetLength(FEvents, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := TJSONObject(Arr.Items[I]);
        FEvents[I].SceneId := Item.Get('scene_id', '');
        FEvents[I].SegmentId := Item.Get('segment_id', '');
        FEvents[I].StartMs := Item.Get('start_ms', Item.Get('start_sec', 0) * 1000);
        FEvents[I].EndMs := Item.Get('end_ms', Item.Get('end_sec', 0) * 1000);
        FEvents[I].SceneDurationMs := Item.Get('scene_duration_ms', 0);
        FEvents[I].SegmentStartMs := Item.Get('segment_start_ms', 0);
        FEvents[I].SegmentEndMs := Item.Get('segment_end_ms', FEvents[I].SceneDurationMs);
        FEvents[I].AssetId := Item.Get('asset_id', '');
        FEvents[I].TextOrCue := Item.Get('cue', '');
      end;
    end;
    if Obj.Find('previews') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('previews'));
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Objects[I];
        if ResolveSafePath(FProjectDir + PathDelim + 'revisions' + PathDelim + RevId,
          Item.Get('uri', ''), Path) and FileExists(Path) then
          AddPreview(Item.Get('scene_id', ''), Item.Get('segment_id', ''), Path);
      end;
    end;
  finally
    Obj.Free;
  end;
end;

function TMsoundMainForm.ProfilePath(const RelUri: string): string;
begin
  if ResolveSafePath(FProjectDir + PathDelim + 'work', RelUri, Result) and FileExists(Result) then Exit;
  if ResolveSafePath(FProjectDir + PathDelim + 'revisions' + PathDelim + FCurrentRevId,
    RelUri, Result) and FileExists(Result) then Exit;
  Result := '';
end;

procedure TMsoundMainForm.AddPreview(const SceneId, SegmentId, FilePath: string);
var
  I: Integer;
begin
  I := Length(FPreviews);
  SetLength(FPreviews, I + 1);
  FPreviews[I].SceneId := SceneId;
  FPreviews[I].SegmentId := SegmentId;
  FPreviews[I].FilePath := FilePath;
  FPreviews[I].RelUri := 'audio/previews/' + SceneId;
  if SegmentId <> '' then FPreviews[I].RelUri := FPreviews[I].RelUri + '_' + SegmentId;
  FPreviews[I].RelUri := FPreviews[I].RelUri + '.wav';
end;

procedure TMsoundMainForm.InvalidatePreviews(const SceneId: string);
var
  I, J: Integer;
begin
  J := 0;
  for I := 0 to High(FPreviews) do
    if (SceneId <> '') and (FPreviews[I].SceneId <> SceneId) then
    begin
      FPreviews[J] := FPreviews[I];
      Inc(J);
    end;
  SetLength(FPreviews, J);
end;

procedure TMsoundMainForm.OnBuildBankClick(Sender: TObject);
var
  Content, BoardPath, SceneId, Dialogue: string;
  ScriptData, BoardData: TJSONData;
  Characters, Scenes, Boards, Segments: TJSONArray;
  Item, Board, Segment: TJSONObject;
  Lines: TMmpDialogueLines;
  OldProfiles: array of TSoundProfileItem;
  I, J, K, N, Offset, Seconds, SceneMs: Integer;
  HasSegmentDialogue: Boolean;

  function VoiceFor(const Name, Id: string): Integer;
  var
    P: Integer;
    Speaker: string;
  begin
    Speaker := Trim(Name);
    if Speaker = '' then Speaker := 'Narrador';
    for P := 0 to High(FProfiles) do
      if (FProfiles[P].Kind = 'voice') and (((Id <> '') and (FProfiles[P].EntityId = Id)) or
        ((Id = '') and SameText(FProfiles[P].EntityName, Speaker))) then Exit(P);
    Result := Length(FProfiles);
    SetLength(FProfiles, Result + 1);
    for P := 0 to High(OldProfiles) do
      if (OldProfiles[P].Kind = 'voice') and (((Id <> '') and (OldProfiles[P].EntityId = Id)) or
        ((Id = '') and SameText(OldProfiles[P].EntityName, Speaker))) then
      begin
        FProfiles[Result] := OldProfiles[P];
        FProfiles[Result].EntityName := Speaker;
        Exit;
      end;
    with FProfiles[Result] do
    begin
      EntityId := Id;
      EntityName := Speaker;
      Kind := 'voice';
      AssetId := GenerateMmpId('a_vox');
      VolumeVal := 100;
      Status := 'pending';
      Permission := 'sintetica_autorizada';
    end;
  end;

  procedure AddSegmentEvents(const PartId, TextValue: string; OffsetMs, DurationMs: Integer);
  var
    Dialogues: TMmpDialogueLines;
    P, Idx, Count: Integer;
  begin
    Dialogues := ParseMmpDialogue(TextValue);
    Count := Max(1, Length(Dialogues));
    for P := 0 to Count - 1 do
    begin
      Idx := Length(FEvents);
      SetLength(FEvents, Idx + 1);
      with FEvents[Idx] do
      begin
        SceneId := Board.Get('scene_id', '');
        SegmentId := PartId;
        SceneDurationMs := SceneMs;
        SegmentStartMs := OffsetMs;
        SegmentEndMs := OffsetMs + DurationMs;
        StartMs := OffsetMs + Int64(P) * DurationMs div Count;
        EndMs := OffsetMs + Int64(P + 1) * DurationMs div Count;
        if Length(Dialogues) > 0 then
        begin
          AssetId := FProfiles[VoiceFor(Dialogues[P].Speaker, '')].AssetId;
          TextOrCue := Dialogues[P].Text;
        end;
      end;
    end;
  end;

begin
  if not FProd.Loaded then Exit;
  if (Length(FEvents) > 0) and (MessageDlg(
    'Reindexar as fontes substitui os eventos, os efeitos marcados e as prévias da timeline. Continuar?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  BoardPath := ExtractFileDir(FBoardProj.ProjectFilePath) + PathDelim + 'revisions' +
    PathDelim + FBoardProj.ActiveRevision + PathDelim + 'storyboard' + PathDelim + 'scenes.json';
  if not ReadTextFileUtf8(BoardPath, Content) then
  begin
    MessageDlg('Publique o storyboard no MBoard antes de montar a timeline sonora.', mtWarning, [mbOK], 0);
    Exit;
  end;
  BoardData := GetJSON(Content);
  ScriptData := nil;
  try
    if not (BoardData.FindPath('scene_boards') is TJSONArray) then Exit;
    Boards := TJSONArray(BoardData.FindPath('scene_boards'));
    FBoardRev := FBoardProj.ActiveRevision;
    FScriptRev := TJSONObject(BoardData).Get('script_revision', FScriptProj.ActiveRevision);
    FVisualRev := TJSONObject(BoardData).Get('visual_revision', FVisualProj.ActiveRevision);
    if not ReadTextFileUtf8(ExtractFileDir(FScriptProj.ProjectFilePath) + PathDelim + 'revisions' +
      PathDelim + FScriptRev + PathDelim + 'scripts' + PathDelim + 'roteiro.json', Content) then
    begin
      MessageDlg('Não encontrei a revisão do roteiro usada no storyboard.', mtError, [mbOK], 0);
      Exit;
    end;
    ScriptData := GetJSON(Content);
    OldProfiles := FProfiles;
    FProfiles := nil;
    FEvents := nil;
    InvalidatePreviews;
    if ScriptData.FindPath('characters') is TJSONArray then
    begin
      Characters := TJSONArray(ScriptData.FindPath('characters'));
      for I := 0 to Characters.Count - 1 do
      begin
        Item := Characters.Objects[I];
        VoiceFor(Item.Get('name', ''), Item.Get('character_id', ''));
      end;
    end;
    for I := 0 to High(OldProfiles) do
      if OldProfiles[I].Kind = 'effect' then
      begin
        N := Length(FProfiles);
        SetLength(FProfiles, N + 1);
        FProfiles[N] := OldProfiles[I];
      end;

    for I := 0 to Boards.Count - 1 do
    begin
      Board := Boards.Objects[I];
      SceneId := Board.Get('scene_id', '');
      SceneMs := 1000 * Board.Get('estimated_duration_seconds', 0);
      if (SceneId = '') or (SceneMs <= 0) then Continue;
      Dialogue := Board.Get('dialogue', '');
      if (Dialogue = '') and (ScriptData.FindPath('scenes') is TJSONArray) then
      begin
        Scenes := TJSONArray(ScriptData.FindPath('scenes'));
        for K := 0 to Scenes.Count - 1 do
          if Scenes.Objects[K].Get('scene_id', '') = SceneId then
          begin
            Dialogue := Scenes.Objects[K].Get('dialogue_text', '');
            Break;
          end;
      end;
      Segments := nil;
      if Board.Find('segments') is TJSONArray then Segments := TJSONArray(Board.Find('segments'));
      if (Segments = nil) or (Segments.Count = 0) then
      begin
        AddSegmentEvents('sg_' + SceneId, Dialogue, 0, SceneMs);
        Continue;
      end;
      Lines := ParseMmpDialogue(Dialogue);
      HasSegmentDialogue := False;
      for J := 0 to Segments.Count - 1 do
        if Trim(Segments.Objects[J].Get('dialogue', '')) <> '' then HasSegmentDialogue := True;
      Offset := 0;
      for J := 0 to Segments.Count - 1 do
      begin
        Segment := Segments.Objects[J];
        Seconds := Segment.Get('duration_seconds', 0);
        if (Seconds <= 0) or (Offset + Int64(Seconds) * 1000 > SceneMs) then Break;
        if HasSegmentDialogue then Dialogue := Segment.Get('dialogue', '')
        else Dialogue := MmpDialoguePortion(Lines, J, Segments.Count);
        AddSegmentEvents(Segment.Get('segment_id', ''), Dialogue, Offset, Seconds * 1000);
        Inc(Offset, Seconds * 1000);
      end;
    end;
  finally
    ScriptData.Free;
    BoardData.Free;
  end;
  RefreshProfilesGrid;
  RefreshEventsGrid;
  LogMsg(Format('Banco sonoro indexado: %d perfis, %d eventos.', [Length(FProfiles), Length(FEvents)]));
end;

procedure TMsoundMainForm.RefreshProfilesGrid;
var
  I, Row: Integer;
begin
  if Length(FProfiles) = 0 then
  begin
    FProfilesGrid.RowCount := 2;
    for I := 0 to FProfilesGrid.ColCount - 1 do FProfilesGrid.Cells[I, 1] := '';
    FSelectedProfile := -1;
    Exit;
  end;
  FProfilesGrid.RowCount := Length(FProfiles) + 1;
  for I := 0 to High(FProfiles) do
  begin
    Row := I + 1;
    FProfilesGrid.Cells[0, Row] := FProfiles[I].AssetId;
    FProfilesGrid.Cells[1, Row] := FProfiles[I].Kind;
    FProfilesGrid.Cells[2, Row] := FProfiles[I].EntityName;
    FProfilesGrid.Cells[3, Row] := FProfiles[I].Timbre;
    FProfilesGrid.Cells[4, Row] := FProfiles[I].Permission;
    FProfilesGrid.Cells[5, Row] := FProfiles[I].Status;
    FProfilesGrid.Cells[6, Row] := FProfiles[I].PreviewUri;
  end;
  if (FSelectedProfile < 0) or (FSelectedProfile > High(FProfiles)) then FSelectedProfile := 0;
  FProfilesGrid.Row := FSelectedProfile + 1;
  LoadProfileToEditor(FSelectedProfile);
end;

procedure TMsoundMainForm.RefreshEventsGrid;
var
  I, Row: Integer;
begin
  if Length(FEvents) = 0 then
  begin
    FEventsGrid.RowCount := 2;
    for I := 0 to FEventsGrid.ColCount - 1 do FEventsGrid.Cells[I, 1] := '';
    Exit;
  end;
  FEventsGrid.RowCount := Length(FEvents) + 1;
  for I := 0 to High(FEvents) do
  begin
    Row := I + 1;
    FEventsGrid.Cells[0, Row] := FEvents[I].SceneId;
    FEventsGrid.Cells[1, Row] := IntToStr(FEvents[I].StartMs);
    FEventsGrid.Cells[2, Row] := IntToStr(FEvents[I].EndMs);
    FEventsGrid.Cells[3, Row] := FEvents[I].AssetId;
    FEventsGrid.Cells[4, Row] := FEvents[I].TextOrCue;
    FEventsGrid.Cells[5, Row] := FEvents[I].SegmentId;
  end;
end;

procedure TMsoundMainForm.LoadProfileToEditor(Idx: Integer);
begin
  if (Idx < 0) or (Idx > High(FProfiles)) then Exit;
  FTimbreEdit.Text := FProfiles[Idx].Timbre;
  FRateEdit.Text := IntToStr(FProfiles[Idx].RateVal);
  FVolEdit.Text := IntToStr(FProfiles[Idx].VolumeVal);
  FPermEdit.Text := FProfiles[Idx].Permission;
end;

procedure TMsoundMainForm.OnTestIsolatedClick(Sender: TObject);
var
  WavPath, Err: string;
begin
  if (FSelectedProfile < 0) or (FSelectedProfile > High(FProfiles)) then Exit;
  if SameText(FProfiles[FSelectedProfile].Kind, 'voice') then
  begin
    WavPath := IncludeTrailingPathDelimiter(FProjectDir) + 'work' + PathDelim +
      'audio' + PathDelim + GenerateMmpId('voice_test') + '.wav';
    ForceDirectories(ExtractFileDir(WavPath));
    if FAi.SynthesizeSpeech(FTestPhraseEdit.Text, WavPath, Err,
      FProfiles[FSelectedProfile].Timbre) and FPlayer.Play(WavPath) then
    begin
      LogMsg('Sintese de voz IA (TAIUnifiedSound) executada para ' +
        FProfiles[FSelectedProfile].EntityName + ' -> ' + WavPath);
      Exit;
    end;
    FSynth.Engine := seSystemDefault;
    FSynth.Rate := StrToIntDef(FRateEdit.Text, 0);
    FSynth.Volume := StrToIntDef(FVolEdit.Text, 100);
    FSynth.Say(FTestPhraseEdit.Text);
    LogMsg('Sintese de teste executada via TAIVoiceSynthesizer para ' +
      FProfiles[FSelectedProfile].EntityName);
  end
  else
  begin
    WavPath := ProfilePath(FProfiles[FSelectedProfile].PreviewUri);
    if WavPath = '' then
    begin
      MessageDlg('Arquivo do efeito não encontrado.', mtError, [mbOK], 0);
      Exit;
    end;
    if (not FileExists(WavPath)) and FAi.GenerateSFX(FProfiles[FSelectedProfile].EntityName, WavPath, Err, 3.0) then
      LogMsg('Efeito sonoro IA gerado: ' + WavPath);
    if FPlayer.Play(WavPath) then
      LogMsg('Reproduzindo efeito isolado via TAIAudioPlayer: ' + WavPath)
    else
      LogMsg('Aviso player: ' + FPlayer.LastError);
  end;
end;

procedure TMsoundMainForm.OnRehearseSceneClick(Sender: TObject);
var
  Idx, I, P, N, DurationMs: Integer;
  SceneId, WorkDir, Mixed, WavPath, Ffmpeg, Err, PartPath: string;
  Clips: array of TMmpAudioClip;
  Slice: array[0..0] of TMmpAudioClip;
  Parts: TStringList;
  Provider: TMmpAiProviderCfg;
  PreviewsBefore: array of TSoundPreview;
  Success: Boolean;
begin
  Idx := FEventsGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FEvents)) then
  begin
    MessageDlg('Selecione um evento da cena na aba Ensaio Sincronizado.', mtInformation, [mbOK], 0);
    Exit;
  end;
  SceneId := FEvents[Idx].SceneId;
  DurationMs := FEvents[Idx].SceneDurationMs;
  if DurationMs <= 0 then
  begin
    MessageDlg('Reindexe o banco para converter a timeline antiga em eventos do storyboard.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  FAi.ReloadIfChanged;
  Ffmpeg := FAi.Settings.ToolFfmpeg;
  if Ffmpeg = '' then Ffmpeg := FAi.Settings.DetectToolPath('ffmpeg');
  if Ffmpeg = '' then
  begin
    MessageDlg('Configure FFmpeg no MMenu.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FAi.Settings.ResolveProvider('voice', maMSound, Provider);
  WorkDir := FProjectDir + PathDelim + 'work' + PathDelim + 'previews' + PathDelim + GenerateMmpId('mix');
  if not ForceDirectories(WorkDir) then Exit;
  FPlayer.Stop;
  FSynth.Stop;
  Parts := TStringList.Create;
  PreviewsBefore := Copy(FPreviews);
  Success := False;
  try
    try
      for I := 0 to High(FEvents) do
      begin
        if FEvents[I].SceneId <> SceneId then Continue;
        if (FEvents[I].SegmentId <> '') and (Parts.IndexOf(FEvents[I].SegmentId) < 0) then
          Parts.AddObject(FEvents[I].SegmentId, TObject(PtrInt(I + 1)));
        if FEvents[I].AssetId = '' then Continue;
        P := 0;
        while (P <= High(FProfiles)) and (FProfiles[P].AssetId <> FEvents[I].AssetId) do Inc(P);
        if P > High(FProfiles) then raise Exception.Create('Perfil sonoro não encontrado: ' + FEvents[I].AssetId);
        if FProfiles[P].Status = 'rejected' then raise Exception.Create('Perfil sonoro reprovado: ' + FProfiles[P].EntityName);
        if FProfiles[P].Kind = 'voice' then
        begin
          WavPath := WorkDir + PathDelim + 'fala_' + IntToStr(I) + '.wav';
          if Provider.Enabled and SameText(Provider.Adapter, 'mock') then
          begin
            WriteToneWav(WavPath, 330 + (P mod 12) * 40,
              Min(FEvents[I].EndMs - FEvents[I].StartMs, 1200));
            LogMsg('Voz simulada para ' + FProfiles[P].EntityName);
          end
          else if not FAi.SynthesizeSpeech(FEvents[I].TextOrCue, WavPath, Err, FProfiles[P].Timbre) then
            raise Exception.Create('Falha na síntese de ' + FProfiles[P].EntityName + ': ' + Err);
        end
        else
          WavPath := ProfilePath(FProfiles[P].PreviewUri);
        N := Length(Clips);
        SetLength(Clips, N + 1);
        Clips[N].FileName := WavPath;
        Clips[N].StartMs := FEvents[I].StartMs;
        Clips[N].EndMs := FEvents[I].EndMs;
        Clips[N].VolumePercent := FProfiles[P].VolumeVal;
      end;
      Mixed := WorkDir + PathDelim + 'cena.wav';
      if not RenderMmpAudio(Ffmpeg, Mixed, Clips, DurationMs, FAi.Settings.ProdAudioRate,
        FAi.Settings.ProdAudioChannels, Err) then raise Exception.Create(Err);
      InvalidatePreviews(SceneId);
      AddPreview(SceneId, '', Mixed);
      for I := 0 to Parts.Count - 1 do
      begin
        P := PtrInt(Parts.Objects[I]) - 1;
        Slice[0].FileName := Mixed;
        Slice[0].SourceStartMs := FEvents[P].SegmentStartMs;
        Slice[0].StartMs := 0;
        Slice[0].EndMs := FEvents[P].SegmentEndMs - FEvents[P].SegmentStartMs;
        Slice[0].VolumePercent := 100;
        PartPath := WorkDir + PathDelim + 'segmento_' + IntToStr(I + 1) + '.wav';
        if not RenderMmpAudio(Ffmpeg, PartPath, Slice, Slice[0].EndMs,
          FAi.Settings.ProdAudioRate, FAi.Settings.ProdAudioChannels, Err) then
          raise Exception.Create(Err);
        AddPreview(SceneId, Parts[I], PartPath);
      end;
      Success := True;
    except
      on E: Exception do
      begin
        FPreviews := PreviewsBefore;
        LogMsg('Falha na prévia: ' + E.Message);
        MessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    Parts.Free;
  end;
  if Success then
  begin
    LogMsg('Prévia WAV gerada para a cena e seus segmentos. Publique para disponibilizar ao MScene.');
    OnPlayPreviewClick(Sender);
  end;
end;

procedure TMsoundMainForm.OnPlayPreviewClick(Sender: TObject);
var
  Idx, I: Integer;
begin
  Idx := FEventsGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FEvents)) then Exit;
  for I := 0 to High(FPreviews) do
    if (FPreviews[I].SceneId = FEvents[Idx].SceneId) and (FPreviews[I].SegmentId = '') then
    begin
      FPlayer.Stop;
      if not FPlayer.Play(FPreviews[I].FilePath) then
        MessageDlg('Não foi possível reproduzir o WAV: ' + FPlayer.LastError, mtWarning, [mbOK], 0);
      Exit;
    end;
  MessageDlg('Gere a prévia WAV desta cena primeiro.', mtInformation, [mbOK], 0);
end;

procedure TMsoundMainForm.OnEditTimingClick(Sender: TObject);
var
  I, StartMs, EndMs: Integer;
  StartText, EndText: string;
begin
  I := FEventsGrid.Row - 1;
  if (I < 0) or (I > High(FEvents)) or (FEvents[I].AssetId = '') then Exit;
  StartText := IntToStr(FEvents[I].StartMs);
  EndText := IntToStr(FEvents[I].EndMs);
  if not InputQuery('Tempo do evento', 'Início na cena (ms):', StartText) or
    not InputQuery('Tempo do evento', 'Fim na cena (ms):', EndText) then Exit;
  if not TryStrToInt(StartText, StartMs) or not TryStrToInt(EndText, EndMs) or
    (StartMs < FEvents[I].SegmentStartMs) or (EndMs > FEvents[I].SegmentEndMs) or
    (EndMs <= StartMs) then
  begin
    MessageDlg('Informe um intervalo válido dentro do segmento selecionado.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  FEvents[I].StartMs := StartMs;
  FEvents[I].EndMs := EndMs;
  InvalidatePreviews(FEvents[I].SceneId);
  RefreshEventsGrid;
end;

procedure TMsoundMainForm.OnAddEffectClick(Sender: TObject);
var
  I, P, E: Integer;
  Source, LabelText, License, RelUri, OutputFile, Id: string;
  Dialog: TOpenDialog;
begin
  I := FEventsGrid.Row - 1;
  if (I < 0) or (I > High(FEvents)) or (FEvents[I].SceneDurationMs <= 0) then Exit;
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'Áudio WAV|*.wav';
    Dialog.Options := [ofFileMustExist];
    if not Dialog.Execute then Exit;
    Source := Dialog.FileName;
  finally
    Dialog.Free;
  end;
  LabelText := ChangeFileExt(ExtractFileName(Source), '');
  License := '';
  if not InputQuery('Adicionar efeito', 'Nome do efeito:', LabelText) or
    not InputQuery('Adicionar efeito', 'Licença ou autorização de uso:', License) or
    (Trim(LabelText) = '') or (Trim(License) = '') then Exit;
  Id := GenerateMmpId('a_sfx');
  RelUri := 'audio/effects/' + Id + '.wav';
  if not ResolveSafePath(FProjectDir + PathDelim + 'work', RelUri, OutputFile) or
    not ForceDirectories(ExtractFileDir(OutputFile)) or not CopyFile(Source, OutputFile) then
  begin
    MessageDlg('Não foi possível copiar o efeito.', mtError, [mbOK], 0);
    Exit;
  end;
  P := Length(FProfiles);
  SetLength(FProfiles, P + 1);
  FProfiles[P].AssetId := Id;
  FProfiles[P].Kind := 'effect';
  FProfiles[P].EntityName := LabelText;
  FProfiles[P].Permission := License;
  FProfiles[P].PreviewUri := RelUri;
  FProfiles[P].VolumeVal := 85;
  FProfiles[P].Status := 'pending';
  E := Length(FEvents);
  SetLength(FEvents, E + 1);
  FEvents[E] := FEvents[I];
  FEvents[E].AssetId := Id;
  FEvents[E].TextOrCue := LabelText;
  InvalidatePreviews(FEvents[I].SceneId);
  RefreshProfilesGrid;
  RefreshEventsGrid;
  FEventsGrid.Row := E + 1;
end;

procedure TMsoundMainForm.OnStopAudioClick(Sender: TObject);
begin
  FSynth.Stop;
  FPlayer.Stop;
  LogMsg('Reproducao sonora interrompida.');
end;

procedure TMsoundMainForm.OnSaveProfileClick(Sender: TObject);
begin
  if (FSelectedProfile < 0) or (FSelectedProfile > High(FProfiles)) then Exit;
  FProfiles[FSelectedProfile].Timbre := FTimbreEdit.Text;
  FProfiles[FSelectedProfile].RateVal := StrToIntDef(FRateEdit.Text, 0);
  FProfiles[FSelectedProfile].VolumeVal := EnsureRange(StrToIntDef(FVolEdit.Text, 100), 0, 200);
  FProfiles[FSelectedProfile].Permission := FPermEdit.Text;
  FProfiles[FSelectedProfile].Status := 'pending';
  InvalidatePreviews;
  RefreshProfilesGrid;
end;

procedure TMsoundMainForm.OnApproveProfileClick(Sender: TObject);
begin
  if (FSelectedProfile < 0) or (FSelectedProfile > High(FProfiles)) then Exit;
  FProfiles[FSelectedProfile].Status := 'approved';
  RefreshProfilesGrid;
end;

function TMsoundMainForm.ProfilesToJson: string;
var
  Root, PObj, EObj: TJSONObject;
  PArr, EArr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.msound.profiles/1');
    Root.Add('script_revision', FScriptRev);
    Root.Add('board_revision', FBoardRev);
    Root.Add('visual_revision', FVisualRev);
    PArr := TJSONArray.Create;
    for I := 0 to High(FProfiles) do
    begin
      PObj := TJSONObject.Create;
      PObj.Add('asset_id', FProfiles[I].AssetId);
      PObj.Add('kind', FProfiles[I].Kind);
      PObj.Add('entity_id', FProfiles[I].EntityId);
      PObj.Add('entity_name', FProfiles[I].EntityName);
      PObj.Add('timbre', FProfiles[I].Timbre);
      PObj.Add('rate', FProfiles[I].RateVal);
      PObj.Add('volume', FProfiles[I].VolumeVal);
      PObj.Add('permission', FProfiles[I].Permission);
      PObj.Add('status', FProfiles[I].Status);
      PObj.Add('preview_uri', FProfiles[I].PreviewUri);
      PArr.Add(PObj);
    end;
    Root.Add('profiles', PArr);

    EArr := TJSONArray.Create;
    for I := 0 to High(FEvents) do
    begin
      EObj := TJSONObject.Create;
      EObj.Add('scene_id', FEvents[I].SceneId);
      EObj.Add('segment_id', FEvents[I].SegmentId);
      EObj.Add('start_ms', FEvents[I].StartMs);
      EObj.Add('end_ms', FEvents[I].EndMs);
      EObj.Add('scene_duration_ms', FEvents[I].SceneDurationMs);
      EObj.Add('segment_start_ms', FEvents[I].SegmentStartMs);
      EObj.Add('segment_end_ms', FEvents[I].SegmentEndMs);
      EObj.Add('asset_id', FEvents[I].AssetId);
      EObj.Add('cue', FEvents[I].TextOrCue);
      EArr.Add(EObj);
    end;
    Root.Add('timeline_events', EArr);
    EArr := TJSONArray.Create;
    Root.Add('previews', EArr);
    for I := 0 to High(FPreviews) do
    begin
      EObj := TJSONObject.Create;
      EObj.Add('scene_id', FPreviews[I].SceneId);
      EObj.Add('segment_id', FPreviews[I].SegmentId);
      EObj.Add('uri', FPreviews[I].RelUri);
      EArr.Add(EObj);
    end;
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

procedure TMsoundMainForm.OnPublishClick(Sender: TObject);
var
  PrepRev, RevDir, NewRev, ErrMsg, SrcF, NewState: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, N: Integer;

  function CopyToRevision(const Source, RelUri: string): Boolean;
  var
    Destination: string;
  begin
    Result := FileExists(Source) and ResolveSafePath(RevDir, RelUri, Destination) and
      ForceDirectories(ExtractFileDir(Destination)) and CopyFile(Source, Destination);
    if not Result then MessageDlg('Não foi possível publicar ' + RelUri, mtError, [mbOK], 0);
  end;

begin
  if not FProd.Loaded or (Length(FEvents) = 0) then Exit;
  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;
  if not AtomicWriteTextFile(RevDir + PathDelim + 'voices' + PathDelim + 'profiles.json',
    ProfilesToJson, False) then
  begin
    MessageDlg('Não foi possível gravar a timeline sonora.', mtError, [mbOK], 0);
    Exit;
  end;

  NewState := 'approved';
  SetLength(Arts, 1);
  Arts[0].ArtifactId := GenerateMmpId('a');
  Arts[0].Kind := 'audio.voice.profile';
  Arts[0].RelUri := 'voices/profiles.json';
  Arts[0].MimeType := 'application/json';

  for I := 0 to High(FProfiles) do
  begin
    if FProfiles[I].Status <> 'approved' then NewState := 'published';
    if FProfiles[I].PreviewUri = '' then Continue;
    SrcF := ProfilePath(FProfiles[I].PreviewUri);
    if not CopyToRevision(SrcF, FProfiles[I].PreviewUri) then Exit;
    N := Length(Arts);
    SetLength(Arts, N + 1);
    Arts[N].ArtifactId := FProfiles[I].AssetId;
    if SameText(FProfiles[I].Kind, 'voice') then
      Arts[N].Kind := 'audio.voice.profile'
    else
      Arts[N].Kind := 'audio.effect';
    Arts[N].RelUri := FProfiles[I].PreviewUri;
    Arts[N].MimeType := 'audio/wav';
    Arts[N].Status := FProfiles[I].Status;
  end;
  Arts[0].Status := NewState;
  for I := 0 to High(FPreviews) do
  begin
    if not CopyToRevision(FPreviews[I].FilePath, FPreviews[I].RelUri) then Exit;
    N := Length(Arts);
    SetLength(Arts, N + 1);
    Arts[N].ArtifactId := GenerateMmpId('a_audio');
    Arts[N].Kind := 'audio.preview';
    Arts[N].SceneId := FPreviews[I].SceneId;
    Arts[N].SegmentId := FPreviews[I].SegmentId;
    Arts[N].RelUri := FPreviews[I].RelUri;
    Arts[N].MimeType := 'audio/wav';
    Arts[N].Status := NewState;
  end;

  SetLength(Srcs, 3);
  Srcs[0].ProjectId := FScriptProj.ProjectId;
  Srcs[0].RevisionId := FScriptRev;
  if FindRevisionInProject(FScriptProj, FScriptRev, RevInfo) then
    Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;

  Srcs[1].ProjectId := FVisualProj.ProjectId;
  Srcs[1].RevisionId := FVisualRev;
  if FindRevisionInProject(FVisualProj, FVisualRev, RevInfo) then
    Srcs[1].ManifestSha256 := RevInfo.ManifestSha256;

  Srcs[2].ProjectId := FBoardProj.ProjectId;
  Srcs[2].RevisionId := FBoardRev;
  if FindRevisionInProject(FBoardProj, FBoardRev, RevInfo) then
    Srcs[2].ManifestSha256 := RevInfo.ManifestSha256;

  if PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MSound',
    FCurrentRevId, NewState, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    LogMsg('Revisao MSound publicada: ' + NewRev);
    LoadProductionAndRevision(FProd.RootDir, FProj.ProjectId, NewRev);
  end
  else
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
end;

procedure TMsoundMainForm.OnOpenProdClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Abrir production.json';
    D.Filter := 'MaurinMovie (production.json)|production.json';
    D.Options := [ofFileMustExist, ofPathMustExist];
    if D.Execute then
      LoadProductionAndRevision(ExtractFileDir(D.FileName), '', '');
  finally
    D.Free;
  end;
end;

procedure TMsoundMainForm.OnAiConfigClick(Sender: TObject);
begin
  if FAi.ShowConfigDialog(Self) then
    LogMsg('IA configurada: ' + FAi.ProviderDisplayName);
end;

procedure TMsoundMainForm.OnProfilesGridSelection(Sender: TObject; aCol, aRow: Integer);
begin
  if (aRow >= 1) and (aRow <= Length(FProfiles)) then
  begin
    FSelectedProfile := aRow - 1;
    LoadProfileToEditor(FSelectedProfile);
  end;
end;

end.
