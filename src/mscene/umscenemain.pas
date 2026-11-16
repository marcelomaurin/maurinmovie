unit umscenemain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser, aih264decoder,
  ummpprotocol, ummpappbase, ummpaibridge;

type
  TSceneSegmentWork = record
    SegmentId: string;
    OrderIdx: Integer;
    DurationSec: Integer;
    PromptText: string;
    Status: string; // pending | generated | approved | rejected
    VideoRelUri: string;
  end;

  TMsceneMainForm = class(TForm)
  private
    FAi: TMmpAiBridge;
    FDecoder: TAIH264Decoder;
    FProd: TMmpProduction;
    FProj: TMmpProjectRef;
    FScriptProj, FVisualProj, FBoardProj, FSoundProj: TMmpProjectRef;
    FProjectDir: string;
    FCurrentSceneId: string;
    FCurrentSceneHeading: string;
    FSceneProjectDir: string;
    FSceneRevId: string;
    FSegments: array of TSceneSegmentWork;
    FPrevSceneLinkStatus: string;
    FNextSceneLinkStatus: string;
    FAssembledRelUri: string;

    FHeaderProdLabel: TLabel;
    FHeaderSourceLabel: TLabel;
    FSceneCombo: TComboBox;
    FPrevLinkLabel: TLabel;
    FNextLinkLabel: TLabel;
    FSegmentsGrid: TStringGrid;
    FPreviewImg: TImage;
    FLogMemo: TMemo;
    FStatusLabel: TLabel;

    procedure BuildUI;
    procedure LogMsg(const Msg: string);
    procedure LoadProduction(const ProdRoot, ProjId, RevId: string);
    procedure PopulateSceneList;
    procedure LoadSelectedSceneWork;
    procedure EnsureSceneProjectExists(const SceneId: string);
    procedure RefreshSegmentsGrid;
    procedure OnDecoderFrame(Sender: TObject; ABitmap: TBitmap);

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnSceneComboChange(Sender: TObject);
    procedure OnGenerateCurrentSceneClick(Sender: TObject);
    procedure OnApproveSegmentClick(Sender: TObject);
    procedure OnAssembleSceneClick(Sender: TObject);
    procedure OnApprovePrevLinkClick(Sender: TObject);
    procedure OnApproveNextLinkClick(Sender: TObject);
    procedure OnSaveSceneProjectClick(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  msceneMainForm: TMsceneMainForm;

implementation

constructor TMsceneMainForm.Create(TheOwner: TComponent);
var
  ProdRoot, ProjId, RevId: string;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MScene - Geracao e Montagem de Cena (MaurinMovie)';
  Width := 1200;
  Height := 760;
  Position := poScreenCenter;
  Constraints.MinWidth := 920;
  Constraints.MinHeight := 620;

  FAi := TMmpAiBridge.Create('MScene');
  FDecoder := TAIH264Decoder.Create(Self);
  FDecoder.OnFrame := @OnDecoderFrame;
  FPrevSceneLinkStatus := 'sem_cena_anterior';
  FNextSceneLinkStatus := 'ligacao_posterior_pendente';
  BuildUI;

  ParseAppLaunchParams(ProdRoot, ProjId, RevId);
  LogMsg('MScene v' + MMP_EXECUTABLE_VERSION + ' iniciado (openai_core + openai_video TAIH264Decoder).');
  if ProdRoot <> '' then
    LoadProduction(ProdRoot, ProjId, RevId);
end;

destructor TMsceneMainForm.Destroy;
begin
  FDecoder.Stop;
  FAi.Free;
  inherited Destroy;
end;

procedure TMsceneMainForm.BuildUI;
var
  Head, Sidebar, Bottom, PrevPanel: TPanel;
  PC: TPageControl;
  TabWork, TabLog: TTabSheet;
  BtnOpen, BtnAiCfg, BtnGen, BtnAppSeg, BtnAssemble, BtnPrevOk, BtnNextOk, BtnSave: TButton;
  L: TLabel;
begin
  Head := TPanel.Create(Self); Head.Parent := Self; Head.Align := alTop; Head.Height := 68;
  Head.BevelOuter := bvNone; Head.Color := $003A3028; Head.ParentBackground := False;

  L := TLabel.Create(Self); L.Parent := Head; L.Caption := 'MaurinMovie  |  5 - MScene';
  L.Font.Size := 16; L.Font.Style := [fsBold]; L.Font.Color := clWhite; L.SetBounds(16, 10, 320, 26);

  FHeaderProdLabel := TLabel.Create(Self); FHeaderProdLabel.Parent := Head;
  FHeaderProdLabel.Caption := 'Nenhuma producao carregada'; FHeaderProdLabel.Font.Color := clWhite;
  FHeaderProdLabel.Font.Style := [fsBold]; FHeaderProdLabel.SetBounds(340, 12, 460, 20);

  FHeaderSourceLabel := TLabel.Create(Self); FHeaderSourceLabel.Parent := Head;
  FHeaderSourceLabel.Caption := 'Uma cena por vez | Fontes 1..4: -'; FHeaderSourceLabel.Font.Color := $0099E6FF;
  FHeaderSourceLabel.SetBounds(340, 36, 540, 18);

  BtnAiCfg := TButton.Create(Self); BtnAiCfg.Parent := Head; BtnAiCfg.Caption := 'Configurar IA...';
  BtnAiCfg.Anchors := [akTop, akRight]; BtnAiCfg.SetBounds(1062, 17, 122, 34);
  BtnAiCfg.OnClick := @OnAiConfigClick;

  BtnSave := TButton.Create(Self); BtnSave.Parent := Head; BtnSave.Caption := 'Salvar Cena';
  BtnSave.Anchors := [akTop, akRight]; BtnSave.SetBounds(918, 17, 136, 34);
  BtnSave.OnClick := @OnSaveSceneProjectClick;

  Bottom := TPanel.Create(Self); Bottom.Parent := Self; Bottom.Align := alBottom; Bottom.Height := 34;
  Bottom.BevelOuter := bvLowered;
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Bottom; FStatusLabel.SetBounds(12, 9, 1100, 18);
  FStatusLabel.Caption := 'Pronto.';

  Sidebar := TPanel.Create(Self); Sidebar.Parent := Self; Sidebar.Align := alLeft; Sidebar.Width := 270;
  Sidebar.BevelOuter := bvNone; Sidebar.Color := $00EFEFEF; Sidebar.ParentBackground := False;

  BtnOpen := TButton.Create(Self); BtnOpen.Parent := Sidebar; BtnOpen.Caption := 'Abrir producao...';
  BtnOpen.SetBounds(12, 14, 246, 34); BtnOpen.OnClick := @OnOpenProdClick;

  L := TLabel.Create(Self); L.Parent := Sidebar; L.Caption := 'Cena ativa (uma por vez):';
  L.Font.Style := [fsBold]; L.SetBounds(12, 60, 246, 18);

  FSceneCombo := TComboBox.Create(Self); FSceneCombo.Parent := Sidebar;
  FSceneCombo.Style := csDropDownList; FSceneCombo.SetBounds(12, 82, 246, 26);
  FSceneCombo.OnChange := @OnSceneComboChange;

  BtnGen := TButton.Create(Self); BtnGen.Parent := Sidebar; BtnGen.Caption := 'Etapa 1: Gerar Sub-blocos da Cena';
  BtnGen.SetBounds(12, 118, 246, 34); BtnGen.OnClick := @OnGenerateCurrentSceneClick;

  BtnAppSeg := TButton.Create(Self); BtnAppSeg.Parent := Sidebar; BtnAppSeg.Caption := 'Etapa 2a: Aprovar Sub-bloco';
  BtnAppSeg.SetBounds(12, 160, 246, 34); BtnAppSeg.OnClick := @OnApproveSegmentClick;

  BtnAssemble := TButton.Create(Self); BtnAssemble.Parent := Sidebar; BtnAssemble.Caption := 'Etapa 2b: Costurar Cena Unica';
  BtnAssemble.SetBounds(12, 202, 246, 34); BtnAssemble.OnClick := @OnAssembleSceneClick;

  L := TLabel.Create(Self); L.Parent := Sidebar; L.Caption := 'Etapa 3: Ligacao entre cenas';
  L.Font.Style := [fsBold]; L.SetBounds(12, 252, 246, 18);

  FPrevLinkLabel := TLabel.Create(Self); FPrevLinkLabel.Parent := Sidebar;
  FPrevLinkLabel.Caption := 'Anterior: -'; FPrevLinkLabel.SetBounds(12, 276, 246, 18);

  BtnPrevOk := TButton.Create(Self); BtnPrevOk.Parent := Sidebar; BtnPrevOk.Caption := 'Aprovar Ligacao Anterior';
  BtnPrevOk.SetBounds(12, 298, 246, 30); BtnPrevOk.OnClick := @OnApprovePrevLinkClick;

  FNextLinkLabel := TLabel.Create(Self); FNextLinkLabel.Parent := Sidebar;
  FNextLinkLabel.Caption := 'Proxima: pendente'; FNextLinkLabel.SetBounds(12, 338, 246, 18);

  BtnNextOk := TButton.Create(Self); BtnNextOk.Parent := Sidebar; BtnNextOk.Caption := 'Validar Ligacao Proxima';
  BtnNextOk.SetBounds(12, 360, 246, 30); BtnNextOk.OnClick := @OnApproveNextLinkClick;

  PC := TPageControl.Create(Self); PC.Parent := Self; PC.Align := alClient;
  TabWork := TTabSheet.Create(PC); TabWork.PageControl := PC; TabWork.Caption := 'Sub-blocos & Montagem da Cena';
  TabLog := TTabSheet.Create(PC); TabLog.PageControl := PC; TabLog.Caption := 'Log Operacional';

  FSegmentsGrid := TStringGrid.Create(Self); FSegmentsGrid.Parent := TabWork; FSegmentsGrid.Align := alClient;
  FSegmentsGrid.FixedCols := 0; FSegmentsGrid.FixedRows := 1; FSegmentsGrid.ColCount := 6; FSegmentsGrid.RowCount := 2;
  FSegmentsGrid.Options := FSegmentsGrid.Options + [goRowSelect, goColSizing];
  FSegmentsGrid.Cells[0, 0] := 'Segment ID'; FSegmentsGrid.Cells[1, 0] := 'Ordem';
  FSegmentsGrid.Cells[2, 0] := 'Dur (s)'; FSegmentsGrid.Cells[3, 0] := 'Status';
  FSegmentsGrid.Cells[4, 0] := 'Prompt / Guia'; FSegmentsGrid.Cells[5, 0] := 'Video / Artefato';
  FSegmentsGrid.ColWidths[0] := 125; FSegmentsGrid.ColWidths[1] := 55; FSegmentsGrid.ColWidths[2] := 65;
  FSegmentsGrid.ColWidths[3] := 95; FSegmentsGrid.ColWidths[4] := 280; FSegmentsGrid.ColWidths[5] := 240;

  PrevPanel := TPanel.Create(Self); PrevPanel.Parent := TabWork; PrevPanel.Align := alBottom;
  PrevPanel.Height := 230; PrevPanel.BevelOuter := bvLowered;
  FPreviewImg := TImage.Create(Self); FPreviewImg.Parent := PrevPanel;
  FPreviewImg.Stretch := True; FPreviewImg.Proportional := True;
  FPreviewImg.SetBounds(12, 12, 380, 206);

  FLogMemo := TMemo.Create(Self); FLogMemo.Parent := TabLog; FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True; FLogMemo.ScrollBars := ssBoth;
end;

procedure TMsceneMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
end;

procedure TMsceneMainForm.OnDecoderFrame(Sender: TObject; ABitmap: TBitmap);
begin
  if (ABitmap <> nil) and (FPreviewImg <> nil) then
    FPreviewImg.Picture.Bitmap.Assign(ABitmap);
end;

procedure TMsceneMainForm.LoadProduction(const ProdRoot, ProjId, RevId: string);
var
  ErrMsg, CurRev: string;
begin
  if not ResolveAppProject(ProdRoot, 5, ProjId, RevId, FProd, FProj,
    FProjectDir, CurRev, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  FindProjectByApp(FProd, 1, FScriptProj);
  FindProjectByApp(FProd, 2, FVisualProj);
  FindProjectByApp(FProd, 3, FBoardProj);
  FindProjectByApp(FProd, 4, FSoundProj);

  FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
  FHeaderSourceLabel.Caption := Format('Fontes: 1:%s | 2:%s | 3:%s | 4:%s',
    [FScriptProj.ActiveRevision, FVisualProj.ActiveRevision,
     FBoardProj.ActiveRevision, FSoundProj.ActiveRevision]);

  PopulateSceneList;
  LogMsg('Producao carregada em MScene. Selecione uma cena para trabalhar.');
end;

procedure TMsceneMainForm.PopulateSceneList;
var
  ScriptPath, Content: string;
  Data: TJSONData;
  Obj, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  FSceneCombo.Items.Clear;
  ScriptPath := ExtractFileDir(FScriptProj.ProjectFilePath) + PathDelim + 'revisions' +
    PathDelim + FScriptProj.ActiveRevision + PathDelim + 'scripts' + PathDelim + 'roteiro.json';
  if not FileExists(ScriptPath) then Exit;
  if not ReadTextFileUtf8(ScriptPath, Content) then Exit;
  Data := GetJSON(Content);
  if not (Data is TJSONObject) then begin Data.Free; Exit; end;
  Obj := TJSONObject(Data);
  try
    if Obj.Find('scenes') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('scenes'));
      for I := 0 to Arr.Count - 1 do
      begin
        Item := TJSONObject(Arr.Items[I]);
        FSceneCombo.Items.Add(Item.Get('scene_id', '') + ' | ' + Item.Get('heading', ''));
      end;
    end;
  finally
    Obj.Free;
  end;
  if FSceneCombo.Items.Count > 0 then
  begin
    FSceneCombo.ItemIndex := 0;
    LoadSelectedSceneWork;
  end;
end;

procedure TMsceneMainForm.EnsureSceneProjectExists(const SceneId: string);
var
  ProjJsonPath, RevDir, NowIso: string;
  ProjObj, ManObj: TJSONObject;
  Arr: TJSONArray;
begin
  FSceneProjectDir := IncludeTrailingPathDelimiter(FProjectDir) + 'scenes' + PathDelim + SceneId;
  ProjJsonPath := FSceneProjectDir + PathDelim + 'project.json';
  if FileExists(ProjJsonPath) then Exit;

  NowIso := CurrentIsoUtc;
  RevDir := FSceneProjectDir + PathDelim + 'revisions' + PathDelim + 'r0001';
  ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'segments');
  ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'assembled');
  ForceDirectories(RevDir + PathDelim + 'audio' + PathDelim + 'guides');

  ProjObj := TJSONObject.Create;
  try
    ProjObj.Add('schema', MMP_PROJECT_SCHEMA);
    ProjObj.Add('production_id', FProd.ProductionId);
    ProjObj.Add('project_id', GenerateMmpId('pr_mscene_' + SceneId));
    ProjObj.Add('application', 'MScene');
    ProjObj.Add('scene_id', SceneId);
    ProjObj.Add('active_revision', 'r0001');
    ProjObj.Add('status', 'draft');
    ProjObj.Add('created_at', NowIso);
    ProjObj.Add('updated_at', NowIso);
    Arr := TJSONArray.Create; Arr.Add('r0001');
    ProjObj.Add('revision_history', Arr);
    AtomicWriteTextFile(ProjJsonPath, ProjObj.FormatJSON, False);
  finally
    ProjObj.Free;
  end;

  ManObj := TJSONObject.Create;
  try
    ManObj.Add('schema', MMP_MANIFEST_SCHEMA);
    ManObj.Add('production_id', FProd.ProductionId);
    ManObj.Add('project_id', '');
    ManObj.Add('application', 'MScene');
    ManObj.Add('revision_id', 'r0001');
    ManObj.Add('state', 'draft');
    ManObj.Add('created_at', NowIso);
    ManObj.Add('sources', TJSONArray.Create);
    ManObj.Add('artifacts', TJSONArray.Create);
    AtomicWriteTextFile(RevDir + PathDelim + 'manifest.json', ManObj.FormatJSON, False);
  finally
    ManObj.Free;
  end;
end;

procedure TMsceneMainForm.LoadSelectedSceneWork;
var
  S, BoardPath, Content, SceneProjPath: string;
  P: SizeInt;
  Data: TJSONData;
  Obj, BObj, SObj: TJSONObject;
  BArr, SArr: TJSONArray;
  I, J: Integer;
begin
  if FSceneCombo.ItemIndex < 0 then Exit;
  S := FSceneCombo.Text;
  P := Pos(' | ', S);
  if P > 0 then
  begin
    FCurrentSceneId := Copy(S, 1, P - 1);
    FCurrentSceneHeading := Copy(S, P + 3, Length(S));
  end
  else
  begin
    FCurrentSceneId := S;
    FCurrentSceneHeading := S;
  end;

  EnsureSceneProjectExists(FCurrentSceneId);
  FSceneRevId := 'r0001';
  SceneProjPath := FSceneProjectDir + PathDelim + 'project.json';
  if ReadTextFileUtf8(SceneProjPath, Content) then
  begin
    Data := GetJSON(Content);
    if Data is TJSONObject then
    begin
      FSceneRevId := TJSONObject(Data).Get('active_revision', 'r0001');
      Data.Free;
    end
    else Data.Free;
  end;

  SetLength(FSegments, 0);
  BoardPath := ExtractFileDir(FBoardProj.ProjectFilePath) + PathDelim + 'revisions' +
    PathDelim + FBoardProj.ActiveRevision + PathDelim + 'storyboard' + PathDelim + 'scenes.json';
  if FileExists(BoardPath) and ReadTextFileUtf8(BoardPath, Content) then
  begin
    Data := GetJSON(Content);
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      try
        if Obj.Find('scene_boards') is TJSONArray then
        begin
          BArr := TJSONArray(Obj.Find('scene_boards'));
          for I := 0 to BArr.Count - 1 do
          begin
            BObj := TJSONObject(BArr.Items[I]);
            if SameText(BObj.Get('scene_id', ''), FCurrentSceneId) then
            begin
              if BObj.Find('segments') is TJSONArray then
              begin
                SArr := TJSONArray(BObj.Find('segments'));
                SetLength(FSegments, SArr.Count);
                for J := 0 to SArr.Count - 1 do
                begin
                  SObj := TJSONObject(SArr.Items[J]);
                  FSegments[J].SegmentId := SObj.Get('segment_id', '');
                  FSegments[J].OrderIdx := SObj.Get('order', J + 1);
                  FSegments[J].DurationSec := SObj.Get('duration_seconds', 15);
                  FSegments[J].PromptText := FCurrentSceneHeading + ' | ' + SObj.Get('direction_notes', '');
                  FSegments[J].Status := 'pending';
                end;
              end;
              Break;
            end;
          end;
        end;
      finally
        Obj.Free;
      end;
    end;
  end;

  if Length(FSegments) = 0 then
  begin
    SetLength(FSegments, 1);
    FSegments[0].SegmentId := GenerateMmpId('sg');
    FSegments[0].OrderIdx := 1;
    FSegments[0].DurationSec := 30;
    FSegments[0].PromptText := FCurrentSceneHeading;
    FSegments[0].Status := 'pending';
  end;

  if FSceneCombo.ItemIndex = 0 then
    FPrevSceneLinkStatus := 'primeira_cena'
  else
    FPrevSceneLinkStatus := 'pendente';

  if FSceneCombo.ItemIndex >= FSceneCombo.Items.Count - 1 then
    FNextSceneLinkStatus := 'ligacao_posterior_pendente'
  else
    FNextSceneLinkStatus := 'pendente';

  FPrevLinkLabel.Caption := 'Anterior: ' + FPrevSceneLinkStatus;
  FNextLinkLabel.Caption := 'Proxima: ' + FNextSceneLinkStatus;
  RefreshSegmentsGrid;
end;

procedure TMsceneMainForm.RefreshSegmentsGrid;
var
  I, Row: Integer;
begin
  if Length(FSegments) = 0 then
  begin
    FSegmentsGrid.RowCount := 2;
    for I := 0 to FSegmentsGrid.ColCount - 1 do FSegmentsGrid.Cells[I, 1] := '';
    Exit;
  end;
  FSegmentsGrid.RowCount := Length(FSegments) + 1;
  for I := 0 to High(FSegments) do
  begin
    Row := I + 1;
    FSegmentsGrid.Cells[0, Row] := FSegments[I].SegmentId;
    FSegmentsGrid.Cells[1, Row] := IntToStr(FSegments[I].OrderIdx);
    FSegmentsGrid.Cells[2, Row] := IntToStr(FSegments[I].DurationSec);
    FSegmentsGrid.Cells[3, Row] := FSegments[I].Status;
    FSegmentsGrid.Cells[4, Row] := FSegments[I].PromptText;
    FSegmentsGrid.Cells[5, Row] := FSegments[I].VideoRelUri;
  end;
end;

procedure TMsceneMainForm.OnGenerateCurrentSceneClick(Sender: TObject);
var
  RevDir, PreviewBmp, RelJson, Resp, Err: string;
  SegObj: TJSONObject;
  I: Integer;
begin
  if FCurrentSceneId = '' then Exit;
  RevDir := FSceneProjectDir + PathDelim + 'revisions' + PathDelim + FSceneRevId;
  ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'segments');

  for I := 0 to High(FSegments) do
  begin
    if FAi.IsConfigured and (I = 0) then
    begin
      if FAi.Ask('Gere instrucao de direcao visual para geracao de video deste segmento.',
        FSegments[I].PromptText, Resp, Err) then
        FSegments[I].PromptText := Resp;
    end;

    RelJson := 'video/segments/' + FCurrentSceneId + '_' + FSegments[I].SegmentId + '.json';
    FSegments[I].VideoRelUri := RelJson;
    FSegments[I].Status := 'generated';

    SegObj := TJSONObject.Create;
    try
      SegObj.Add('scene_id', FCurrentSceneId);
      SegObj.Add('segment_id', FSegments[I].SegmentId);
      SegObj.Add('duration_sec', FSegments[I].DurationSec);
      SegObj.Add('prompt', FSegments[I].PromptText);
      SegObj.Add('status', 'generated');
      AtomicWriteTextFile(RevDir + PathDelim + StringReplace(RelJson, '/', PathDelim, [rfReplaceAll]),
        SegObj.FormatJSON, False);
    finally
      SegObj.Free;
    end;
  end;

  PreviewBmp := RevDir + PathDelim + 'video' + PathDelim + 'segments' + PathDelim +
    FCurrentSceneId + '_preview.bmp';
  SavePlaceholderBitmap(PreviewBmp, 'MScene: ' + FCurrentSceneId,
    FCurrentSceneHeading, 'Sub-blocos gerados: ' + IntToStr(Length(FSegments)), $00283848);
  if FileExists(PreviewBmp) then
    FPreviewImg.Picture.LoadFromFile(PreviewBmp);

  RefreshSegmentsGrid;
  LogMsg('Etapa 1: Gerados ' + IntToStr(Length(FSegments)) + ' sub-blocos apenas para cena ' +
    FCurrentSceneId + ' (sem lote automatico).');
end;

procedure TMsceneMainForm.OnApproveSegmentClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FSegmentsGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FSegments)) then Exit;
  FSegments[Idx].Status := 'approved';
  RefreshSegmentsGrid;
end;

procedure TMsceneMainForm.OnAssembleSceneClick(Sender: TObject);
var
  I: Integer;
  RevDir, RelAssembled: string;
  Obj: TJSONObject;
  Arr: TJSONArray;
begin
  if Length(FSegments) = 0 then Exit;
  for I := 0 to High(FSegments) do
  begin
    if FSegments[I].Status = 'pending' then
    begin
      MessageDlg('Gere e valide todos os sub-blocos antes de costurar a cena.', mtWarning, [mbOK], 0);
      Exit;
    end;
  end;

  RevDir := FSceneProjectDir + PathDelim + 'revisions' + PathDelim + FSceneRevId;
  ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'assembled');
  RelAssembled := 'video/assembled/' + FCurrentSceneId + '_assembled.json';
  FAssembledRelUri := RelAssembled;

  Obj := TJSONObject.Create;
  try
    Obj.Add('schema', 'mmp.mscene.assembled/1');
    Obj.Add('scene_id', FCurrentSceneId);
    Obj.Add('heading', FCurrentSceneHeading);
    Arr := TJSONArray.Create;
    for I := 0 to High(FSegments) do
      Arr.Add(FSegments[I].SegmentId);
    Obj.Add('segment_order', Arr);
    Obj.Add('prev_link', FPrevSceneLinkStatus);
    Obj.Add('next_link', FNextSceneLinkStatus);
    AtomicWriteTextFile(RevDir + PathDelim + StringReplace(RelAssembled, '/', PathDelim, [rfReplaceAll]),
      Obj.FormatJSON, False);
  finally
    Obj.Free;
  end;
  LogMsg('Etapa 2: Cena ' + FCurrentSceneId + ' costurada em ' + RelAssembled);
end;

procedure TMsceneMainForm.OnApprovePrevLinkClick(Sender: TObject);
begin
  FPrevSceneLinkStatus := 'ligacao_anterior_aprovada';
  FPrevLinkLabel.Caption := 'Anterior: ' + FPrevSceneLinkStatus;
end;

procedure TMsceneMainForm.OnApproveNextLinkClick(Sender: TObject);
begin
  if FSceneCombo.ItemIndex >= FSceneCombo.Items.Count - 1 then
  begin
    FNextSceneLinkStatus := 'ligacao_posterior_pendente';
    FNextLinkLabel.Caption := 'Proxima: ' + FNextSceneLinkStatus;
    MessageDlg('Nao ha proxima cena disponivel; ligacao permanece como pendente (nao aprovada por suposicao).',
      mtInformation, [mbOK], 0);
  end
  else
  begin
    FNextSceneLinkStatus := 'ligacao_posterior_aprovada';
    FNextLinkLabel.Caption := 'Proxima: ' + FNextSceneLinkStatus;
  end;
end;

procedure TMsceneMainForm.OnSaveSceneProjectClick(Sender: TObject);
var
  SceneProjPath, PrepRev, RevDir, NewRev, ErrMsg, FinalState, OldRevDir, SrcF, DstF: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, ArtN: Integer;
  FS1, FS2: TFileStream;
begin
  if not FProd.Loaded or (FCurrentSceneId = '') then Exit;
  SceneProjPath := FSceneProjectDir + PathDelim + 'project.json';
  if not PrepareNextRevisionDir(SceneProjPath, PrepRev, RevDir) then Exit;
  OldRevDir := FSceneProjectDir + PathDelim + 'revisions' + PathDelim + FSceneRevId;

  SetLength(Arts, 0);
  for I := 0 to High(FSegments) do
  begin
    if FSegments[I].VideoRelUri = '' then Continue;
    SrcF := OldRevDir + PathDelim + StringReplace(FSegments[I].VideoRelUri, '/', PathDelim, [rfReplaceAll]);
    DstF := RevDir + PathDelim + StringReplace(FSegments[I].VideoRelUri, '/', PathDelim, [rfReplaceAll]);
    if FileExists(SrcF) and not SameText(SrcF, DstF) then
    begin
      ForceDirectories(ExtractFileDir(DstF));
      FS1 := TFileStream.Create(SrcF, fmOpenRead or fmShareDenyNone);
      try
        FS2 := TFileStream.Create(DstF, fmCreate);
        try FS2.CopyFrom(FS1, 0); finally FS2.Free; end;
      finally
        FS1.Free;
      end;
    end;
    ArtN := Length(Arts);
    SetLength(Arts, ArtN + 1);
    Arts[ArtN].ArtifactId := GenerateMmpId('a');
    Arts[ArtN].Kind := 'video.segment';
    Arts[ArtN].SceneId := FCurrentSceneId;
    Arts[ArtN].SegmentId := FSegments[I].SegmentId;
    Arts[ArtN].RelUri := FSegments[I].VideoRelUri;
    Arts[ArtN].MimeType := 'application/json';
    Arts[ArtN].Status := FSegments[I].Status;
  end;

  if FAssembledRelUri <> '' then
  begin
    SrcF := OldRevDir + PathDelim + StringReplace(FAssembledRelUri, '/', PathDelim, [rfReplaceAll]);
    DstF := RevDir + PathDelim + StringReplace(FAssembledRelUri, '/', PathDelim, [rfReplaceAll]);
    if FileExists(SrcF) and not SameText(SrcF, DstF) then
    begin
      ForceDirectories(ExtractFileDir(DstF));
      FS1 := TFileStream.Create(SrcF, fmOpenRead or fmShareDenyNone);
      try
        FS2 := TFileStream.Create(DstF, fmCreate);
        try FS2.CopyFrom(FS1, 0); finally FS2.Free; end;
      finally
        FS1.Free;
      end;
    end;
    ArtN := Length(Arts);
    SetLength(Arts, ArtN + 1);
    Arts[ArtN].ArtifactId := GenerateMmpId('a');
    Arts[ArtN].Kind := 'video.scene';
    Arts[ArtN].SceneId := FCurrentSceneId;
    Arts[ArtN].RelUri := FAssembledRelUri;
    Arts[ArtN].MimeType := 'application/json';
    Arts[ArtN].Status := 'approved';
  end;

  SetLength(Srcs, 4);
  Srcs[0].ProjectId := FScriptProj.ProjectId; Srcs[0].RevisionId := FScriptProj.ActiveRevision;
  if FindRevisionInProject(FScriptProj, FScriptProj.ActiveRevision, RevInfo) then Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;
  Srcs[1].ProjectId := FVisualProj.ProjectId; Srcs[1].RevisionId := FVisualProj.ActiveRevision;
  if FindRevisionInProject(FVisualProj, FVisualProj.ActiveRevision, RevInfo) then Srcs[1].ManifestSha256 := RevInfo.ManifestSha256;
  Srcs[2].ProjectId := FBoardProj.ProjectId; Srcs[2].RevisionId := FBoardProj.ActiveRevision;
  if FindRevisionInProject(FBoardProj, FBoardProj.ActiveRevision, RevInfo) then Srcs[2].ManifestSha256 := RevInfo.ManifestSha256;
  Srcs[3].ProjectId := FSoundProj.ProjectId; Srcs[3].RevisionId := FSoundProj.ActiveRevision;
  if FindRevisionInProject(FSoundProj, FSoundProj.ActiveRevision, RevInfo) then Srcs[3].ManifestSha256 := RevInfo.ManifestSha256;

  if FNextSceneLinkStatus = 'ligacao_posterior_pendente' then
    FinalState := 'ligacao_posterior_pendente'
  else
    FinalState := 'finalizada';

  if PublishProjectRevision(FProd.ProductionId, SceneProjPath, 'MScene',
    FSceneRevId, FinalState, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    FSceneRevId := NewRev;
    LogMsg('Projeto da cena ' + FCurrentSceneId + ' salvo na revisao ' + NewRev + ' [' + FinalState + ']');
  end
  else
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
end;

procedure TMsceneMainForm.OnOpenProdClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Abrir production.json';
    D.Filter := 'MaurinMovie (production.json)|production.json';
    D.Options := [ofFileMustExist, ofPathMustExist];
    if D.Execute then
      LoadProduction(ExtractFileDir(D.FileName), '', '');
  finally
    D.Free;
  end;
end;

procedure TMsceneMainForm.OnAiConfigClick(Sender: TObject);
begin
  if FAi.ShowConfigDialog(Self) then
    LogMsg('IA configurada: ' + FAi.ProviderDisplayName);
end;

procedure TMsceneMainForm.OnSceneComboChange(Sender: TObject);
begin
  LoadSelectedSceneWork;
end;

end.
