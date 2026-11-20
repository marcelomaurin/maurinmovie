unit umscenemain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Math, fpjson, jsonparser, aih264decoder,
  ummpprotocol, ummpappbase, ummpaibridge, ummpmedia;

type
  TSceneSegmentWork = record
    SegmentId: string;
    OrderIdx: Integer;
    DurationSec: Integer;
    PromptText: string;
    Status: string; // pending | generated | approved | rejected
    VideoRelUri: string;   // video/segments/<cena>_<seg>.mp4
    MetaRelUri: string;    // video/segments/<cena>_<seg>.json
    OpeningUri, ClosingUri: string; // quadros do MBoard (relativos a revisao ativa)
    Dialogue: string;      // "Nome: fala", uma por linha
    Method: string;        // ia_video | animatica_local
    RealSec: Double;       // duracao do video gerado
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
    FAssembledRelUri: string;       // video/assembled/<cena>.mp4
    FAssembledMetaRelUri: string;   // video/assembled/<cena>_assembled.json

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
    function NewMedia: TMmpMedia;
    function BoardFile(const RelUri: string): string;
    function SoundRevDir: string;
    function DraftPath(const RelUri: string): string;
    procedure FindSoundForScene(out Ambience: string; Voices: TStrings);
    procedure ShowVideoFrame(const Video: string; AtSec: Double);
    function SceneVideoFile(const SceneId: string): string;
    procedure WatchLink(ToPrevious: Boolean);
    procedure RestoreSceneState;
    procedure CopyRelToRevision(const RelUri, RevDir: string);
    procedure OnWatchSegmentClick(Sender: TObject);
    procedure OnWatchSceneClick(Sender: TObject);
    procedure OnWatchPrevLinkClick(Sender: TObject);
    procedure OnWatchNextLinkClick(Sender: TObject);

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
  BtnWatchSeg, BtnWatchScene, BtnWatchPrev, BtnWatchNext: TButton;
  L: TLabel;
begin
  Head := TPanel.Create(Self); Head.Parent := Self; Head.Align := alTop; MmpPrepareAligned(Head); Head.Height := 68;
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

  Bottom := TPanel.Create(Self); Bottom.Parent := Self; Bottom.Align := alBottom; MmpPrepareAligned(Bottom); Bottom.Height := 34;
  Bottom.BevelOuter := bvLowered;
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Bottom; FStatusLabel.SetBounds(12, 9, 1100, 18);
  FStatusLabel.Caption := 'Pronto.';

  Sidebar := TPanel.Create(Self); Sidebar.Parent := Self; Sidebar.Align := alLeft; MmpPrepareAligned(Sidebar); Sidebar.Width := 270;
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

  BtnAppSeg := TButton.Create(Self); BtnAppSeg.Parent := Sidebar; BtnAppSeg.Caption := 'Etapa 2a: Aprovar';
  BtnAppSeg.SetBounds(12, 160, 160, 34); BtnAppSeg.OnClick := @OnApproveSegmentClick;

  BtnWatchSeg := TButton.Create(Self); BtnWatchSeg.Parent := Sidebar; BtnWatchSeg.Caption := 'Assistir';
  BtnWatchSeg.SetBounds(178, 160, 80, 34); BtnWatchSeg.OnClick := @OnWatchSegmentClick;

  BtnAssemble := TButton.Create(Self); BtnAssemble.Parent := Sidebar; BtnAssemble.Caption := 'Etapa 2b: Costurar';
  BtnAssemble.SetBounds(12, 202, 160, 34); BtnAssemble.OnClick := @OnAssembleSceneClick;

  BtnWatchScene := TButton.Create(Self); BtnWatchScene.Parent := Sidebar; BtnWatchScene.Caption := 'Assistir';
  BtnWatchScene.SetBounds(178, 202, 80, 34); BtnWatchScene.OnClick := @OnWatchSceneClick;

  L := TLabel.Create(Self); L.Parent := Sidebar; L.Caption := 'Etapa 3: Ligacao entre cenas';
  L.Font.Style := [fsBold]; L.SetBounds(12, 252, 246, 18);

  FPrevLinkLabel := TLabel.Create(Self); FPrevLinkLabel.Parent := Sidebar;
  FPrevLinkLabel.Caption := 'Anterior: -'; FPrevLinkLabel.SetBounds(12, 276, 246, 18);

  BtnPrevOk := TButton.Create(Self); BtnPrevOk.Parent := Sidebar; BtnPrevOk.Caption := 'Aprovar Anterior';
  BtnPrevOk.SetBounds(12, 298, 160, 30); BtnPrevOk.OnClick := @OnApprovePrevLinkClick;

  BtnWatchPrev := TButton.Create(Self); BtnWatchPrev.Parent := Sidebar; BtnWatchPrev.Caption := 'Ver';
  BtnWatchPrev.SetBounds(178, 298, 80, 30); BtnWatchPrev.OnClick := @OnWatchPrevLinkClick;

  FNextLinkLabel := TLabel.Create(Self); FNextLinkLabel.Parent := Sidebar;
  FNextLinkLabel.Caption := 'Proxima: pendente'; FNextLinkLabel.SetBounds(12, 338, 246, 18);

  BtnNextOk := TButton.Create(Self); BtnNextOk.Parent := Sidebar; BtnNextOk.Caption := 'Validar Proxima';
  BtnNextOk.SetBounds(12, 360, 160, 30); BtnNextOk.OnClick := @OnApproveNextLinkClick;

  BtnWatchNext := TButton.Create(Self); BtnWatchNext.Parent := Sidebar; BtnWatchNext.Caption := 'Ver';
  BtnWatchNext.SetBounds(178, 360, 80, 30); BtnWatchNext.OnClick := @OnWatchNextLinkClick;

  L := TLabel.Create(Self); L.Parent := Sidebar; L.WordWrap := True; L.AutoSize := False;
  L.SetBounds(12, 404, 246, 120); L.Font.Color := $00555555;
  L.Caption := 'Sem IA de video configurada, cada sub-bloco vira uma animatica: quadros de ' +
    'abertura e fechamento do MBoard com movimento de camera, falas e ambiencia do MSound. ' +
    '"Ver" monta os ultimos e os primeiros segundos das duas cenas para conferir a ligacao.';

  PC := TPageControl.Create(Self); PC.Parent := Self; PC.Align := alClient; MmpPrepareAligned(PC);
  TabWork := TTabSheet.Create(PC); TabWork.PageControl := PC; MmpPrepareTabSheet(TabWork); TabWork.Caption := 'Sub-blocos && Montagem da Cena';
  TabLog := TTabSheet.Create(PC); TabLog.PageControl := PC; MmpPrepareTabSheet(TabLog); TabLog.Caption := 'Log Operacional';

  FSegmentsGrid := TStringGrid.Create(Self); FSegmentsGrid.Parent := TabWork; FSegmentsGrid.Align := alClient; MmpPrepareAligned(FSegmentsGrid);
  FSegmentsGrid.FixedCols := 0; FSegmentsGrid.FixedRows := 1; FSegmentsGrid.ColCount := 7; FSegmentsGrid.RowCount := 2;
  FSegmentsGrid.Options := FSegmentsGrid.Options + [goRowSelect, goColSizing];
  FSegmentsGrid.Cells[0, 0] := 'Segment ID'; FSegmentsGrid.Cells[1, 0] := 'Ordem';
  FSegmentsGrid.Cells[2, 0] := 'Dur (s)'; FSegmentsGrid.Cells[3, 0] := 'Status';
  FSegmentsGrid.Cells[4, 0] := 'Prompt / Guia'; FSegmentsGrid.Cells[5, 0] := 'Video / Artefato';
  FSegmentsGrid.Cells[6, 0] := 'Origem';
  FSegmentsGrid.ColWidths[0] := 125; FSegmentsGrid.ColWidths[1] := 55; FSegmentsGrid.ColWidths[2] := 65;
  FSegmentsGrid.ColWidths[3] := 95; FSegmentsGrid.ColWidths[4] := 250; FSegmentsGrid.ColWidths[5] := 230;
  FSegmentsGrid.ColWidths[6] := 120;
  FSegmentsGrid.OnDblClick := @OnWatchSegmentClick;

  PrevPanel := TPanel.Create(Self); PrevPanel.Parent := TabWork; PrevPanel.Align := alBottom; MmpPrepareAligned(PrevPanel);
  PrevPanel.Height := 230; PrevPanel.BevelOuter := bvLowered;
  FPreviewImg := TImage.Create(Self); FPreviewImg.Parent := PrevPanel;
  FPreviewImg.Stretch := True; FPreviewImg.Proportional := True;
  FPreviewImg.SetBounds(12, 12, 380, 206);

  FLogMemo := TMemo.Create(Self); FLogMemo.Parent := TabLog; FLogMemo.Align := alClient; MmpPrepareAligned(FLogMemo);
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
begin
  if not ResolveAppProject(ProdRoot, 5, ProjId, RevId, FProd, FProj,
    FProjectDir, CurRev, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

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
    LoadSelectedSceneWork;
  end;
end;

procedure TMsceneMainForm.EnsureSceneProjectExists(const SceneId: string);
var
  ProjJsonPath, RevDir, NowIso, NewProjId: string;
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
    NewProjId := GenerateMmpId('pr_mscene_' + SceneId);
    ProjObj.Add('project_id', NewProjId);
    ProjObj.Add('application', 'MScene');
    ProjObj.Add('scene_id', SceneId);
    ProjObj.Add('name_base', FProd.Title);
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
    { o manifesto precisa do mesmo project_id do project.json (antes ficava vazio) }
    ManObj.Add('project_id', NewProjId);
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
                  FSegments[J].OpeningUri := SObj.Get('opening_uri', BObj.Get('opening_uri', ''));
                  FSegments[J].ClosingUri := SObj.Get('closing_uri', BObj.Get('closing_uri', ''));
                  FSegments[J].Dialogue := SObj.Get('dialogue', '');
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
  RestoreSceneState;

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
    if FSegments[I].Method = 'ia_video' then FSegmentsGrid.Cells[6, Row] := 'IA de video'
    else if FSegments[I].Method = 'animatica_local' then FSegmentsGrid.Cells[6, Row] := 'Animatica local'
    else FSegmentsGrid.Cells[6, Row] := '';
  end;
end;

function TMsceneMainForm.NewMedia: TMmpMedia;
var Ff, Fp: string;
begin
  Ff := FAi.Settings.ToolFfmpeg;
  if (Ff = '') or not FileExists(Ff) then Ff := FAi.Settings.DetectToolPath('ffmpeg');
  Fp := FAi.Settings.ToolFfprobe;
  if (Fp = '') or not FileExists(Fp) then Fp := FAi.Settings.DetectToolPath('ffprobe');
  Result := TMmpMedia.Create(Ff, Fp);
  Result.Width := 1280;
  Result.Height := 720;
  Result.Fps := 25;
end;

function TMsceneMainForm.BoardFile(const RelUri: string): string;
begin
  Result := '';
  if (Trim(RelUri) = '') or (FBoardProj.ProjectFilePath = '') then Exit;
  Result := ExtractFileDir(FBoardProj.ProjectFilePath) + PathDelim + 'revisions' + PathDelim +
    FBoardProj.ActiveRevision + PathDelim + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
  if not FileExists(Result) then Result := '';
end;

function TMsceneMainForm.SoundRevDir: string;
begin
  Result := '';
  if FSoundProj.ProjectFilePath = '' then Exit;
  Result := ExtractFileDir(FSoundProj.ProjectFilePath) + PathDelim + 'revisions' + PathDelim +
    FSoundProj.ActiveRevision + PathDelim;
end;

function TMsceneMainForm.DraftPath(const RelUri: string): string;
begin
  Result := IncludeTrailingPathDelimiter(MmpDraftDir(FSceneProjectDir)) +
    StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
end;

{ Lê voices/profiles.json do MSound: a ambiência ligada à cena (evento da
  linha do tempo com um perfil de efeito) e a amostra de voz de cada
  personagem (Voices: "Nome=arquivo.wav"). }
procedure TMsceneMainForm.FindSoundForScene(out Ambience: string; Voices: TStrings);
var
  Dir, Content, EntContent, F: string;
  LocIds: TStringList;
  Data: TJSONData;
  Obj, P, E: TJSONObject;
  Profs, Events: TJSONArray;
  I, J: Integer;
begin
  Ambience := '';
  Dir := SoundRevDir;
  if (Dir = '') or not ReadTextFileUtf8(Dir + 'voices' + PathDelim + 'profiles.json', Content) then Exit;
  LocIds := TStringList.Create;
  { locais da cena segundo o índice de entidades do MVisual }
  if (FVisualProj.ProjectFilePath <> '') and ReadTextFileUtf8(ExtractFileDir(FVisualProj.ProjectFilePath) +
    PathDelim + 'revisions' + PathDelim + FVisualProj.ActiveRevision + PathDelim + 'indexes' +
    PathDelim + 'entities.json', EntContent) then
  try
    Data := GetJSON(EntContent);
    try
      if (Data is TJSONObject) and (TJSONObject(Data).Find('entities') is TJSONArray) then
      begin
        Events := TJSONArray(TJSONObject(Data).Find('entities'));
        for I := 0 to Events.Count - 1 do
        begin
          if not (Events.Items[I] is TJSONObject) then Continue;
          E := TJSONObject(Events.Items[I]);
          if (E.Get('kind', '') = 'location') and
            (Pos(',' + LowerCase(FCurrentSceneId) + ',',
              ',' + LowerCase(StringReplace(E.Get('scenes_csv', ''), ' ', '', [rfReplaceAll])) + ',') > 0) then
            LocIds.Add(E.Get('entity_id', ''));
        end;
      end;
    finally
      Data.Free;
    end;
  except
  end;
  try
    Data := GetJSON(Content);
  except
    LocIds.Free;
    Exit;
  end;
  try
    if not (Data is TJSONObject) then Exit;
    Obj := TJSONObject(Data);
    if not (Obj.Find('profiles') is TJSONArray) then Exit;
    Profs := TJSONArray(Obj.Find('profiles'));
    for I := 0 to Profs.Count - 1 do
      if Profs.Items[I] is TJSONObject then
      begin
        P := TJSONObject(Profs.Items[I]);
        F := Dir + StringReplace(P.Get('preview_uri', ''), '/', PathDelim, [rfReplaceAll]);
        if (P.Get('kind', '') = 'voice') and FileExists(F) then
          Voices.Values[LowerCase(P.Get('entity_name', ''))] := F;
      end;
    if Obj.Find('timeline_events') is TJSONArray then
    begin
      Events := TJSONArray(Obj.Find('timeline_events'));
      for I := 0 to Events.Count - 1 do
      begin
        if not (Events.Items[I] is TJSONObject) then Continue;
        E := TJSONObject(Events.Items[I]);
        if not SameText(E.Get('scene_id', ''), FCurrentSceneId) then Continue;
        for J := 0 to Profs.Count - 1 do
        begin
          P := TJSONObject(Profs.Items[J]);
          if (P.Get('asset_id', '') = E.Get('asset_id', '')) and (P.Get('kind', '') = 'effect') then
          begin
            F := Dir + StringReplace(P.Get('preview_uri', ''), '/', PathDelim, [rfReplaceAll]);
            if FileExists(F) then Ambience := F;
          end;
        end;
      end;
    end;
    { sem efeito na linha do tempo: usa o efeito ligado a um local da cena
      (entidades do MVisual com a cena em scenes_csv) }
    if Ambience = '' then
      for I := 0 to Profs.Count - 1 do
      begin
        P := TJSONObject(Profs.Items[I]);
        if (P.Get('kind', '') <> 'effect') or (LocIds.IndexOf(P.Get('entity_id', '')) < 0) then Continue;
        F := Dir + StringReplace(P.Get('preview_uri', ''), '/', PathDelim, [rfReplaceAll]);
        if FileExists(F) then
        begin
          Ambience := F;
          Break;
        end;
      end;
  finally
    Data.Free;
    LocIds.Free;
  end;
end;

procedure TMsceneMainForm.ShowVideoFrame(const Video: string; AtSec: Double);
var
  M: TMmpMedia;
  Png: string;
begin
  if not FileExists(Video) then Exit;
  M := NewMedia;
  try
    { sempre no rascunho: o vídeo pode estar numa revisão publicada (imutável) }
    Png := DraftPath('video/previews/' + ChangeFileExt(ExtractFileName(Video), '') + '_quadro.png');
    ForceDirectories(ExtractFileDir(Png));
    if M.ExtractFrame(Video, AtSec, Png) then
    try
      FPreviewImg.Picture.LoadFromFile(Png);
    except
    end;
  finally
    M.Free;
  end;
end;

{ Retoma o estado da cena a partir do rascunho ou da revisão ativa: vídeos
  já gerados, aprovações e a cena costurada. }
procedure TMsceneMainForm.RestoreSceneState;
var
  I: Integer;
  Meta, Vid, Content: string;
  Data: TJSONData;
begin
  FAssembledRelUri := '';
  FAssembledMetaRelUri := '';
  for I := 0 to High(FSegments) do
  begin
    FSegments[I].MetaRelUri := 'video/segments/' + FCurrentSceneId + '_' + FSegments[I].SegmentId + '.json';
    Meta := MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, FSegments[I].MetaRelUri);
    if (Meta = '') or not ReadTextFileUtf8(Meta, Content) then
    begin
      FSegments[I].MetaRelUri := '';
      Continue;
    end;
    try
      Data := GetJSON(Content);
    except
      Continue;
    end;
    try
      if Data is TJSONObject then
      begin
        Vid := TJSONObject(Data).Get('video_uri', '');
        if (Vid <> '') and (MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, Vid) <> '') then
        begin
          FSegments[I].VideoRelUri := Vid;
          FSegments[I].Status := TJSONObject(Data).Get('status', 'generated');
          FSegments[I].Method := TJSONObject(Data).Get('method', '');
          FSegments[I].RealSec := TJSONObject(Data).Get('real_duration_sec', 0.0);
        end;
      end;
    finally
      Data.Free;
    end;
  end;
  Vid := 'video/assembled/' + FCurrentSceneId + '.mp4';
  if MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, Vid) <> '' then
  begin
    FAssembledRelUri := Vid;
    FAssembledMetaRelUri := 'video/assembled/' + FCurrentSceneId + '_assembled.json';
    ShowVideoFrame(MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, Vid), 1);
  end
  else
    FPreviewImg.Picture.Clear;
end;

procedure TMsceneMainForm.OnGenerateCurrentSceneClick(Sender: TObject);
var
  M: TMmpMedia;
  Voices, Lines: TStringList;
  Ambience, Resp, Err, Wav, RawVid, SegVid, Speaker, LineText, LineWav, Guide: string;
  LineFiles: array of string;
  SegObj: TJSONObject;
  LinesArr: TJSONArray;
  I, K, P, Ok: Integer;
  Total: Double;
  LiveVideo, LiveVoice: Boolean;
begin
  if FCurrentSceneId = '' then Exit;
  M := NewMedia;
  Voices := TStringList.Create;
  Lines := TStringList.Create;
  Screen.Cursor := crHourGlass;
  try
    if not M.Available then
    begin
      MessageDlg('O ffmpeg nao foi encontrado. Indique o caminho em MMenu > Configuracoes > Ferramentas ' +
        '(ou instale o ffmpeg no PATH) para gerar os videos dos sub-blocos.', mtError, [mbOK], 0);
      Exit;
    end;
    { arquivos novos vao para o rascunho do projeto da cena; revisoes publicadas
      sao imutaveis (docs/11, docs/specs/00-comum 5.1) }
    ForceDirectories(DraftPath('video/segments'));
    ForceDirectories(DraftPath('audio/guides'));
    FindSoundForScene(Ambience, Voices);
    LiveVideo := FAi.HasLiveProvider('video');
    LiveVoice := FAi.HasLiveProvider('voice');
    LogMsg(Format('Etapa 1: cena %s, %d sub-blocos | video: %s | voz: %s | ambiencia: %s',
      [FCurrentSceneId, Length(FSegments),
       BoolToStr(LiveVideo, 'IA configurada', 'animatica local'),
       BoolToStr(LiveVoice, 'IA configurada', 'amostras do MSound'),
       BoolToStr(Ambience <> '', ExtractFileName(Ambience), 'nenhuma')]));
    Ok := 0;

    for I := 0 to High(FSegments) do
    begin
      FStatusLabel.Caption := Format('Gerando sub-bloco %d de %d...', [I + 1, Length(FSegments)]);
      Application.ProcessMessages;

      if FAi.IsConfigured and LiveVideo and (I = 0) then
      begin
        if FAi.Ask('Gere instrucao de direcao visual para geracao de video deste segmento.',
          FSegments[I].PromptText, Resp, Err) then
          FSegments[I].PromptText := Resp;
      end;

      { falas: voz sintetizada (IA real) ou amostra da voz do personagem como guia }
      Lines.Text := FSegments[I].Dialogue;
      SetLength(LineFiles, 0);
      LinesArr := TJSONArray.Create;
      for K := 0 to Lines.Count - 1 do
      begin
        LineText := Trim(Lines[K]);
        if LineText = '' then Continue;
        P := Pos(':', LineText);
        if P > 0 then
        begin
          Speaker := Trim(Copy(LineText, 1, P - 1));
          LineText := Trim(Copy(LineText, P + 1, MaxInt));
        end
        else Speaker := '';
        LineWav := '';
        Guide := 'sem_audio';
        if LiveVoice then
        begin
          LineWav := DraftPath(Format('audio/guides/%s_%s_%d.wav', [FCurrentSceneId, FSegments[I].SegmentId, K + 1]));
          if FAi.SynthesizeSpeech(LineText, LineWav, Err) and FileExists(LineWav) then
            Guide := 'voz_sintetizada'
          else
          begin
            LogMsg('Voz nao sintetizada (' + Speaker + '): ' + Err);
            LineWav := '';
          end;
        end;
        if (LineWav = '') and (Voices.Values[LowerCase(Speaker)] <> '') then
        begin
          LineWav := Voices.Values[LowerCase(Speaker)];
          Guide := 'amostra_msound';
        end;
        if LineWav <> '' then
        begin
          SetLength(LineFiles, Length(LineFiles) + 1);
          LineFiles[High(LineFiles)] := LineWav;
        end;
        LinesArr.Add(TJSONObject.Create(['speaker', Speaker, 'text', LineText, 'audio', Guide]));
      end;

      Wav := DraftPath(Format('audio/guides/%s_%s.wav', [FCurrentSceneId, FSegments[I].SegmentId]));
      if not M.MakeSegmentAudio(LineFiles, Ambience, FSegments[I].DurationSec, Wav, Total, Err) then
      begin
        LogMsg('Audio do sub-bloco ' + FSegments[I].SegmentId + ' falhou: ' + Err);
        Wav := '';
        Total := FSegments[I].DurationSec;
      end;

      FSegments[I].VideoRelUri := 'video/segments/' + FCurrentSceneId + '_' + FSegments[I].SegmentId + '.mp4';
      FSegments[I].MetaRelUri := 'video/segments/' + FCurrentSceneId + '_' + FSegments[I].SegmentId + '.json';
      SegVid := DraftPath(FSegments[I].VideoRelUri);
      FSegments[I].Method := '';

      if LiveVideo then
      begin
        RawVid := ChangeFileExt(SegVid, '') + '_ia.mp4';
        if FAi.GenerateVideo(FSegments[I].PromptText, RawVid, Err, BoardFile(FSegments[I].OpeningUri),
          '', Max(1, Round(Total))) and FileExists(RawVid) and
          M.MuxAudio(RawVid, Wav, Total, SegVid, Err) then
          FSegments[I].Method := 'ia_video'
        else
          LogMsg('IA de video falhou no sub-bloco ' + FSegments[I].SegmentId +
            '; usando animatica local. ' + Err);
        DeleteFile(RawVid);
      end;
      if FSegments[I].Method = '' then
      begin
        if M.RenderAnimatic(BoardFile(FSegments[I].OpeningUri), BoardFile(FSegments[I].ClosingUri),
          Wav, Total, SegVid, Err) then
          FSegments[I].Method := 'animatica_local'
        else
        begin
          LogMsg('Falha ao gerar o sub-bloco ' + FSegments[I].SegmentId + ': ' + Err);
          FSegments[I].VideoRelUri := '';
          FSegments[I].Status := 'pending';
          LinesArr.Free;
          Continue;
        end;
      end;

      FSegments[I].RealSec := M.Duration(SegVid);
      FSegments[I].Status := 'generated';
      Inc(Ok);

      SegObj := TJSONObject.Create;
      try
        SegObj.Add('schema', 'mmp.mscene.segment/1');
        SegObj.Add('scene_id', FCurrentSceneId);
        SegObj.Add('segment_id', FSegments[I].SegmentId);
        SegObj.Add('order', FSegments[I].OrderIdx);
        SegObj.Add('duration_sec', FSegments[I].DurationSec);
        SegObj.Add('real_duration_sec', FSegments[I].RealSec);
        SegObj.Add('prompt', FSegments[I].PromptText);
        SegObj.Add('method', FSegments[I].Method);
        SegObj.Add('video_uri', FSegments[I].VideoRelUri);
        SegObj.Add('opening_uri', FSegments[I].OpeningUri);
        SegObj.Add('closing_uri', FSegments[I].ClosingUri);
        SegObj.Add('board_revision', FBoardProj.ActiveRevision);
        SegObj.Add('sound_revision', FSoundProj.ActiveRevision);
        SegObj.Add('ambience', ExtractFileName(Ambience));
        SegObj.Add('lines', LinesArr);
        LinesArr := nil;
        SegObj.Add('status', 'generated');
        SegObj.Add('generated_at', CurrentIsoUtc);
        AtomicWriteTextFile(DraftPath(FSegments[I].MetaRelUri), SegObj.FormatJSON, False);
      finally
        SegObj.Free;
        LinesArr.Free;
      end;
      RefreshSegmentsGrid;
      if Ok = 1 then ShowVideoFrame(SegVid, Min(1, FSegments[I].RealSec / 2));
      Application.ProcessMessages;
    end;

    { a costura antiga deixou de valer }
    FAssembledRelUri := '';
    FAssembledMetaRelUri := '';
    RefreshSegmentsGrid;
    LogMsg(Format('Etapa 1: %d de %d sub-blocos com video para a cena %s (sem lote automatico). ' +
      'Assista, aprove e costure a cena.', [Ok, Length(FSegments), FCurrentSceneId]));
  finally
    Screen.Cursor := crDefault;
    Lines.Free;
    Voices.Free;
    M.Free;
  end;
end;

procedure TMsceneMainForm.OnApproveSegmentClick(Sender: TObject);
var
  Idx: Integer;
  Meta, Content: string;
  Data: TJSONData;
begin
  Idx := FSegmentsGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FSegments)) then Exit;
  if FSegments[Idx].VideoRelUri = '' then
  begin
    MessageDlg('Gere o video deste sub-bloco antes de aprovar.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FSegments[Idx].Status := 'approved';
  { grava a aprovação nos metadados do rascunho }
  Meta := MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, FSegments[Idx].MetaRelUri);
  if (Meta <> '') and ReadTextFileUtf8(Meta, Content) then
  begin
    Data := GetJSON(Content);
    try
      if Data is TJSONObject then
      begin
        TJSONObject(Data).Strings['status'] := 'approved';
        AtomicWriteTextFile(DraftPath(FSegments[Idx].MetaRelUri), Data.FormatJSON, False);
      end;
    finally
      Data.Free;
    end;
  end;
  RefreshSegmentsGrid;
  LogMsg('Sub-bloco ' + FSegments[Idx].SegmentId + ' aprovado.');
end;

procedure TMsceneMainForm.OnWatchSegmentClick(Sender: TObject);
var
  Idx: Integer;
  F: string;
begin
  Idx := FSegmentsGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FSegments)) then Exit;
  F := MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, FSegments[Idx].VideoRelUri);
  if F = '' then
  begin
    MessageDlg('Este sub-bloco ainda nao tem video. Use a Etapa 1.', mtInformation, [mbOK], 0);
    Exit;
  end;
  ShowVideoFrame(F, Min(1, FSegments[Idx].RealSec / 2));
  if not MmpOpenMedia(F, FAi.Settings.ToolMpv) then
    LogMsg('Nao foi possivel abrir o reprodutor para ' + F);
end;

procedure TMsceneMainForm.OnWatchSceneClick(Sender: TObject);
var F: string;
begin
  F := MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, FAssembledRelUri);
  if F = '' then
  begin
    MessageDlg('A cena ainda nao foi costurada. Use a Etapa 2b.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not MmpOpenMedia(F, FAi.Settings.ToolMpv) then
    LogMsg('Nao foi possivel abrir o reprodutor para ' + F);
end;

procedure TMsceneMainForm.OnAssembleSceneClick(Sender: TObject);
var
  I: Integer;
  M: TMmpMedia;
  Files: array of string;
  OutF, Err: string;
  Obj: TJSONObject;
  Arr: TJSONArray;
  Dur: Double;
begin
  if Length(FSegments) = 0 then Exit;
  SetLength(Files, Length(FSegments));
  for I := 0 to High(FSegments) do
  begin
    Files[I] := MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, FSegments[I].VideoRelUri);
    if (FSegments[I].Status = 'pending') or (Files[I] = '') then
    begin
      MessageDlg('Gere e valide todos os sub-blocos antes de costurar a cena.', mtWarning, [mbOK], 0);
      Exit;
    end;
  end;
  for I := 0 to High(FSegments) do
    if FSegments[I].Status <> 'approved' then
    begin
      if MessageDlg('Ha sub-blocos ainda nao aprovados. Costurar mesmo assim?', mtConfirmation,
        [mbYes, mbNo], 0) <> mrYes then Exit;
      Break;
    end;

  M := NewMedia;
  Screen.Cursor := crHourGlass;
  try
    FStatusLabel.Caption := 'Costurando a cena...';
    Application.ProcessMessages;
    FAssembledRelUri := 'video/assembled/' + FCurrentSceneId + '.mp4';
    FAssembledMetaRelUri := 'video/assembled/' + FCurrentSceneId + '_assembled.json';
    OutF := DraftPath(FAssembledRelUri);
    if not M.Concat(Files, OutF, Err) then
    begin
      FAssembledRelUri := '';
      FAssembledMetaRelUri := '';
      LogMsg('Falha ao costurar a cena: ' + Err);
      MessageDlg('Falha ao costurar a cena. Veja o log operacional.', mtError, [mbOK], 0);
      Exit;
    end;
    Dur := M.Duration(OutF);

    Obj := TJSONObject.Create;
    try
      Obj.Add('schema', 'mmp.mscene.assembled/1');
      Obj.Add('scene_id', FCurrentSceneId);
      Obj.Add('heading', FCurrentSceneHeading);
      Obj.Add('video_uri', FAssembledRelUri);
      Obj.Add('duration_sec', Dur);
      Arr := TJSONArray.Create;
      for I := 0 to High(FSegments) do
        Arr.Add(FSegments[I].SegmentId);
      Obj.Add('segment_order', Arr);
      Obj.Add('prev_link', FPrevSceneLinkStatus);
      Obj.Add('next_link', FNextSceneLinkStatus);
      Obj.Add('assembled_at', CurrentIsoUtc);
      AtomicWriteTextFile(DraftPath(FAssembledMetaRelUri), Obj.FormatJSON, False);
    finally
      Obj.Free;
    end;
    ShowVideoFrame(OutF, Min(1, Dur / 2));
    LogMsg(Format('Etapa 2: cena %s costurada em %s (%.1f s).', [FCurrentSceneId, FAssembledRelUri, Dur]));
  finally
    Screen.Cursor := crDefault;
    M.Free;
  end;
end;

{ Vídeo costurado de outra cena: rascunho ou revisão ativa do projeto dela. }
function TMsceneMainForm.SceneVideoFile(const SceneId: string): string;
var
  Dir, Content, Rev: string;
  Data: TJSONData;
begin
  Result := '';
  if SameText(SceneId, FCurrentSceneId) then
    Exit(MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, FAssembledRelUri));
  Dir := IncludeTrailingPathDelimiter(FProjectDir) + 'scenes' + PathDelim + SceneId;
  Rev := '';
  if ReadTextFileUtf8(Dir + PathDelim + 'project.json', Content) then
  begin
    Data := GetJSON(Content);
    try
      if Data is TJSONObject then Rev := TJSONObject(Data).Get('active_revision', '');
    finally
      Data.Free;
    end;
  end;
  Result := MmpResolveDraftOrRevisionFile(Dir, Rev, 'video/assembled/' + SceneId + '.mp4');
end;

procedure TMsceneMainForm.WatchLink(ToPrevious: Boolean);
const Window = 4.0;
var
  OtherIdx: Integer;
  OtherId, A, B, OutF, Err: string;
  M: TMmpMedia;
  Clips: array of TMmpClip;
  DA: Double;
begin
  if ToPrevious then OtherIdx := FSceneCombo.ItemIndex - 1 else OtherIdx := FSceneCombo.ItemIndex + 1;
  if (OtherIdx < 0) or (OtherIdx >= FSceneCombo.Items.Count) then
  begin
    MessageDlg('Nao ha cena ' + BoolToStr(ToPrevious, 'anterior', 'seguinte') + '.', mtInformation, [mbOK], 0);
    Exit;
  end;
  OtherId := FSceneCombo.Items[OtherIdx];
  if Pos(' | ', OtherId) > 0 then OtherId := Copy(OtherId, 1, Pos(' | ', OtherId) - 1);
  if ToPrevious then
  begin
    A := SceneVideoFile(OtherId);
    B := SceneVideoFile(FCurrentSceneId);
  end
  else
  begin
    A := SceneVideoFile(FCurrentSceneId);
    B := SceneVideoFile(OtherId);
  end;
  if (A = '') or (B = '') then
  begin
    MessageDlg('As duas cenas precisam estar costuradas para ver a ligacao (cena ' + OtherId +
      ' ou a atual ainda sem video).', mtInformation, [mbOK], 0);
    Exit;
  end;
  M := NewMedia;
  Screen.Cursor := crHourGlass;
  try
    DA := M.Duration(A);
    SetLength(Clips, 2);
    Clips[0].FileName := A; Clips[0].InSec := Max(0, DA - Window); Clips[0].OutSec := 0;
    Clips[0].Transition := 'cut'; Clips[0].TransitionSec := 0;
    Clips[1].FileName := B; Clips[1].InSec := 0; Clips[1].OutSec := Window;
    Clips[1].Transition := 'cut'; Clips[1].TransitionSec := 0;
    OutF := DraftPath('video/previews/ligacao_' + BoolToStr(ToPrevious, 'anterior', 'proxima') + '.mp4');
    if M.RenderTimeline(Clips, OutF, Err) then
    begin
      LogMsg('Previa da ligacao montada: ' + OutF);
      MmpOpenMedia(OutF, FAi.Settings.ToolMpv);
    end
    else
      LogMsg('Falha ao montar a previa da ligacao: ' + Err);
  finally
    Screen.Cursor := crDefault;
    M.Free;
  end;
end;

procedure TMsceneMainForm.OnWatchPrevLinkClick(Sender: TObject);
begin
  WatchLink(True);
end;

procedure TMsceneMainForm.OnWatchNextLinkClick(Sender: TObject);
begin
  WatchLink(False);
end;

procedure TMsceneMainForm.CopyRelToRevision(const RelUri, RevDir: string);
var
  SrcF, DstF: string;
  FS1, FS2: TFileStream;
begin
  if RelUri = '' then Exit;
  SrcF := MmpResolveDraftOrRevisionFile(FSceneProjectDir, FSceneRevId, RelUri);
  DstF := IncludeTrailingPathDelimiter(RevDir) + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
  if (SrcF = '') or SameText(SrcF, DstF) then Exit;
  ForceDirectories(ExtractFileDir(DstF));
  FS1 := TFileStream.Create(SrcF, fmOpenRead or fmShareDenyNone);
  try
    FS2 := TFileStream.Create(DstF, fmCreate);
    try FS2.CopyFrom(FS1, 0); finally FS2.Free; end;
  finally
    FS1.Free;
  end;
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
  SceneProjPath, PrepRev, RevDir, NewRev, ErrMsg, FinalState, OldRevDir: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, ArtN: Integer;
begin
  if not FProd.Loaded or (FCurrentSceneId = '') then Exit;
  SceneProjPath := FSceneProjectDir + PathDelim + 'project.json';
  if not PrepareNextRevisionDir(SceneProjPath, PrepRev, RevDir) then Exit;
  OldRevDir := FSceneProjectDir + PathDelim + 'revisions' + PathDelim + FSceneRevId;

  SetLength(Arts, 0);
  for I := 0 to High(FSegments) do
  begin
    if FSegments[I].VideoRelUri = '' then Continue;
    CopyRelToRevision(FSegments[I].VideoRelUri, RevDir);
    CopyRelToRevision(FSegments[I].MetaRelUri, RevDir);
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
    CopyRelToRevision(FAssembledRelUri, RevDir);
    CopyRelToRevision(FAssembledMetaRelUri, RevDir);
    ArtN := Length(Arts);
    SetLength(Arts, ArtN + 1);
    Arts[ArtN].ArtifactId := GenerateMmpId('a');
    Arts[ArtN].Kind := 'video.scene';
    Arts[ArtN].SceneId := FCurrentSceneId;
    Arts[ArtN].RelUri := FAssembledRelUri;
    Arts[ArtN].MimeType := 'video/mp4';
    Arts[ArtN].Status := 'approved';
  end;

  SetLength(Srcs, 4);
  Srcs[0].ResolvedApp := 'MScript';
  Srcs[1].ResolvedApp := 'MVisual';
  Srcs[2].ResolvedApp := 'MBoard';
  Srcs[3].ResolvedApp := 'MSound';
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
    MmpClearDraftDir(FSceneProjectDir);
    LogMsg('Projeto da cena ' + FCurrentSceneId + ' salvo na revisao ' + NewRev + ' [' + FinalState + ']');
  end
  else
  begin
    MmpDiscardUnpublishedRevisionDir(RevDir);
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
  end;
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
