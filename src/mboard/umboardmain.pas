unit umboardmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser, imagefilters,
  ummpprotocol, ummpappbase, ummpaibridge;

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
    if Obj.Find('scene_boards') is TJSONArray then
    begin
      BArr := TJSONArray(Obj.Find('scene_boards'));
      SetLength(FBoards, BArr.Count);
      for I := 0 to BArr.Count - 1 do
      begin
        BObj := TJSONObject(BArr.Items[I]);
        FBoards[I].BoardId := BObj.Get('board_id', '');
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

procedure TMboardMainForm.OnGenerateFromSourcesClick(Sender: TObject);
var
  ScriptPath, Content, BaseRevDir, QuadDir, OpenRel, CloseRel, Resp, Err: string;
  Data: TJSONData;
  Obj, SItem: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  ScriptPath := ExtractFileDir(FScriptProj.ProjectFilePath) + PathDelim + 'revisions' +
    PathDelim + FScriptRevId + PathDelim + 'scripts' + PathDelim + 'roteiro.json';
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
    SetLength(FBoards, Arr.Count);
    BaseRevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;
    QuadDir := BaseRevDir + PathDelim + 'images' + PathDelim + 'quadros';
    ForceDirectories(QuadDir);

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

      if FAi.IsConfigured and (I = 0) then
      begin
        if FAi.Ask('Gere uma orientacao curta de enquadramento de camera.',
          FBoards[I].Heading + ': ' + FBoards[I].DirectionNotes, Resp, Err) then
          FBoards[I].DirectionNotes := FBoards[I].DirectionNotes + LineEnding + '[IA] ' + Resp;
      end;

      FBoards[I].OpeningAssetId := GenerateMmpId('a_qopen');
      FBoards[I].ClosingAssetId := GenerateMmpId('a_qclose');
      OpenRel := 'images/quadros/' + FBoards[I].SceneId + '_open.bmp';
      CloseRel := 'images/quadros/' + FBoards[I].SceneId + '_close.bmp';
      FBoards[I].OpeningUri := OpenRel;
      FBoards[I].ClosingUri := CloseRel;

      if not FAi.GenerateImage('Storyboard inicial: ' + FBoards[I].Heading + ' - ' +
        FBoards[I].DirectionNotes,
        BaseRevDir + PathDelim + StringReplace(OpenRel, '/', PathDelim, [rfReplaceAll]), Err) then
        SavePlaceholderBitmap(BaseRevDir + PathDelim + StringReplace(OpenRel, '/', PathDelim, [rfReplaceAll]),
          FBoards[I].Heading + ' [INICIO]', FBoards[I].DirectionNotes,
          'Asset: ' + FBoards[I].OpeningAssetId, $00383044);
      SavePlaceholderBitmap(BaseRevDir + PathDelim + StringReplace(CloseRel, '/', PathDelim, [rfReplaceAll]),
        FBoards[I].Heading + ' [FIM]', FBoards[I].DialogueText,
        'Asset: ' + FBoards[I].ClosingAssetId, $002C3D34);

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
  CountStr, BaseRevDir, MidId, MidRel: string;
  N, I, SegDur, Rem: Integer;
begin
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then Exit;
  CountStr := '2';
  if not InputQuery('Subdividir Cena em Segmentos', 'Quantidade de segmentos:', CountStr) then Exit;
  N := StrToIntDef(CountStr, 2);
  if N < 1 then N := 1;
  if N > 60 then N := 60;

  BaseRevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;
  SegDur := FBoards[FSelectedBoard].DurationSec div N;
  Rem := FBoards[FSelectedBoard].DurationSec mod N;
  SetLength(FBoards[FSelectedBoard].Segments, N);

  for I := 0 to N - 1 do
  begin
    FBoards[FSelectedBoard].Segments[I].SegmentId := GenerateMmpId('sg');
    FBoards[FSelectedBoard].Segments[I].OrderIdx := I + 1;
    FBoards[FSelectedBoard].Segments[I].DurationSec := SegDur;
    if I = N - 1 then
      FBoards[FSelectedBoard].Segments[I].DurationSec := SegDur + Rem;

    if I = 0 then
    begin
      FBoards[FSelectedBoard].Segments[I].OpeningAssetId := FBoards[FSelectedBoard].OpeningAssetId;
      FBoards[FSelectedBoard].Segments[I].OpeningUri := FBoards[FSelectedBoard].OpeningUri;
    end
    else
    begin
      // Continuidade exata: o asset inicial do segmento i eh exatamente o final do segmento i-1
      FBoards[FSelectedBoard].Segments[I].OpeningAssetId := FBoards[FSelectedBoard].Segments[I - 1].ClosingAssetId;
      FBoards[FSelectedBoard].Segments[I].OpeningUri := FBoards[FSelectedBoard].Segments[I - 1].ClosingUri;
    end;

    if I = N - 1 then
    begin
      FBoards[FSelectedBoard].Segments[I].ClosingAssetId := FBoards[FSelectedBoard].ClosingAssetId;
      FBoards[FSelectedBoard].Segments[I].ClosingUri := FBoards[FSelectedBoard].ClosingUri;
    end
    else
    begin
      MidId := GenerateMmpId('a_qmid');
      MidRel := 'images/quadros/' + FBoards[FSelectedBoard].SceneId + '_mid_' + IntToStr(I + 1) + '.bmp';
      SavePlaceholderBitmap(BaseRevDir + PathDelim + StringReplace(MidRel, '/', PathDelim, [rfReplaceAll]),
        FBoards[FSelectedBoard].Heading + ' [TRANSICAO ' + IntToStr(I + 1) + ']',
        'Quadro de fronteira compartilhado', 'Asset: ' + MidId, $003A3A28);
      FBoards[FSelectedBoard].Segments[I].ClosingAssetId := MidId;
      FBoards[FSelectedBoard].Segments[I].ClosingUri := MidRel;
    end;
    FBoards[FSelectedBoard].Segments[I].NotesText := 'Segmento ' + IntToStr(I + 1) + '/' + IntToStr(N);
  end;

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
  P1, P2, RevDir: string;
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

  RevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;
  P1 := RevDir + PathDelim + StringReplace(FBoards[FSelectedBoard].OpeningUri, '/', PathDelim, [rfReplaceAll]);
  P2 := RevDir + PathDelim + StringReplace(FBoards[FSelectedBoard].ClosingUri, '/', PathDelim, [rfReplaceAll]);
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
  PrepRev, RevDir, OldRevDir, NewRev, ErrMsg: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, J, ArtCount: Integer;

  procedure CopyAndAddFrame(const Aid, SceneId, SegId, RelUri, StatusStr: string);
  var
    SrcF, DstF: string;
    FS1, FS2: TFileStream;
  begin
    if RelUri = '' then Exit;
    SrcF := OldRevDir + PathDelim + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
    DstF := RevDir + PathDelim + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
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
    ArtCount := Length(Arts);
    SetLength(Arts, ArtCount + 1);
    Arts[ArtCount].ArtifactId := Aid;
    Arts[ArtCount].Kind := 'storyboard.frame';
    Arts[ArtCount].SceneId := SceneId;
    Arts[ArtCount].SegmentId := SegId;
    Arts[ArtCount].RelUri := RelUri;
    Arts[ArtCount].MimeType := 'image/bmp';
    Arts[ArtCount].Status := StatusStr;
  end;
begin
  if not FProd.Loaded then Exit;
  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;
  OldRevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;

  AtomicWriteTextFile(RevDir + PathDelim + 'storyboard' + PathDelim + 'scenes.json',
    BoardsToJson, False);

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
begin
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then Exit;
  FBoards[FSelectedBoard].DurationSec := StrToIntDef(FDurEdit.Text, 30);
  FBoards[FSelectedBoard].DialogueText := FDialogueMemo.Text;
  FBoards[FSelectedBoard].DirectionNotes := FNotesMemo.Text;
  FBoards[FSelectedBoard].Status := 'edited';
  RefreshBoardsGrid;
  LogMsg('Ajuste em rascunho aplicado no storyboard (MScript/MVisual ainda inalterados).');
end;

procedure TMboardMainForm.OnApproveBoardClick(Sender: TObject);
begin
  if (FSelectedBoard < 0) or (FSelectedBoard > High(FBoards)) then Exit;
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
  EvtId, Desc: string;
begin
  if not FProd.Loaded then Exit;
  Desc := 'Ajuste editorial aprovado no MBoard';
  if not InputQuery('Sincronizacao em Cascata', 'Descreva a alteracao para MScript -> MVisual -> MBoard:', Desc) then
    Exit;

  if EmitSyncEvent(FProd.RootDir, 'MBoard', 'MScript', FScriptProj.ProjectId,
    FCurrentRevId, Desc, 'MScript', 'queued', '', EvtId) then
  begin
    SaveRevision('approved', EvtId);
    LogMsg('Evento de cascata emitido (' + EvtId + ') em shared/sync/ para MScript.');
    MessageDlg('Evento de sincronizacao ' + EvtId + ' registrado em shared/sync/.' + LineEnding +
      'Acompanhe o progresso pelo MMenu.', mtInformation, [mbOK], 0);
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
