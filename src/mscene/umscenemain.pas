unit umscenemain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser, aih264decoder,
  ummpprotocol, ummpappbase, ummpaibridge, ummpvideo, LCLIntf, mmpcommon, FileUtil, ummpsha256;

type
  TSceneSegmentWork = record
    SegmentId: string;
    OrderIdx: Integer;
    DurationSec: Integer;
    PromptText: string;
    Status: string; // pending | generated | approved | rejected
    VideoRelUri, VideoPath, OpeningPath: string;
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
    FAssembledRelUri, FAssembledPath: string;
    FLoadedBoard: Boolean;
    FPreferredSceneId, FPreferredSceneRevision: string;

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
    function FindAudioGuide(const PartId: string): string;
    function TryOpenPublishedSceneAt(Index: Integer): Boolean;
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
  ProdRoot, ProjId, RevId, MMenuVer, ProdId: string;
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

  ParseAppLaunchContext(ProdRoot, ProjId, RevId, MMenuVer, ProdId);
  LogMsg('MScene v' + MMP_EXECUTABLE_VERSION + ' iniciado (openai_core + openai_video) | MMenu v' +
    MMenuVer + ' | Projeto: ' + ProjId);
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

  BtnAiCfg := TButton.Create(Self); BtnAiCfg.Parent := Head; BtnAiCfg.Caption := 'Alterar no MMenu...';
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
  if FProd.Loaded then
    MmpLogAppOperation(FProd.RootDir, FProd.ProductionId, 'MScene', Msg, FSceneRevId);
end;

procedure TMsceneMainForm.OnDecoderFrame(Sender: TObject; ABitmap: TBitmap);
begin
  if (ABitmap <> nil) and (FPreviewImg <> nil) then
    FPreviewImg.Picture.Bitmap.Assign(ABitmap);
end;

procedure TMsceneMainForm.LoadProduction(const ProdRoot, ProjId, RevId: string);
var
  ErrMsg, CurRev: string;
  Args: TMMLaunchArgs;
begin
  if not ResolveAppProject(ProdRoot, 5, ProjId, RevId, FProd, FProj,
    FProjectDir, CurRev, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  Args := ParseLaunchArgs;
  FPreferredSceneId := FProj.SceneId;
  FPreferredSceneRevision := '';
  if FPreferredSceneId <> '' then
  begin
    FPreferredSceneRevision := CurRev;
    FProjectDir := ExtractFileDir(ExtractFileDir(FProjectDir));
  end
  else if ProdRoot = Args.Production then
    FPreferredSceneId := Args.SceneId;

  FAi.LoadForProduction(FProd.RootDir);
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
    if FPreferredSceneId <> '' then
      for I := 0 to FSceneCombo.Items.Count - 1 do
        if Pos(FPreferredSceneId + ' | ', FSceneCombo.Items[I]) = 1 then
        begin
          FSceneCombo.ItemIndex := I;
          Break;
        end;
    LoadSelectedSceneWork;
  end;
end;

procedure TMsceneMainForm.EnsureSceneProjectExists(const SceneId: string);
var
  ProjJsonPath, RevDir, NowIso, SceneProjectId: string;
  ProjObj, ManObj: TJSONObject;
  Arr: TJSONArray;
begin
  FSceneProjectDir := IncludeTrailingPathDelimiter(FProjectDir) + 'scenes' + PathDelim + SceneId;
  ProjJsonPath := FSceneProjectDir + PathDelim + 'project.json';
  if FileExists(ProjJsonPath) then Exit;

  NowIso := CurrentIsoUtc;
  SceneProjectId := GenerateMmpId('pr_mscene_' + SceneId);
  RevDir := FSceneProjectDir + PathDelim + 'revisions' + PathDelim + 'r0001';
  ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'segments');
  ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'assembled');
  ForceDirectories(RevDir + PathDelim + 'audio' + PathDelim + 'guides');

  ProjObj := TJSONObject.Create;
  try
    ProjObj.Add('schema', MMP_PROJECT_SCHEMA);
    ProjObj.Add('production_id', FProd.ProductionId);
    ProjObj.Add('project_id', SceneProjectId);
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
    ManObj.Add('project_id', SceneProjectId);
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
  S, BoardPath, BoardDir, Content, SceneProjPath: string;
  P: SizeInt;
  Data: TJSONData;
  Obj, BObj, SObj: TJSONObject;
  BArr, SArr: TJSONArray;
  I, J, K: Integer;
  SceneProj: TMmpProjectRef;
  Rev: TMmpRevisionInfo;
  function HasExactSource(const Project: TMmpProjectRef): Boolean;
  var
    SourceIndex: Integer;
  begin
    for SourceIndex := 0 to High(Rev.Sources) do
      if (Rev.Sources[SourceIndex].ProjectId = Project.ProjectId) and
        (Rev.Sources[SourceIndex].RevisionId = Project.ActiveRevision) then Exit(True);
    Result := False;
  end;

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

  if (FPreferredSceneRevision <> '') and (FCurrentSceneId = FPreferredSceneId) then
    FSceneRevId := FPreferredSceneRevision;
  FPreferredSceneRevision := '';
  SetLength(FSegments, 0);
  FAssembledRelUri := '';
  FAssembledPath := '';
  FLoadedBoard := False;
  FPreviewImg.Picture.Clear;
  BoardPath := ExtractFileDir(FBoardProj.ProjectFilePath) + PathDelim + 'revisions' +
    PathDelim + FBoardProj.ActiveRevision + PathDelim + 'storyboard' + PathDelim + 'scenes.json';
  BoardDir := ExtractFileDir(ExtractFileDir(BoardPath));
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
              FLoadedBoard := True;
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
                  ResolveSafePath(BoardDir, SObj.Get('opening_uri', ''), FSegments[J].OpeningPath);
                end;
              end;
              if Length(FSegments) = 0 then
              begin
                SetLength(FSegments, 1);
                FSegments[0].SegmentId := 'sg_' + FCurrentSceneId;
                FSegments[0].OrderIdx := 1;
                FSegments[0].DurationSec := BObj.Get('estimated_duration_seconds', 30);
                FSegments[0].PromptText := FCurrentSceneHeading + ' | ' + BObj.Get('direction_notes', '');
                FSegments[0].Status := 'pending';
                ResolveSafePath(BoardDir, BObj.Get('opening_uri', ''), FSegments[0].OpeningPath);
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

  if FSceneCombo.ItemIndex = 0 then
    FPrevSceneLinkStatus := 'primeira_cena'
  else
    FPrevSceneLinkStatus := 'pendente';

  FNextSceneLinkStatus := 'ligacao_posterior_pendente';

  for I := 0 to High(FProd.Projects) do
    if SameText(FProd.Projects[I].ProjectFilePath, SceneProjPath) then
    begin
      SceneProj := FProd.Projects[I];
      if not FindRevisionInProject(SceneProj, FSceneRevId, Rev) then Break;
      if not (HasExactSource(FBoardProj) and HasExactSource(FScriptProj) and
        HasExactSource(FVisualProj) and HasExactSource(FSoundProj)) then Break;
      for J := 0 to High(Rev.Artifacts) do
        with Rev.Artifacts[J] do
        begin
          if (ResolvedPath = '') or (Sha256 = '') or not FileExists(ResolvedPath) then Continue;
          if (Kind <> 'scene.details') and (Kind <> 'video.scene') and (Kind <> 'video.segment') then Continue;
          if not SameText(SHA256File(ResolvedPath), Sha256) then Continue;
          if (Kind = 'scene.details') and ReadTextFileUtf8(ResolvedPath, Content) then
          begin
            Data := GetJSON(Content);
            try
              if Data is TJSONObject then
              begin
                FPrevSceneLinkStatus := TJSONObject(Data).Get('prev_link', FPrevSceneLinkStatus);
                FNextSceneLinkStatus := TJSONObject(Data).Get('next_link', FNextSceneLinkStatus);
              end;
            finally
              Data.Free;
            end;
          end;
          if (Kind = 'video.scene') and (MimeType = 'video/mp4') then
          begin
            FAssembledPath := ResolvedPath;
            FAssembledRelUri := 'video/assembled/scene.mp4';
          end;
          if (Kind <> 'video.segment') or (MimeType <> 'video/mp4') then Continue;
          for K := 0 to High(FSegments) do
            if FSegments[K].SegmentId = SegmentId then
            begin
              FSegments[K].VideoPath := ResolvedPath;
              FSegments[K].VideoRelUri := 'video/segments/' + SegmentId + '.mp4';
              FSegments[K].Status := Status;
              Break;
            end;
        end;
      Break;
    end;

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

function TMsceneMainForm.FindAudioGuide(const PartId: string): string;
var
  Rev: TMmpRevisionInfo;
  I: Integer;
  CurrentBoard: Boolean;
begin
  Result := '';
  if not FindRevisionInProject(FSoundProj, FSoundProj.ActiveRevision, Rev) then Exit;
  CurrentBoard := False;
  for I := 0 to High(Rev.Sources) do
    if (Rev.Sources[I].ProjectId = FBoardProj.ProjectId) and
      (Rev.Sources[I].RevisionId = FBoardProj.ActiveRevision) and
      (Rev.Sources[I].Status = 'ok') then
      CurrentBoard := True;
  if not CurrentBoard then Exit;
  for I := 0 to High(Rev.Artifacts) do
    with Rev.Artifacts[I] do
      if (Kind = 'audio.preview') and (SceneId = FCurrentSceneId) and
        (SegmentId = PartId) and
        ((Status = 'approved') or not FAi.Settings.RequireVoiceApprovalForScene) and
        (Sha256 <> '') and FileExists(ResolvedPath) and SameText(SHA256File(ResolvedPath), Sha256) then
        Exit(ResolvedPath);
end;

procedure TMsceneMainForm.OnGenerateCurrentSceneClick(Sender: TObject);
var
  WorkDir, OutputFile, Err, ProbeExe, AudioGuide: string;
  I: Integer;
  Duration: Double;
  HasAudio: Boolean;
begin
  if not FLoadedBoard then
  begin
    MessageDlg('Publique o storyboard desta cena no MBoard primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FAi.ReloadIfChanged;
  ProbeExe := FAi.Settings.ToolFfprobe;
  if ProbeExe = '' then ProbeExe := FAi.Settings.DetectToolPath('ffprobe');
  WorkDir := FSceneProjectDir + PathDelim + 'work' + PathDelim + 'segments';
  if not ForceDirectories(WorkDir) then Exit;
  for I := 0 to High(FSegments) do
  begin
    if FSegments[I].Status = 'approved' then Continue;
    if (FSegments[I].Status = 'generated') and FileExists(FSegments[I].VideoPath) then Continue;
    if not FileExists(FSegments[I].OpeningPath) then
    begin
      LogMsg('Quadro inicial ausente no segmento ' + FSegments[I].SegmentId);
      Break;
    end;
    AudioGuide := FindAudioGuide(FSegments[I].SegmentId);
    if AudioGuide = '' then
      LogMsg('Sem guia de áudio compatível para ' + FSegments[I].SegmentId + '.');
    OutputFile := WorkDir + PathDelim + GenerateMmpId('video') + '.mp4';
    if not FAi.GenerateVideo(FSegments[I].PromptText, OutputFile, Err,
      FSegments[I].OpeningPath, AudioGuide, FSegments[I].DurationSec) or
      not ProbeMmpVideo(ProbeExe, OutputFile, Duration, HasAudio, Err) then
    begin
      DeleteFile(OutputFile);
      LogMsg('Falha no segmento ' + FSegments[I].SegmentId + ': ' + Err);
      Break;
    end;
    FSegments[I].VideoPath := OutputFile;
    FSegments[I].VideoRelUri := 'video/segments/' + FSegments[I].SegmentId + '.mp4';
    FSegments[I].Status := 'generated';
    FAssembledPath := '';
    FAssembledRelUri := '';
    LogMsg('Segmento gerado para revisão: ' + FSegments[I].SegmentId);
  end;
  RefreshSegmentsGrid;
end;

procedure TMsceneMainForm.OnApproveSegmentClick(Sender: TObject);
var
  Idx: Integer;
  Review: TModalResult;
begin
  Idx := FSegmentsGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FSegments)) then Exit;
  if not FileExists(FSegments[Idx].VideoPath) then
  begin
    MessageDlg('Gere o vídeo deste segmento primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not OpenDocument(FSegments[Idx].VideoPath) then
  begin
    MessageDlg('Não foi possível abrir o vídeo para revisão.', mtError, [mbOK], 0);
    Exit;
  end;
  Review := MessageDlg('Depois de assistir, confirme a aprovação do segmento. ' +
    'Escolha Não para reprovar e permitir gerar novamente.', mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if Review = mrYes then FSegments[Idx].Status := 'approved';
  if Review = mrNo then
  begin
    FSegments[Idx].Status := 'rejected';
    FAssembledPath := '';
    FAssembledRelUri := '';
  end;
  RefreshSegmentsGrid;
end;

procedure TMsceneMainForm.OnAssembleSceneClick(Sender: TObject);
var
  I: Integer;
  Clips: array of TMmpVideoClip;
  OutputFile, Ffmpeg, Ffprobe, Err: string;
  Duration: Double;
begin
  if Length(FSegments) = 0 then Exit;
  SetLength(Clips, Length(FSegments));
  for I := 0 to High(FSegments) do
  begin
    if (FSegments[I].Status <> 'approved') or not FileExists(FSegments[I].VideoPath) then
    begin
      MessageDlg('Gere e valide todos os segmentos antes de costurar a cena.', mtWarning, [mbOK], 0);
      Exit;
    end;
    Clips[I].FileName := FSegments[I].VideoPath;
  end;

  FAi.ReloadIfChanged;
  Ffmpeg := FAi.Settings.ToolFfmpeg;
  if Ffmpeg = '' then Ffmpeg := FAi.Settings.DetectToolPath('ffmpeg');
  Ffprobe := FAi.Settings.ToolFfprobe;
  if Ffprobe = '' then Ffprobe := FAi.Settings.DetectToolPath('ffprobe');
  OutputFile := FSceneProjectDir + PathDelim + 'work' + PathDelim +
    GenerateMmpId('scene') + '.mp4';
  if not RenderMmpVideo(Ffmpeg, Ffprobe, OutputFile, Clips, FAi.Settings.ProdWidth,
    FAi.Settings.ProdHeight, FAi.Settings.ProdFps, Duration, Err) then
  begin
    MessageDlg(Err, mtError, [mbOK], 0);
    Exit;
  end;
  FAssembledPath := OutputFile;
  FAssembledRelUri := 'video/assembled/scene.mp4';
  OpenDocument(FAssembledPath);
  LogMsg('Cena costurada. Assista ao vídeo antes de salvar a revisão.');
end;

function TMsceneMainForm.TryOpenPublishedSceneAt(Index: Integer): Boolean;
var
  I, J, DelimiterPos: Integer;
  Id: string;
  Rev: TMmpRevisionInfo;
begin
  Result := False;
  if (Index < 0) or (Index >= FSceneCombo.Items.Count) then Exit;
  Id := FSceneCombo.Items[Index];
  DelimiterPos := Pos(' | ', Id);
  if DelimiterPos > 0 then SetLength(Id, DelimiterPos - 1);
  for I := 0 to High(FProd.Projects) do
    if (FProd.Projects[I].SceneId = Id) and
      FindRevisionInProject(FProd.Projects[I], FProd.Projects[I].ActiveRevision, Rev) then
      for J := 0 to High(Rev.Artifacts) do
        with Rev.Artifacts[J] do
          if (Kind = 'video.scene') and (MimeType = 'video/mp4') and
            (Status = 'approved') and FileExists(ResolvedPath) then
          begin
            Exit(OpenDocument(ResolvedPath));
          end;
end;

procedure TMsceneMainForm.OnApprovePrevLinkClick(Sender: TObject);
begin
  if not FileExists(FAssembledPath) or not TryOpenPublishedSceneAt(FSceneCombo.ItemIndex - 1) then
  begin
    MessageDlg('A cena atual e o vídeo aprovado da cena anterior precisam estar disponíveis.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  OpenDocument(FAssembledPath);
  if MessageDlg('Você assistiu à ligação e aprova a continuidade com a cena anterior?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FPrevSceneLinkStatus := 'ligacao_anterior_aprovada';
    FPrevLinkLabel.Caption := 'Anterior: ' + FPrevSceneLinkStatus;
  end;
end;

procedure TMsceneMainForm.OnApproveNextLinkClick(Sender: TObject);
begin
  if not FileExists(FAssembledPath) or not TryOpenPublishedSceneAt(FSceneCombo.ItemIndex + 1) then
  begin
    FNextSceneLinkStatus := 'ligacao_posterior_pendente';
    FNextLinkLabel.Caption := 'Próxima: ' + FNextSceneLinkStatus;
    MessageDlg('A cena atual e o vídeo aprovado da próxima cena precisam estar disponíveis.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  OpenDocument(FAssembledPath);
  if MessageDlg('Você assistiu à ligação e aprova a continuidade com a próxima cena?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FNextSceneLinkStatus := 'ligacao_posterior_aprovada';
    FNextLinkLabel.Caption := 'Próxima: ' + FNextSceneLinkStatus;
  end;
end;

procedure TMsceneMainForm.OnSaveSceneProjectClick(Sender: TObject);
var
  SceneProjPath, PrepRev, RevDir, NewRev, ErrMsg, FinalState, SrcF, DstF: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, ArtN: Integer;
  UpdatedProd: TMmpProduction;
  Details: TJSONObject;
  SegmentsJson: TJSONArray;
  SegmentJson: TJSONObject;
begin
  if not FProd.Loaded or (FCurrentSceneId = '') then Exit;
  if not FileExists(FAssembledPath) then
  begin
    MessageDlg('Costure a cena antes de salvar a revisão.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Você revisou e aprova o vídeo da cena?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then Exit;
  SceneProjPath := FSceneProjectDir + PathDelim + 'project.json';
  if not PrepareNextRevisionDir(SceneProjPath, PrepRev, RevDir) then Exit;

  SetLength(Arts, 0);
  for I := 0 to High(FSegments) do
  begin
    if FSegments[I].VideoRelUri = '' then Continue;
    SrcF := FSegments[I].VideoPath;
    DstF := RevDir + PathDelim + StringReplace(FSegments[I].VideoRelUri, '/', PathDelim, [rfReplaceAll]);
    if not ForceDirectories(ExtractFileDir(DstF)) or not CopyFile(SrcF, DstF) then
    begin
      MessageDlg('Não foi possível copiar o vídeo para a revisão: ' + SrcF, mtError, [mbOK], 0);
      Exit;
    end;
    ArtN := Length(Arts);
    SetLength(Arts, ArtN + 1);
    Arts[ArtN].ArtifactId := GenerateMmpId('a');
    Arts[ArtN].Kind := 'video.segment';
    Arts[ArtN].SceneId := FCurrentSceneId;
    Arts[ArtN].SegmentId := FSegments[I].SegmentId;
    Arts[ArtN].RelUri := FSegments[I].VideoRelUri;
    Arts[ArtN].MimeType := 'video/mp4';
    Arts[ArtN].Status := FSegments[I].Status;
  end;

  if FAssembledRelUri <> '' then
  begin
    SrcF := FAssembledPath;
    DstF := RevDir + PathDelim + StringReplace(FAssembledRelUri, '/', PathDelim, [rfReplaceAll]);
    if not ForceDirectories(ExtractFileDir(DstF)) or not CopyFile(SrcF, DstF) then
    begin
      MessageDlg('Não foi possível copiar o vídeo para a revisão: ' + SrcF, mtError, [mbOK], 0);
      Exit;
    end;
    ArtN := Length(Arts);
    SetLength(Arts, ArtN + 1);
    Arts[ArtN].ArtifactId := GenerateMmpId('a');
    Arts[ArtN].Kind := 'video.scene';
    Arts[ArtN].SceneId := FCurrentSceneId;
    Arts[ArtN].RelUri := FAssembledRelUri;
    Arts[ArtN].MimeType := 'video/mp4';
    Arts[ArtN].Status := 'approved';
  end;

  Details := TJSONObject.Create;
  try
    Details.Add('schema', 'mmp.mscene.assembled/1');
    Details.Add('scene_id', FCurrentSceneId);
    Details.Add('prev_link', FPrevSceneLinkStatus);
    Details.Add('next_link', FNextSceneLinkStatus);
    SegmentsJson := TJSONArray.Create;
    Details.Add('segments', SegmentsJson);
    for I := 0 to High(FSegments) do
    begin
      SegmentJson := TJSONObject.Create;
      SegmentJson.Add('segment_id', FSegments[I].SegmentId);
      SegmentJson.Add('order', FSegments[I].OrderIdx);
      SegmentJson.Add('duration_seconds', FSegments[I].DurationSec);
      SegmentJson.Add('prompt', FSegments[I].PromptText);
      SegmentsJson.Add(SegmentJson);
    end;
    if not AtomicWriteTextFile(RevDir + PathDelim + 'video' + PathDelim +
      'scene_details.json', Details.FormatJSON, False) then
    begin
      MessageDlg('Não foi possível gravar os dados da cena.', mtError, [mbOK], 0);
      Exit;
    end;
  finally
    Details.Free;
  end;
  ArtN := Length(Arts);
  SetLength(Arts, ArtN + 1);
  Arts[ArtN].Kind := 'scene.details';
  Arts[ArtN].SceneId := FCurrentSceneId;
  Arts[ArtN].RelUri := 'video/scene_details.json';
  Arts[ArtN].MimeType := 'application/json';
  Arts[ArtN].Status := 'approved';

  SetLength(Srcs, 4);
  Srcs[0].ProjectId := FScriptProj.ProjectId; Srcs[0].RevisionId := FScriptProj.ActiveRevision;
  if FindRevisionInProject(FScriptProj, FScriptProj.ActiveRevision, RevInfo) then Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;
  Srcs[1].ProjectId := FVisualProj.ProjectId; Srcs[1].RevisionId := FVisualProj.ActiveRevision;
  if FindRevisionInProject(FVisualProj, FVisualProj.ActiveRevision, RevInfo) then Srcs[1].ManifestSha256 := RevInfo.ManifestSha256;
  Srcs[2].ProjectId := FBoardProj.ProjectId; Srcs[2].RevisionId := FBoardProj.ActiveRevision;
  if FindRevisionInProject(FBoardProj, FBoardProj.ActiveRevision, RevInfo) then Srcs[2].ManifestSha256 := RevInfo.ManifestSha256;
  Srcs[3].ProjectId := FSoundProj.ProjectId; Srcs[3].RevisionId := FSoundProj.ActiveRevision;
  if FindRevisionInProject(FSoundProj, FSoundProj.ActiveRevision, RevInfo) then Srcs[3].ManifestSha256 := RevInfo.ManifestSha256;

  if (FPrevSceneLinkStatus <> 'primeira_cena') and
    (FPrevSceneLinkStatus <> 'ligacao_anterior_aprovada') then
    FinalState := 'ligacao_anterior_pendente'
  else if FNextSceneLinkStatus = 'ligacao_posterior_pendente' then
    FinalState := 'ligacao_posterior_pendente'
  else
    FinalState := 'finalizada';

  if PublishProjectRevision(FProd.ProductionId, SceneProjPath, 'MScene',
    FSceneRevId, FinalState, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    FSceneRevId := NewRev;
    if ummpprotocol.LoadProduction(FProd.RootDir, False, UpdatedProd) then FProd := UpdatedProd;
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
