unit umcutmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser, aih264decoder,
  ummpprotocol, ummpappbase, ummpaibridge, ummpvideo, ummpsha256, LCLIntf;

type
  TTimelineClip = record
    OrderIdx: Integer;
    SceneId: string;
    Heading: string;
    SceneRevision: string;
    InPointSec: Integer;
    OutPointSec: Integer;
    TransitionOut: string; // cut | fade_out | dissolve
    TransitionSec: Integer;
    SceneStatus: string; // ok | missing_scene | pending_approval
  end;

  TAudienceRating = record
    FeedbackId: string;
    SessionId: string;
    FilmRevision: string;
    SceneId: string;
    Participant: string;
    Score: Integer;
    Comment: string;
    CreatedAt: string;
  end;

  TMcutMainForm = class(TForm)
  private
    FAi: TMmpAiBridge;
    FDecoder: TAIH264Decoder;
    FProd: TMmpProduction;
    FProj, FScriptProj: TMmpProjectRef;
    FProjectDir: string;
    FCurrentRevId, FTimelineScriptRev: string;
    FClips: array of TTimelineClip;
    FRatings: array of TAudienceRating;
    FCurrentSessionId: string;

    FHeaderProdLabel: TLabel;
    FHeaderRevLabel: TLabel;
    FTimelineGrid: TStringGrid;
    FInEdit: TEdit;
    FOutEdit: TEdit;
    FTransCombo: TComboBox;
    FRatingsGrid: TStringGrid;
    FAnalysisMemo: TMemo;
    FExportFormatCombo: TComboBox;
    FLogMemo: TMemo;
    FStatusLabel: TLabel;

    procedure BuildUI;
    procedure LogMsg(const Msg: string);
    procedure LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
    procedure LoadCutFromRevision(const RevId: string);
    procedure RefreshTimelineGrid;
    procedure RefreshRatingsGrid;
    procedure RunAudienceAnalysis(IncludeAi: Boolean = True);
    function TimelineToJson: string;
    function ResolveSceneVideo(const Clip: TTimelineClip; VerifyHash: Boolean;
      out VideoFile: string; out Source: TMmpSourceRef): Boolean;
    function RatingsToJson: string;
    function AnalysisToJson: string;

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnBuildTimelineClick(Sender: TObject);
    procedure OnApplyClipCutClick(Sender: TObject);
    procedure OnTimelineSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnAddFeedbackClick(Sender: TObject);
    procedure OnAnalyzeFeedbackClick(Sender: TObject);
    procedure OnRequestSceneCorrectionClick(Sender: TObject);
    procedure OnSaveAndExportClick(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mcutMainForm: TMcutMainForm;

implementation

constructor TMcutMainForm.Create(TheOwner: TComponent);
var
  ProdRoot, ProjId, RevId, MMenuVer, ProdId: string;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MCut - Montagem Final, Publico e Exportacao (MaurinMovie)';
  Width := 1220;
  Height := 760;
  Position := poScreenCenter;
  Constraints.MinWidth := 940;
  Constraints.MinHeight := 620;

  FAi := TMmpAiBridge.Create('MCut');
  FDecoder := TAIH264Decoder.Create(Self);
  FCurrentSessionId := GenerateMmpId('sess');
  BuildUI;

  ParseAppLaunchContext(ProdRoot, ProjId, RevId, MMenuVer, ProdId);
  LogMsg('MCut v' + MMP_EXECUTABLE_VERSION + ' iniciado (openai_core + openai_video) | MMenu v' +
    MMenuVer + ' | Projeto: ' + ProjId);
  if ProdRoot <> '' then
    LoadProductionAndRevision(ProdRoot, ProjId, RevId);
end;

destructor TMcutMainForm.Destroy;
begin
  FDecoder.Stop;
  FAi.Free;
  inherited Destroy;
end;

procedure TMcutMainForm.BuildUI;
var
  Head, Sidebar, Bottom, ClipEditBar, FeedBar: TPanel;
  PC: TPageControl;
  TabTimeline, TabFeedback, TabAnalysis, TabLog: TTabSheet;
  BtnOpen, BtnAiCfg, BtnBuildTL, BtnApplyCut, BtnAddRate, BtnAnalyze, BtnCorr, BtnExport: TButton;
  L: TLabel;
begin
  Head := TPanel.Create(Self); Head.Parent := Self; Head.Align := alTop; Head.Height := 68;
  Head.BevelOuter := bvNone; Head.Color := $003A3028; Head.ParentBackground := False;

  L := TLabel.Create(Self); L.Parent := Head; L.Caption := 'MaurinMovie  |  6 - MCut';
  L.Font.Size := 16; L.Font.Style := [fsBold]; L.Font.Color := clWhite; L.SetBounds(16, 10, 320, 26);

  FHeaderProdLabel := TLabel.Create(Self); FHeaderProdLabel.Parent := Head;
  FHeaderProdLabel.Caption := 'Nenhuma producao carregada'; FHeaderProdLabel.Font.Color := clWhite;
  FHeaderProdLabel.Font.Style := [fsBold]; FHeaderProdLabel.SetBounds(340, 12, 460, 20);

  FHeaderRevLabel := TLabel.Create(Self); FHeaderRevLabel.Parent := Head;
  FHeaderRevLabel.Caption := 'Revisao Filme: -'; FHeaderRevLabel.Font.Color := $0099E6FF;
  FHeaderRevLabel.SetBounds(340, 36, 460, 18);

  BtnAiCfg := TButton.Create(Self); BtnAiCfg.Parent := Head; BtnAiCfg.Caption := 'Alterar no MMenu...';
  BtnAiCfg.Anchors := [akTop, akRight]; BtnAiCfg.SetBounds(1082, 17, 122, 34);
  BtnAiCfg.OnClick := @OnAiConfigClick;

  BtnExport := TButton.Create(Self); BtnExport.Parent := Head; BtnExport.Caption := 'Salvar e Exportar Filme';
  BtnExport.Anchors := [akTop, akRight]; BtnExport.SetBounds(900, 17, 174, 34);
  BtnExport.OnClick := @OnSaveAndExportClick;

  Bottom := TPanel.Create(Self); Bottom.Parent := Self; Bottom.Align := alBottom; Bottom.Height := 34;
  Bottom.BevelOuter := bvLowered;
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Bottom; FStatusLabel.SetBounds(12, 9, 1100, 18);
  FStatusLabel.Caption := 'Pronto.';

  Sidebar := TPanel.Create(Self); Sidebar.Parent := Self; Sidebar.Align := alLeft; Sidebar.Width := 255;
  Sidebar.BevelOuter := bvNone; Sidebar.Color := $00EFEFEF; Sidebar.ParentBackground := False;

  BtnOpen := TButton.Create(Self); BtnOpen.Parent := Sidebar; BtnOpen.Caption := 'Abrir producao...';
  BtnOpen.SetBounds(12, 14, 231, 34); BtnOpen.OnClick := @OnOpenProdClick;

  BtnBuildTL := TButton.Create(Self); BtnBuildTL.Parent := Sidebar; BtnBuildTL.Caption := 'Etapa 1: Montar Ordem Narrativa';
  BtnBuildTL.SetBounds(12, 58, 231, 34); BtnBuildTL.OnClick := @OnBuildTimelineClick;

  L := TLabel.Create(Self); L.Parent := Sidebar; L.Caption := 'Formato de exportacao (Etapa 5):';
  L.Font.Style := [fsBold]; L.SetBounds(12, 108, 231, 18);

  FExportFormatCombo := TComboBox.Create(Self); FExportFormatCombo.Parent := Sidebar;
  FExportFormatCombo.Style := csDropDownList;
  FExportFormatCombo.Items.Add('MP4 (H.264 / AAC) VGA 480p');
  FExportFormatCombo.Items.Add('MP4 (H.264 / AAC) HD 720p');
  FExportFormatCombo.Items.Add('MP4 (H.264 / AAC) Full HD 1080p');
  FExportFormatCombo.Items.Add('MP4 (H.264 / AAC) 2K 1440p');
  FExportFormatCombo.Items.Add('MP4 (H.264 / AAC) 4K 2160p');
  FExportFormatCombo.Items.Add('MP4 (H.264 / AAC) 8K 4320p');
  FExportFormatCombo.Items.Add('MKV (Lossless / Master)');
  FExportFormatCombo.ItemIndex := 2;
  FExportFormatCombo.SetBounds(12, 130, 231, 26);

  BtnCorr := TButton.Create(Self); BtnCorr.Parent := Sidebar; BtnCorr.Caption := 'Etapa 4: Solicitar Correcao (MScene)';
  BtnCorr.SetBounds(12, 170, 231, 34); BtnCorr.OnClick := @OnRequestSceneCorrectionClick;

  PC := TPageControl.Create(Self); PC.Parent := Self; PC.Align := alClient;
  TabTimeline := TTabSheet.Create(PC); TabTimeline.PageControl := PC; TabTimeline.Caption := 'Etapa 1 & 2: Timeline & Transicoes';
  TabFeedback := TTabSheet.Create(PC); TabFeedback.PageControl := PC; TabFeedback.Caption := 'Etapa 3: Sessoes de Publico';
  TabAnalysis := TTabSheet.Create(PC); TabAnalysis.PageControl := PC; TabAnalysis.Caption := 'Etapa 4: Analise & Evidencias';
  TabLog := TTabSheet.Create(PC); TabLog.PageControl := PC; TabLog.Caption := 'Log Operacional';

  ClipEditBar := TPanel.Create(Self); ClipEditBar.Parent := TabTimeline; ClipEditBar.Align := alBottom;
  ClipEditBar.Height := 58; ClipEditBar.BevelOuter := bvLowered;

  L := TLabel.Create(Self); L.Parent := ClipEditBar; L.Caption := 'In (s):'; L.SetBounds(12, 18, 45, 18);
  FInEdit := TEdit.Create(Self); FInEdit.Parent := ClipEditBar; FInEdit.SetBounds(58, 14, 60, 24);
  L := TLabel.Create(Self); L.Parent := ClipEditBar; L.Caption := 'Out (s):'; L.SetBounds(130, 18, 52, 18);
  FOutEdit := TEdit.Create(Self); FOutEdit.Parent := ClipEditBar; FOutEdit.SetBounds(184, 14, 60, 24);
  L := TLabel.Create(Self); L.Parent := ClipEditBar; L.Caption := 'Transicao:'; L.SetBounds(256, 18, 70, 18);
  FTransCombo := TComboBox.Create(Self); FTransCombo.Parent := ClipEditBar; FTransCombo.Style := csDropDownList;
  FTransCombo.Items.Add('cut'); FTransCombo.Items.Add('fade_out'); FTransCombo.Items.Add('dissolve');
  FTransCombo.ItemIndex := 0; FTransCombo.SetBounds(328, 14, 115, 26);

  BtnApplyCut := TButton.Create(Self); BtnApplyCut.Parent := ClipEditBar; BtnApplyCut.Caption := 'Aplicar Corte / Transicao';
  BtnApplyCut.SetBounds(458, 12, 195, 30); BtnApplyCut.OnClick := @OnApplyClipCutClick;

  FTimelineGrid := TStringGrid.Create(Self); FTimelineGrid.Parent := TabTimeline; FTimelineGrid.Align := alClient;
  FTimelineGrid.FixedCols := 0; FTimelineGrid.FixedRows := 1; FTimelineGrid.ColCount := 8; FTimelineGrid.RowCount := 2;
  FTimelineGrid.Options := FTimelineGrid.Options + [goRowSelect, goColSizing];
  FTimelineGrid.Cells[0, 0] := 'Ordem'; FTimelineGrid.Cells[1, 0] := 'Cena ID';
  FTimelineGrid.Cells[2, 0] := 'Cabecalho'; FTimelineGrid.Cells[3, 0] := 'Rev MScene';
  FTimelineGrid.Cells[4, 0] := 'In (s)'; FTimelineGrid.Cells[5, 0] := 'Out (s)';
  FTimelineGrid.Cells[6, 0] := 'Transicao'; FTimelineGrid.Cells[7, 0] := 'Status';
  FTimelineGrid.ColWidths[0] := 55; FTimelineGrid.ColWidths[1] := 115; FTimelineGrid.ColWidths[2] := 230;
  FTimelineGrid.ColWidths[3] := 85; FTimelineGrid.ColWidths[4] := 60; FTimelineGrid.ColWidths[5] := 60;
  FTimelineGrid.ColWidths[6] := 90; FTimelineGrid.ColWidths[7] := 150;
  FTimelineGrid.OnSelection := @OnTimelineSelection;

  FeedBar := TPanel.Create(Self); FeedBar.Parent := TabFeedback; FeedBar.Align := alTop;
  FeedBar.Height := 46; FeedBar.BevelOuter := bvNone;
  BtnAddRate := TButton.Create(Self); BtnAddRate.Parent := FeedBar; BtnAddRate.Caption := '+ Registrar Avaliacao de Cena...';
  BtnAddRate.SetBounds(12, 8, 250, 30); BtnAddRate.OnClick := @OnAddFeedbackClick;
  BtnAnalyze := TButton.Create(Self); BtnAnalyze.Parent := FeedBar; BtnAnalyze.Caption := 'Consolidar Analise (Etapa 4)';
  BtnAnalyze.SetBounds(274, 8, 230, 30); BtnAnalyze.OnClick := @OnAnalyzeFeedbackClick;

  FRatingsGrid := TStringGrid.Create(Self); FRatingsGrid.Parent := TabFeedback; FRatingsGrid.Align := alClient;
  FRatingsGrid.FixedCols := 0; FRatingsGrid.FixedRows := 1; FRatingsGrid.ColCount := 6; FRatingsGrid.RowCount := 2;
  FRatingsGrid.Options := FRatingsGrid.Options + [goRowSelect, goColSizing];
  FRatingsGrid.Cells[0, 0] := 'Sessao'; FRatingsGrid.Cells[1, 0] := 'Revisao Filme';
  FRatingsGrid.Cells[2, 0] := 'Cena ID'; FRatingsGrid.Cells[3, 0] := 'Participante';
  FRatingsGrid.Cells[4, 0] := 'Nota'; FRatingsGrid.Cells[5, 0] := 'Comentario';
  FRatingsGrid.ColWidths[0] := 120; FRatingsGrid.ColWidths[1] := 95; FRatingsGrid.ColWidths[2] := 115;
  FRatingsGrid.ColWidths[3] := 120; FRatingsGrid.ColWidths[4] := 55; FRatingsGrid.ColWidths[5] := 350;

  FAnalysisMemo := TMemo.Create(Self); FAnalysisMemo.Parent := TabAnalysis; FAnalysisMemo.Align := alClient;
  FAnalysisMemo.ReadOnly := True; FAnalysisMemo.ScrollBars := ssBoth;

  FLogMemo := TMemo.Create(Self); FLogMemo.Parent := TabLog; FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True; FLogMemo.ScrollBars := ssBoth;
end;

procedure TMcutMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
  if FProd.Loaded then
    MmpLogAppOperation(FProd.RootDir, FProd.ProductionId, 'MCut', Msg, FCurrentRevId);
end;

procedure TMcutMainForm.LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
var
  ErrMsg: string;
begin
  if not ResolveAppProject(ProdRoot, 6, ProjId, RevId, FProd, FProj,
    FProjectDir, FCurrentRevId, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  FAi.LoadForProduction(FProd.RootDir);
  FindProjectByApp(FProd, 1, FScriptProj);
  FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
  FHeaderRevLabel.Caption := 'Revisao Filme: ' + FCurrentRevId + '  |  Roteiro: ' + FScriptProj.ActiveRevision;
  LoadCutFromRevision(FCurrentRevId);
  RefreshTimelineGrid;
  RefreshRatingsGrid;
  LogMsg('Producao carregada em MCut.');
end;

procedure TMcutMainForm.LoadCutFromRevision(const RevId: string);
var
  TLPath, RatePath, Content: string;
  Data: TJSONData;
  Obj, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  SetLength(FClips, 0);
  SetLength(FRatings, 0);
  FTimelineScriptRev := FScriptProj.ActiveRevision;

  TLPath := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
    RevId + PathDelim + 'timeline' + PathDelim + 'timeline.json';
  if FileExists(TLPath) and ReadTextFileUtf8(TLPath, Content) then
  begin
    Data := GetJSON(Content);
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      try
        FTimelineScriptRev := Obj.Get('script_revision', FScriptProj.ActiveRevision);
        if Obj.Find('timeline_items') is TJSONArray then
        begin
          Arr := TJSONArray(Obj.Find('timeline_items'));
          SetLength(FClips, Arr.Count);
          for I := 0 to Arr.Count - 1 do
          begin
            Item := TJSONObject(Arr.Items[I]);
            FClips[I].OrderIdx := Item.Get('order', I + 1);
            FClips[I].SceneId := Item.Get('scene_id', '');
            FClips[I].Heading := Item.Get('heading', '');
            FClips[I].SceneRevision := Item.Get('scene_video_revision_id', '');
            FClips[I].InPointSec := Item.Get('in_point', 0);
            FClips[I].OutPointSec := Item.Get('out_point', 30);
            FClips[I].TransitionOut := Item.Get('transition_out', 'cut');
            FClips[I].TransitionSec := Item.Get('transition_sec', 1);
            FClips[I].SceneStatus := Item.Get('status', 'ok');
          end;
        end;
      finally
        Obj.Free;
      end;
    end
    else Data.Free;
  end;

  RatePath := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
    RevId + PathDelim + 'feedback' + PathDelim + 'ratings.json';
  if FileExists(RatePath) and ReadTextFileUtf8(RatePath, Content) then
  begin
    Data := GetJSON(Content);
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      try
        if Obj.Find('feedback') is TJSONArray then
        begin
          Arr := TJSONArray(Obj.Find('feedback'));
          SetLength(FRatings, Arr.Count);
          for I := 0 to Arr.Count - 1 do
          begin
            Item := TJSONObject(Arr.Items[I]);
            FRatings[I].FeedbackId := Item.Get('feedback_id', '');
            FRatings[I].SessionId := Item.Get('session_id', '');
            FRatings[I].FilmRevision := Item.Get('revision_id', '');
            FRatings[I].SceneId := Item.Get('scene_id', '');
            FRatings[I].Participant := Item.Get('participant', 'anonimo');
            FRatings[I].Score := Item.Get('rating', 5);
            FRatings[I].Comment := Item.Get('comment', '');
            FRatings[I].CreatedAt := Item.Get('timestamp', '');
          end;
        end;
      finally
        Obj.Free;
      end;
    end
    else Data.Free;
  end;
end;

procedure TMcutMainForm.OnBuildTimelineClick(Sender: TObject);
var
  ScriptPath, Content, SId, VideoFile: string;
  Source: TMmpSourceRef;
  Data: TJSONData;
  Obj, SItem: TJSONObject;
  Arr: TJSONArray;
  I, J: Integer;
  FoundSceneProj: Boolean;
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
    if not (Obj.Find('scenes') is TJSONArray) then Exit;
    Arr := TJSONArray(Obj.Find('scenes'));
    FTimelineScriptRev := FScriptProj.ActiveRevision;
    SetLength(FClips, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      SItem := TJSONObject(Arr.Items[I]);
      SId := SItem.Get('scene_id', '');
      FClips[I].OrderIdx := I + 1;
      FClips[I].SceneId := SId;
      FClips[I].Heading := SItem.Get('heading', '');
      FClips[I].InPointSec := 0;
      FClips[I].OutPointSec := 0;
      FClips[I].TransitionOut := 'cut';
      FClips[I].TransitionSec := 1;

      FoundSceneProj := False;
      FClips[I].SceneRevision := '-';
      FClips[I].SceneStatus := 'missing_scene';
      for J := 0 to High(FProd.Projects) do
      begin
        if (FProd.Projects[J].SoftwareIndex = 5) and SameText(FProd.Projects[J].SceneId, SId) then
        begin
          FoundSceneProj := True;
          FClips[I].SceneRevision := FProd.Projects[J].ActiveRevision;
          if ResolveSceneVideo(FClips[I], False, VideoFile, Source) then
            FClips[I].SceneStatus := 'ok'
          else
            FClips[I].SceneStatus := 'pending_approval';
          Break;
        end;
      end;
      if not FoundSceneProj then
        LogMsg('PENDENCIA: Cena ' + SId + ' ainda nao foi finalizada no MScene.');
    end;
  finally
    Obj.Free;
  end;

  RefreshTimelineGrid;
  LogMsg('Timeline montada na ordem narrativa do roteiro (' + IntToStr(Length(FClips)) + ' cenas).');
end;

function TMcutMainForm.ResolveSceneVideo(const Clip: TTimelineClip;
  VerifyHash: Boolean; out VideoFile: string; out Source: TMmpSourceRef): Boolean;
var
  I, J: Integer;
  Rev: TMmpRevisionInfo;
begin
  Result := False;
  VideoFile := '';
  Source := Default(TMmpSourceRef);
  for I := 0 to High(FProd.Projects) do
    if (FProd.Projects[I].SoftwareIndex = 5) and
      (FProd.Projects[I].SceneId = Clip.SceneId) then
    begin
      if not FindRevisionInProject(FProd.Projects[I], Clip.SceneRevision, Rev) then Continue;
      for J := 0 to High(Rev.Artifacts) do
        with Rev.Artifacts[J] do
          if (Kind = 'video.scene') and (MimeType = 'video/mp4') and
            (SceneId = Clip.SceneId) and (Status = 'approved') and
            (Sha256 <> '') and FileExists(ResolvedPath) then
          begin
            if VerifyHash and not SameText(SHA256File(ResolvedPath), Sha256) then Exit;
            VideoFile := ResolvedPath;
            Source.ProjectId := FProd.Projects[I].ProjectId;
            Source.RevisionId := Rev.RevisionId;
            Source.ManifestSha256 := Rev.ManifestSha256;
            Exit(True);
          end;
    end;
end;

procedure TMcutMainForm.RefreshTimelineGrid;
var
  I, Row: Integer;
begin
  if Length(FClips) = 0 then
  begin
    FTimelineGrid.RowCount := 2;
    for I := 0 to FTimelineGrid.ColCount - 1 do FTimelineGrid.Cells[I, 1] := '';
    Exit;
  end;
  FTimelineGrid.RowCount := Length(FClips) + 1;
  for I := 0 to High(FClips) do
  begin
    Row := I + 1;
    FTimelineGrid.Cells[0, Row] := IntToStr(FClips[I].OrderIdx);
    FTimelineGrid.Cells[1, Row] := FClips[I].SceneId;
    FTimelineGrid.Cells[2, Row] := FClips[I].Heading;
    FTimelineGrid.Cells[3, Row] := FClips[I].SceneRevision;
    FTimelineGrid.Cells[4, Row] := IntToStr(FClips[I].InPointSec);
    FTimelineGrid.Cells[5, Row] := IntToStr(FClips[I].OutPointSec);
    FTimelineGrid.Cells[6, Row] := FClips[I].TransitionOut;
    FTimelineGrid.Cells[7, Row] := FClips[I].SceneStatus;
  end;
end;

procedure TMcutMainForm.RefreshRatingsGrid;
var
  I, Row: Integer;
begin
  if Length(FRatings) = 0 then
  begin
    FRatingsGrid.RowCount := 2;
    for I := 0 to FRatingsGrid.ColCount - 1 do FRatingsGrid.Cells[I, 1] := '';
    Exit;
  end;
  FRatingsGrid.RowCount := Length(FRatings) + 1;
  for I := 0 to High(FRatings) do
  begin
    Row := I + 1;
    FRatingsGrid.Cells[0, Row] := FRatings[I].SessionId;
    FRatingsGrid.Cells[1, Row] := FRatings[I].FilmRevision;
    FRatingsGrid.Cells[2, Row] := FRatings[I].SceneId;
    FRatingsGrid.Cells[3, Row] := FRatings[I].Participant;
    FRatingsGrid.Cells[4, Row] := IntToStr(FRatings[I].Score);
    FRatingsGrid.Cells[5, Row] := FRatings[I].Comment;
  end;
end;

procedure TMcutMainForm.OnTimelineSelection(Sender: TObject; aCol, aRow: Integer);
var
  Idx: Integer;
begin
  Idx := aRow - 1;
  if (Idx < 0) or (Idx > High(FClips)) then Exit;
  FInEdit.Text := IntToStr(FClips[Idx].InPointSec);
  FOutEdit.Text := IntToStr(FClips[Idx].OutPointSec);
  FTransCombo.ItemIndex := FTransCombo.Items.IndexOf(FClips[Idx].TransitionOut);
  if FTransCombo.ItemIndex < 0 then FTransCombo.ItemIndex := 0;
end;

procedure TMcutMainForm.OnApplyClipCutClick(Sender: TObject);
var
  Idx, InSec, OutSec: Integer;
begin
  Idx := FTimelineGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FClips)) then Exit;
  if not TryStrToInt(FInEdit.Text, InSec) or not TryStrToInt(FOutEdit.Text, OutSec) or
    (InSec < 0) or ((OutSec <> 0) and (OutSec <= InSec)) then
  begin
    MessageDlg('Informe tempos em segundos. Use 0 na saída para manter o fim do vídeo.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  FClips[Idx].InPointSec := InSec;
  FClips[Idx].OutPointSec := OutSec;
  FClips[Idx].TransitionOut := FTransCombo.Text;
  RefreshTimelineGrid;
  LogMsg('Corte não destrutivo e transição aplicados na cena ' + FClips[Idx].SceneId);
end;

procedure TMcutMainForm.OnAddFeedbackClick(Sender: TObject);
var
  Idx, N: Integer;
  SceneId, PartName, ScoreStr, CommentStr: string;
begin
  Idx := FTimelineGrid.Row - 1;
  if (Idx >= 0) and (Idx <= High(FClips)) then
    SceneId := FClips[Idx].SceneId
  else if Length(FClips) > 0 then
    SceneId := FClips[0].SceneId
  else
  begin
    MessageDlg('Monte a timeline primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;

  PartName := 'anonimo';
  ScoreStr := '4';
  CommentStr := 'Bom ritmo, transicao clara';
  if not InputQuery('Avaliacao de Publico - Cena ' + SceneId, 'Participante (ou anonimo):', PartName) then Exit;
  if not InputQuery('Avaliacao de Publico - Cena ' + SceneId, 'Nota (1 a 5):', ScoreStr) then Exit;
  if not InputQuery('Avaliacao de Publico - Cena ' + SceneId, 'Comentario:', CommentStr) then Exit;

  N := Length(FRatings);
  SetLength(FRatings, N + 1);
  FRatings[N].FeedbackId := GenerateMmpId('fb');
  FRatings[N].SessionId := FCurrentSessionId;
  FRatings[N].FilmRevision := FCurrentRevId;
  FRatings[N].SceneId := SceneId;
  FRatings[N].Participant := PartName;
  FRatings[N].Score := StrToIntDef(ScoreStr, 4);
  if FRatings[N].Score < 1 then FRatings[N].Score := 1;
  if FRatings[N].Score > 5 then FRatings[N].Score := 5;
  FRatings[N].Comment := CommentStr;
  FRatings[N].CreatedAt := CurrentIsoUtc;
  RefreshRatingsGrid;
  LogMsg('Avaliacao registrada para cena ' + SceneId + ' @ ' + FCurrentRevId);
end;

procedure TMcutMainForm.RunAudienceAnalysis(IncludeAi: Boolean);
var
  I, J, Cnt, SumScore, RevisionRatingCount: Integer;
  CommentsAll, AiAdvice, Err: string;
begin
  FAnalysisMemo.Lines.Clear;
  FAnalysisMemo.Lines.Add('=== RELATORIO DE ANALISE DE PUBLICO (' + FCurrentRevId + ') ===');
  RevisionRatingCount := 0;
  for J := 0 to High(FRatings) do
    if FRatings[J].FilmRevision = FCurrentRevId then Inc(RevisionRatingCount);
  FAnalysisMemo.Lines.Add('Total de avaliacoes: ' + IntToStr(RevisionRatingCount));
  FAnalysisMemo.Lines.Add('');

  for I := 0 to High(FClips) do
  begin
    Cnt := 0;
    SumScore := 0;
    CommentsAll := '';
    for J := 0 to High(FRatings) do
    begin
      if (FRatings[J].FilmRevision = FCurrentRevId) and
        SameText(FRatings[J].SceneId, FClips[I].SceneId) then
      begin
        Inc(Cnt);
        Inc(SumScore, FRatings[J].Score);
        CommentsAll := CommentsAll + ' - [' + FRatings[J].FilmRevision + '] ' +
          FRatings[J].Comment + LineEnding;
      end;
    end;
    if Cnt = 0 then
      FAnalysisMemo.Lines.Add(Format('Cena %s (%s): sem avaliacoes (nao confundir com nota zero)',
        [FClips[I].SceneId, FClips[I].Heading]))
    else
    begin
      FAnalysisMemo.Lines.Add(Format('Cena %s (%s): media %.1f/5 (%d respostas)',
        [FClips[I].SceneId, FClips[I].Heading, SumScore / Cnt, Cnt]));
      FAnalysisMemo.Lines.Add(CommentsAll);
    end;
  end;

  if IncludeAi and (RevisionRatingCount > 0) and FAi.IsConfigured then
  begin
    if FAi.Ask('Voce e um editor de cinema. Analise objetivamente as avaliacoes abaixo sem alterar nada automaticamente.',
      FAnalysisMemo.Text, AiAdvice, Err) then
    begin
      FAnalysisMemo.Lines.Add('=== SUGESTOES DA IA (CHATGPT) ===');
      FAnalysisMemo.Lines.Add(AiAdvice);
    end;
  end;
end;

procedure TMcutMainForm.OnAnalyzeFeedbackClick(Sender: TObject);
begin
  RunAudienceAnalysis;
  LogMsg('Analise de avaliacoes consolidada.');
end;

procedure TMcutMainForm.OnRequestSceneCorrectionClick(Sender: TObject);
var
  Idx: Integer;
  Reason, EvtId: string;
begin
  if not FProd.Loaded or (Length(FClips) = 0) then Exit;
  Idx := FTimelineGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FClips)) then Idx := 0;
  Reason := 'Ajustar ritmo/transicao da cena ' + FClips[Idx].SceneId;
  if not InputQuery('Solicitar Correcao em Cascata', 'Motivo da revisao para MScene:', Reason) then Exit;

  if EmitSyncEvent(FProd.RootDir, 'MCut', 'MScene', FClips[Idx].SceneId,
    FCurrentRevId, Reason, 'MScene', 'queued', '', EvtId) then
  begin
    LogMsg('Solicitacao de correcao emitida (' + EvtId + ') para MScene.');
    MessageDlg('Evento de correcao ' + EvtId + ' registrado em shared/sync/.', mtInformation, [mbOK], 0);
  end;
end;

function TMcutMainForm.TimelineToJson: string;
var
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.mcut.timeline/1');
    Root.Add('script_revision', FTimelineScriptRev);
    Arr := TJSONArray.Create;
    for I := 0 to High(FClips) do
    begin
      Item := TJSONObject.Create;
      Item.Add('order', FClips[I].OrderIdx);
      Item.Add('scene_id', FClips[I].SceneId);
      Item.Add('heading', FClips[I].Heading);
      Item.Add('scene_video_revision_id', FClips[I].SceneRevision);
      Item.Add('in_point', FClips[I].InPointSec);
      Item.Add('out_point', FClips[I].OutPointSec);
      Item.Add('transition_out', FClips[I].TransitionOut);
      Item.Add('transition_sec', FClips[I].TransitionSec);
      Item.Add('status', FClips[I].SceneStatus);
      Arr.Add(Item);
    end;
    Root.Add('timeline_items', Arr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

function TMcutMainForm.RatingsToJson: string;
var
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.mcut.feedback/1');
    Arr := TJSONArray.Create;
    for I := 0 to High(FRatings) do
    begin
      Item := TJSONObject.Create;
      Item.Add('feedback_id', FRatings[I].FeedbackId);
      Item.Add('session_id', FRatings[I].SessionId);
      Item.Add('revision_id', FRatings[I].FilmRevision);
      Item.Add('scene_id', FRatings[I].SceneId);
      Item.Add('participant', FRatings[I].Participant);
      Item.Add('rating', FRatings[I].Score);
      Item.Add('comment', FRatings[I].Comment);
      Item.Add('timestamp', FRatings[I].CreatedAt);
      Arr.Add(Item);
    end;
    Root.Add('feedback', Arr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

function TMcutMainForm.AnalysisToJson: string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.mcut.analysis/1');
    Root.Add('film_revision', FCurrentRevId);
    Root.Add('report_text', FAnalysisMemo.Text);
    Root.Add('generated_at', CurrentIsoUtc);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

procedure TMcutMainForm.OnSaveAndExportClick(Sender: TObject);
const
  Mp4Widths: array[0..5] of Integer = (854, 1280, 1920, 2560, 3840, 7680);
  Mp4Heights: array[0..5] of Integer = (480, 720, 1080, 1440, 2160, 4320);
var
  PrepRev, RevDir, NewRev, ErrMsg, ExportStatus, VideoFile, ExportRel, ExportPath,
    Ffmpeg, Ffprobe, MimeType: string;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  Videos: array of TMmpVideoClip;
  SceneSource: TMmpSourceRef;
  RevInfo: TMmpRevisionInfo;
  I, MissingCnt, ExportWidth, ExportHeight, Fps, FormatIndex: Integer;
  Duration: Double;
  ExportObj: TJSONObject;

  procedure AddArtifact(const Kind, RelUri, Mime, Status: string);
  var
    N: Integer;
  begin
    N := Length(Arts);
    SetLength(Arts, N + 1);
    Arts[N].ArtifactId := GenerateMmpId('a');
    Arts[N].Kind := Kind;
    Arts[N].RelUri := RelUri;
    Arts[N].MimeType := Mime;
    Arts[N].Status := Status;
  end;

  function WriteRevisionJson(const RelUri, Content: string): Boolean;
  begin
    Result := AtomicWriteTextFile(IncludeTrailingPathDelimiter(RevDir) +
      StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]), Content, False);
    if not Result then MessageDlg('Não foi possível gravar ' + RelUri, mtError, [mbOK], 0);
  end;

begin
  if not FProd.Loaded then Exit;
  if Length(FClips) = 0 then
  begin
    MessageDlg('Monte a timeline antes de exportar.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not FindRevisionInProject(FScriptProj, FTimelineScriptRev, RevInfo) then
  begin
    MessageDlg('A revisão do roteiro vinculada à timeline está indisponível.', mtError, [mbOK], 0);
    Exit;
  end;
  SetLength(Srcs, 1);
  Srcs[0].ProjectId := FScriptProj.ProjectId;
  Srcs[0].RevisionId := FTimelineScriptRev;
  Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;

  MissingCnt := 0;
  SetLength(Videos, Length(FClips));
  for I := 0 to High(FClips) do
    if ResolveSceneVideo(FClips[I], True, VideoFile, SceneSource) then
    begin
      Videos[I].FileName := VideoFile;
      Videos[I].InSec := FClips[I].InPointSec;
      Videos[I].OutSec := FClips[I].OutPointSec;
      Videos[I].Transition := FClips[I].TransitionOut;
      Videos[I].TransitionSec := FClips[I].TransitionSec;
      SetLength(Srcs, Length(Srcs) + 1);
      Srcs[High(Srcs)] := SceneSource;
      FClips[I].SceneStatus := 'ok';
    end
    else
    begin
      Inc(MissingCnt);
      FClips[I].SceneStatus := 'missing_or_invalid_video';
    end;
  RefreshTimelineGrid;
  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;

  Duration := 0;
  ExportWidth := 0; ExportHeight := 0; Fps := 0;
  ExportRel := '';
  ExportPath := '';
  ExportStatus := 'pending_scenes_missing';
  if MissingCnt = 0 then
  begin
    FAi.ReloadIfChanged;
    Ffmpeg := FAi.Settings.ToolFfmpeg;
    if Ffmpeg = '' then Ffmpeg := FAi.Settings.DetectToolPath('ffmpeg');
    Ffprobe := FAi.Settings.ToolFfprobe;
    if Ffprobe = '' then Ffprobe := FAi.Settings.DetectToolPath('ffprobe');
    Fps := FAi.Settings.ProdFps;
    FormatIndex := FExportFormatCombo.ItemIndex;
    if (FormatIndex >= Low(Mp4Widths)) and (FormatIndex <= High(Mp4Widths)) then
    begin
      ExportWidth := Mp4Widths[FormatIndex];
      ExportHeight := Mp4Heights[FormatIndex];
      ExportRel := 'video/exports/filme.mp4';
      MimeType := 'video/mp4';
    end
    else
    begin
      ExportWidth := FAi.Settings.ProdWidth;
      ExportHeight := FAi.Settings.ProdHeight;
      ExportRel := 'video/exports/filme.mkv';
      MimeType := 'video/x-matroska';
    end;
    ExportPath := IncludeTrailingPathDelimiter(RevDir) +
      StringReplace(ExportRel, '/', PathDelim, [rfReplaceAll]);
    if not RenderMmpVideo(Ffmpeg, Ffprobe, ExportPath, Videos, ExportWidth,
      ExportHeight, Fps, Duration, ErrMsg) then
    begin
      LogMsg('Falha na exportação: ' + ErrMsg);
      MessageDlg(ErrMsg, mtError, [mbOK], 0);
      Exit;
    end;
    ExportStatus := 'exported';
  end;

  RunAudienceAnalysis(False);
  if not WriteRevisionJson('timeline/timeline.json', TimelineToJson) or
    not WriteRevisionJson('feedback/ratings.json', RatingsToJson) or
    not WriteRevisionJson('analysis/report.json', AnalysisToJson) then Exit;

  ExportObj := TJSONObject.Create;
  try
    ExportObj.Add('export_id', GenerateMmpId('exp'));
    ExportObj.Add('film_revision_id', PrepRev);
    ExportObj.Add('format', FExportFormatCombo.Text);
    ExportObj.Add('missing_scenes', MissingCnt);
    ExportObj.Add('status', ExportStatus);
    ExportObj.Add('created_at', CurrentIsoUtc);
    if ExportPath <> '' then
    begin
      ExportObj.Add('file_uri', ExportRel);
      ExportObj.Add('width', ExportWidth);
      ExportObj.Add('height', ExportHeight);
      ExportObj.Add('fps', Fps);
      ExportObj.Add('sha256', SHA256File(ExportPath));
      ExportObj.Add('duration_ms', Round(Duration * 1000));
    end;
    if not WriteRevisionJson('video/exports/export_report.json', ExportObj.FormatJSON) then Exit;
  finally
    ExportObj.Free;
  end;

  AddArtifact('film.timeline', 'timeline/timeline.json', 'application/json', 'published');
  AddArtifact('feedback.rating', 'feedback/ratings.json', 'application/json', 'published');
  AddArtifact('analysis.report', 'analysis/report.json', 'application/json', 'published');
  AddArtifact('export.report', 'video/exports/export_report.json', 'application/json', ExportStatus);
  if ExportPath <> '' then
    AddArtifact('video.film.export', ExportRel, MimeType, 'published');

  if not PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MCut',
    FCurrentRevId, ExportStatus, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;
  LogMsg('Revisão MCut salva (' + NewRev + '): ' + ExportStatus);
  if MissingCnt > 0 then
    MessageDlg(Format('Revisão %s salva. %d cena(s) sem vídeo aprovado e íntegro. Filme não exportado.',
      [NewRev, MissingCnt]), mtWarning, [mbOK], 0)
  else if MessageDlg('Filme exportado em ' + ExportPath + LineEnding + 'Abrir agora?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    OpenDocument(ExportPath);
  LoadProductionAndRevision(FProd.RootDir, FProj.ProjectId, NewRev);
end;

procedure TMcutMainForm.OnOpenProdClick(Sender: TObject);
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

procedure TMcutMainForm.OnAiConfigClick(Sender: TObject);
begin
  if FAi.ShowConfigDialog(Self) then
    LogMsg('IA configurada: ' + FAi.ProviderDisplayName);
end;

end.

