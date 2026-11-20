unit umboardmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser, imagefilters,
  ummpprotocol, ummpappbase, ummpaibridge, ummpdialogue, ummpsha256,
  mmpsettings, mmpcommon, FileUtil;

type
  TBoardSegment = record
    SegmentId: string;
    OrderIdx: Integer;
    DurationSec: Integer;
    OpeningAssetId: string;
    OpeningUri: string;
    ClosingAssetId: string;
    ClosingUri: string;
    DialogueText: string;
    NotesText: string;
  end;

  TSceneBoard = record
    BoardId: string;
    ReferenceAssetId, ReferenceSha: string;
    SceneId: string;
    OrderIdx: Integer;
    Heading: string;
    DurationSec: Integer;
    OpeningAssetId: string;
    OpeningUri: string;
    ClosingAssetId: string;
    ClosingUri: string;
    DialogueText: string;
    DirectionNotes: string;
    Status: string; // generated | approved | rejected | edited
    Segments: array of TBoardSegment;
  end;

  TMboardMainForm = class(TForm)
  private
    FAi: TMmpAiBridge;
    FProd: TMmpProduction;
    FProj: TMmpProjectRef;
    FScriptProj: TMmpProjectRef;
    FVisualProj: TMmpProjectRef;
    FProjectDir: string;
    FCurrentRevId: string;
    FScriptRevId: string;
    FVisualRevId: string;
    FBoards: array of TSceneBoard;
    FSelectedBoard: Integer;

    FHeaderProdLabel: TLabel;
    FHeaderSourceLabel: TLabel;
    FBoardsGrid: TStringGrid;
    FSegmentsGrid: TStringGrid;
    FOpenImg: TImage;
    FCloseImg: TImage;
    FDurEdit: TEdit;
    FDialogueMemo: TMemo;
    FNotesMemo: TMemo;
    FLogMemo: TMemo;
    FStatusLabel: TLabel;

    procedure BuildUI;
    procedure LogMsg(const Msg: string);
    procedure LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
    procedure LoadBoardsFromRevision(const RevId: string);
    procedure RefreshBoardsGrid;
    procedure RefreshSelectedBoard;
    procedure RefreshSegmentsGrid;
    function FindSceneReference(const SceneId: string; out ArtifactId: string): string;
    function FindFrame(const RelUri: string): string;
    function GenerateFrame(const Prompt, ReferencePath, AssetId: string; out RelUri: string): Boolean;
    function ValidBoard(const Board: TSceneBoard): Boolean;
    function BoardsToJson: string;
    procedure SaveRevision(const NewState, ChangeEventId: string);

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnGenerateFromSourcesClick(Sender: TObject);
    procedure OnSubdivideClick(Sender: TObject);
    procedure OnApplyEditClick(Sender: TObject);
    procedure OnApproveBoardClick(Sender: TObject);
    procedure OnPublishClick(Sender: TObject);
    procedure OnEmitCascadeClick(Sender: TObject);
    procedure OnBoardsGridSelection(Sender: TObject; aCol, aRow: Integer);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mboardMainForm: TMboardMainForm;

implementation

constructor TMboardMainForm.Create(TheOwner: TComponent);
var
  ProdRoot, ProjId, RevId, MMenuVer, ProdId: string;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MBoard - Storyboard e Sincronizacao (MaurinMovie)';
  Width := 1220;
  Height := 760;
  Position := poScreenCenter;
  Constraints.MinWidth := 940;
  Constraints.MinHeight := 620;

  FAi := TMmpAiBridge.Create('MBoard');
  FSelectedBoard := -1;
  BuildUI;

  ParseAppLaunchContext(ProdRoot, ProjId, RevId, MMenuVer, ProdId);
  LogMsg('MBoard v' + MMP_EXECUTABLE_VERSION + ' iniciado (openai_core + openai_image) | MMenu v' +
    MMenuVer + ' | Projeto: ' + ProjId);
  if ProdRoot <> '' then
    LoadProductionAndRevision(ProdRoot, ProjId, RevId);
end;

destructor TMboardMainForm.Destroy;
begin
  FAi.Free;
  inherited Destroy;
end;

procedure TMboardMainForm.BuildUI;
var
  Head, Sidebar, Bottom, DetailPanel: TPanel;
  PC: TPageControl;
  TabBoard, TabSegs, TabLog: TTabSheet;
  BtnOpen, BtnAiCfg, BtnGen, BtnSubdiv, BtnApply, BtnApprove, BtnPublish, BtnCascade: TButton;
  L: TLabel;
begin
  Head := TPanel.Create(Self);
  Head.Parent := Self;
  Head.Align := alTop;
  Head.Height := 68;
  Head.BevelOuter := bvNone;
  Head.Color := $003A3028;
  Head.ParentBackground := False;

  L := TLabel.Create(Self);
  L.Parent := Head;
  L.Caption := 'MaurinMovie  |  3 - MBoard';
  L.Font.Size := 16;
  L.Font.Style := [fsBold];
  L.Font.Color := clWhite;
  L.SetBounds(16, 10, 320, 26);

  FHeaderProdLabel := TLabel.Create(Self);
  FHeaderProdLabel.Parent := Head;
  FHeaderProdLabel.Caption := 'Nenhuma producao carregada';
  FHeaderProdLabel.Font.Color := clWhite;
  FHeaderProdLabel.Font.Style := [fsBold];
  FHeaderProdLabel.SetBounds(340, 12, 420, 20);

  FHeaderSourceLabel := TLabel.Create(Self);
  FHeaderSourceLabel.Parent := Head;
  FHeaderSourceLabel.Caption := 'Fontes: MScript (-) | MVisual (-)';
  FHeaderSourceLabel.Font.Color := $0099E6FF;
  FHeaderSourceLabel.SetBounds(340, 36, 460, 18);

  BtnAiCfg := TButton.Create(Self);
  BtnAiCfg.Parent := Head;
  BtnAiCfg.Caption := 'Alterar no MMenu...';
  BtnAiCfg.Anchors := [akTop, akRight];
  BtnAiCfg.SetBounds(1082, 17, 122, 34);
  BtnAiCfg.OnClick := @OnAiConfigClick;

  BtnPublish := TButton.Create(Self);
  BtnPublish.Parent := Head;
  BtnPublish.Caption := 'Publicar Revisao';
  BtnPublish.Anchors := [akTop, akRight];
  BtnPublish.SetBounds(934, 17, 140, 34);
  BtnPublish.OnClick := @OnPublishClick;

  BtnCascade := TButton.Create(Self);
  BtnCascade.Parent := Head;
  BtnCascade.Caption := 'Aprovar e Cascata';
  BtnCascade.Anchors := [akTop, akRight];
  BtnCascade.SetBounds(782, 17, 144, 34);
  BtnCascade.OnClick := @OnEmitCascadeClick;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 34;
  Bottom.BevelOuter := bvLowered;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Bottom;
  FStatusLabel.SetBounds(12, 9, 1100, 18);
  FStatusLabel.Caption := 'Pronto.';

  Sidebar := TPanel.Create(Self);
  Sidebar.Parent := Self;
  Sidebar.Align := alLeft;
  Sidebar.Width := 255;
  Sidebar.BevelOuter := bvNone;
  Sidebar.Color := $00EFEFEF;
  Sidebar.ParentBackground := False;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := Sidebar;
  BtnOpen.Caption := 'Abrir producao...';
  BtnOpen.SetBounds(12, 14, 231, 34);
  BtnOpen.OnClick := @OnOpenProdClick;

  BtnGen := TButton.Create(Self);
  BtnGen.Parent := Sidebar;
  BtnGen.Caption := 'Etapa 1: Gerar Storyboard';
  BtnGen.SetBounds(12, 58, 231, 34);
  BtnGen.OnClick := @OnGenerateFromSourcesClick;

  BtnSubdiv := TButton.Create(Self);
  BtnSubdiv.Parent := Sidebar;
  BtnSubdiv.Caption := 'Etapa 2: Subdividir Cena...';
  BtnSubdiv.SetBounds(12, 100, 231, 34);
  BtnSubdiv.OnClick := @OnSubdivideClick;

  BtnApprove := TButton.Create(Self);
  BtnApprove.Parent := Sidebar;
  BtnApprove.Caption := 'Aprovar Cena Selecionada';
  BtnApprove.SetBounds(12, 142, 231, 34);
  BtnApprove.OnClick := @OnApproveBoardClick;

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.WordWrap := True;
  L.Caption := 'Regra de continuidade:' + LineEnding +
    'O quadro final do segmento i referencia exatamente o mesmo asset_id do quadro inicial do segmento i+1.';
  L.SetBounds(12, 196, 231, 74);

  PC := TPageControl.Create(Self);
  PC.Parent := Self;
  PC.Align := alClient;

  TabBoard := TTabSheet.Create(PC); TabBoard.PageControl := PC; TabBoard.Caption := 'Quadros & Edicao';
  TabSegs := TTabSheet.Create(PC); TabSegs.PageControl := PC; TabSegs.Caption := 'Segmentos & Continuidade';
  TabLog := TTabSheet.Create(PC); TabLog.PageControl := PC; TabLog.Caption := 'Log Operacional';

  FBoardsGrid := TStringGrid.Create(Self);
  FBoardsGrid.Parent := TabBoard;
  FBoardsGrid.Align := alTop;
  FBoardsGrid.Height := 190;
  FBoardsGrid.FixedCols := 0;
  FBoardsGrid.FixedRows := 1;
  FBoardsGrid.ColCount := 6;
  FBoardsGrid.RowCount := 2;
  FBoardsGrid.Options := FBoardsGrid.Options + [goRowSelect, goColSizing];
  FBoardsGrid.Cells[0, 0] := 'Board ID';
  FBoardsGrid.Cells[1, 0] := 'Cena ID';
  FBoardsGrid.Cells[2, 0] := 'Cabecalho';
  FBoardsGrid.Cells[3, 0] := 'Dur (s)';
  FBoardsGrid.Cells[4, 0] := 'Segmentos';
  FBoardsGrid.Cells[5, 0] := 'Status';
  FBoardsGrid.ColWidths[0] := 125;
  FBoardsGrid.ColWidths[1] := 115;
  FBoardsGrid.ColWidths[2] := 260;
  FBoardsGrid.ColWidths[3] := 70;
  FBoardsGrid.ColWidths[4] := 85;
  FBoardsGrid.ColWidths[5] := 105;
  FBoardsGrid.OnSelection := @OnBoardsGridSelection;

  DetailPanel := TPanel.Create(Self);
  DetailPanel.Parent := TabBoard;
  DetailPanel.Align := alClient;
  DetailPanel.BevelOuter := bvNone;

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Quadro Inicial:'; L.Font.Style := [fsBold]; L.SetBounds(12, 8, 150, 18);
  FOpenImg := TImage.Create(Self); FOpenImg.Parent := DetailPanel; FOpenImg.Stretch := True; FOpenImg.Proportional := True;
  FOpenImg.SetBounds(12, 28, 280, 160);

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Quadro Final:'; L.Font.Style := [fsBold]; L.SetBounds(308, 8, 150, 18);
  FCloseImg := TImage.Create(Self); FCloseImg.Parent := DetailPanel; FCloseImg.Stretch := True; FCloseImg.Proportional := True;
  FCloseImg.SetBounds(308, 28, 280, 160);

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Duracao (s):'; L.SetBounds(604, 10, 90, 18);
  FDurEdit := TEdit.Create(Self); FDurEdit.Parent := DetailPanel; FDurEdit.SetBounds(696, 6, 80, 24);

  BtnApply := TButton.Create(Self); BtnApply.Parent := DetailPanel;
  BtnApply.Caption := 'Salvar Ajuste (Rascunho)'; BtnApply.SetBounds(604, 40, 190, 30);
  BtnApply.OnClick := @OnApplyEditClick;

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Falas / Acao da cena:'; L.SetBounds(12, 198, 200, 18);
  FDialogueMemo := TMemo.Create(Self); FDialogueMemo.Parent := DetailPanel;
  FDialogueMemo.ScrollBars := ssVertical; FDialogueMemo.SetBounds(12, 218, 430, 175);

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Orientacoes de ambiente e camera:'; L.SetBounds(456, 198, 250, 18);
  FNotesMemo := TMemo.Create(Self); FNotesMemo.Parent := DetailPanel;
  FNotesMemo.ScrollBars := ssVertical; FNotesMemo.SetBounds(456, 218, 430, 175);

  FSegmentsGrid := TStringGrid.Create(Self);
  FSegmentsGrid.Parent := TabSegs;
  FSegmentsGrid.Align := alClient;
  FSegmentsGrid.FixedCols := 0;
  FSegmentsGrid.FixedRows := 1;
  FSegmentsGrid.ColCount := 6;
  FSegmentsGrid.RowCount := 2;
  FSegmentsGrid.Options := FSegmentsGrid.Options + [goRowSelect, goColSizing];
  FSegmentsGrid.Cells[0, 0] := 'Segment ID';
  FSegmentsGrid.Cells[1, 0] := 'Ordem';
  FSegmentsGrid.Cells[2, 0] := 'Dur (s)';
  FSegmentsGrid.Cells[3, 0] := 'Asset Inicial';
  FSegmentsGrid.Cells[4, 0] := 'Asset Final';
  FSegmentsGrid.Cells[5, 0] := 'Notas';
  FSegmentsGrid.ColWidths[0] := 130;
  FSegmentsGrid.ColWidths[1] := 60;
  FSegmentsGrid.ColWidths[2] := 70;
  FSegmentsGrid.ColWidths[3] := 160;
  FSegmentsGrid.ColWidths[4] := 160;
  FSegmentsGrid.ColWidths[5] := 260;

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := TabLog;
  FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssBoth;
end;

procedure TMboardMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
  if FProd.Loaded then
    MmpLogAppOperation(FProd.RootDir, FProd.ProductionId, 'MBoard', Msg, FCurrentRevId);
end;

procedure TMboardMainForm.LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
var
  ErrMsg: string;
begin
  if not ResolveAppProject(ProdRoot, 3, ProjId, RevId, FProd, FProj,
    FProjectDir, FCurrentRevId, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  FAi.LoadForProduction(FProd.RootDir);
  FindProjectByApp(FProd, 1, FScriptProj);
  FindProjectByApp(FProd, 2, FVisualProj);
  FScriptRevId := FScriptProj.ActiveRevision;
  FVisualRevId := FVisualProj.ActiveRevision;

  FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
  FHeaderSourceLabel.Caption := Format('Fontes: MScript (%s) | MVisual (%s) | MBoard: %s',
    [FScriptRevId, FVisualRevId, FCurrentRevId]);

  LoadBoardsFromRevision(FCurrentRevId);
  RefreshBoardsGrid;
  LogMsg('Producao carregada em MBoard.');
end;

procedure TMboardMainForm.LoadBoardsFromRevision(const RevId: string);
var
  Path, Content: string;
  Data: TJSONData;
  Obj, BObj, SObj: TJSONObject;
  BArr, SArr: TJSONArray;
  I, J: Integer;
begin
  SetLength(FBoards, 0);
  Path := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
    RevId + PathDelim + 'storyboard' + PathDelim + 'scenes.json';
  if not FileExists(Path) then Exit;
  if not ReadTextFileUtf8(Path, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  try
    FScriptRevId := Obj.Get('script_revision', FScriptRevId);
    FVisualRevId := Obj.Get('visual_revision', FVisualRevId);
    if Obj.Find('scene_boards') is TJSONArray then
    begin
      BArr := TJSONArray(Obj.Find('scene_boards'));
      SetLength(FBoards, BArr.Count);
      for I := 0 to BArr.Count - 1 do
      begin
        BObj := TJSONObject(BArr.Items[I]);
        FBoards[I].BoardId := BObj.Get('board_id', '');
        FBoards[I].ReferenceAssetId := BObj.Get('visual_reference_asset_id', '');
        FBoards[I].ReferenceSha := BObj.Get('visual_reference_sha256', '');
        FBoards[I].SceneId := BObj.Get('scene_id', '');
        FBoards[I].OrderIdx := BObj.Get('order', I + 1);
        FBoards[I].Heading := BObj.Get('heading', '');
        FBoards[I].DurationSec := BObj.Get('estimated_duration_seconds', 30);
        FBoards[I].OpeningAssetId := BObj.Get('opening_asset_id', '');
        FBoards[I].OpeningUri := BObj.Get('opening_uri', '');
        FBoards[I].ClosingAssetId := BObj.Get('closing_asset_id', '');
        FBoards[I].ClosingUri := BObj.Get('closing_uri', '');
        FBoards[I].DialogueText := BObj.Get('dialogue', '');
        FBoards[I].DirectionNotes := BObj.Get('direction_notes', '');
        FBoards[I].Status := BObj.Get('status', 'generated');

        if BObj.Find('segments') is TJSONArray then
        begin
          SArr := TJSONArray(BObj.Find('segments'));
          SetLength(FBoards[I].Segments, SArr.Count);
          for J := 0 to SArr.Count - 1 do
          begin
            SObj := TJSONObject(SArr.Items[J]);
            FBoards[I].Segments[J].SegmentId := SObj.Get('segment_id', '');
            FBoards[I].Segments[J].OrderIdx := SObj.Get('order', J + 1);
            FBoards[I].Segments[J].DurationSec := SObj.Get('duration_seconds', 15);
            FBoards[I].Segments[J].OpeningAssetId := SObj.Get('opening_asset_id', '');
            FBoards[I].Segments[J].OpeningUri := SObj.Get('opening_uri', '');
            FBoards[I].Segments[J].ClosingAssetId := SObj.Get('closing_asset_id', '');
            FBoards[I].Segments[J].ClosingUri := SObj.Get('closing_uri', '');
            FBoards[I].Segments[J].DialogueText := SObj.Get('dialogue', '');
            FBoards[I].Segments[J].NotesText := SObj.Get('direction_notes', '');
          end;
        end;
      end;
    end;
  finally
    Obj.Free;
  end;
end;

function TMboardMainForm.FindFrame(const RelUri: string): string;
begin
  Result := '';
  if ResolveSafePath(FProjectDir + PathDelim + 'work', RelUri, Result) and FileExists(Result) then Exit;
  if ResolveSafePath(FProjectDir + PathDelim + 'revisions' + PathDelim + FCurrentRevId,
    RelUri, Result) and FileExists(Result) then Exit;
  Result := '';
end;

function TMboardMainForm.FindSceneReference(const SceneId: string; out ArtifactId: string): string;
var
  Rev: TMmpRevisionInfo;
  TextValue: string;
  Data: TJSONData;
  Items: TJSONArray;
  Item: TJSONObject;
  I, J, Pass: Integer;
begin
  Result := '';
  ArtifactId := '';
  if not FindRevisionInProject(FVisualProj, FVisualRevId, Rev) then Exit;
  if not ReadTextFileUtf8(ExtractFileDir(Rev.ManifestPath) + PathDelim +
    'indexes' + PathDelim + 'entities.json', TextValue) then Exit;
  Data := GetJSON(TextValue);
  try
    if not (Data.FindPath('entities') is TJSONArray) then Exit;
    Items := TJSONArray(Data.FindPath('entities'));
    for Pass := 0 to 1 do
      for I := 0 to Items.Count - 1 do
      begin
        Item := Items.Objects[I];
        if ((Pass = 0) and (Item.Get('kind', '') <> 'location')) or
          (Item.Get('approval_status', '') <> 'approved') or
          (Pos(',' + SceneId + ',', ',' + StringReplace(Item.Get('scenes_csv', ''),
            ', ', ',', [rfReplaceAll]) + ',') = 0) then Continue;
        for J := 0 to High(Rev.Artifacts) do
          with Rev.Artifacts[J] do
            if (Uri = Item.Get('front_uri', '')) and (Status = 'approved') and
              (Sha256 <> '') and FileExists(ResolvedPath) and SameText(SHA256File(ResolvedPath), Sha256) then
            begin
              ArtifactId := Rev.Artifacts[J].ArtifactId;
              Exit(ResolvedPath);
            end;
      end;
  finally
    Data.Free;
  end;
end;

function TMboardMainForm.GenerateFrame(const Prompt, ReferencePath, AssetId: string;
  out RelUri: string): Boolean;
var
  Provider: TMmpAiProviderCfg;
  OutputFile, Err: string;
begin
  Result := False;
  FAi.ReloadIfChanged;
  FAi.Settings.ResolveProvider('image', maMBoard, Provider);
  RelUri := 'images/quadros/' + AssetId;
  if Provider.Enabled and (SameText(Provider.Adapter, 'mock') or FAi.Settings.OfflineMode) then
  begin
    RelUri := RelUri + '.bmp';
    ResolveSafePath(FProjectDir + PathDelim + 'work', RelUri, OutputFile);
    Result := SavePlaceholderBitmap(OutputFile, 'Storyboard simulado', Prompt, AssetId, $00383044);
  end
  else
  begin
    RelUri := RelUri + '.png';
    ResolveSafePath(FProjectDir + PathDelim + 'work', RelUri, OutputFile);
    if ForceDirectories(ExtractFileDir(OutputFile)) then
      Result := FAi.GenerateImage(Prompt, OutputFile, Err, '', 0, 0, ReferencePath) and FileExists(OutputFile);
    if not Result then LogMsg('Falha ao gerar quadro: ' + Err);
  end;
  if not Result then RelUri := '';
end;

function TMboardMainForm.ValidBoard(const Board: TSceneBoard): Boolean;
var
  I: Integer;
  Total: Int64;
begin
  Result := False;
  if (Board.DurationSec < 1) or (Length(Board.Segments) = 0) or
    (FindFrame(Board.OpeningUri) = '') or (FindFrame(Board.ClosingUri) = '') or
    (Board.Segments[0].OpeningAssetId <> Board.OpeningAssetId) or
    (Board.Segments[High(Board.Segments)].ClosingAssetId <> Board.ClosingAssetId) then Exit;
  Total := 0;
  for I := 0 to High(Board.Segments) do
    with Board.Segments[I] do
    begin
      if (DurationSec < 1) or (FindFrame(OpeningUri) = '') or (FindFrame(ClosingUri) = '') then Exit;
      if I > 0 then
        if (OpeningAssetId <> Board.Segments[I - 1].ClosingAssetId) or
          (OpeningUri <> Board.Segments[I - 1].ClosingUri) then Exit;
      Inc(Total, DurationSec);
    end;
  Result := Total = Board.DurationSec;
end;

procedure TMboardMainForm.OnGenerateFromSourcesClick(Sender: TObject);
var
  ScriptPath, Content, OpenRel, CloseRel, ReferencePath, ContinuityRef: string;
  Data: TJSONData;
  Obj, SItem: TJSONObject;
  Arr: TJSONArray;
  I, J: Integer;
  PreviousBoards: array of TSceneBoard;
  ReferenceShaValue: string;
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
    MessageDlg('Roteiro nao encontrado em MScript @ ' + FScriptRevId, mtWarning, [mbOK], 0);
    Exit;
  end;
  if not ReadTextFileUtf8(ScriptPath, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  try
    if not (Obj.Find('scenes') is TJSONArray) then Exit;
    Arr := TJSONArray(Obj.Find('scenes'));
    PreviousBoards := FBoards;
    FBoards := nil;
    SetLength(FBoards, Arr.Count);
    FScriptRevId := FScriptProj.ActiveRevision;
    FVisualRevId := FVisualProj.ActiveRevision;

    for I := 0 to Arr.Count - 1 do
    begin
      SItem := TJSONObject(Arr.Items[I]);
      FBoards[I].BoardId := GenerateMmpId('brd');
      FBoards[I].SceneId := SItem.Get('scene_id', '');
      FBoards[I].OrderIdx := SItem.Get('sequence', I + 1);
      FBoards[I].Heading := SItem.Get('heading', '');
      FBoards[I].DurationSec := SItem.Get('estimated_duration', 30);
      FBoards[I].DialogueText := SItem.Get('dialogue_text', '');
      FBoards[I].DirectionNotes := SItem.Get('action', '');
      FBoards[I].Status := 'generated';

      ReferencePath := FindSceneReference(FBoards[I].SceneId, FBoards[I].ReferenceAssetId);
      ReferenceShaValue := '';
      if ReferencePath <> '' then ReferenceShaValue := SHA256File(ReferencePath);
      FBoards[I].ReferenceSha := ReferenceShaValue;
      for J := 0 to High(PreviousBoards) do
        if (PreviousBoards[J].SceneId = FBoards[I].SceneId) and
          (PreviousBoards[J].Heading = FBoards[I].Heading) and
          (PreviousBoards[J].DurationSec = FBoards[I].DurationSec) and
          (PreviousBoards[J].DirectionNotes = FBoards[I].DirectionNotes) and
          (PreviousBoards[J].DialogueText = FBoards[I].DialogueText) and
          (PreviousBoards[J].ReferenceSha = ReferenceShaValue) and
          (PreviousBoards[J].Status = 'approved') and ValidBoard(PreviousBoards[J]) then
        begin
          PreviousBoards[J].ReferenceAssetId := FBoards[I].ReferenceAssetId;
          PreviousBoards[J].OrderIdx := FBoards[I].OrderIdx;
          FBoards[I] := PreviousBoards[J];
          Break;
        end;
      if FBoards[I].Status = 'approved' then Continue;
      if ReferencePath = '' then LogMsg('Cena sem imagem de referência aprovada: ' + FBoards[I].SceneId);
      FBoards[I].OpeningAssetId := GenerateMmpId('a_qopen');
      FBoards[I].ClosingAssetId := GenerateMmpId('a_qclose');
      if not GenerateFrame('Quadro inicial: ' + FBoards[I].Heading + ' | ' +
        FBoards[I].DirectionNotes, ReferencePath, FBoards[I].OpeningAssetId, OpenRel) then
        FBoards[I].Status := 'failed';
      ContinuityRef := FindFrame(OpenRel);
      if ContinuityRef = '' then ContinuityRef := ReferencePath;
      if not GenerateFrame('Quadro final. Preserve a identidade e mostre o resultado da ação: ' +
        FBoards[I].Heading + ' | ' + FBoards[I].DirectionNotes, ContinuityRef,
        FBoards[I].ClosingAssetId, CloseRel) then
        FBoards[I].Status := 'failed';
      FBoards[I].OpeningUri := OpenRel;
      FBoards[I].ClosingUri := CloseRel;

      SetLength(FBoards[I].Segments, 1);
      FBoards[I].Segments[0].SegmentId := GenerateMmpId('sg');
      FBoards[I].Segments[0].OrderIdx := 1;
      FBoards[I].Segments[0].DurationSec := FBoards[I].DurationSec;
      FBoards[I].Segments[0].OpeningAssetId := FBoards[I].OpeningAssetId;
      FBoards[I].Segments[0].OpeningUri := OpenRel;
      FBoards[I].Segments[0].ClosingAssetId := FBoards[I].ClosingAssetId;
      FBoards[I].Segments[0].ClosingUri := CloseRel;
      FBoards[I].Segments[0].DialogueText := FBoards[I].DialogueText;
      FBoards[I].Segments[0].NotesText := FBoards[I].DirectionNotes;
    end;
  finally
    Obj.Free;
  end;

  RefreshBoardsGrid;
  LogMsg('Etapa 1: Storyboard gerado para ' + IntToStr(Length(FBoards)) + ' cenas (aguardando revisao).');
end;

procedure TMboardMainForm.OnSubdivideClick(Sender: TObject);
var
  CountStr, MidId, MidRel: string;
  N, I, SegDur, Rem: Integer;
  Parts: array of TBoardSegment;
  Lines: TMmpDialogueLines;
begin
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then Exit;
  CountStr := '2';
  if not InputQuery('Subdividir Cena em Segmentos', 'Quantidade de segmentos:', CountStr) then Exit;
  if not TryStrToInt(CountStr, N) or (N < 1) or (N > 60) or
    (N > FBoards[FSelectedBoard].DurationSec) then
  begin
    MessageDlg('Informe de 1 a 60 segmentos, com pelo menos um segundo por segmento.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  Lines := ParseMmpDialogue(FBoards[FSelectedBoard].DialogueText);
  SegDur := FBoards[FSelectedBoard].DurationSec div N;
  Rem := FBoards[FSelectedBoard].DurationSec mod N;
  SetLength(Parts, N);

  for I := 0 to N - 1 do
  begin
    Parts[I].SegmentId := GenerateMmpId('sg');
    Parts[I].OrderIdx := I + 1;
    Parts[I].DurationSec := SegDur;
    if I = N - 1 then
      Parts[I].DurationSec := SegDur + Rem;

    if I = 0 then
    begin
      Parts[I].OpeningAssetId := FBoards[FSelectedBoard].OpeningAssetId;
      Parts[I].OpeningUri := FBoards[FSelectedBoard].OpeningUri;
    end
    else
    begin
      // Continuidade exata: o asset inicial do segmento i eh exatamente o final do segmento i-1
      Parts[I].OpeningAssetId := Parts[I - 1].ClosingAssetId;
      Parts[I].OpeningUri := Parts[I - 1].ClosingUri;
    end;

    if I = N - 1 then
    begin
      Parts[I].ClosingAssetId := FBoards[FSelectedBoard].ClosingAssetId;
      Parts[I].ClosingUri := FBoards[FSelectedBoard].ClosingUri;
    end
    else
    begin
      MidId := GenerateMmpId('a_qmid');
      if not GenerateFrame(Format('Quadro de transição %d/%d: %s | %s',
        [I + 1, N, FBoards[FSelectedBoard].Heading, FBoards[FSelectedBoard].DirectionNotes]),
        FindFrame(Parts[I].OpeningUri), MidId, MidRel) then
      begin
        MessageDlg('Falha ao gerar a fronteira. A divisão anterior foi preservada.',
          mtError, [mbOK], 0);
        Exit;
      end;
      Parts[I].ClosingAssetId := MidId;
      Parts[I].ClosingUri := MidRel;
    end;
    Parts[I].DialogueText := MmpDialoguePortion(Lines, I, N);
    Parts[I].NotesText := 'Segmento ' + IntToStr(I + 1) + '/' + IntToStr(N);
  end;

  FBoards[FSelectedBoard].Segments := Parts;
  FBoards[FSelectedBoard].Status := 'generated';
  RefreshBoardsGrid;
  RefreshSegmentsGrid;
  LogMsg('Cena subdividida em ' + IntToStr(N) + ' segmentos com continuidade exata por asset_id.');
end;

procedure TMboardMainForm.RefreshBoardsGrid;
var
  I, Row: Integer;
begin
  if Length(FBoards) = 0 then
  begin
    FBoardsGrid.RowCount := 2;
    for I := 0 to FBoardsGrid.ColCount - 1 do FBoardsGrid.Cells[I, 1] := '';
    FSelectedBoard := -1;
    RefreshSelectedBoard;
    Exit;
  end;
  FBoardsGrid.RowCount := Length(FBoards) + 1;
  for I := 0 to High(FBoards) do
  begin
    Row := I + 1;
    FBoardsGrid.Cells[0, Row] := FBoards[I].BoardId;
    FBoardsGrid.Cells[1, Row] := FBoards[I].SceneId;
    FBoardsGrid.Cells[2, Row] := FBoards[I].Heading;
    FBoardsGrid.Cells[3, Row] := IntToStr(FBoards[I].DurationSec);
    FBoardsGrid.Cells[4, Row] := IntToStr(Length(FBoards[I].Segments));
    FBoardsGrid.Cells[5, Row] := FBoards[I].Status;
  end;
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then FSelectedBoard := 0;
  FBoardsGrid.Row := FSelectedBoard + 1;
  RefreshSelectedBoard;
end;

procedure TMboardMainForm.RefreshSelectedBoard;
var
  P1, P2: string;
begin
  FOpenImg.Picture := nil;
  FCloseImg.Picture := nil;
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then
  begin
    RefreshSegmentsGrid;
    Exit;
  end;
  FDurEdit.Text := IntToStr(FBoards[FSelectedBoard].DurationSec);
  FDialogueMemo.Text := FBoards[FSelectedBoard].DialogueText;
  FNotesMemo.Text := FBoards[FSelectedBoard].DirectionNotes;

  P1 := FindFrame(FBoards[FSelectedBoard].OpeningUri);
  P2 := FindFrame(FBoards[FSelectedBoard].ClosingUri);
  if FileExists(P1) then FOpenImg.Picture.LoadFromFile(P1);
  if FileExists(P2) then FCloseImg.Picture.LoadFromFile(P2);
  RefreshSegmentsGrid;
end;

procedure TMboardMainForm.RefreshSegmentsGrid;
var
  I, Row: Integer;
begin
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) or
     (Length(FBoards[FSelectedBoard].Segments) = 0) then
  begin
    FSegmentsGrid.RowCount := 2;
    for I := 0 to FSegmentsGrid.ColCount - 1 do FSegmentsGrid.Cells[I, 1] := '';
    Exit;
  end;
  FSegmentsGrid.RowCount := Length(FBoards[FSelectedBoard].Segments) + 1;
  for I := 0 to High(FBoards[FSelectedBoard].Segments) do
  begin
    Row := I + 1;
    with FBoards[FSelectedBoard].Segments[I] do
    begin
      FSegmentsGrid.Cells[0, Row] := SegmentId;
      FSegmentsGrid.Cells[1, Row] := IntToStr(OrderIdx);
      FSegmentsGrid.Cells[2, Row] := IntToStr(DurationSec);
      FSegmentsGrid.Cells[3, Row] := OpeningAssetId;
      FSegmentsGrid.Cells[4, Row] := ClosingAssetId;
      FSegmentsGrid.Cells[5, Row] := NotesText;
    end;
  end;
end;

function TMboardMainForm.BoardsToJson: string;
var
  Root, BObj, SObj: TJSONObject;
  BArr, SArr: TJSONArray;
  I, J: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.mboard.storyboard/1');
    Root.Add('script_revision', FScriptRevId);
    Root.Add('visual_revision', FVisualRevId);
    BArr := TJSONArray.Create;
    for I := 0 to High(FBoards) do
    begin
      BObj := TJSONObject.Create;
      BObj.Add('board_id', FBoards[I].BoardId);
      BObj.Add('visual_reference_asset_id', FBoards[I].ReferenceAssetId);
      BObj.Add('visual_reference_sha256', FBoards[I].ReferenceSha);
      BObj.Add('scene_id', FBoards[I].SceneId);
      BObj.Add('order', FBoards[I].OrderIdx);
      BObj.Add('heading', FBoards[I].Heading);
      BObj.Add('estimated_duration_seconds', FBoards[I].DurationSec);
      BObj.Add('opening_asset_id', FBoards[I].OpeningAssetId);
      BObj.Add('opening_uri', FBoards[I].OpeningUri);
      BObj.Add('closing_asset_id', FBoards[I].ClosingAssetId);
      BObj.Add('closing_uri', FBoards[I].ClosingUri);
      BObj.Add('dialogue', FBoards[I].DialogueText);
      BObj.Add('direction_notes', FBoards[I].DirectionNotes);
      BObj.Add('status', FBoards[I].Status);
      SArr := TJSONArray.Create;
      for J := 0 to High(FBoards[I].Segments) do
      begin
        SObj := TJSONObject.Create;
        SObj.Add('segment_id', FBoards[I].Segments[J].SegmentId);
        SObj.Add('order', FBoards[I].Segments[J].OrderIdx);
        SObj.Add('duration_seconds', FBoards[I].Segments[J].DurationSec);
        SObj.Add('opening_asset_id', FBoards[I].Segments[J].OpeningAssetId);
        SObj.Add('opening_uri', FBoards[I].Segments[J].OpeningUri);
        SObj.Add('closing_asset_id', FBoards[I].Segments[J].ClosingAssetId);
        SObj.Add('closing_uri', FBoards[I].Segments[J].ClosingUri);
        SObj.Add('dialogue', FBoards[I].Segments[J].DialogueText);
        SObj.Add('direction_notes', FBoards[I].Segments[J].NotesText);
        SArr.Add(SObj);
      end;
      BObj.Add('segments', SArr);
      BArr.Add(BObj);
    end;
    Root.Add('scene_boards', BArr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

procedure TMboardMainForm.SaveRevision(const NewState, ChangeEventId: string);
var
  PrepRev, RevDir, NewRev, ErrMsg: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, J, ArtCount: Integer;

  procedure CopyAndAddFrame(const Aid, SceneId, SegId, RelUri, StatusStr: string);
  var
    SrcF, DstF: string;
  begin
    SrcF := FindFrame(RelUri);
    if (SrcF = '') or not ResolveSafePath(RevDir, RelUri, DstF) or
      not ForceDirectories(ExtractFileDir(DstF)) or not CopyFile(SrcF, DstF) then
      raise Exception.Create('Não foi possível publicar o quadro ' + Aid + '.');
    ArtCount := Length(Arts);
    SetLength(Arts, ArtCount + 1);
    Arts[ArtCount].ArtifactId := Aid;
    Arts[ArtCount].Kind := 'storyboard.frame';
    Arts[ArtCount].SceneId := SceneId;
    Arts[ArtCount].SegmentId := SegId;
    Arts[ArtCount].RelUri := RelUri;
    if SameText(ExtractFileExt(RelUri), '.png') then Arts[ArtCount].MimeType := 'image/png'
    else Arts[ArtCount].MimeType := 'image/bmp';
    Arts[ArtCount].Status := StatusStr;
  end;
begin
  if not FProd.Loaded then Exit;
  if Length(FBoards) = 0 then Exit;
  for I := 0 to High(FBoards) do
    if (FBoards[I].Status <> 'approved') or not ValidBoard(FBoards[I]) then
    begin
      MessageDlg('Revise e aprove os quadros e os tempos de cada cena antes de publicar.',
        mtWarning, [mbOK], 0);
      Exit;
    end;
  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;
  if not AtomicWriteTextFile(RevDir + PathDelim + 'storyboard' + PathDelim + 'scenes.json',
    BoardsToJson, False) then
    raise Exception.Create('Não foi possível publicar os dados do storyboard.');

  SetLength(Arts, 1);
  Arts[0].ArtifactId := GenerateMmpId('a');
  Arts[0].Kind := 'storyboard.segment';
  Arts[0].RelUri := 'storyboard/scenes.json';
  Arts[0].MimeType := 'application/json';
  Arts[0].Status := NewState;

  for I := 0 to High(FBoards) do
  begin
    CopyAndAddFrame(FBoards[I].OpeningAssetId, FBoards[I].SceneId, '', FBoards[I].OpeningUri, FBoards[I].Status);
    CopyAndAddFrame(FBoards[I].ClosingAssetId, FBoards[I].SceneId, '', FBoards[I].ClosingUri, FBoards[I].Status);
    for J := 0 to High(FBoards[I].Segments) do
      if (J < High(FBoards[I].Segments)) then
        CopyAndAddFrame(FBoards[I].Segments[J].ClosingAssetId, FBoards[I].SceneId,
          FBoards[I].Segments[J].SegmentId, FBoards[I].Segments[J].ClosingUri, FBoards[I].Status);
  end;

  SetLength(Srcs, 2);
  Srcs[0].ProjectId := FScriptProj.ProjectId;
  Srcs[0].RevisionId := FScriptRevId;
  if FindRevisionInProject(FScriptProj, FScriptRevId, RevInfo) then
    Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;

  Srcs[1].ProjectId := FVisualProj.ProjectId;
  Srcs[1].RevisionId := FVisualRevId;
  if FindRevisionInProject(FVisualProj, FVisualRevId, RevInfo) then
    Srcs[1].ManifestSha256 := RevInfo.ManifestSha256;

  if PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MBoard',
    FCurrentRevId, NewState, ChangeEventId, Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    LogMsg('Revisao MBoard publicada: ' + NewRev);
    LoadProductionAndRevision(FProd.RootDir, FProj.ProjectId, NewRev);
  end
  else
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
end;

procedure TMboardMainForm.OnOpenProdClick(Sender: TObject);
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

procedure TMboardMainForm.OnAiConfigClick(Sender: TObject);
begin
  if FAi.ShowConfigDialog(Self) then
    LogMsg('IA configurada: ' + FAi.ProviderDisplayName);
end;

procedure TMboardMainForm.OnApplyEditClick(Sender: TObject);
var
  I: Integer;
  Lines: TMmpDialogueLines;
begin
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then Exit;
  FBoards[FSelectedBoard].DurationSec := StrToIntDef(FDurEdit.Text, FBoards[FSelectedBoard].DurationSec);
  FBoards[FSelectedBoard].DialogueText := FDialogueMemo.Text;
  FBoards[FSelectedBoard].DirectionNotes := FNotesMemo.Text;
  if Length(FBoards[FSelectedBoard].Segments) = 1 then
  begin
    FBoards[FSelectedBoard].Segments[0].DurationSec := FBoards[FSelectedBoard].DurationSec;
  end;
  Lines := ParseMmpDialogue(FBoards[FSelectedBoard].DialogueText);
  for I := 0 to High(FBoards[FSelectedBoard].Segments) do
    FBoards[FSelectedBoard].Segments[I].DialogueText := MmpDialoguePortion(Lines, I,
      Length(FBoards[FSelectedBoard].Segments));
  FBoards[FSelectedBoard].Status := 'edited';
  RefreshBoardsGrid;
  LogMsg('Ajuste em rascunho aplicado no storyboard (MScript/MVisual ainda inalterados).');
end;

procedure TMboardMainForm.OnApproveBoardClick(Sender: TObject);
begin
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then Exit;
  if not ValidBoard(FBoards[FSelectedBoard]) then
  begin
    MessageDlg('Confira a continuidade dos quadros e a soma das durações. ' +
      'Se o tempo da cena mudou, subdivida novamente.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FBoards[FSelectedBoard].Status := 'approved';
  RefreshBoardsGrid;
end;

procedure TMboardMainForm.OnPublishClick(Sender: TObject);
begin
  if not FProd.Loaded then Exit;
  SaveRevision('approved', '');
end;

procedure TMboardMainForm.OnEmitCascadeClick(Sender: TObject);
var
  EvtId, Content, ScriptPath, SceneId: string;
  Data: TJSONData;
  Scenes, Ops: TJSONArray;
  Scene: TJSONObject;
  I: Integer;

  procedure RecordChange(const Name, Previous, Edited: string);
  var
    Op: TJSONObject;
  begin
    if Previous = Edited then Exit;
    Op := TJSONObject.Create;
    Op.Add('scene_id', SceneId);
    Op.Add('field', Name);
    Op.Add('operation', 'set');
    Op.Add('from', Previous);
    Op.Add('to', Edited);
    Ops.Add(Op);
  end;

begin
  if not FProd.Loaded or (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then Exit;
  if (FBoards[FSelectedBoard].Status <> 'approved') or not ValidBoard(FBoards[FSelectedBoard]) then
  begin
    MessageDlg('Aprove o storyboard selecionado antes de enviar a correção.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  ScriptPath := ExtractFileDir(FScriptProj.ProjectFilePath) + PathDelim + 'revisions' +
    PathDelim + FScriptRevId + PathDelim + 'scripts' + PathDelim + 'roteiro.json';
  if not ReadTextFileUtf8(ScriptPath, Content) then
  begin
    MessageDlg('A revisão original do roteiro não está disponível.', mtError, [mbOK], 0);
    Exit;
  end;
  SceneId := FBoards[FSelectedBoard].SceneId;
  Data := GetJSON(Content);
  Ops := TJSONArray.Create;
  try
    if not (Data.FindPath('scenes') is TJSONArray) then Exit;
    Scenes := TJSONArray(Data.FindPath('scenes'));
    for I := 0 to Scenes.Count - 1 do
      if Scenes.Objects[I].Get('scene_id', '') = SceneId then
      begin
        Scene := Scenes.Objects[I];
        RecordChange('action', Scene.Get('action', ''), FBoards[FSelectedBoard].DirectionNotes);
        RecordChange('dialogue_text', Scene.Get('dialogue_text', ''), FBoards[FSelectedBoard].DialogueText);
        Break;
      end;
    if Ops.Count = 0 then
    begin
      MessageDlg('Não há mudança de ação ou de diálogo para enviar ao roteiro.',
        mtInformation, [mbOK], 0);
      Exit;
    end;
    if MessageDlg('Enviar as mudanças aprovadas da cena ' + SceneId + ' para o MScript?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
    if EmitSyncEvent(FProd.RootDir, 'MBoard', 'MScript', FScriptProj.ProjectId,
      FScriptRevId, 'Ajuste de ação ou diálogo na cena ' + SceneId, 'MScript',
      'queued', '', EvtId, Ops) then
      MessageDlg('Correção ' + EvtId + ' registrada. Use Retomar sincronização no MMenu.',
        mtInformation, [mbOK], 0)
    else
      MessageDlg('Não foi possível registrar a correção.', mtError, [mbOK], 0);
  finally
    Ops.Free;
    Data.Free;
  end;
end;

procedure TMboardMainForm.OnBoardsGridSelection(Sender: TObject; aCol, aRow: Integer);
begin
  if (aRow >= 1) and (aRow <= Length(FBoards)) then
  begin
    FSelectedBoard := aRow - 1;
    RefreshSelectedBoard;
  end;
end;

end.
