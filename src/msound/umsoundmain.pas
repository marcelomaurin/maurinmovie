unit umsoundmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser,
  aivoicesynthesizer, aiaudioplayback,
  ummpprotocol, ummpappbase, ummpaibridge;

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
    SceneId: string;
    StartSec: Integer;
    EndSec: Integer;
    AssetId: string;
    TextOrCue: string;
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
    procedure WriteToneWav(const FilePath: string; FreqHz, DurationMs: Integer);

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnBuildBankClick(Sender: TObject);
    procedure OnTestIsolatedClick(Sender: TObject);
    procedure OnStopAudioClick(Sender: TObject);
    procedure OnSaveProfileClick(Sender: TObject);
    procedure OnApproveProfileClick(Sender: TObject);
    procedure OnRehearseSceneClick(Sender: TObject);
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
  ProdRoot, ProjId, RevId: string;
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

  ParseAppLaunchParams(ProdRoot, ProjId, RevId);
  LogMsg('MSound v' + MMP_EXECUTABLE_VERSION + ' iniciado (CHATGPT TAIVoiceSynthesizer + TAIAudioPlayer).');
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
  Head, Sidebar, Bottom, EditPanel: TPanel;
  PC: TPageControl;
  TabBank, TabRehearsal, TabLog: TTabSheet;
  BtnOpen, BtnAiCfg, BtnBuild, BtnTest, BtnStop, BtnSaveProf, BtnApprove, BtnRehearse, BtnPublish: TButton;
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

  BtnRehearse := TButton.Create(Self); BtnRehearse.Parent := Sidebar; BtnRehearse.Caption := 'Etapa 3: Tocar Ensaio Sonoro';
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

  FEventsGrid := TStringGrid.Create(Self); FEventsGrid.Parent := TabRehearsal; FEventsGrid.Align := alClient;
  FEventsGrid.FixedCols := 0; FEventsGrid.FixedRows := 1; FEventsGrid.ColCount := 5; FEventsGrid.RowCount := 2;
  FEventsGrid.Options := FEventsGrid.Options + [goRowSelect, goColSizing];
  FEventsGrid.Cells[0, 0] := 'Cena ID'; FEventsGrid.Cells[1, 0] := 'Inicio (s)';
  FEventsGrid.Cells[2, 0] := 'Fim (s)'; FEventsGrid.Cells[3, 0] := 'Asset ID';
  FEventsGrid.Cells[4, 0] := 'Fala / Evento';
  FEventsGrid.ColWidths[0] := 130; FEventsGrid.ColWidths[1] := 80; FEventsGrid.ColWidths[2] := 80;
  FEventsGrid.ColWidths[3] := 140; FEventsGrid.ColWidths[4] := 420;

  FLogMemo := TMemo.Create(Self); FLogMemo.Parent := TabLog; FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True; FLogMemo.ScrollBars := ssBoth;
end;

procedure TMsoundMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
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
  SampleCount := (SampleRate * DurationMs) div 1000;
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
  Path := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
    RevId + PathDelim + 'voices' + PathDelim + 'profiles.json';
  if not FileExists(Path) then Exit;
  if not ReadTextFileUtf8(Path, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  try
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
        FEvents[I].StartSec := Item.Get('start_sec', 0);
        FEvents[I].EndSec := Item.Get('end_sec', 10);
        FEvents[I].AssetId := Item.Get('asset_id', '');
        FEvents[I].TextOrCue := Item.Get('cue', '');
      end;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TMsoundMainForm.OnBuildBankClick(Sender: TObject);
var
  ScriptPath, Content, RevDir, RelWav: string;
  Data: TJSONData;
  Obj, Item: TJSONObject;
  Arr: TJSONArray;
  I, N, EvN, CurT: Integer;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  ScriptPath := ExtractFileDir(FScriptProj.ProjectFilePath) + PathDelim + 'revisions' +
    PathDelim + FScriptProj.ActiveRevision + PathDelim + 'scripts' + PathDelim + 'roteiro.json';
  if not FileExists(ScriptPath) then
  begin
    MessageDlg('Roteiro nao encontrado em MScript.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not ReadTextFileUtf8(ScriptPath, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  try
    SetLength(FProfiles, 0);
    SetLength(FEvents, 0);
    RevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;

    if Obj.Find('characters') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('characters'));
      for I := 0 to Arr.Count - 1 do
      begin
        Item := TJSONObject(Arr.Items[I]);
        N := Length(FProfiles);
        SetLength(FProfiles, N + 1);
        FProfiles[N].AssetId := GenerateMmpId('a_vox');
        FProfiles[N].Kind := 'voice';
        FProfiles[N].EntityId := Item.Get('character_id', '');
        FProfiles[N].EntityName := Item.Get('name', 'Personagem');
        FProfiles[N].Timbre := 'Natural / Expressivo';
        FProfiles[N].RateVal := 0;
        FProfiles[N].VolumeVal := 100;
        FProfiles[N].Permission := 'sintetica_autorizada';
        FProfiles[N].Status := 'pending';
        RelWav := 'audio/voices/' + FProfiles[N].AssetId + '.wav';
        FProfiles[N].PreviewUri := RelWav;
        WriteToneWav(RevDir + PathDelim + StringReplace(RelWav, '/', PathDelim, [rfReplaceAll]),
          330 + (I * 60), 400);
      end;
    end;

    // Effect item + timeline events per scene
    N := Length(FProfiles);
    SetLength(FProfiles, N + 1);
    FProfiles[N].AssetId := GenerateMmpId('a_sfx');
    FProfiles[N].Kind := 'effect';
    FProfiles[N].EntityId := 'env_ambiente';
    FProfiles[N].EntityName := 'Ambiencia / Passos';
    FProfiles[N].Timbre := 'Foley / Sala';
    FProfiles[N].RateVal := 0;
    FProfiles[N].VolumeVal := 85;
    FProfiles[N].Permission := 'cc0_interno';
    FProfiles[N].Status := 'pending';
    RelWav := 'audio/effects/' + FProfiles[N].AssetId + '.wav';
    FProfiles[N].PreviewUri := RelWav;
    WriteToneWav(RevDir + PathDelim + StringReplace(RelWav, '/', PathDelim, [rfReplaceAll]), 220, 500);

    if Obj.Find('scenes') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('scenes'));
      CurT := 0;
      for I := 0 to Arr.Count - 1 do
      begin
        Item := TJSONObject(Arr.Items[I]);
        EvN := Length(FEvents);
        SetLength(FEvents, EvN + 1);
        FEvents[EvN].SceneId := Item.Get('scene_id', '');
        FEvents[EvN].StartSec := CurT;
        FEvents[EvN].EndSec := CurT + Item.Get('estimated_duration', 30);
        if Length(FProfiles) > 0 then
          FEvents[EvN].AssetId := FProfiles[0].AssetId;
        FEvents[EvN].TextOrCue := Item.Get('dialogue_text', Item.Get('heading', ''));
        CurT := FEvents[EvN].EndSec;
      end;
    end;
  finally
    Obj.Free;
  end;

  RefreshProfilesGrid;
  RefreshEventsGrid;
  LogMsg('Etapa 1: Banco de vozes e efeitos criado (' + IntToStr(Length(FProfiles)) + ' itens).');
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
    FEventsGrid.Cells[1, Row] := IntToStr(FEvents[I].StartSec);
    FEventsGrid.Cells[2, Row] := IntToStr(FEvents[I].EndSec);
    FEventsGrid.Cells[3, Row] := FEvents[I].AssetId;
    FEventsGrid.Cells[4, Row] := FEvents[I].TextOrCue;
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
  WavPath: string;
begin
  if (FSelectedProfile < 0) or (FSelectedProfile > High(FProfiles)) then Exit;
  if SameText(FProfiles[FSelectedProfile].Kind, 'voice') then
  begin
    FSynth.Engine := seSystemDefault;
    FSynth.Rate := StrToIntDef(FRateEdit.Text, 0);
    FSynth.Volume := StrToIntDef(FVolEdit.Text, 100);
    FSynth.Say(FTestPhraseEdit.Text);
    LogMsg('Sintese de teste executada via TAIVoiceSynthesizer para ' +
      FProfiles[FSelectedProfile].EntityName);
  end
  else
  begin
    WavPath := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
      FCurrentRevId + PathDelim + StringReplace(FProfiles[FSelectedProfile].PreviewUri, '/', PathDelim, [rfReplaceAll]);
    if FPlayer.Play(WavPath) then
      LogMsg('Reproduzindo efeito isolado via TAIAudioPlayer: ' + WavPath)
    else
      LogMsg('Aviso player: ' + FPlayer.LastError);
  end;
end;

procedure TMsoundMainForm.OnRehearseSceneClick(Sender: TObject);
var
  Idx: Integer;
begin
  if Length(FEvents) = 0 then
  begin
    MessageDlg('Nenhum evento de cena indexado.', mtInformation, [mbOK], 0);
    Exit;
  end;
  Idx := FEventsGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FEvents)) then Idx := 0;
  FSynth.Engine := seSystemDefault;
  FSynth.Say(FEvents[Idx].TextOrCue);
  LogMsg('Ensaio apenas sonoro da cena ' + FEvents[Idx].SceneId + ' reproduzido.');
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
  FProfiles[FSelectedProfile].VolumeVal := StrToIntDef(FVolEdit.Text, 100);
  FProfiles[FSelectedProfile].Permission := FPermEdit.Text;
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
      EObj.Add('start_sec', FEvents[I].StartSec);
      EObj.Add('end_sec', FEvents[I].EndSec);
      EObj.Add('asset_id', FEvents[I].AssetId);
      EObj.Add('cue', FEvents[I].TextOrCue);
      EArr.Add(EObj);
    end;
    Root.Add('timeline_events', EArr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

procedure TMsoundMainForm.OnPublishClick(Sender: TObject);
var
  PrepRev, RevDir, OldRevDir, NewRev, ErrMsg, SrcF, DstF: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I: Integer;
  FS1, FS2: TFileStream;
begin
  if not FProd.Loaded then Exit;
  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;
  OldRevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;

  AtomicWriteTextFile(RevDir + PathDelim + 'voices' + PathDelim + 'profiles.json',
    ProfilesToJson, False);

  SetLength(Arts, 1 + Length(FProfiles));
  Arts[0].ArtifactId := GenerateMmpId('a');
  Arts[0].Kind := 'audio.voice.profile';
  Arts[0].RelUri := 'voices/profiles.json';
  Arts[0].MimeType := 'application/json';
  Arts[0].Status := 'approved';

  for I := 0 to High(FProfiles) do
  begin
    SrcF := OldRevDir + PathDelim + StringReplace(FProfiles[I].PreviewUri, '/', PathDelim, [rfReplaceAll]);
    DstF := RevDir + PathDelim + StringReplace(FProfiles[I].PreviewUri, '/', PathDelim, [rfReplaceAll]);
    if FileExists(SrcF) and not SameText(SrcF, DstF) then
    begin
      ForceDirectories(ExtractFileDir(DstF));
      FS1 := TFileStream.Create(SrcF, fmOpenRead or fmShareDenyNone);
      try
        FS2 := TFileStream.Create(DstF, fmCreate);
        try
          FS2.CopyFrom(FS1, 0);
        finally
          FS2.Free;
        end;
      finally
        FS1.Free;
      end;
    end;
    Arts[I + 1].ArtifactId := FProfiles[I].AssetId;
    if SameText(FProfiles[I].Kind, 'voice') then
      Arts[I + 1].Kind := 'audio.voice.profile'
    else
      Arts[I + 1].Kind := 'audio.effect';
    Arts[I + 1].RelUri := FProfiles[I].PreviewUri;
    Arts[I + 1].MimeType := 'audio/wav';
    Arts[I + 1].Status := FProfiles[I].Status;
  end;

  SetLength(Srcs, 3);
  Srcs[0].ProjectId := FScriptProj.ProjectId;
  Srcs[0].RevisionId := FScriptProj.ActiveRevision;
  if FindRevisionInProject(FScriptProj, FScriptProj.ActiveRevision, RevInfo) then
    Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;

  Srcs[1].ProjectId := FVisualProj.ProjectId;
  Srcs[1].RevisionId := FVisualProj.ActiveRevision;
  if FindRevisionInProject(FVisualProj, FVisualProj.ActiveRevision, RevInfo) then
    Srcs[1].ManifestSha256 := RevInfo.ManifestSha256;

  Srcs[2].ProjectId := FBoardProj.ProjectId;
  Srcs[2].RevisionId := FBoardProj.ActiveRevision;
  if FindRevisionInProject(FBoardProj, FBoardProj.ActiveRevision, RevInfo) then
    Srcs[2].ManifestSha256 := RevInfo.ManifestSha256;

  if PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MSound',
    FCurrentRevId, 'approved', '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
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
