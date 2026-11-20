unit umvisualmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Menus, fpjson, jsonparser, imagefilters,
  ummpsha256, ummpprotocol, ummpappbase, ummpaibridge, ummpdb;

type
  TVisualEntity = record
    EntityId: string;
    Kind: string; // character | location | object | costume
    Name: string;
    Aliases: string;
    Description: string;
    SceneIdsCsv: string;
    ApprovalStatus: string; // pending | approved | rejected
    FrontRelUri: string;
    BackRelUri: string;
    RightRelUri: string;
    LeftRelUri: string;
  end;

  TMvisualMainForm = class(TForm)
  private
    FAi: TMmpAiBridge;
    FProd: TMmpProduction;
    FProj: TMmpProjectRef;
    FScriptProj: TMmpProjectRef;
    FProjectDir: string;
    FCurrentRevId: string;
    FScriptSourceRevId: string;
    FEntities: array of TVisualEntity;
    FSelectedIdx: Integer;

    FHeaderProdLabel: TLabel;
    FHeaderSourceLabel: TLabel;
    FScriptRevCombo: TComboBox;
    FSearchEdit: TEdit;
    FKindFilterCombo: TComboBox;
    FEntitiesGrid: TStringGrid;
    FGridMenu: TPopupMenu;
    FDetailMemo: TMemo;
    FDescEditMemo: TMemo;
    FPreviewImg: TImage;
    FPreviewOutImg: TImage;
    FViewCombo: TComboBox;
    FLogMemo: TMemo;
    FStatusLabel: TLabel;
    FProgressOverlay: TPanel;
    FOverlayTitleLbl: TLabel;
    FOverlayItemLbl: TLabel;
    FOverlayPctLbl: TLabel;
    FOverlayBar: TProgressBar;
    FOverlayImg: TImage;
    FBtnStopGen: TButton;
    FStopRequested: Boolean;
    FTotalStepsGen: Integer;
    FDoneStepsGen: Integer;

    procedure BuildUI;
    procedure LogMsg(const Msg: string);
    procedure LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
    procedure LoadEntitiesFromRevision(const RevId: string);
    procedure RefreshGrid;
    procedure RefreshSelectedEntity;
    procedure AddEntityIfMissing(const Kind, EntityName, Desc, SceneId: string;
      const FixedId: string = '');
    function EntityFolderName(const Kind: string): string;
    function ResolveAssetFile(const RelUri: string): string;
    function DraftAssetFile(const RelUri: string): string;
    function FindScriptCharacterId(const ScriptObj: TJSONObject; const AName: string): string;
    function IsScriptRevisionApproved(const RevId: string): Boolean;
    function EntitiesToJson: string;
    procedure SaveCurrentEntitiesDraft;
    procedure SaveRevision(const NewState: string);
    procedure GenerateViewsForEntity(EntIdx: Integer; ForceAll, KeepFront: Boolean; OnlyViewIdx: Integer = -1);

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnIndexScriptClick(Sender: TObject);
    procedure OnGenerateViewsClick(Sender: TObject);
    procedure OnValidateStageClick(Sender: TObject);
    procedure OnSaveDescClick(Sender: TObject);
    procedure OnGridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnGenItemAllClick(Sender: TObject);
    procedure OnGenItemCurrentViewClick(Sender: TObject);
    procedure OnGenItemSidesFromFrontClick(Sender: TObject);
    procedure OnApplySharpenClick(Sender: TObject);
    procedure OnApproveEntityClick(Sender: TObject);
    procedure OnRejectEntityClick(Sender: TObject);
    procedure OnPublishClick(Sender: TObject);
    procedure OnGridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnGridPrepareCanvas(sender: TObject; aCol, aRow: Integer; aState: TGridDrawState);
    procedure ShowProgressOverlay(const ATitle: string; ATotalSteps: Integer);
    procedure UpdateProgressOverlay(const AItemText, APreviewPath: string);
    procedure HideProgressOverlay;
    procedure OnStopGenClick(Sender: TObject);
    procedure OnFilterChanged(Sender: TObject);
    procedure OnViewComboChange(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mvisualMainForm: TMvisualMainForm;

implementation

constructor TMvisualMainForm.Create(TheOwner: TComponent);
var
  ProdRoot, ProjId, RevId, MMenuVer, ProdId: string;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MVisual - Biblioteca Visual e Continuidade (MaurinMovie)';
  Width := 1220;
  Height := 760;
  Position := poScreenCenter;
  Constraints.MinWidth := 940;
  Constraints.MinHeight := 620;

  FAi := TMmpAiBridge.Create('MVisual');
  FSelectedIdx := -1;
  BuildUI;

  ParseAppLaunchContext(ProdRoot, ProjId, RevId, MMenuVer, ProdId);
  LogMsg('MVisual v' + MMP_EXECUTABLE_VERSION + ' iniciado (openai_core + openai_image) | MMenu v' +
    MMenuVer + ' | Projeto: ' + ProjId);
  if ProdRoot <> '' then
    LoadProductionAndRevision(ProdRoot, ProjId, RevId);
end;

destructor TMvisualMainForm.Destroy;
begin
  FAi.Free;
  inherited Destroy;
end;

procedure TMvisualMainForm.BuildUI;
var
  Head, Sidebar, Bottom, FilterBar, RightPanel: TPanel;
  PC: TPageControl;
  TabWork, TabLog: TTabSheet;
  BtnOpen, BtnAiCfg, BtnPublish, BtnIndex, BtnGenViews, BtnValidateStage, BtnSharpen, BtnApprove, BtnReject, B: TButton;
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
  L.Caption := 'MaurinMovie  |  2 - MVisual';
  L.Font.Size := 16;
  L.Font.Style := [fsBold];
  L.Font.Color := clWhite;
  L.SetBounds(16, 10, 320, 26);

  FHeaderProdLabel := TLabel.Create(Self);
  FHeaderProdLabel.Parent := Head;
  FHeaderProdLabel.Caption := 'Nenhuma producao carregada';
  FHeaderProdLabel.Font.Color := clWhite;
  FHeaderProdLabel.Font.Style := [fsBold];
  FHeaderProdLabel.SetBounds(340, 12, 460, 20);

  FHeaderSourceLabel := TLabel.Create(Self);
  FHeaderSourceLabel.Parent := Head;
  FHeaderSourceLabel.Caption := 'Origem MScript: -';
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
  Sidebar.Width := 270;
  Sidebar.BevelOuter := bvNone;
  Sidebar.Color := $00EFEFEF;
  Sidebar.ParentBackground := False;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := Sidebar;
  BtnOpen.Caption := 'Abrir producao...';
  BtnOpen.SetBounds(12, 14, 246, 34);
  BtnOpen.OnClick := @OnOpenProdClick;

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'Revisao de origem (MScript):';
  L.Font.Style := [fsBold];
  L.SetBounds(12, 60, 246, 18);

  FScriptRevCombo := TComboBox.Create(Self);
  FScriptRevCombo.Parent := Sidebar;
  FScriptRevCombo.Style := csDropDownList;
  FScriptRevCombo.SetBounds(12, 82, 246, 26);

  BtnIndex := TButton.Create(Self);
  BtnIndex.Parent := Sidebar;
  BtnIndex.Caption := 'Etapa 1: Indexar Roteiro (sem imgs)';
  BtnIndex.SetBounds(12, 118, 246, 34);
  BtnIndex.OnClick := @OnIndexScriptClick;

  BtnGenViews := TButton.Create(Self);
  BtnGenViews.Parent := Sidebar;
  BtnGenViews.Caption := 'Etapa 2: Gerar Vistas Padronizadas';
  BtnGenViews.SetBounds(12, 160, 246, 34);
  BtnGenViews.OnClick := @OnGenerateViewsClick;

  BtnValidateStage := TButton.Create(Self);
  BtnValidateStage.Parent := Sidebar;
  BtnValidateStage.Caption := 'Validar Etapa (Liberar MBoard)';
  BtnValidateStage.Font.Style := [fsBold];
  BtnValidateStage.SetBounds(12, 202, 246, 34);
  BtnValidateStage.OnClick := @OnValidateStageClick;

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'Detalhes da entidade / ocorrencias:';
  L.Font.Style := [fsBold];
  L.SetBounds(12, 244, 246, 18);

  FDetailMemo := TMemo.Create(Self);
  FDetailMemo.Parent := Sidebar;
  FDetailMemo.ReadOnly := True;
  FDetailMemo.ScrollBars := ssVertical;
  FDetailMemo.SetBounds(12, 266, 246, 137);

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'Script / Descricao Visual (editavel):';
  L.Font.Style := [fsBold];
  L.SetBounds(12, 410, 246, 18);

  FDescEditMemo := TMemo.Create(Self);
  FDescEditMemo.Parent := Sidebar;
  FDescEditMemo.ScrollBars := ssVertical;
  FDescEditMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  FDescEditMemo.SetBounds(12, 430, 246, 174);

  B := TButton.Create(Self);
  B.Parent := Sidebar;
  B.Caption := 'Salvar Script da Entidade';
  B.Anchors := [akLeft, akRight, akBottom];
  B.SetBounds(12, 610, 246, 30);
  B.OnClick := @OnSaveDescClick;

  PC := TPageControl.Create(Self);
  PC.Parent := Self;
  PC.Align := alClient;

  TabWork := TTabSheet.Create(PC);
  TabWork.PageControl := PC;
  TabWork.Caption := 'Catalogo & Validacao Visual';

  TabLog := TTabSheet.Create(PC);
  TabLog.PageControl := PC;
  TabLog.Caption := 'Log Operacional';

  FilterBar := TPanel.Create(Self);
  FilterBar.Parent := TabWork;
  FilterBar.Align := alTop;
  FilterBar.Height := 46;
  FilterBar.BevelOuter := bvNone;

  L := TLabel.Create(Self); L.Parent := FilterBar; L.Caption := 'Categoria:'; L.SetBounds(12, 14, 70, 18);
  FKindFilterCombo := TComboBox.Create(Self);
  FKindFilterCombo.Parent := FilterBar;
  FKindFilterCombo.Style := csDropDownList;
  FKindFilterCombo.Items.Add('Todos');
  FKindFilterCombo.Items.Add('character');
  FKindFilterCombo.Items.Add('location');
  FKindFilterCombo.Items.Add('object');
  FKindFilterCombo.Items.Add('costume');
  FKindFilterCombo.ItemIndex := 0;
  FKindFilterCombo.SetBounds(86, 10, 120, 26);
  FKindFilterCombo.OnChange := @OnFilterChanged;

  L := TLabel.Create(Self); L.Parent := FilterBar; L.Caption := 'Consulta (nome/ID/cena):'; L.SetBounds(220, 14, 165, 18);
  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := FilterBar;
  FSearchEdit.SetBounds(388, 10, 220, 26);
  FSearchEdit.OnChange := @OnFilterChanged;

  RightPanel := TPanel.Create(Self);
  RightPanel.Parent := TabWork;
  RightPanel.Align := alBottom;
  RightPanel.Height := 270;
  RightPanel.BevelOuter := bvLowered;

  L := TLabel.Create(Self); L.Parent := RightPanel; L.Caption := 'Vista:'; L.SetBounds(14, 14, 46, 18);
  FViewCombo := TComboBox.Create(Self);
  FViewCombo.Parent := RightPanel;
  FViewCombo.Style := csDropDownList;
  FViewCombo.Items.Add('front');
  FViewCombo.Items.Add('back');
  FViewCombo.Items.Add('right');
  FViewCombo.Items.Add('left');
  FViewCombo.ItemIndex := 0;
  FViewCombo.SetBounds(62, 10, 110, 26);
  FViewCombo.OnChange := @OnViewComboChange;

  BtnSharpen := TButton.Create(Self);
  BtnSharpen.Parent := RightPanel;
  BtnSharpen.Caption := 'Filtro Nitidez (openai_image)';
  BtnSharpen.SetBounds(184, 9, 200, 28);
  BtnSharpen.OnClick := @OnApplySharpenClick;

  BtnApprove := TButton.Create(Self);
  BtnApprove.Parent := RightPanel;
  BtnApprove.Caption := 'Aprovar Item';
  BtnApprove.SetBounds(394, 9, 120, 28);
  BtnApprove.OnClick := @OnApproveEntityClick;

  BtnReject := TButton.Create(Self);
  BtnReject.Parent := RightPanel;
  BtnReject.Caption := 'Rejeitar Item';
  BtnReject.SetBounds(522, 9, 120, 28);
  BtnReject.OnClick := @OnRejectEntityClick;

  FPreviewImg := TImage.Create(Self);
  FPreviewImg.Parent := RightPanel;
  FPreviewImg.Stretch := True;
  FPreviewImg.Proportional := True;
  FPreviewImg.SetBounds(14, 46, 360, 210);

  FPreviewOutImg := TImage.Create(Self);
  FPreviewOutImg.Parent := RightPanel;
  FPreviewOutImg.Visible := False;

  FEntitiesGrid := TStringGrid.Create(Self);
  FEntitiesGrid.Parent := TabWork;
  FEntitiesGrid.Align := alClient;
  FEntitiesGrid.FixedCols := 0;
  FEntitiesGrid.FixedRows := 1;
  FEntitiesGrid.ColCount := 6;
  FEntitiesGrid.RowCount := 2;
  FEntitiesGrid.Options := FEntitiesGrid.Options + [goRowSelect, goColSizing];
  FEntitiesGrid.Cells[0, 0] := 'Entity ID';
  FEntitiesGrid.Cells[1, 0] := 'Tipo';
  FEntitiesGrid.Cells[2, 0] := 'Nome';
  FEntitiesGrid.Cells[3, 0] := 'Cenas';
  FEntitiesGrid.Cells[4, 0] := 'Status';
  FEntitiesGrid.Cells[5, 0] := 'Vista Frontal';
  FEntitiesGrid.ColWidths[0] := 130;
  FEntitiesGrid.ColWidths[1] := 85;
  FEntitiesGrid.ColWidths[2] := 175;
  FEntitiesGrid.ColWidths[3] := 160;
  FEntitiesGrid.ColWidths[4] := 95;
  FEntitiesGrid.ColWidths[5] := 240;
  FEntitiesGrid.OnSelection := @OnGridSelection;
  FEntitiesGrid.OnMouseDown := @OnGridMouseDown;
  FEntitiesGrid.OnPrepareCanvas := @OnGridPrepareCanvas;

  FGridMenu := TPopupMenu.Create(Self);
  with FGridMenu.Items do
  begin
    Add(TMenuItem.Create(FGridMenu)); Items[0].Caption := 'Gerar Item (4 Vistas)'; Items[0].OnClick := @OnGenItemAllClick;
    Add(TMenuItem.Create(FGridMenu)); Items[1].Caption := 'Gerar Apenas Vista Atual'; Items[1].OnClick := @OnGenItemCurrentViewClick;
    Add(TMenuItem.Create(FGridMenu)); Items[2].Caption := 'Gerar Costas/Dir/Esq da Frontal'; Items[2].OnClick := @OnGenItemSidesFromFrontClick;
  end;
  FEntitiesGrid.PopupMenu := FGridMenu;

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := TabLog;
  FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssBoth;

  // Painel suspenso de progresso e preview durante a geracao
  FProgressOverlay := TPanel.Create(Self);
  FProgressOverlay.Parent := Self;
  FProgressOverlay.SetBounds((Width - 460) div 2, (Height - 360) div 2, 460, 360);
  FProgressOverlay.Anchors := [];
  FProgressOverlay.BevelOuter := bvRaised;
  FProgressOverlay.BevelWidth := 2;
  FProgressOverlay.Color := $00382C22;
  FProgressOverlay.ParentBackground := False;
  FProgressOverlay.Visible := False;

  FOverlayTitleLbl := TLabel.Create(FProgressOverlay);
  FOverlayTitleLbl.Parent := FProgressOverlay;
  FOverlayTitleLbl.Font.Color := clWhite;
  FOverlayTitleLbl.Font.Size := 11;
  FOverlayTitleLbl.Font.Style := [fsBold];
  FOverlayTitleLbl.SetBounds(16, 12, 428, 22);
  FOverlayTitleLbl.Caption := 'Gerando imagens...';

  FOverlayItemLbl := TLabel.Create(FProgressOverlay);
  FOverlayItemLbl.Parent := FProgressOverlay;
  FOverlayItemLbl.Font.Color := $00D0E8FF;
  FOverlayItemLbl.SetBounds(16, 38, 428, 20);
  FOverlayItemLbl.Caption := '';

  FOverlayImg := TImage.Create(FProgressOverlay);
  FOverlayImg.Parent := FProgressOverlay;
  FOverlayImg.Stretch := True;
  FOverlayImg.Proportional := True;
  FOverlayImg.Center := True;
  FOverlayImg.SetBounds(16, 64, 428, 200);

  FOverlayBar := TProgressBar.Create(FProgressOverlay);
  FOverlayBar.Parent := FProgressOverlay;
  FOverlayBar.Min := 0;
  FOverlayBar.Max := 100;
  FOverlayBar.Position := 0;
  FOverlayBar.SetBounds(16, 274, 340, 22);

  FOverlayPctLbl := TLabel.Create(FProgressOverlay);
  FOverlayPctLbl.Parent := FProgressOverlay;
  FOverlayPctLbl.Font.Color := clWhite;
  FOverlayPctLbl.Font.Style := [fsBold];
  FOverlayPctLbl.Alignment := taRightJustify;
  FOverlayPctLbl.AutoSize := False;
  FOverlayPctLbl.SetBounds(364, 276, 80, 20);
  FOverlayPctLbl.Caption := '0%';

  FBtnStopGen := TButton.Create(FProgressOverlay);
  FBtnStopGen.Parent := FProgressOverlay;
  FBtnStopGen.Caption := 'Parar';
  FBtnStopGen.SetBounds(170, 310, 120, 34);
  FBtnStopGen.OnClick := @OnStopGenClick;
end;

procedure TMvisualMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
  if FProd.Loaded then
    MmpLogAppOperation(FProd.RootDir, FProd.ProductionId, 'MVisual', Msg, FCurrentRevId);
end;

procedure TMvisualMainForm.LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
var
  ErrMsg: string;
  I, Idx: Integer;
begin
  if not ResolveAppProject(ProdRoot, 2, ProjId, RevId, FProd, FProj,
    FProjectDir, FCurrentRevId, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  FAi.LoadForProduction(FProd.RootDir);
  FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
  FScriptRevCombo.Items.Clear;
  if FindProjectByApp(FProd, 1, FScriptProj) then
  begin
    for I := 0 to High(FScriptProj.Revisions) do
      FScriptRevCombo.Items.Add(FScriptProj.Revisions[I].RevisionId);
    Idx := FScriptRevCombo.Items.IndexOf(FScriptProj.ActiveRevision);
    { RF-MV-01: so revisoes aprovadas do MScript podem ser importadas;
      se a ativa nao estiver aprovada, sugere a aprovada mais recente. }
    if not IsScriptRevisionApproved(FScriptProj.ActiveRevision) then
      for I := High(FScriptProj.Revisions) downto 0 do
        if SameText(FScriptProj.Revisions[I].State, 'approved') then
        begin
          Idx := FScriptRevCombo.Items.IndexOf(FScriptProj.Revisions[I].RevisionId);
          Break;
        end;
    if Idx < 0 then Idx := 0;
    if FScriptRevCombo.Items.Count > 0 then
    begin
      FScriptRevCombo.ItemIndex := Idx;
      FScriptSourceRevId := FScriptRevCombo.Text;
    end;
  end;
  FHeaderSourceLabel.Caption := 'Origem MScript: ' + FScriptProj.ProjectId +
    ' @ ' + FScriptSourceRevId + '  |  MVisual: ' + FCurrentRevId;

  LoadEntitiesFromRevision(FCurrentRevId);
  RefreshGrid;
  LogMsg('Producao carregada em MVisual.');
end;

procedure TMvisualMainForm.LoadEntitiesFromRevision(const RevId: string);
var
  Path, Content: string;
  Data: TJSONData;
  Obj, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  DbStatus: string;
begin
  SetLength(FEntities, 0);
  Path := MmpDraftFilePath(FProjectDir, 'indexes/entities.json');
  if FileExists(Path) then
    LogMsg('Rascunho nao publicado restaurado (work/draft).')
  else
    Path := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
      RevId + PathDelim + 'indexes' + PathDelim + 'entities.json';
  if not FileExists(Path) then Exit;
  if not ReadTextFileUtf8(Path, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  try
    if Obj.Find('entities') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('entities'));
      SetLength(FEntities, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[I] is TJSONObject) then Continue;
        Item := TJSONObject(Arr.Items[I]);
        FEntities[I].EntityId := Item.Get('entity_id', '');
        FEntities[I].Kind := Item.Get('kind', 'character');
        FEntities[I].Name := Item.Get('name', '');
        FEntities[I].Aliases := Item.Get('aliases', '');
        FEntities[I].Description := Item.Get('description', '');
        FEntities[I].SceneIdsCsv := Item.Get('scenes_csv', '');
        FEntities[I].ApprovalStatus := Item.Get('approval_status', 'pending');
        if MmpDbGetVisualEntityApproval(FProd.RootDir, FProj.ProjectId,
          RevId, FEntities[I].EntityId, DbStatus) then
          FEntities[I].ApprovalStatus := DbStatus;
        FEntities[I].FrontRelUri := Item.Get('front_uri', '');
        FEntities[I].BackRelUri := Item.Get('back_uri', '');
        FEntities[I].RightRelUri := Item.Get('right_uri', '');
        FEntities[I].LeftRelUri := Item.Get('left_uri', '');
      end;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TMvisualMainForm.AddEntityIfMissing(const Kind, EntityName, Desc, SceneId: string;
  const FixedId: string);
var
  TrimName: string;
  I, N: Integer;
begin
  TrimName := Trim(EntityName);
  if TrimName = '' then Exit;
  for I := 0 to High(FEntities) do
  begin
    if SameText(FEntities[I].Kind, Kind) and SameText(FEntities[I].Name, TrimName) then
    begin
      if (SceneId <> '') and (Pos(SceneId, FEntities[I].SceneIdsCsv) = 0) then
      begin
        if FEntities[I].SceneIdsCsv = '' then
          FEntities[I].SceneIdsCsv := SceneId
        else
          FEntities[I].SceneIdsCsv := FEntities[I].SceneIdsCsv + ', ' + SceneId;
      end;
      Exit;
    end;
  end;

  N := Length(FEntities);
  SetLength(FEntities, N + 1);
  if FixedId <> '' then
    FEntities[N].EntityId := FixedId
  else
    FEntities[N].EntityId := GenerateMmpId('ent');
  FEntities[N].Kind := Kind;
  FEntities[N].Name := TrimName;
  FEntities[N].Description := Desc;
  FEntities[N].SceneIdsCsv := SceneId;
  FEntities[N].ApprovalStatus := 'pending';
end;

procedure TMvisualMainForm.OnIndexScriptClick(Sender: TObject);
var
  ScriptDir, ScriptJsonPath, Content, SceneId, Loc, Chars, Objs, Costumes: string;
  Data: TJSONData;
  Obj, Item: TJSONObject;
  Arr: TJSONArray;
  Parts: TStringList;
  I, J: Integer;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;

  FScriptSourceRevId := FScriptRevCombo.Text;
  if FScriptSourceRevId = '' then FScriptSourceRevId := FScriptProj.ActiveRevision;
  ScriptDir := ExtractFileDir(FScriptProj.ProjectFilePath);
  ScriptJsonPath := IncludeTrailingPathDelimiter(ScriptDir) + 'revisions' +
    PathDelim + FScriptSourceRevId + PathDelim + 'scripts' + PathDelim + 'roteiro.json';

  if not FileExists(ScriptJsonPath) then
  begin
    MessageDlg('Arquivo scripts/roteiro.json nao encontrado na revisao ' + FScriptSourceRevId +
      ' do MScript. Salve/valide o roteiro no MScript primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not IsScriptRevisionApproved(FScriptSourceRevId) then
  begin
    MessageDlg('A revisao ' + FScriptSourceRevId + ' do MScript ainda nao foi validada.' + LineEnding +
      'O MVisual so importa revisoes aprovadas do roteiro (valide no MScript primeiro).',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if not ReadTextFileUtf8(ScriptJsonPath, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ',';
    Parts.StrictDelimiter := True;
    if Obj.Find('scenes') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('scenes'));
      for I := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[I] is TJSONObject) then Continue;
        Item := TJSONObject(Arr.Items[I]);
        SceneId := Item.Get('scene_id', '');
        Loc := Item.Get('location_ref', '');
        Chars := Item.Get('characters_csv', '');
        Objs := Item.Get('objects_csv', '');
        Costumes := Item.Get('costumes_csv', '');

        AddEntityIfMissing('location', Loc, 'Cenario extraido do roteiro (' + Item.Get('time_of_day', '') + ')', SceneId);

        Parts.DelimitedText := Chars;
        for J := 0 to Parts.Count - 1 do
          AddEntityIfMissing('character', Parts[J], 'Personagem em ' + Item.Get('heading', ''),
            SceneId, FindScriptCharacterId(Obj, Parts[J]));

        Parts.Delimiter := ',';
        Parts.DelimitedText := Objs;
        for J := 0 to Parts.Count - 1 do
          AddEntityIfMissing('object', Parts[J], 'Objeto de cena', SceneId);

        if Trim(Costumes) <> '' then
        begin
          { O MScript grava figurinos separados por virgula; ';' tambem e aceito. }
          if Pos(';', Costumes) > 0 then
            Parts.Delimiter := ';'
          else
            Parts.Delimiter := ',';
          Parts.DelimitedText := Costumes;
          for J := 0 to Parts.Count - 1 do
            AddEntityIfMissing('costume', Parts[J], 'Figurino vinculado ao roteiro', SceneId);
          Parts.Delimiter := ',';
        end;
      end;
    end;
  finally
    Parts.Free;
    Obj.Free;
  end;

  SaveCurrentEntitiesDraft;
  RefreshGrid;
  LogMsg('Etapa 1 concluida e salva: ' + IntToStr(Length(FEntities)) +
    ' entidades indexadas a partir de MScript @ ' + FScriptSourceRevId);
end;

{ Arquivos do rascunho ficam em projects/02-mvisual/work/draft; a revisao
  publicada (revisions/rNNNN) nunca e reescrita (docs/11, docs/specs/00-comum 5.1). }
function TMvisualMainForm.ResolveAssetFile(const RelUri: string): string;
begin
  Result := MmpResolveDraftOrRevisionFile(FProjectDir, FCurrentRevId, RelUri);
end;

function TMvisualMainForm.DraftAssetFile(const RelUri: string): string;
begin
  Result := MmpDraftFilePath(FProjectDir, RelUri);
  ForceDirectories(ExtractFileDir(Result));
end;

{ RF-MV-04: personagens reutilizam o character_id do MScript. }
function TMvisualMainForm.FindScriptCharacterId(const ScriptObj: TJSONObject;
  const AName: string): string;
var
  Arr: TJSONArray;
  I: Integer;
begin
  Result := '';
  if (ScriptObj = nil) or not (ScriptObj.Find('characters') is TJSONArray) then Exit;
  Arr := TJSONArray(ScriptObj.Find('characters'));
  for I := 0 to Arr.Count - 1 do
    if (Arr.Items[I] is TJSONObject) and
       SameText(Trim(TJSONObject(Arr.Items[I]).Get('name', '')), Trim(AName)) then
      Exit(TJSONObject(Arr.Items[I]).Get('character_id', ''));
end;

function TMvisualMainForm.IsScriptRevisionApproved(const RevId: string): Boolean;
var
  RevInfo: TMmpRevisionInfo;
begin
  Result := FindRevisionInProject(FScriptProj, RevId, RevInfo) and
    SameText(RevInfo.State, 'approved');
end;

function TMvisualMainForm.EntityFolderName(const Kind: string): string;
begin
  if SameText(Kind, 'character') or SameText(Kind, 'costume') then
    Result := 'personagens'
  else if SameText(Kind, 'location') then
    Result := 'cenarios'
  else
    Result := 'objetos';
end;

procedure TMvisualMainForm.ShowProgressOverlay(const ATitle: string; ATotalSteps: Integer);
begin
  FStopRequested := False;
  FTotalStepsGen := ATotalSteps;
  if FTotalStepsGen < 1 then FTotalStepsGen := 1;
  FDoneStepsGen := 0;
  FOverlayTitleLbl.Caption := ATitle;
  FOverlayItemLbl.Caption := 'Preparando...';
  FOverlayBar.Position := 0;
  FOverlayPctLbl.Caption := '0%';
  FOverlayImg.Picture := nil;
  FProgressOverlay.SetBounds((ClientWidth - FProgressOverlay.Width) div 2,
    (ClientHeight - FProgressOverlay.Height) div 2,
    FProgressOverlay.Width, FProgressOverlay.Height);
  FProgressOverlay.Visible := True;
  FProgressOverlay.BringToFront;
  Application.ProcessMessages;
end;

procedure TMvisualMainForm.UpdateProgressOverlay(const AItemText, APreviewPath: string);
var
  Pct: Integer;
begin
  if FOverlayItemLbl <> nil then
    FOverlayItemLbl.Caption := AItemText;
  Pct := Round((FDoneStepsGen / FTotalStepsGen) * 100);
  if Pct > 100 then Pct := 100;
  if FOverlayBar <> nil then
    FOverlayBar.Position := Pct;
  if FOverlayPctLbl <> nil then
    FOverlayPctLbl.Caption := IntToStr(Pct) + '%';
  if (FOverlayImg <> nil) and (APreviewPath <> '') and FileExists(APreviewPath) then
  begin
    try
      FOverlayImg.Picture.LoadFromFile(APreviewPath);
    except
    end;
  end;
  Application.ProcessMessages;
end;

procedure TMvisualMainForm.HideProgressOverlay;
begin
  if FProgressOverlay <> nil then
    FProgressOverlay.Visible := False;
  Application.ProcessMessages;
end;

procedure TMvisualMainForm.OnStopGenClick(Sender: TObject);
begin
  FStopRequested := True;
  if FOverlayItemLbl <> nil then
    FOverlayItemLbl.Caption := 'Parando apos concluir a imagem atual...';
  try
    FAi.ImageAI.Cancel;
  except
  end;
  if Sender <> nil then;
end;

procedure TMvisualMainForm.OnGridPrepareCanvas(sender: TObject; aCol, aRow: Integer;
  aState: TGridDrawState);
var
  EntId: string;
  I: Integer;
  HasPng: Boolean;
begin
  if (aRow <= 0) or (aRow >= FEntitiesGrid.RowCount) then Exit;
  if gdSelected in aState then Exit;
  EntId := Trim(FEntitiesGrid.Cells[0, aRow]);
  if EntId = '' then Exit;
  HasPng := False;
  for I := 0 to High(FEntities) do
  begin
    if SameText(FEntities[I].EntityId, EntId) then
    begin
      HasPng := SameText(ExtractFileExt(FEntities[I].FrontRelUri), '.png') or
                SameText(ExtractFileExt(FEntities[I].BackRelUri), '.png') or
                SameText(ExtractFileExt(FEntities[I].RightRelUri), '.png') or
                SameText(ExtractFileExt(FEntities[I].LeftRelUri), '.png');
      Break;
    end;
  end;
  if HasPng then
    FEntitiesGrid.Canvas.Brush.Color := $00C8F5CA;
  if aCol >= 0 then;
end;

procedure TMvisualMainForm.GenerateViewsForEntity(EntIdx: Integer; ForceAll, KeepFront: Boolean; OnlyViewIdx: Integer);
var
  BaseRevDir, Folder, Prefix, SubDir, RelBase, FrontRefPath, Err: string;

  procedure EnsureView(var RelUri: string; const Suffix, ViewLabel, ViewPrompt, RefImg: string; BgColor: TColor; ForceThis: Boolean);
  var
    NeedGen: Boolean;
    FullPrompt, OutPng: string;
  begin
    if FStopRequested then Exit;
    NeedGen := ForceThis or (RelUri = '') or (FAi.IsConfigured and SameText(ExtractFileExt(RelUri), '.bmp'));
    if not NeedGen then
    begin
      Inc(FDoneStepsGen);
      UpdateProgressOverlay(Format('%s - %s (ja gerado)', [FEntities[EntIdx].Name, ViewLabel]), RefImg);
      Exit;
    end;

    UpdateProgressOverlay(Format('Gerando: %s - %s', [FEntities[EntIdx].Name, ViewLabel]), RefImg);
    if FStopRequested then Exit;

    if FAi.IsConfigured then
    begin
      FStatusLabel.Caption := Format('Gerando vista %s (%d/%d): %s...', [ViewLabel, EntIdx + 1, Length(FEntities), FEntities[EntIdx].Name]);
      Application.ProcessMessages;
      if RefImg <> '' then
        FullPrompt := 'Use EXACTLY the same ' + FEntities[EntIdx].Kind + ' appearance, colors, outfit, and proportions from the reference image. ' +
          FEntities[EntIdx].Kind + ' "' + FEntities[EntIdx].Name + '": ' + FEntities[EntIdx].Description +
          '. Show ONLY the ' + ViewPrompt + ', clean neutral background.'
      else
        FullPrompt := FEntities[EntIdx].Kind + ' "' + FEntities[EntIdx].Name + '": ' +
          FEntities[EntIdx].Description + ' (' + ViewPrompt + ', cinema, clean neutral background)';

      OutPng := Prefix + '_' + Suffix + '.png';
      if FAi.GenerateImage(FullPrompt, OutPng, Err, '', 0, 0, RefImg) then
      begin
        RelUri := RelBase + '_' + Suffix + '.png';
        Inc(FDoneStepsGen);
        SaveCurrentEntitiesDraft;
        RefreshGrid;
        UpdateProgressOverlay(Format('Concluido: %s - %s', [FEntities[EntIdx].Name, ViewLabel]), OutPng);
        Exit;
      end
      else
        LogMsg('Falha IA [' + FEntities[EntIdx].Name + ' / ' + ViewLabel + ']: ' + Err);
    end;

    SavePlaceholderBitmap(Prefix + '_' + Suffix + '.bmp',
      FEntities[EntIdx].Name + ' [' + UpperCase(ViewLabel) + ']', FEntities[EntIdx].Description,
      'ID: ' + FEntities[EntIdx].EntityId + ' | Tipo: ' + FEntities[EntIdx].Kind, BgColor);
    RelUri := RelBase + '_' + Suffix + '.bmp';
    Inc(FDoneStepsGen);
    SaveCurrentEntitiesDraft;
    UpdateProgressOverlay(Format('Concluido: %s - %s', [FEntities[EntIdx].Name, ViewLabel]), Prefix + '_' + Suffix + '.bmp');
  end;

begin
  if FStopRequested or (EntIdx < 0) or (EntIdx > High(FEntities)) then Exit;
  FAi.ReloadIfChanged;
  BaseRevDir := MmpDraftDir(FProjectDir);
  Folder := EntityFolderName(FEntities[EntIdx].Kind);
  SubDir := BaseRevDir + PathDelim + 'images' + PathDelim + Folder;
  ForceDirectories(SubDir);
  RelBase := 'images/' + Folder + '/' + FEntities[EntIdx].EntityId;
  Prefix := SubDir + PathDelim + FEntities[EntIdx].EntityId;

  if (OnlyViewIdx < 0) or (OnlyViewIdx = 0) then
  begin
    if not KeepFront then
      EnsureView(FEntities[EntIdx].FrontRelUri, 'front', 'Frontal',
        'FRONT VIEW (vista frontal, facing camera directly)', '', $00403830, ForceAll);
  end;
  if FStopRequested then Exit;

  FrontRefPath := '';
  if (FEntities[EntIdx].FrontRelUri <> '') and SameText(ExtractFileExt(FEntities[EntIdx].FrontRelUri), '.png') then
    FrontRefPath := ResolveAssetFile(FEntities[EntIdx].FrontRelUri);

  if (OnlyViewIdx < 0) or (OnlyViewIdx = 1) then
    EnsureView(FEntities[EntIdx].BackRelUri, 'back', 'Costas',
      'BACK VIEW (vista traseira / de costas, 180 degrees turned away from camera)', FrontRefPath, $00384030, ForceAll or (OnlyViewIdx = 1));
  if FStopRequested then Exit;

  if (OnlyViewIdx < 0) or (OnlyViewIdx = 2) then
    EnsureView(FEntities[EntIdx].RightRelUri, 'right', 'Direita',
      'RIGHT SIDE PROFILE VIEW (perfil lateral direito, facing right, 90 degrees)', FrontRefPath, $00303848, ForceAll or (OnlyViewIdx = 2));
  if FStopRequested then Exit;

  if (OnlyViewIdx < 0) or (OnlyViewIdx = 3) then
    EnsureView(FEntities[EntIdx].LeftRelUri, 'left', 'Esquerda',
      'LEFT SIDE PROFILE VIEW (perfil lateral esquerdo, facing left, 90 degrees)', FrontRefPath, $00483038, ForceAll or (OnlyViewIdx = 3));
end;

procedure TMvisualMainForm.OnGenerateViewsClick(Sender: TObject);
var
  I: Integer;
begin
  if Length(FEntities) = 0 then
  begin
    MessageDlg('Execute a Etapa 1 (Indexar Roteiro) primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if (FSelectedIdx >= 0) and (FSelectedIdx <= High(FEntities)) and (FDescEditMemo <> nil) then
    FEntities[FSelectedIdx].Description := Trim(FDescEditMemo.Text);

  ShowProgressOverlay('Etapa 2: Gerando Vistas Padronizadas', Length(FEntities) * 4);
  try
    for I := 0 to High(FEntities) do
    begin
      if FStopRequested then Break;
      GenerateViewsForEntity(I, False, False);
    end;
  finally
    HideProgressOverlay;
  end;

  SaveCurrentEntitiesDraft;
  RefreshGrid;
  RefreshSelectedEntity;
  if FStopRequested then
  begin
    FStatusLabel.Caption := 'Geracao interrompida. Itens concluidos foram salvos.';
    LogMsg('Geracao interrompida pelo usuario. Os itens concluidos foram salvos e serao pulados ao retomar.');
  end
  else
  begin
    FStatusLabel.Caption := 'Etapa 2 concluida.';
    LogMsg('Etapa 2 concluida: vistas frontal/costas/direita/esquerda geradas e salvas (aguardando aprovacao).');
  end;
end;

procedure TMvisualMainForm.OnSaveDescClick(Sender: TObject);
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  FEntities[FSelectedIdx].Description := Trim(FDescEditMemo.Text);
  SaveCurrentEntitiesDraft;
  RefreshSelectedEntity;
  LogMsg('Script/descricao da entidade "' + FEntities[FSelectedIdx].Name + '" salvo.');
end;

procedure TMvisualMainForm.OnGridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Col, Row: Longint;
begin
  if Button = mbRight then
  begin
    FEntitiesGrid.MouseToCell(X, Y, Col, Row);
    if (Row >= 1) and (Row < FEntitiesGrid.RowCount) then
    begin
      FEntitiesGrid.Row := Row;
      OnGridSelection(FEntitiesGrid, Col, Row);
    end;
  end;
  if Shift = [] then;
end;

procedure TMvisualMainForm.OnGenItemAllClick(Sender: TObject);
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  if FDescEditMemo <> nil then
    FEntities[FSelectedIdx].Description := Trim(FDescEditMemo.Text);
  ShowProgressOverlay('Gerando Item: ' + FEntities[FSelectedIdx].Name, 4);
  try
    GenerateViewsForEntity(FSelectedIdx, True, False, -1);
  finally
    HideProgressOverlay;
  end;
  SaveCurrentEntitiesDraft;
  FStatusLabel.Caption := 'Item "' + FEntities[FSelectedIdx].Name + '" gerado (4 vistas).';
  RefreshGrid;
  RefreshSelectedEntity;
  LogMsg('Item "' + FEntities[FSelectedIdx].Name + '" regerado (4 vistas).');
end;

procedure TMvisualMainForm.OnGenItemCurrentViewClick(Sender: TObject);
var
  VIdx: Integer;
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  if FDescEditMemo <> nil then
    FEntities[FSelectedIdx].Description := Trim(FDescEditMemo.Text);
  VIdx := FViewCombo.ItemIndex;
  if VIdx < 0 then VIdx := 0;
  ShowProgressOverlay('Gerando Vista: ' + FEntities[FSelectedIdx].Name, 1);
  try
    GenerateViewsForEntity(FSelectedIdx, VIdx = 0, VIdx <> 0, VIdx);
  finally
    HideProgressOverlay;
  end;
  SaveCurrentEntitiesDraft;
  FStatusLabel.Caption := 'Vista atual de "' + FEntities[FSelectedIdx].Name + '" regerada.';
  RefreshGrid;
  RefreshSelectedEntity;
  LogMsg('Vista "' + FViewCombo.Text + '" de "' + FEntities[FSelectedIdx].Name + '" regerada.');
end;

procedure TMvisualMainForm.OnGenItemSidesFromFrontClick(Sender: TObject);
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  if FDescEditMemo <> nil then
    FEntities[FSelectedIdx].Description := Trim(FDescEditMemo.Text);
  ShowProgressOverlay('Gerando Vistas da Frontal: ' + FEntities[FSelectedIdx].Name, 3);
  try
    GenerateViewsForEntity(FSelectedIdx, True, True, -1);
  finally
    HideProgressOverlay;
  end;
  SaveCurrentEntitiesDraft;
  FStatusLabel.Caption := 'Vistas Costas/Dir/Esq geradas a partir da Frontal para "' + FEntities[FSelectedIdx].Name + '".';
  RefreshGrid;
  RefreshSelectedEntity;
  LogMsg('Vistas laterais/costas geradas a partir da imagem frontal para "' + FEntities[FSelectedIdx].Name + '".');
end;

procedure TMvisualMainForm.OnApplySharpenClick(Sender: TObject);
var
  Path: string;
  Filter: TSharpenFilter;
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  Path := ResolveAssetFile(FEntities[FSelectedIdx].FrontRelUri);
  if (Path = '') or not FileExists(Path) then
  begin
    MessageDlg('Gere as vistas primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;

  FPreviewImg.Picture.LoadFromFile(Path);
  { a imagem filtrada vira versao de rascunho; a da revisao publicada e preservada }
  Path := DraftAssetFile(FEntities[FSelectedIdx].FrontRelUri);
  Filter := TSharpenFilter.Create(Self);
  try
    Filter.InputImage := FPreviewImg;
    Filter.OutputImage := FPreviewOutImg;
    Filter.Apply;
    FPreviewImg.Picture.Assign(FPreviewOutImg.Picture);
    FPreviewImg.Picture.SaveToFile(Path);
    LogMsg('Filtro TSharpenFilter (openai_image) aplicado em ' + ExtractFileName(Path));
  finally
    Filter.Free;
  end;
end;

procedure TMvisualMainForm.RefreshGrid;
var
  I, Row, Count: Integer;
  KindFilter, SearchTxt: string;
  Matches: array of Integer;
begin
  KindFilter := FKindFilterCombo.Text;
  SearchTxt := LowerCase(Trim(FSearchEdit.Text));
  SetLength(Matches, 0);

  for I := 0 to High(FEntities) do
  begin
    if (KindFilter <> 'Todos') and not SameText(FEntities[I].Kind, KindFilter) then Continue;
    if SearchTxt <> '' then
    begin
      if (Pos(SearchTxt, LowerCase(FEntities[I].Name)) = 0) and
         (Pos(SearchTxt, LowerCase(FEntities[I].EntityId)) = 0) and
         (Pos(SearchTxt, LowerCase(FEntities[I].SceneIdsCsv)) = 0) then
        Continue;
    end;
    Count := Length(Matches);
    SetLength(Matches, Count + 1);
    Matches[Count] := I;
  end;

  if Length(Matches) = 0 then
  begin
    FEntitiesGrid.RowCount := 2;
    for I := 0 to FEntitiesGrid.ColCount - 1 do
      FEntitiesGrid.Cells[I, 1] := '';
    FSelectedIdx := -1;
    RefreshSelectedEntity;
    Exit;
  end;

  FEntitiesGrid.RowCount := Length(Matches) + 1;
  for I := 0 to High(Matches) do
  begin
    Row := I + 1;
    with FEntities[Matches[I]] do
    begin
      FEntitiesGrid.Cells[0, Row] := EntityId;
      FEntitiesGrid.Cells[1, Row] := Kind;
      FEntitiesGrid.Cells[2, Row] := Name;
      FEntitiesGrid.Cells[3, Row] := SceneIdsCsv;
      FEntitiesGrid.Cells[4, Row] := ApprovalStatus;
      FEntitiesGrid.Cells[5, Row] := FrontRelUri;
    end;
  end;

  if FSelectedIdx < 0 then FSelectedIdx := Matches[0];
  RefreshSelectedEntity;
end;

procedure TMvisualMainForm.RefreshSelectedEntity;
var
  RelUri, FullPath: string;
begin
  FDetailMemo.Lines.Clear;
  FPreviewImg.Picture := nil;
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then
  begin
    if FDescEditMemo <> nil then FDescEditMemo.Text := '';
    Exit;
  end;

  with FEntities[FSelectedIdx] do
  begin
    if FDescEditMemo <> nil then FDescEditMemo.Text := Description;
    FDetailMemo.Lines.Add('ID: ' + EntityId);
    FDetailMemo.Lines.Add('Tipo: ' + Kind + ' | Status: ' + ApprovalStatus);
    FDetailMemo.Lines.Add('Nome: ' + Name);
    FDetailMemo.Lines.Add('Cenas vinculadas: ' + SceneIdsCsv);
    FDetailMemo.Lines.Add('Descricao: ' + Description);

    case FViewCombo.ItemIndex of
      1: RelUri := BackRelUri;
      2: RelUri := RightRelUri;
      3: RelUri := LeftRelUri;
    else
      RelUri := FrontRelUri;
    end;

    if RelUri <> '' then
    begin
      FullPath := ResolveAssetFile(RelUri);
      if (FullPath <> '') and FileExists(FullPath) then
        FPreviewImg.Picture.LoadFromFile(FullPath);
    end;
  end;
end;

function TMvisualMainForm.EntitiesToJson: string;
var
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.mvisual.entities/1');
    Root.Add('source_script_project_id', FScriptProj.ProjectId);
    Root.Add('source_script_revision', FScriptSourceRevId);
    Arr := TJSONArray.Create;
    for I := 0 to High(FEntities) do
    begin
      Item := TJSONObject.Create;
      Item.Add('entity_id', FEntities[I].EntityId);
      Item.Add('kind', FEntities[I].Kind);
      Item.Add('name', FEntities[I].Name);
      Item.Add('aliases', FEntities[I].Aliases);
      Item.Add('description', FEntities[I].Description);
      Item.Add('scenes_csv', FEntities[I].SceneIdsCsv);
      Item.Add('approval_status', FEntities[I].ApprovalStatus);
      Item.Add('front_uri', FEntities[I].FrontRelUri);
      Item.Add('back_uri', FEntities[I].BackRelUri);
      Item.Add('right_uri', FEntities[I].RightRelUri);
      Item.Add('left_uri', FEntities[I].LeftRelUri);
      Arr.Add(Item);
    end;
    Root.Add('entities', Arr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

procedure TMvisualMainForm.SaveCurrentEntitiesDraft;
var
  DraftFile: string;
begin
  if (not FProd.Loaded) or (FProjectDir = '') or (FCurrentRevId = '') then Exit;
  DraftFile := DraftAssetFile('indexes/entities.json');
  if not AtomicWriteTextFile(DraftFile, EntitiesToJson, False) then
    raise Exception.Create('Falha ao salvar o rascunho ' + DraftFile);
end;

procedure TMvisualMainForm.SaveRevision(const NewState: string);
var
  PrepRev, RevDir, NewRev, ErrMsg, OldRevDir: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, ArtCount: Integer;

  procedure CopyAndAddView(const RelUri, Kind, StatusStr: string);
  var
    SrcFile, DstFile: string;
    FS1, FS2: TFileStream;
  begin
    if RelUri = '' then Exit;
    SrcFile := MmpResolveDraftOrRevisionFile(FProjectDir, FCurrentRevId, RelUri);
    DstFile := RevDir + PathDelim + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
    if FileExists(SrcFile) and not SameText(SrcFile, DstFile) then
    begin
      ForceDirectories(ExtractFileDir(DstFile));
      FS1 := TFileStream.Create(SrcFile, fmOpenRead or fmShareDenyNone);
      try
        FS2 := TFileStream.Create(DstFile, fmCreate);
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
    Arts[ArtCount].ArtifactId := GenerateMmpId('a');
    Arts[ArtCount].Kind := Kind;
    Arts[ArtCount].RelUri := RelUri;
    if SameText(ExtractFileExt(RelUri), '.png') then
      Arts[ArtCount].MimeType := 'image/png'
    else
      Arts[ArtCount].MimeType := 'image/bmp';
    Arts[ArtCount].Status := StatusStr;
  end;
begin
  if not FProd.Loaded then Exit;
  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;
  OldRevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;

  if not AtomicWriteTextFile(RevDir + PathDelim + 'indexes' + PathDelim + 'entities.json',
    EntitiesToJson, False) then
  begin
    MmpDiscardUnpublishedRevisionDir(RevDir);
    MessageDlg('Falha ao gravar indexes/entities.json.', mtError, [mbOK], 0);
    Exit;
  end;

  SetLength(Arts, 0);
  for I := 0 to High(FEntities) do
  begin
    CopyAndAddView(FEntities[I].FrontRelUri, 'visual.' + FEntities[I].Kind + '.reference', FEntities[I].ApprovalStatus);
    CopyAndAddView(FEntities[I].BackRelUri, 'visual.' + FEntities[I].Kind + '.reference', FEntities[I].ApprovalStatus);
    CopyAndAddView(FEntities[I].RightRelUri, 'visual.' + FEntities[I].Kind + '.reference', FEntities[I].ApprovalStatus);
    CopyAndAddView(FEntities[I].LeftRelUri, 'visual.' + FEntities[I].Kind + '.reference', FEntities[I].ApprovalStatus);
  end;

  SetLength(Srcs, 1);
  Srcs[0].ProjectId := FScriptProj.ProjectId;
  Srcs[0].ResolvedApp := 'MScript';
  Srcs[0].RevisionId := FScriptSourceRevId;
  if FindRevisionInProject(FScriptProj, FScriptSourceRevId, RevInfo) then
    Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;

  if PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MVisual',
    FCurrentRevId, NewState, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    MmpClearDraftDir(FProjectDir);
    LogMsg('Nova revisao visual publicada: ' + NewRev + ' [' + NewState + ']');
    LoadProductionAndRevision(FProd.RootDir, FProj.ProjectId, NewRev);
  end
  else
  begin
    MmpDiscardUnpublishedRevisionDir(RevDir);
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
  end;
end;

procedure TMvisualMainForm.OnOpenProdClick(Sender: TObject);
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

procedure TMvisualMainForm.OnAiConfigClick(Sender: TObject);
begin
  if FAi.ShowConfigDialog(Self) then
    LogMsg('IA configurada: ' + FAi.ProviderDisplayName);
end;

procedure TMvisualMainForm.OnApproveEntityClick(Sender: TObject);
var
  ErrMsg, VerifiedStatus, PreviousStatus: string;
  I: Integer;
  AllApproved: Boolean;
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  PreviousStatus := FEntities[FSelectedIdx].ApprovalStatus;
  try
    if not MmpDbSetVisualEntityApproval(FProd.RootDir, FProj.ProjectId,
      FCurrentRevId, FEntities[FSelectedIdx].EntityId, 'approved', ErrMsg) then
      raise Exception.Create(ErrMsg);
    if not MmpDbGetVisualEntityApproval(FProd.RootDir, FProj.ProjectId,
      FCurrentRevId, FEntities[FSelectedIdx].EntityId, VerifiedStatus) or
      (not SameText(VerifiedStatus, 'approved')) then
      raise Exception.Create('Leitura de confirmacao do SQLite nao retornou approved.');
    FEntities[FSelectedIdx].ApprovalStatus := 'approved';
    SaveCurrentEntitiesDraft;
    RefreshGrid;
    LogMsg('APROVACAO CONFIRMADA no SQLite ' + MmpProductionDbPath(FProd.RootDir) +
      ' | revisao ' + FCurrentRevId + ' | entidade ' + FEntities[FSelectedIdx].EntityId);

    AllApproved := Length(FEntities) > 0;
    for I := 0 to High(FEntities) do
      if not SameText(FEntities[I].ApprovalStatus, 'approved') then
      begin
        AllApproved := False;
        Break;
      end;
    if AllApproved then
    begin
      SaveRevision('approved');
      LogMsg('Todos os itens aprovados! Revisao visual publicada automaticamente (MBoard liberado).');
    end;
  except
    on E: Exception do
    begin
      FEntities[FSelectedIdx].ApprovalStatus := PreviousStatus;
      RefreshGrid;
      LogMsg('ERRO AO APROVAR ' + FEntities[FSelectedIdx].EntityId + ': ' + E.Message);
      MessageDlg('Erro ao salvar aprovacao: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMvisualMainForm.OnRejectEntityClick(Sender: TObject);
var
  ErrMsg, VerifiedStatus, PreviousStatus: string;
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  PreviousStatus := FEntities[FSelectedIdx].ApprovalStatus;
  try
    if not MmpDbSetVisualEntityApproval(FProd.RootDir, FProj.ProjectId,
      FCurrentRevId, FEntities[FSelectedIdx].EntityId, 'rejected', ErrMsg) then
      raise Exception.Create(ErrMsg);
    if not MmpDbGetVisualEntityApproval(FProd.RootDir, FProj.ProjectId,
      FCurrentRevId, FEntities[FSelectedIdx].EntityId, VerifiedStatus) or
      (not SameText(VerifiedStatus, 'rejected')) then
      raise Exception.Create('Leitura de confirmacao do SQLite nao retornou rejected.');
    FEntities[FSelectedIdx].ApprovalStatus := 'rejected';
    SaveCurrentEntitiesDraft;
    RefreshGrid;
    LogMsg('REJEICAO CONFIRMADA no SQLite ' + MmpProductionDbPath(FProd.RootDir) +
      ' | revisao ' + FCurrentRevId + ' | entidade ' + FEntities[FSelectedIdx].EntityId);
  except
    on E: Exception do
    begin
      FEntities[FSelectedIdx].ApprovalStatus := PreviousStatus;
      RefreshGrid;
      LogMsg('ERRO AO REJEITAR ' + FEntities[FSelectedIdx].EntityId + ': ' + E.Message);
      MessageDlg('Erro ao salvar rejeicao: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMvisualMainForm.OnPublishClick(Sender: TObject);
var
  I: Integer;
  AllApproved: Boolean;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  { docs/specs/00-comum 6.5: revisao "approved" exige todos os itens aprovados
    por pessoa; publicar sem isso gera revisao "published". }
  AllApproved := Length(FEntities) > 0;
  for I := 0 to High(FEntities) do
    if not SameText(FEntities[I].ApprovalStatus, 'approved') then
    begin
      AllApproved := False;
      Break;
    end;
  if AllApproved then
    SaveRevision('approved')
  else
    SaveRevision('published');
end;

procedure TMvisualMainForm.OnValidateStageClick(Sender: TObject);
var
  I, PendingCount, MissingImgCount: Integer;
  RevDir, FrontPath, ErrMsg, CheckStatus: string;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Length(FEntities) = 0 then
  begin
    MessageDlg('Nao ha entidades indexadas para validar. Execute a Etapa 1 primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;

  PendingCount := 0;
  MissingImgCount := 0;
  CheckStatus := '';
  RevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;
  for I := 0 to High(FEntities) do
  begin
    if not SameText(FEntities[I].ApprovalStatus, 'approved') then
      Inc(PendingCount);
    FrontPath := '';
    if FEntities[I].FrontRelUri <> '' then
      FrontPath := ResolveAssetFile(FEntities[I].FrontRelUri);
    if (FrontPath = '') or (not FileExists(FrontPath)) then
      Inc(MissingImgCount);
  end;

  if PendingCount > 0 then
  begin
    if MessageDlg('Existem ' + IntToStr(PendingCount) + ' entidade(s) ainda nao aprovadas.' + LineEnding +
      'Deseja aprovar todas e validar a etapa MVisual agora?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;

    for I := 0 to High(FEntities) do
    begin
      if not SameText(FEntities[I].ApprovalStatus, 'approved') then
      begin
        if not MmpDbSetVisualEntityApproval(FProd.RootDir, FProj.ProjectId, FCurrentRevId,
          FEntities[I].EntityId, 'approved', ErrMsg) then
        begin
          MessageDlg('Erro ao aprovar entidade ' + FEntities[I].EntityId + ' no SQLite: ' + ErrMsg, mtError, [mbOK], 0);
          Exit;
        end;
        if not MmpDbGetVisualEntityApproval(FProd.RootDir, FProj.ProjectId, FCurrentRevId,
          FEntities[I].EntityId, CheckStatus) or (not SameText(CheckStatus, 'approved')) then
        begin
          MessageDlg('Falha ao confirmar aprovacao no SQLite para ' + FEntities[I].EntityId, mtError, [mbOK], 0);
          Exit;
        end;
        FEntities[I].ApprovalStatus := 'approved';
      end;
    end;
    SaveCurrentEntitiesDraft;
    RefreshGrid;
  end;

  if MissingImgCount > 0 then
  begin
    if MessageDlg('Existem ' + IntToStr(MissingImgCount) + ' entidade(s) sem vista frontal gerada no disco.' + LineEnding +
      'Deseja validar a etapa e liberar o MBoard mesmo assim?', mtWarning, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;

  SaveRevision('approved');
  if MmpProjectHasActivity(FProj) then
  begin
    LogMsg('Etapa MVisual VALIDADA! Revisao ' + FCurrentRevId + ' publicada. 3 - MBoard desbloqueado no MMenu.');
    MessageDlg('Etapa MVisual validada com sucesso!' + LineEnding +
      'Revisao publicada: ' + FCurrentRevId + LineEnding +
      'O 3 - MBoard esta liberado no MMenu (clique em Atualizar no MMenu se ele ja estiver aberto).',
      mtInformation, [mbOK], 0);
  end
  else
  begin
    LogMsg('AVISO: Revisao salva (' + FCurrentRevId + '), mas MmpProjectHasActivity ainda retornou False.');
    MessageDlg('Revisao ' + FCurrentRevId + ' salva, mas o protocolo ainda nao acusou atividade no projeto.',
      mtWarning, [mbOK], 0);
  end;
end;

procedure TMvisualMainForm.OnGridSelection(Sender: TObject; aCol, aRow: Integer);
var
  IdStr: string;
  I: Integer;
begin
  if (aRow < 1) or (aRow >= FEntitiesGrid.RowCount) then Exit;
  IdStr := FEntitiesGrid.Cells[0, aRow];
  for I := 0 to High(FEntities) do
    if SameText(FEntities[I].EntityId, IdStr) then
    begin
      FSelectedIdx := I;
      RefreshSelectedEntity;
      Break;
    end;
end;

procedure TMvisualMainForm.OnFilterChanged(Sender: TObject);
begin
  RefreshGrid;
end;

procedure TMvisualMainForm.OnViewComboChange(Sender: TObject);
begin
  RefreshSelectedEntity;
end;

end.
