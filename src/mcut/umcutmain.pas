unit umcutmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Math, fpjson, jsonparser, aih264decoder,
  ummpprotocol, ummpappbase, ummpaibridge, ummpmedia, ummpsha256;

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
    SceneStatus: string; // ok | missing_scene | pending_approval | missing_video
    VideoFile: string;   // video costurado da cena no MScene (revisao ativa)
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
    FCurrentRevId: string;
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
    procedure RunAudienceAnalysis;
    function TimelineToJson: string;
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
    procedure OnWatchFilmClick(Sender: TObject);
    procedure OnMediaProgress(Sender: TObject);
    function SceneVideoFile(const SceneId: string; out SceneRev: string): string;
    function RenderFilm(const RevDir, RevId: string; out RelUri, Err: string;
      out DurationSec: Double): Boolean;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mcutMainForm: TMcutMainForm;

implementation

function MediaFileSize(const F: string): Int64;
var Fs: TFileStream;
begin
  Result := 0;
  try
    Fs := TFileStream.Create(F, fmOpenRead or fmShareDenyNone);
    try
      Result := Fs.Size;
    finally
      Fs.Free;
    end;
  except
  end;
end;

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
  BtnOpen, BtnAiCfg, BtnBuildTL, BtnApplyCut, BtnAddRate, BtnAnalyze, BtnCorr, BtnExport, BtnWatch: TButton;
  L: TLabel;
begin
  Head := TPanel.Create(Self); Head.Parent := Self; Head.Align := alTop; MmpPrepareAligned(Head); Head.Height := 68;
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

  Bottom := TPanel.Create(Self); Bottom.Parent := Self; Bottom.Align := alBottom; MmpPrepareAligned(Bottom); Bottom.Height := 34;
  Bottom.BevelOuter := bvLowered;
  FStatusLabel := TLabel.Create(Self); FStatusLabel.Parent := Bottom; FStatusLabel.SetBounds(12, 9, 1100, 18);
  FStatusLabel.Caption := 'Pronto.';

  Sidebar := TPanel.Create(Self); Sidebar.Parent := Self; Sidebar.Align := alLeft; MmpPrepareAligned(Sidebar); Sidebar.Width := 255;
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

  BtnWatch := TButton.Create(Self); BtnWatch.Parent := Sidebar; BtnWatch.Caption := 'Assistir filme exportado';
  BtnWatch.SetBounds(12, 212, 231, 34); BtnWatch.OnClick := @OnWatchFilmClick;

  L := TLabel.Create(Self); L.Parent := Sidebar; L.WordWrap := True; L.AutoSize := False;
  L.SetBounds(12, 258, 231, 140); L.Font.Color := $00555555;
  L.Caption := '"Salvar e Exportar" grava o filme em video/exports da nova revisao: cada cena ' +
    'costurada no MScene, cortada pelos pontos In/Out e unida pela transicao escolhida ' +
    '(corte, fusao ou fade para preto), no formato acima. Com cenas pendentes, so a ' +
    'montagem e salva.';

  PC := TPageControl.Create(Self); PC.Parent := Self; PC.Align := alClient; MmpPrepareAligned(PC);
  TabTimeline := TTabSheet.Create(PC); TabTimeline.PageControl := PC; MmpPrepareTabSheet(TabTimeline); TabTimeline.Caption := 'Etapa 1 && 2: Timeline && Transicoes';
  TabFeedback := TTabSheet.Create(PC); TabFeedback.PageControl := PC; MmpPrepareTabSheet(TabFeedback); TabFeedback.Caption := 'Etapa 3: Sessoes de Publico';
  TabAnalysis := TTabSheet.Create(PC); TabAnalysis.PageControl := PC; MmpPrepareTabSheet(TabAnalysis); TabAnalysis.Caption := 'Etapa 4: Analise && Evidencias';
  TabLog := TTabSheet.Create(PC); TabLog.PageControl := PC; MmpPrepareTabSheet(TabLog); TabLog.Caption := 'Log Operacional';

  ClipEditBar := TPanel.Create(Self); ClipEditBar.Parent := TabTimeline; ClipEditBar.Align := alBottom; MmpPrepareAligned(ClipEditBar);
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

  FTimelineGrid := TStringGrid.Create(Self); FTimelineGrid.Parent := TabTimeline; FTimelineGrid.Align := alClient; MmpPrepareAligned(FTimelineGrid);
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

  FeedBar := TPanel.Create(Self); FeedBar.Parent := TabFeedback; FeedBar.Align := alTop; MmpPrepareAligned(FeedBar);
  FeedBar.Height := 46; FeedBar.BevelOuter := bvNone;
  BtnAddRate := TButton.Create(Self); BtnAddRate.Parent := FeedBar; BtnAddRate.Caption := '+ Registrar Avaliacao de Cena...';
  BtnAddRate.SetBounds(12, 8, 250, 30); BtnAddRate.OnClick := @OnAddFeedbackClick;
  BtnAnalyze := TButton.Create(Self); BtnAnalyze.Parent := FeedBar; BtnAnalyze.Caption := 'Consolidar Analise (Etapa 4)';
  BtnAnalyze.SetBounds(274, 8, 230, 30); BtnAnalyze.OnClick := @OnAnalyzeFeedbackClick;

  FRatingsGrid := TStringGrid.Create(Self); FRatingsGrid.Parent := TabFeedback; FRatingsGrid.Align := alClient; MmpPrepareAligned(FRatingsGrid);
  FRatingsGrid.FixedCols := 0; FRatingsGrid.FixedRows := 1; FRatingsGrid.ColCount := 6; FRatingsGrid.RowCount := 2;
  FRatingsGrid.Options := FRatingsGrid.Options + [goRowSelect, goColSizing];
  FRatingsGrid.Cells[0, 0] := 'Sessao'; FRatingsGrid.Cells[1, 0] := 'Revisao Filme';
  FRatingsGrid.Cells[2, 0] := 'Cena ID'; FRatingsGrid.Cells[3, 0] := 'Participante';
  FRatingsGrid.Cells[4, 0] := 'Nota'; FRatingsGrid.Cells[5, 0] := 'Comentario';
  FRatingsGrid.ColWidths[0] := 120; FRatingsGrid.ColWidths[1] := 95; FRatingsGrid.ColWidths[2] := 115;
  FRatingsGrid.ColWidths[3] := 120; FRatingsGrid.ColWidths[4] := 55; FRatingsGrid.ColWidths[5] := 350;

  FAnalysisMemo := TMemo.Create(Self); FAnalysisMemo.Parent := TabAnalysis; FAnalysisMemo.Align := alClient; MmpPrepareAligned(FAnalysisMemo);
  FAnalysisMemo.ReadOnly := True; FAnalysisMemo.ScrollBars := ssBoth;

  FLogMemo := TMemo.Create(Self); FLogMemo.Parent := TabLog; FLogMemo.Align := alClient; MmpPrepareAligned(FLogMemo);
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

  TLPath := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim +
    RevId + PathDelim + 'timeline' + PathDelim + 'timeline.json';
  if FileExists(TLPath) and ReadTextFileUtf8(TLPath, Content) then
  begin
    Data := GetJSON(Content);
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      try
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
  ScriptPath, Content, SId: string;
  Data: TJSONData;
  Obj, SItem: TJSONObject;
  Arr: TJSONArray;
  I, J: Integer;
  FoundSceneProj: Boolean;
  Rev: string;
  Media: TMmpMedia;
  Dur: Double;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  { recarrega a producao: cenas podem ter sido salvas no MScene desde a abertura }
  Rev := FProd.RootDir;
  if not LoadProduction(Rev, False, FProd) then Exit;
  Media := TMmpMedia.Create(FAi.Settings.ToolFfmpeg, FAi.Settings.ToolFfprobe);
  if Media.Ffprobe = '' then FreeAndNil(Media);
  try
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
    SetLength(FClips, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      SItem := TJSONObject(Arr.Items[I]);
      SId := SItem.Get('scene_id', '');
      FClips[I].OrderIdx := I + 1;
      FClips[I].SceneId := SId;
      FClips[I].Heading := SItem.Get('heading', '');
      FClips[I].InPointSec := 0;
      FClips[I].OutPointSec := SItem.Get('estimated_duration', 30);
      FClips[I].TransitionOut := 'cut';
      FClips[I].TransitionSec := 1;

      FoundSceneProj := False;
      FClips[I].SceneRevision := '-';
      FClips[I].SceneStatus := 'missing_scene';
      FClips[I].VideoFile := '';
      for J := 0 to High(FProd.Projects) do
      begin
        if (FProd.Projects[J].SoftwareIndex = 5) and SameText(FProd.Projects[J].SceneId, SId) then
        begin
          FoundSceneProj := True;
          FClips[I].SceneRevision := FProd.Projects[J].ActiveRevision;
          if (FProd.Projects[J].Status = 'finalizada') or
             (FProd.Projects[J].Status = 'ligacao_posterior_pendente') or
             (FProd.Projects[J].Status = 'approved') then
            FClips[I].SceneStatus := 'ok'
          else
            FClips[I].SceneStatus := 'pending_approval';
          FClips[I].VideoFile := SceneVideoFile(SId, Rev);
          if FClips[I].VideoFile = '' then
          begin
            if FClips[I].SceneStatus = 'ok' then FClips[I].SceneStatus := 'missing_video';
          end
          else
          begin
            FClips[I].SceneRevision := Rev;
            if Media <> nil then
            begin
              Dur := Media.Duration(FClips[I].VideoFile);
              if Dur > 0 then FClips[I].OutPointSec := Max(1, Trunc(Dur));
            end;
          end;
          Break;
        end;
      end;
      if not FoundSceneProj then
        LogMsg('PENDENCIA: Cena ' + SId + ' ainda nao foi finalizada no MScene.');
    end;
  finally
    Obj.Free;
  end;
  finally
    Media.Free;
  end;

  RefreshTimelineGrid;
  LogMsg('Timeline montada na ordem narrativa do roteiro (' + IntToStr(Length(FClips)) + ' cenas).');
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
  Idx: Integer;
begin
  Idx := FTimelineGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FClips)) then Exit;
  FClips[Idx].InPointSec := StrToIntDef(FInEdit.Text, 0);
  FClips[Idx].OutPointSec := StrToIntDef(FOutEdit.Text, 30);
  FClips[Idx].TransitionOut := FTransCombo.Text;
  RefreshTimelineGrid;
  LogMsg('Corte nao destrutivo e transicao aplicados na cena ' + FClips[Idx].SceneId);
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

procedure TMcutMainForm.RunAudienceAnalysis;
var
  I, J, Cnt, SumScore: Integer;
  CommentsAll, AiAdvice, Err: string;
begin
  FAnalysisMemo.Lines.Clear;
  FAnalysisMemo.Lines.Add('=== RELATORIO DE ANALISE DE PUBLICO (' + FCurrentRevId + ') ===');
  FAnalysisMemo.Lines.Add('Total de avaliacoes: ' + IntToStr(Length(FRatings)));
  FAnalysisMemo.Lines.Add('');

  for I := 0 to High(FClips) do
  begin
    Cnt := 0;
    SumScore := 0;
    CommentsAll := '';
    for J := 0 to High(FRatings) do
    begin
      if SameText(FRatings[J].SceneId, FClips[I].SceneId) then
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

  if FAi.IsConfigured and (Length(FRatings) > 0) then
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
  Idx, J: Integer;
  Reason, EvtId, SceneProjId, SceneRev: string;
begin
  if not FProd.Loaded or (Length(FClips) = 0) then Exit;
  Idx := FTimelineGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FClips)) then Idx := 0;
  Reason := 'Ajustar ritmo/transicao da cena ' + FClips[Idx].SceneId;
  if not InputQuery('Solicitar Correcao em Cascata', 'Motivo da revisao para MScene:', Reason) then Exit;

  { O destino e o projeto da cena no MScene (project_id e revisao exata), nao o scene_id. }
  SceneProjId := '';
  SceneRev := FClips[Idx].SceneRevision;
  for J := 0 to High(FProd.Projects) do
    if (FProd.Projects[J].SoftwareIndex = 5) and SameText(FProd.Projects[J].SceneId, FClips[Idx].SceneId) then
    begin
      SceneProjId := FProd.Projects[J].ProjectId;
      SceneRev := FProd.Projects[J].ActiveRevision;
      Break;
    end;
  if SceneProjId = '' then
  begin
    MessageDlg('A cena ' + FClips[Idx].SceneId + ' ainda nao tem projeto no MScene.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if EmitSyncEvent(FProd.RootDir, 'MCut', 'MScene', SceneProjId,
    SceneRev, Reason, 'MScene', 'queued', '', EvtId, '', FClips[Idx].SceneId,
    FProj.ProjectId, FCurrentRevId, FAi.Settings.UserName) then
  begin
    LogMsg('Solicitacao de correcao emitida (' + EvtId + ') para MScene.');
    MessageDlg('Pedido de correcao ' + EvtId + ' registrado para o MScene (cena ' +
      FClips[Idx].SceneId + ').' + LineEnding + 'Acompanhe em Sincronizacoes no MMenu.', mtInformation, [mbOK], 0);
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
    Root.Add('script_revision', FScriptProj.ActiveRevision);
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
var
  PrepRev, RevDir, NewRev, ErrMsg, ExportStatus, FilmRel, FilmErr, FilmPath: string;
  FilmSec: Double;
  W, H: Integer;
  Lossless: Boolean;
  ClipsArr: TJSONArray;
  Srcs: array of TMmpSourceRef;
  Arts: array of TMmpArtifactInput;
  RevInfo: TMmpRevisionInfo;
  I, J, N, MissingCnt: Integer;
  ExportObj: TJSONObject;
begin
  if not FProd.Loaded then Exit;
  if Length(FClips) = 0 then
  begin
    MessageDlg('Monte a ordem narrativa (Etapa 1) antes de exportar.', mtWarning, [mbOK], 0);
    Exit;
  end;

  MissingCnt := 0;
  for I := 0 to High(FClips) do
  begin
    { timeline carregada de uma revisao: localiza de novo o video de cada cena }
    if (FClips[I].SceneStatus = 'ok') and (FClips[I].VideoFile = '') then
      FClips[I].VideoFile := SceneVideoFile(FClips[I].SceneId, ErrMsg);
    if (FClips[I].SceneStatus = 'ok') and (FClips[I].VideoFile = '') then
      FClips[I].SceneStatus := 'missing_video';
    if FClips[I].SceneStatus <> 'ok' then
      Inc(MissingCnt);
  end;
  RefreshTimelineGrid;

  if MissingCnt > 0 then
    ExportStatus := 'pending_scenes_missing'
  else
    ExportStatus := 'exported';

  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then Exit;

  FilmRel := ''; FilmErr := ''; FilmSec := 0;
  if MissingCnt = 0 then
  begin
    Screen.Cursor := crHourGlass;
    try
      if not RenderFilm(RevDir, PrepRev, FilmRel, FilmErr, FilmSec) then
      begin
        ExportStatus := 'export_failed';
        LogMsg('Falha ao gravar o filme: ' + FilmErr);
      end;
    finally
      Screen.Cursor := crDefault;
    end;
  end;

  RunAudienceAnalysis;
  AtomicWriteTextFile(RevDir + PathDelim + 'timeline' + PathDelim + 'timeline.json', TimelineToJson, False);
  AtomicWriteTextFile(RevDir + PathDelim + 'feedback' + PathDelim + 'ratings.json', RatingsToJson, False);
  AtomicWriteTextFile(RevDir + PathDelim + 'analysis' + PathDelim + 'report.json', AnalysisToJson, False);

  ForceDirectories(RevDir + PathDelim + 'video' + PathDelim + 'exports');
  ExportObj := TJSONObject.Create;
  try
    ExportObj.Add('export_id', GenerateMmpId('exp'));
    ExportObj.Add('film_revision_id', PrepRev);
    ExportObj.Add('format', FExportFormatCombo.Text);
    ExportObj.Add('missing_scenes', MissingCnt);
    ExportObj.Add('status', ExportStatus);
    if FilmRel <> '' then
    begin
      FilmPath := RevDir + PathDelim + StringReplace(FilmRel, '/', PathDelim, [rfReplaceAll]);
      ExportObj.Add('file', FilmRel);
      ExportObj.Add('duration_sec', FilmSec);
      ExportObj.Add('size_bytes', MediaFileSize(FilmPath));
      ExportObj.Add('sha256', SHA256File(FilmPath));
      MmpFormatSize(FExportFormatCombo.Text, W, H, Lossless);
      ExportObj.Add('width', W);
      ExportObj.Add('height', H);
      ClipsArr := TJSONArray.Create;
      for I := 0 to High(FClips) do
        ClipsArr.Add(TJSONObject.Create(['scene_id', FClips[I].SceneId,
          'scene_revision', FClips[I].SceneRevision, 'in_point', FClips[I].InPointSec,
          'out_point', FClips[I].OutPointSec, 'transition_out', FClips[I].TransitionOut,
          'transition_sec', FClips[I].TransitionSec]));
      ExportObj.Add('clips', ClipsArr);
    end;
    if FilmErr <> '' then ExportObj.Add('error', FilmErr);
    ExportObj.Add('created_at', CurrentIsoUtc);
    AtomicWriteTextFile(RevDir + PathDelim + 'video' + PathDelim + 'exports' + PathDelim + 'export_report.json',
      ExportObj.FormatJSON, False);
  finally
    ExportObj.Free;
  end;

  SetLength(Arts, 4);
  Arts[0].ArtifactId := GenerateMmpId('a'); Arts[0].Kind := 'film.timeline'; Arts[0].RelUri := 'timeline/timeline.json'; Arts[0].MimeType := 'application/json'; Arts[0].Status := 'approved';
  Arts[1].ArtifactId := GenerateMmpId('a'); Arts[1].Kind := 'feedback.rating'; Arts[1].RelUri := 'feedback/ratings.json'; Arts[1].MimeType := 'application/json'; Arts[1].Status := 'approved';
  Arts[2].ArtifactId := GenerateMmpId('a'); Arts[2].Kind := 'analysis.report'; Arts[2].RelUri := 'analysis/report.json'; Arts[2].MimeType := 'application/json'; Arts[2].Status := 'approved';
  Arts[3].ArtifactId := GenerateMmpId('a'); Arts[3].Kind := 'video.film.export'; Arts[3].RelUri := 'video/exports/export_report.json'; Arts[3].MimeType := 'application/json'; Arts[3].Status := ExportStatus;
  if FilmRel <> '' then
  begin
    SetLength(Arts, 5);
    Arts[4].ArtifactId := GenerateMmpId('a'); Arts[4].Kind := 'video.film'; Arts[4].RelUri := FilmRel;
    if SameText(ExtractFileExt(FilmRel), '.mkv') then Arts[4].MimeType := 'video/x-matroska'
    else Arts[4].MimeType := 'video/mp4';
    Arts[4].Status := 'approved';
  end;

  SetLength(Srcs, 1);
  Srcs[0].ResolvedApp := 'MScript';
  Srcs[0].ProjectId := FScriptProj.ProjectId;
  Srcs[0].RevisionId := FScriptProj.ActiveRevision;
  if FindRevisionInProject(FScriptProj, FScriptProj.ActiveRevision, RevInfo) then
    Srcs[0].ManifestSha256 := RevInfo.ManifestSha256;

  { RF-MC-17 / docs/08: cada cena da montagem aponta para a revisao exata do
    projeto da cena no MScene (e, por ele, para as fontes 1-4). }
  for I := 0 to High(FClips) do
    for J := 0 to High(FProd.Projects) do
      if (FProd.Projects[J].SoftwareIndex = 5) and (FProd.Projects[J].SceneId <> '') and
         SameText(FProd.Projects[J].SceneId, FClips[I].SceneId) then
      begin
        N := Length(Srcs);
        SetLength(Srcs, N + 1);
        Srcs[N].ResolvedApp := 'MScene';
        Srcs[N].ProjectId := FProd.Projects[J].ProjectId;
        Srcs[N].RevisionId := FProd.Projects[J].ActiveRevision;
        if FindRevisionInProject(FProd.Projects[J], FProd.Projects[J].ActiveRevision, RevInfo) then
          Srcs[N].ManifestSha256 := RevInfo.ManifestSha256;
        Break;
      end;

  if PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MCut',
    FCurrentRevId, ExportStatus, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    LogMsg('Revisao MCut salva (' + NewRev + '): ' + ExportStatus);
    if MissingCnt > 0 then
      MessageDlg('Revisao ' + NewRev + ' salva, mas ' + IntToStr(MissingCnt) +
        ' cena(s) ainda estao pendentes no MScene (sem video costurado ou nao finalizadas). ' +
        'O filme nao foi gravado.', mtWarning, [mbOK], 0)
    else if FilmRel = '' then
      MessageDlg('Revisao ' + NewRev + ' salva, mas o filme nao foi gravado: ' + FilmErr,
        mtWarning, [mbOK], 0)
    else
      MessageDlg(Format('Revisao %s salva. Filme gravado em %s (%.0f s).',
        [NewRev, FilmRel, FilmSec]), mtInformation, [mbOK], 0);
    LoadProductionAndRevision(FProd.RootDir, FProj.ProjectId, NewRev);
  end
  else
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
end;

function TMcutMainForm.SceneVideoFile(const SceneId: string; out SceneRev: string): string;
var
  J: Integer;
  Dir: string;
begin
  Result := '';
  SceneRev := '';
  for J := 0 to High(FProd.Projects) do
    if (FProd.Projects[J].SoftwareIndex = 5) and SameText(FProd.Projects[J].SceneId, SceneId) then
    begin
      SceneRev := FProd.Projects[J].ActiveRevision;
      Dir := ExtractFileDir(FProd.Projects[J].ProjectFilePath) + PathDelim + 'revisions' + PathDelim +
        SceneRev + PathDelim + 'video' + PathDelim + 'assembled' + PathDelim + SceneId + '.mp4';
      if FileExists(Dir) then Result := Dir;
      Exit;
    end;
end;

procedure TMcutMainForm.OnMediaProgress(Sender: TObject);
begin
  Application.ProcessMessages;
end;

{ Grava o filme: cada cena com seus pontos In/Out e a transicao de saida,
  na resolucao do formato escolhido (MKV = sem perdas). }
function TMcutMainForm.RenderFilm(const RevDir, RevId: string; out RelUri, Err: string;
  out DurationSec: Double): Boolean;
var
  M: TMmpMedia;
  Clips: array of TMmpClip;
  I, W, H: Integer;
  Lossless: Boolean;
  Ext, OutF: string;
begin
  Result := False;
  RelUri := '';
  Err := '';
  DurationSec := 0;
  M := TMmpMedia.Create(FAi.Settings.ToolFfmpeg, FAi.Settings.ToolFfprobe);
  try
    if not M.Available then
    begin
      Err := 'ffmpeg nao encontrado (configure em MMenu > Configuracoes > Ferramentas).';
      Exit;
    end;
    MmpFormatSize(FExportFormatCombo.Text, W, H, Lossless);
    M.Width := W; M.Height := H; M.Fps := 25;
    M.OnProgress := @OnMediaProgress;
    SetLength(Clips, Length(FClips));
    for I := 0 to High(FClips) do
    begin
      Clips[I].FileName := FClips[I].VideoFile;
      Clips[I].InSec := FClips[I].InPointSec;
      Clips[I].OutSec := FClips[I].OutPointSec;
      Clips[I].Transition := FClips[I].TransitionOut;
      Clips[I].TransitionSec := Max(0.5, FClips[I].TransitionSec);
    end;
    if Lossless then Ext := '.mkv' else Ext := '.mp4';
    RelUri := 'video/exports/filme_' + RevId + Ext;
    OutF := RevDir + PathDelim + StringReplace(RelUri, '/', PathDelim, [rfReplaceAll]);
    FStatusLabel.Caption := Format('Gravando o filme (%dx%d)... pode levar alguns minutos.', [W, H]);
    Application.ProcessMessages;
    Result := M.RenderTimeline(Clips, OutF, Err);
    if Result then
    begin
      DurationSec := M.Duration(OutF);
      LogMsg(Format('Filme gravado: %s (%.1f s, %dx%d).', [RelUri, DurationSec, W, H]));
    end
    else
    begin
      RelUri := '';
      DeleteFile(OutF);
    end;
  finally
    M.Free;
  end;
end;

procedure TMcutMainForm.OnWatchFilmClick(Sender: TObject);
var
  RepPath, Content, Rel, F: string;
  Data: TJSONData;
begin
  if not FProd.Loaded then Exit;
  RepPath := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId +
    PathDelim + 'video' + PathDelim + 'exports' + PathDelim + 'export_report.json';
  Rel := '';
  if ReadTextFileUtf8(RepPath, Content) then
  begin
    Data := GetJSON(Content);
    try
      if Data is TJSONObject then Rel := TJSONObject(Data).Get('file', '');
    finally
      Data.Free;
    end;
  end;
  F := '';
  if Rel <> '' then
    F := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' + PathDelim + FCurrentRevId +
      PathDelim + StringReplace(Rel, '/', PathDelim, [rfReplaceAll]);
  if (F = '') or not FileExists(F) then
  begin
    MessageDlg('A revisao ' + FCurrentRevId + ' nao tem filme gravado. Use "Salvar e Exportar Filme".',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if not MmpOpenMedia(F, FAi.Settings.ToolMpv) then
    LogMsg('Nao foi possivel abrir o reprodutor para ' + F);
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

