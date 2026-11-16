unit umvisualmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser, imagefilters,
  ummpsha256, ummpprotocol, ummpappbase, ummpaibridge;

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
    FDetailMemo: TMemo;
    FPreviewImg: TImage;
    FPreviewOutImg: TImage;
    FViewCombo: TComboBox;
    FLogMemo: TMemo;
    FStatusLabel: TLabel;

    procedure BuildUI;
    procedure LogMsg(const Msg: string);
    procedure LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
    procedure LoadEntitiesFromRevision(const RevId: string);
    procedure RefreshGrid;
    procedure RefreshSelectedEntity;
    procedure AddEntityIfMissing(const Kind, EntityName, Desc, SceneId: string);
    function EntityFolderName(const Kind: string): string;
    function EntitiesToJson: string;
    procedure SaveRevision(const NewState: string);

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnIndexScriptClick(Sender: TObject);
    procedure OnGenerateViewsClick(Sender: TObject);
    procedure OnApplySharpenClick(Sender: TObject);
    procedure OnApproveEntityClick(Sender: TObject);
    procedure OnRejectEntityClick(Sender: TObject);
    procedure OnPublishClick(Sender: TObject);
    procedure OnGridSelection(Sender: TObject; aCol, aRow: Integer);
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
  ProdRoot, ProjId, RevId: string;
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

  ParseAppLaunchParams(ProdRoot, ProjId, RevId);
  LogMsg('MVisual v' + MMP_EXECUTABLE_VERSION + ' iniciado (openai_core + openai_image).');
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
  BtnOpen, BtnAiCfg, BtnPublish, BtnIndex, BtnGenViews, BtnSharpen, BtnApprove, BtnReject: TButton;
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

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'Detalhes da entidade / ocorrencias:';
  L.Font.Style := [fsBold];
  L.SetBounds(12, 206, 246, 18);

  FDetailMemo := TMemo.Create(Self);
  FDetailMemo.Parent := Sidebar;
  FDetailMemo.ReadOnly := True;
  FDetailMemo.ScrollBars := ssVertical;
  FDetailMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  FDetailMemo.SetBounds(12, 228, 246, 418);

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

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := TabLog;
  FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssBoth;
end;

procedure TMvisualMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
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
begin
  SetLength(FEntities, 0);
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
        Item := TJSONObject(Arr.Items[I]);
        FEntities[I].EntityId := Item.Get('entity_id', '');
        FEntities[I].Kind := Item.Get('kind', 'character');
        FEntities[I].Name := Item.Get('name', '');
        FEntities[I].Aliases := Item.Get('aliases', '');
        FEntities[I].Description := Item.Get('description', '');
        FEntities[I].SceneIdsCsv := Item.Get('scenes_csv', '');
        FEntities[I].ApprovalStatus := Item.Get('approval_status', 'pending');
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

procedure TMvisualMainForm.AddEntityIfMissing(const Kind, EntityName, Desc, SceneId: string);
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
        Item := TJSONObject(Arr.Items[I]);
        SceneId := Item.Get('scene_id', '');
        Loc := Item.Get('location_ref', '');
        Chars := Item.Get('characters_csv', '');
        Objs := Item.Get('objects_csv', '');
        Costumes := Item.Get('costumes_csv', '');

        AddEntityIfMissing('location', Loc, 'Cenario extraido do roteiro (' + Item.Get('time_of_day', '') + ')', SceneId);

        Parts.DelimitedText := Chars;
        for J := 0 to Parts.Count - 1 do
          AddEntityIfMissing('character', Parts[J], 'Personagem em ' + Item.Get('heading', ''), SceneId);

        Parts.DelimitedText := Objs;
        for J := 0 to Parts.Count - 1 do
          AddEntityIfMissing('object', Parts[J], 'Objeto de cena', SceneId);

        Parts.DelimitedText := Costumes;
        for J := 0 to Parts.Count - 1 do
          AddEntityIfMissing('costume', Parts[J], 'Figurino vinculado ao roteiro', SceneId);
      end;
    end;
  finally
    Parts.Free;
    Obj.Free;
  end;

  RefreshGrid;
  LogMsg('Etapa 1 concluida (sem imagens): ' + IntToStr(Length(FEntities)) +
    ' entidades indexadas a partir de MScript @ ' + FScriptSourceRevId);
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

procedure TMvisualMainForm.OnGenerateViewsClick(Sender: TObject);
var
  BaseRevDir, Folder, Prefix, SubDir, RelBase, PromptTxt, Resp, Err: string;
  I: Integer;
begin
  if Length(FEntities) = 0 then
  begin
    MessageDlg('Execute a Etapa 1 (Indexar Roteiro) primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;

  BaseRevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;
  for I := 0 to High(FEntities) do
  begin
    Folder := EntityFolderName(FEntities[I].Kind);
    SubDir := BaseRevDir + PathDelim + 'images' + PathDelim + Folder;
    ForceDirectories(SubDir);
    RelBase := 'images/' + Folder + '/' + FEntities[I].EntityId;
    Prefix := SubDir + PathDelim + FEntities[I].EntityId;

    if FAi.IsConfigured and (I = 0) then
    begin
      PromptTxt := 'Descreva brevemente caracteristicas visuais para storyboard: ' +
        FEntities[I].Kind + ' "' + FEntities[I].Name + '" (' + FEntities[I].Description + ')';
      if FAi.Ask('Responda em ate 1 frase curta em portugues.', PromptTxt, Resp, Err) then
        FEntities[I].Description := Resp;
    end;

    if FEntities[I].FrontRelUri = '' then
    begin
      SavePlaceholderBitmap(Prefix + '_front.bmp',
        FEntities[I].Name + ' [FRONTAL]', FEntities[I].Description,
        'ID: ' + FEntities[I].EntityId + ' | Tipo: ' + FEntities[I].Kind, $00403830);
      FEntities[I].FrontRelUri := RelBase + '_front.bmp';
    end;
    if FEntities[I].BackRelUri = '' then
    begin
      SavePlaceholderBitmap(Prefix + '_back.bmp',
        FEntities[I].Name + ' [COSTAS]', FEntities[I].Description,
        'ID: ' + FEntities[I].EntityId, $00384030);
      FEntities[I].BackRelUri := RelBase + '_back.bmp';
    end;
    if FEntities[I].RightRelUri = '' then
    begin
      SavePlaceholderBitmap(Prefix + '_right.bmp',
        FEntities[I].Name + ' [DIREITA]', FEntities[I].Description,
        'ID: ' + FEntities[I].EntityId, $00303848);
      FEntities[I].RightRelUri := RelBase + '_right.bmp';
    end;
    if FEntities[I].LeftRelUri = '' then
    begin
      SavePlaceholderBitmap(Prefix + '_left.bmp',
        FEntities[I].Name + ' [ESQUERDA]', FEntities[I].Description,
        'ID: ' + FEntities[I].EntityId, $00483038);
      FEntities[I].LeftRelUri := RelBase + '_left.bmp';
    end;
  end;

  RefreshGrid;
  RefreshSelectedEntity;
  LogMsg('Etapa 2 concluida: vistas frontal/costas/direita/esquerda geradas (aguardando aprovacao).');
end;

procedure TMvisualMainForm.OnApplySharpenClick(Sender: TObject);
var
  Path: string;
  Filter: TSharpenFilter;
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  Path := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
    FCurrentRevId + PathDelim + StringReplace(FEntities[FSelectedIdx].FrontRelUri, '/', PathDelim, [rfReplaceAll]);
  if not FileExists(Path) then
  begin
    MessageDlg('Gere as vistas primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;

  FPreviewImg.Picture.LoadFromFile(Path);
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
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;

  with FEntities[FSelectedIdx] do
  begin
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
      FullPath := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
        FCurrentRevId + PathDelim + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
      if FileExists(FullPath) then
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
    SrcFile := OldRevDir + PathDelim + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
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
    Arts[ArtCount].MimeType := 'image/bmp';
    Arts[ArtCount].Status := StatusStr;
  end;
begin
  if not FProd.Loaded then Exit;
  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;
  OldRevDir := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId;

  AtomicWriteTextFile(RevDir + PathDelim + 'indexes' + PathDelim + 'entities.json',
    EntitiesToJson, False);

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
  Srcs[0].RevisionId := FScriptSourceRevId;
  if FindRevisionInProject(FScriptProj, FScriptSourceRevId, RevInfo) then
    Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;

  if PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MVisual',
    FCurrentRevId, NewState, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    LogMsg('Nova revisao visual publicada: ' + NewRev);
    LoadProductionAndRevision(FProd.RootDir, FProj.ProjectId, NewRev);
  end
  else
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
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
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  FEntities[FSelectedIdx].ApprovalStatus := 'approved';
  RefreshGrid;
end;

procedure TMvisualMainForm.OnRejectEntityClick(Sender: TObject);
begin
  if (FSelectedIdx < 0) or (FSelectedIdx > High(FEntities)) then Exit;
  FEntities[FSelectedIdx].ApprovalStatus := 'rejected';
  RefreshGrid;
end;

procedure TMvisualMainForm.OnPublishClick(Sender: TObject);
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  SaveRevision('approved');
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
