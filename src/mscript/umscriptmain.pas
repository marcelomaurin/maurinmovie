unit umscriptmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser,
  mmpcommon, ummpprotocol, ummpappbase, ummpaibridge;

type
  TScriptSceneItem = record
    SceneId: string;
    Sequence: Integer;
    Heading: string;
    LocationRef: string;
    TimeOfDay: string;
    Mood: string;
    DurationSec: Integer;
    ActionText: string;
    DialogueText: string;
    CharactersCsv: string;
    ObjectsCsv: string;
    CostumesCsv: string;
  end;

  TScriptCharItem = record
    CharacterId: string;
    Name: string;
    PhysicalDesc: string;
    WardrobeDesc: string;
    ScenesCsv: string;
  end;

  TMscriptMainForm = class(TForm)
  private
    FAi: TMmpAiBridge;
    FProd: TMmpProduction;
    FProj: TMmpProjectRef;
    FProjectDir: string;
    FCurrentRevId: string;
    FValidated: Boolean;
    FScenes: array of TScriptSceneItem;
    FChars: array of TScriptCharItem;
    FSelectedScene: Integer;

    FHeaderProdLabel: TLabel;
    FHeaderRevLabel: TLabel;
    FSideInfoLabel: TLabel;
    FRevList: TListBox;
    FPageControl: TPageControl;

    // Sinopse
    FTitleEdit: TEdit;
    FGenreEdit: TEdit;
    FTargetMinEdit: TEdit;
    FSynopsisMemo: TMemo;
    FAiPromptEdit: TEdit;

    // Cenas
    FScenesGrid: TStringGrid;
    FSceneHeadingEdit: TEdit;
    FSceneLocEdit: TEdit;
    FSceneTimeEdit: TEdit;
    FSceneMoodEdit: TEdit;
    FSceneDurEdit: TEdit;
    FSceneCharsEdit: TEdit;
    FSceneObjectsEdit: TEdit;
    FSceneCostumesEdit: TEdit;
    FSceneActionMemo: TMemo;
    FSceneDialogueMemo: TMemo;

    // Personagens
    FCharsGrid: TStringGrid;

    // Log
    FLogMemo: TMemo;
    FStatusLabel: TLabel;

    procedure BuildUI;
    procedure LogMsg(const Msg: string);
    procedure LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
    procedure LoadScriptFromRevision(const RevId: string);
    procedure RefreshUI;
    procedure RefreshScenesGrid;
    procedure LoadSceneToEditor(Idx: Integer);
    procedure SaveEditorToScene;
    procedure ExtractCharacterMap;
    procedure RefreshCharsGrid;
    procedure PopulateFromAiJson(const RawJson: string);
    procedure GenerateOfflineTemplateScenes;
    function BuildScriptJsonText: string;
    function BuildScriptMarkdownText: string;
    procedure SaveRevision(const NewState: string);

    procedure OnOpenProdClick(Sender: TObject);
    procedure OnAiConfigClick(Sender: TObject);
    procedure OnGenerateAiClick(Sender: TObject);
    procedure OnRewriteSceneAiClick(Sender: TObject);
    procedure OnAddSceneClick(Sender: TObject);
    procedure OnSaveSceneEditClick(Sender: TObject);
    procedure OnScenesGridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnExtractCharsClick(Sender: TObject);
    procedure OnSaveDraftClick(Sender: TObject);
    procedure OnValidatePublishClick(Sender: TObject);
    procedure OnRevListDblClick(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mscriptMainForm: TMscriptMainForm;

function RunMScriptHeadlessEvent(const Args: TMMLaunchArgs): Integer;

implementation

constructor TMscriptMainForm.Create(TheOwner: TComponent);
var
  ProdRoot, ProjId, RevId: string;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MScript - Roteiro e Personagens (MaurinMovie)';
  Width := 1200;
  Height := 760;
  Position := poScreenCenter;
  Constraints.MinWidth := 920;
  Constraints.MinHeight := 620;

  FAi := TMmpAiBridge.Create('MScript');
  FSelectedScene := -1;
  BuildUI;

  ParseAppLaunchParams(ProdRoot, ProjId, RevId);
  LogMsg('MScript v' + MMP_EXECUTABLE_VERSION + ' iniciado | IA: ' + FAi.ProviderDisplayName);
  if ProdRoot <> '' then
    LoadProductionAndRevision(ProdRoot, ProjId, RevId)
  else
    RefreshUI;
end;

destructor TMscriptMainForm.Destroy;
begin
  FAi.Free;
  inherited Destroy;
end;

procedure TMscriptMainForm.BuildUI;
var
  Head, Sidebar, Bottom, DetailPanel: TPanel;
  TabSinopse, TabScenes, TabChars, TabLog: TTabSheet;
  BtnOpen, BtnAiCfg, BtnSaveDraft, BtnApprove: TButton;
  BtnGenAi, BtnAddScene, BtnSaveScene, BtnRewriteScene, BtnExtract: TButton;
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
  L.Caption := 'MaurinMovie  |  1 - MScript';
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

  FHeaderRevLabel := TLabel.Create(Self);
  FHeaderRevLabel.Parent := Head;
  FHeaderRevLabel.Caption := 'Revisao: -  |  Rascunho';
  FHeaderRevLabel.Font.Color := $0099E6FF;
  FHeaderRevLabel.SetBounds(340, 36, 420, 18);

  BtnAiCfg := TButton.Create(Self);
  BtnAiCfg.Parent := Head;
  BtnAiCfg.Caption := 'Alterar no MMenu...';
  BtnAiCfg.Anchors := [akTop, akRight];
  BtnAiCfg.SetBounds(1062, 17, 122, 34);
  BtnAiCfg.OnClick := @OnAiConfigClick;

  BtnApprove := TButton.Create(Self);
  BtnApprove.Parent := Head;
  BtnApprove.Caption := 'Validar e Publicar';
  BtnApprove.Anchors := [akTop, akRight];
  BtnApprove.SetBounds(918, 17, 136, 34);
  BtnApprove.OnClick := @OnValidatePublishClick;

  BtnSaveDraft := TButton.Create(Self);
  BtnSaveDraft.Parent := Head;
  BtnSaveDraft.Caption := 'Salvar Rascunho';
  BtnSaveDraft.Anchors := [akTop, akRight];
  BtnSaveDraft.SetBounds(786, 17, 124, 34);
  BtnSaveDraft.OnClick := @OnSaveDraftClick;

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
  Sidebar.Width := 250;
  Sidebar.BevelOuter := bvNone;
  Sidebar.Color := $00EFEFEF;
  Sidebar.ParentBackground := False;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := Sidebar;
  BtnOpen.Caption := 'Abrir producao...';
  BtnOpen.SetBounds(12, 14, 226, 34);
  BtnOpen.OnClick := @OnOpenProdClick;

  FSideInfoLabel := TLabel.Create(Self);
  FSideInfoLabel.Parent := Sidebar;
  FSideInfoLabel.WordWrap := True;
  FSideInfoLabel.SetBounds(12, 58, 226, 90);
  FSideInfoLabel.Caption := 'Projeto: (nenhum)';

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'REVISOES DO ROTEIRO (duplo clique)';
  L.Font.Style := [fsBold];
  L.SetBounds(12, 158, 226, 18);

  FRevList := TListBox.Create(Self);
  FRevList.Parent := Sidebar;
  FRevList.Anchors := [akLeft, akTop, akRight, akBottom];
  FRevList.SetBounds(12, 180, 226, 460);
  FRevList.OnDblClick := @OnRevListDblClick;

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;

  TabSinopse := TTabSheet.Create(FPageControl);
  TabSinopse.PageControl := FPageControl;
  TabSinopse.Caption := 'Sinopse & IA';

  TabScenes := TTabSheet.Create(FPageControl);
  TabScenes.PageControl := FPageControl;
  TabScenes.Caption := 'Cenas & Roteiro';

  TabChars := TTabSheet.Create(FPageControl);
  TabChars.PageControl := FPageControl;
  TabChars.Caption := 'Mapa de Personagens';

  TabLog := TTabSheet.Create(FPageControl);
  TabLog.PageControl := FPageControl;
  TabLog.Caption := 'Log Operacional';

  // Tab Sinopse
  L := TLabel.Create(Self);
  L.Parent := TabSinopse;
  L.Caption := 'Titulo provisorio:';
  L.SetBounds(16, 16, 140, 18);
  FTitleEdit := TEdit.Create(Self);
  FTitleEdit.Parent := TabSinopse;
  FTitleEdit.SetBounds(16, 36, 420, 26);

  L := TLabel.Create(Self);
  L.Parent := TabSinopse;
  L.Caption := 'Genero:';
  L.SetBounds(454, 16, 100, 18);
  FGenreEdit := TEdit.Create(Self);
  FGenreEdit.Parent := TabSinopse;
  FGenreEdit.SetBounds(454, 36, 220, 26);
  FGenreEdit.Text := 'Drama / Ficao';

  L := TLabel.Create(Self);
  L.Parent := TabSinopse;
  L.Caption := 'Duracao-alvo (min):';
  L.SetBounds(692, 16, 140, 18);
  FTargetMinEdit := TEdit.Create(Self);
  FTargetMinEdit.Parent := TabSinopse;
  FTargetMinEdit.SetBounds(692, 36, 110, 26);
  FTargetMinEdit.Text := '10';

  L := TLabel.Create(Self);
  L.Parent := TabSinopse;
  L.Caption := 'Sinopse e premissas:';
  L.SetBounds(16, 74, 240, 18);
  FSynopsisMemo := TMemo.Create(Self);
  FSynopsisMemo.Parent := TabSinopse;
  FSynopsisMemo.ScrollBars := ssVertical;
  FSynopsisMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  FSynopsisMemo.SetBounds(16, 94, 886, 430);

  L := TLabel.Create(Self);
  L.Parent := TabSinopse;
  L.Caption := 'Instrucoes adicionais para IA (opcional):';
  L.Anchors := [akLeft, akBottom];
  L.SetBounds(16, 534, 300, 18);
  FAiPromptEdit := TEdit.Create(Self);
  FAiPromptEdit.Parent := TabSinopse;
  FAiPromptEdit.Anchors := [akLeft, akRight, akBottom];
  FAiPromptEdit.SetBounds(16, 554, 650, 26);

  BtnGenAi := TButton.Create(Self);
  BtnGenAi.Parent := TabSinopse;
  BtnGenAi.Caption := 'Gerar Roteiro com IA';
  BtnGenAi.Anchors := [akRight, akBottom];
  BtnGenAi.SetBounds(678, 550, 224, 34);
  BtnGenAi.OnClick := @OnGenerateAiClick;

  // Tab Cenas
  FScenesGrid := TStringGrid.Create(Self);
  FScenesGrid.Parent := TabScenes;
  FScenesGrid.Align := alTop;
  FScenesGrid.Height := 230;
  FScenesGrid.FixedCols := 0;
  FScenesGrid.FixedRows := 1;
  FScenesGrid.ColCount := 7;
  FScenesGrid.RowCount := 2;
  FScenesGrid.Options := FScenesGrid.Options + [goRowSelect, goColSizing];
  FScenesGrid.Cells[0, 0] := 'ID';
  FScenesGrid.Cells[1, 0] := 'Ordem';
  FScenesGrid.Cells[2, 0] := 'Cena / Cabecalho';
  FScenesGrid.Cells[3, 0] := 'Local';
  FScenesGrid.Cells[4, 0] := 'Periodo';
  FScenesGrid.Cells[5, 0] := 'Dur (s)';
  FScenesGrid.Cells[6, 0] := 'Personagens';
  FScenesGrid.ColWidths[0] := 110;
  FScenesGrid.ColWidths[1] := 55;
  FScenesGrid.ColWidths[2] := 230;
  FScenesGrid.ColWidths[3] := 150;
  FScenesGrid.ColWidths[4] := 90;
  FScenesGrid.ColWidths[5] := 65;
  FScenesGrid.ColWidths[6] := 180;
  FScenesGrid.OnSelection := @OnScenesGridSelection;

  DetailPanel := TPanel.Create(Self);
  DetailPanel.Parent := TabScenes;
  DetailPanel.Align := alClient;
  DetailPanel.BevelOuter := bvNone;

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Cabecalho:'; L.SetBounds(12, 10, 80, 18);
  FSceneHeadingEdit := TEdit.Create(Self); FSceneHeadingEdit.Parent := DetailPanel; FSceneHeadingEdit.SetBounds(100, 6, 300, 24);
  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Local:'; L.SetBounds(412, 10, 50, 18);
  FSceneLocEdit := TEdit.Create(Self); FSceneLocEdit.Parent := DetailPanel; FSceneLocEdit.SetBounds(464, 6, 170, 24);
  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Periodo:'; L.SetBounds(644, 10, 60, 18);
  FSceneTimeEdit := TEdit.Create(Self); FSceneTimeEdit.Parent := DetailPanel; FSceneTimeEdit.SetBounds(706, 6, 100, 24);
  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Dur(s):'; L.SetBounds(816, 10, 50, 18);
  FSceneDurEdit := TEdit.Create(Self); FSceneDurEdit.Parent := DetailPanel; FSceneDurEdit.SetBounds(866, 6, 50, 24);

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Clima:'; L.SetBounds(12, 40, 60, 18);
  FSceneMoodEdit := TEdit.Create(Self); FSceneMoodEdit.Parent := DetailPanel; FSceneMoodEdit.SetBounds(100, 36, 170, 24);
  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Personagens:'; L.SetBounds(280, 40, 86, 18);
  FSceneCharsEdit := TEdit.Create(Self); FSceneCharsEdit.Parent := DetailPanel; FSceneCharsEdit.SetBounds(368, 36, 190, 24);
  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Objetos:'; L.SetBounds(568, 40, 60, 18);
  FSceneObjectsEdit := TEdit.Create(Self); FSceneObjectsEdit.Parent := DetailPanel; FSceneObjectsEdit.SetBounds(628, 36, 140, 24);
  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Figurinos:'; L.SetBounds(776, 40, 65, 18);
  FSceneCostumesEdit := TEdit.Create(Self); FSceneCostumesEdit.Parent := DetailPanel; FSceneCostumesEdit.SetBounds(842, 36, 120, 24);

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Acao / Descricao da cena:'; L.SetBounds(12, 68, 220, 18);
  FSceneActionMemo := TMemo.Create(Self); FSceneActionMemo.Parent := DetailPanel;
  FSceneActionMemo.ScrollBars := ssVertical; FSceneActionMemo.SetBounds(12, 88, 450, 220);

  L := TLabel.Create(Self); L.Parent := DetailPanel; L.Caption := 'Dialogos (Personagem: fala):'; L.SetBounds(474, 68, 240, 18);
  FSceneDialogueMemo := TMemo.Create(Self); FSceneDialogueMemo.Parent := DetailPanel;
  FSceneDialogueMemo.ScrollBars := ssVertical; FSceneDialogueMemo.SetBounds(474, 88, 444, 220);

  BtnAddScene := TButton.Create(Self); BtnAddScene.Parent := DetailPanel;
  BtnAddScene.Caption := '+ Nova Cena'; BtnAddScene.SetBounds(12, 320, 120, 30);
  BtnAddScene.OnClick := @OnAddSceneClick;

  BtnSaveScene := TButton.Create(Self); BtnSaveScene.Parent := DetailPanel;
  BtnSaveScene.Caption := 'Aplicar Edicao na Cena'; BtnSaveScene.SetBounds(142, 320, 175, 30);
  BtnSaveScene.OnClick := @OnSaveSceneEditClick;

  BtnRewriteScene := TButton.Create(Self); BtnRewriteScene.Parent := DetailPanel;
  BtnRewriteScene.Caption := 'Reescrever Cena com IA'; BtnRewriteScene.SetBounds(326, 320, 195, 30);
  BtnRewriteScene.OnClick := @OnRewriteSceneAiClick;

  // Tab Personagens
  BtnExtract := TButton.Create(Self);
  BtnExtract.Parent := TabChars;
  BtnExtract.Caption := 'Extrair Mapa Textual de Personagens e Figurinos';
  BtnExtract.SetBounds(14, 12, 340, 32);
  BtnExtract.OnClick := @OnExtractCharsClick;

  FCharsGrid := TStringGrid.Create(Self);
  FCharsGrid.Parent := TabChars;
  FCharsGrid.Anchors := [akLeft, akTop, akRight, akBottom];
  FCharsGrid.SetBounds(14, 54, 892, 540);
  FCharsGrid.FixedCols := 0;
  FCharsGrid.FixedRows := 1;
  FCharsGrid.ColCount := 5;
  FCharsGrid.RowCount := 2;
  FCharsGrid.Options := FCharsGrid.Options + [goRowSelect, goColSizing];
  FCharsGrid.Cells[0, 0] := 'Character ID';
  FCharsGrid.Cells[1, 0] := 'Nome';
  FCharsGrid.Cells[2, 0] := 'Descricao Fisica';
  FCharsGrid.Cells[3, 0] := 'Figurinos';
  FCharsGrid.Cells[4, 0] := 'Cenas';
  FCharsGrid.ColWidths[0] := 130;
  FCharsGrid.ColWidths[1] := 160;
  FCharsGrid.ColWidths[2] := 260;
  FCharsGrid.ColWidths[3] := 210;
  FCharsGrid.ColWidths[4] := 110;

  // Tab Log
  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := TabLog;
  FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssBoth;
end;

procedure TMscriptMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
end;

procedure TMscriptMainForm.LoadProductionAndRevision(const ProdRoot, ProjId, RevId: string);
var
  ErrMsg: string;
begin
  if not ResolveAppProject(ProdRoot, 1, ProjId, RevId, FProd, FProj,
    FProjectDir, FCurrentRevId, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  FAi.LoadForProduction(FProd.RootDir);
  FTitleEdit.Text := FProd.Title;
  LoadScriptFromRevision(FCurrentRevId);
  RefreshUI;
  LogMsg('Producao aberta: ' + FProd.Title + ' | Revisao: ' + FCurrentRevId);
end;

procedure TMscriptMainForm.LoadScriptFromRevision(const RevId: string);
var
  ScriptPath, Content: string;
  Data: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  Item: TJSONObject;
  I: Integer;
  RevInfo: TMmpRevisionInfo;
begin
  SetLength(FScenes, 0);
  SetLength(FChars, 0);
  FValidated := False;
  FCurrentRevId := RevId;

  if FindRevisionInProject(FProj, RevId, RevInfo) then
    FValidated := SameText(RevInfo.State, 'approved');

  ScriptPath := IncludeTrailingPathDelimiter(FProjectDir) + 'revisions' +
    PathDelim + RevId + PathDelim + 'scripts' + PathDelim + 'roteiro.json';

  if not FileExists(ScriptPath) then Exit;
  if not ReadTextFileUtf8(ScriptPath, Content) then Exit;
  try
    Data := GetJSON(Content);
    if not (Data is TJSONObject) then begin Data.Free; Exit; end;
    Obj := TJSONObject(Data);
    try
      if Obj.Get('title', '') <> '' then FTitleEdit.Text := Obj.Get('title', '');
      if Obj.Get('genre', '') <> '' then FGenreEdit.Text := Obj.Get('genre', '');
      FTargetMinEdit.Text := IntToStr(Obj.Get('target_minutes', 10));
      FSynopsisMemo.Text := Obj.Get('synopsis', '');
      FValidated := Obj.Get('validated', FValidated);

      if Obj.Find('scenes') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('scenes'));
        SetLength(FScenes, Arr.Count);
        for I := 0 to Arr.Count - 1 do
        begin
          if Arr.Items[I] is TJSONObject then
          begin
            Item := TJSONObject(Arr.Items[I]);
            FScenes[I].SceneId := Item.Get('scene_id', GenerateMmpId('sc'));
            FScenes[I].Sequence := Item.Get('sequence', I + 1);
            FScenes[I].Heading := Item.Get('heading', '');
            FScenes[I].LocationRef := Item.Get('location_ref', '');
            FScenes[I].TimeOfDay := Item.Get('time_of_day', 'DIA');
            FScenes[I].Mood := Item.Get('mood', '');
            FScenes[I].DurationSec := Item.Get('estimated_duration', 30);
            FScenes[I].ActionText := Item.Get('action', '');
            FScenes[I].DialogueText := Item.Get('dialogue_text', '');
            FScenes[I].CharactersCsv := Item.Get('characters_csv', '');
            FScenes[I].ObjectsCsv := Item.Get('objects_csv', '');
            FScenes[I].CostumesCsv := Item.Get('costumes_csv', '');
          end;
        end;
      end;

      if Obj.Find('characters') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('characters'));
        SetLength(FChars, Arr.Count);
        for I := 0 to Arr.Count - 1 do
        begin
          if Arr.Items[I] is TJSONObject then
          begin
            Item := TJSONObject(Arr.Items[I]);
            FChars[I].CharacterId := Item.Get('character_id', GenerateMmpId('ch'));
            FChars[I].Name := Item.Get('name', '');
            FChars[I].PhysicalDesc := Item.Get('description', '');
            FChars[I].WardrobeDesc := Item.Get('wardrobe', '');
            FChars[I].ScenesCsv := Item.Get('scenes_csv', '');
          end;
        end;
      end;
    finally
      Obj.Free;
    end;
  except
    on E: Exception do
      LogMsg('Erro ao carregar roteiro.json: ' + E.Message);
  end;
end;

procedure TMscriptMainForm.RefreshUI;
var
  I: Integer;
begin
  if FProd.Loaded then
  begin
    FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
    if FValidated then
      FHeaderRevLabel.Caption := 'Revisao: ' + FCurrentRevId + '  |  APROVADO'
    else
      FHeaderRevLabel.Caption := 'Revisao: ' + FCurrentRevId + '  |  Rascunho (nao aprovado)';
    FSideInfoLabel.Caption := 'Project ID: ' + FProj.ProjectId + LineEnding +
      'Ativa: ' + FProj.ActiveRevision + LineEnding +
      'Cenas: ' + IntToStr(Length(FScenes));
    FRevList.Items.Clear;
    for I := 0 to High(FProj.Revisions) do
      FRevList.Items.Add(FProj.Revisions[I].RevisionId + ' [' + FProj.Revisions[I].State + ']');
  end;
  RefreshScenesGrid;
  RefreshCharsGrid;
end;

procedure TMscriptMainForm.RefreshScenesGrid;
var
  I, Row: Integer;
begin
  if Length(FScenes) = 0 then
  begin
    FScenesGrid.RowCount := 2;
    for I := 0 to FScenesGrid.ColCount - 1 do
      FScenesGrid.Cells[I, 1] := '';
    FSelectedScene := -1;
    Exit;
  end;

  FScenesGrid.RowCount := Length(FScenes) + 1;
  for I := 0 to High(FScenes) do
  begin
    Row := I + 1;
    FScenesGrid.Cells[0, Row] := FScenes[I].SceneId;
    FScenesGrid.Cells[1, Row] := IntToStr(FScenes[I].Sequence);
    FScenesGrid.Cells[2, Row] := FScenes[I].Heading;
    FScenesGrid.Cells[3, Row] := FScenes[I].LocationRef;
    FScenesGrid.Cells[4, Row] := FScenes[I].TimeOfDay;
    FScenesGrid.Cells[5, Row] := IntToStr(FScenes[I].DurationSec);
    FScenesGrid.Cells[6, Row] := FScenes[I].CharactersCsv;
  end;
  if (FSelectedScene < 0) or (FSelectedScene > High(FScenes)) then
    FSelectedScene := 0;
  FScenesGrid.Row := FSelectedScene + 1;
  LoadSceneToEditor(FSelectedScene);
end;

procedure TMscriptMainForm.LoadSceneToEditor(Idx: Integer);
begin
  if (Idx < 0) or (Idx > High(FScenes)) then Exit;
  FSceneHeadingEdit.Text := FScenes[Idx].Heading;
  FSceneLocEdit.Text := FScenes[Idx].LocationRef;
  FSceneTimeEdit.Text := FScenes[Idx].TimeOfDay;
  FSceneMoodEdit.Text := FScenes[Idx].Mood;
  FSceneDurEdit.Text := IntToStr(FScenes[Idx].DurationSec);
  FSceneCharsEdit.Text := FScenes[Idx].CharactersCsv;
  FSceneObjectsEdit.Text := FScenes[Idx].ObjectsCsv;
  FSceneCostumesEdit.Text := FScenes[Idx].CostumesCsv;
  FSceneActionMemo.Text := FScenes[Idx].ActionText;
  FSceneDialogueMemo.Text := FScenes[Idx].DialogueText;
end;

procedure TMscriptMainForm.SaveEditorToScene;
begin
  if (FSelectedScene < 0) or (FSelectedScene > High(FScenes)) then Exit;
  FScenes[FSelectedScene].Heading := Trim(FSceneHeadingEdit.Text);
  FScenes[FSelectedScene].LocationRef := Trim(FSceneLocEdit.Text);
  FScenes[FSelectedScene].TimeOfDay := Trim(FSceneTimeEdit.Text);
  FScenes[FSelectedScene].Mood := Trim(FSceneMoodEdit.Text);
  FScenes[FSelectedScene].DurationSec := StrToIntDef(FSceneDurEdit.Text, 30);
  FScenes[FSelectedScene].CharactersCsv := Trim(FSceneCharsEdit.Text);
  FScenes[FSelectedScene].ObjectsCsv := Trim(FSceneObjectsEdit.Text);
  FScenes[FSelectedScene].CostumesCsv := Trim(FSceneCostumesEdit.Text);
  FScenes[FSelectedScene].ActionText := FSceneActionMemo.Text;
  FScenes[FSelectedScene].DialogueText := FSceneDialogueMemo.Text;
  FValidated := False;
end;

procedure TMscriptMainForm.ExtractCharacterMap;
var
  I, J, K, N: Integer;
  Parts: TStringList;
  NameTrim: string;
  FoundIdx: Integer;
begin
  SetLength(FChars, 0);
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ',';
    Parts.StrictDelimiter := True;
    for I := 0 to High(FScenes) do
    begin
      Parts.DelimitedText := FScenes[I].CharactersCsv;
      for J := 0 to Parts.Count - 1 do
      begin
        NameTrim := Trim(Parts[J]);
        if NameTrim = '' then Continue;
        FoundIdx := -1;
        for K := 0 to High(FChars) do
          if SameText(FChars[K].Name, NameTrim) then
          begin
            FoundIdx := K;
            Break;
          end;
        if FoundIdx < 0 then
        begin
          N := Length(FChars);
          SetLength(FChars, N + 1);
          FChars[N].CharacterId := GenerateMmpId('ch');
          FChars[N].Name := NameTrim;
          FChars[N].PhysicalDesc := 'Extraido do roteiro (' + FScenes[I].Mood + ')';
          FChars[N].WardrobeDesc := FScenes[I].CostumesCsv;
          FChars[N].ScenesCsv := FScenes[I].SceneId;
        end
        else
        begin
          if Pos(FScenes[I].SceneId, FChars[FoundIdx].ScenesCsv) = 0 then
            FChars[FoundIdx].ScenesCsv := FChars[FoundIdx].ScenesCsv + ', ' + FScenes[I].SceneId;
          if (FScenes[I].CostumesCsv <> '') and
             (Pos(FScenes[I].CostumesCsv, FChars[FoundIdx].WardrobeDesc) = 0) then
            FChars[FoundIdx].WardrobeDesc := FChars[FoundIdx].WardrobeDesc + '; ' + FScenes[I].CostumesCsv;
        end;
      end;
    end;
  finally
    Parts.Free;
  end;
  RefreshCharsGrid;
end;

procedure TMscriptMainForm.RefreshCharsGrid;
var
  I, Row: Integer;
begin
  if Length(FChars) = 0 then
  begin
    FCharsGrid.RowCount := 2;
    for I := 0 to FCharsGrid.ColCount - 1 do
      FCharsGrid.Cells[I, 1] := '';
    Exit;
  end;
  FCharsGrid.RowCount := Length(FChars) + 1;
  for I := 0 to High(FChars) do
  begin
    Row := I + 1;
    FCharsGrid.Cells[0, Row] := FChars[I].CharacterId;
    FCharsGrid.Cells[1, Row] := FChars[I].Name;
    FCharsGrid.Cells[2, Row] := FChars[I].PhysicalDesc;
    FCharsGrid.Cells[3, Row] := FChars[I].WardrobeDesc;
    FCharsGrid.Cells[4, Row] := FChars[I].ScenesCsv;
  end;
end;

procedure TMscriptMainForm.GenerateOfflineTemplateScenes;
begin
  SetLength(FScenes, 3);
  FScenes[0].SceneId := GenerateMmpId('sc');
  FScenes[0].Sequence := 1;
  FScenes[0].Heading := 'INT. ESCRITORIO - NOITE';
  FScenes[0].LocationRef := 'Escritorio';
  FScenes[0].TimeOfDay := 'NOITE';
  FScenes[0].Mood := 'Misterioso';
  FScenes[0].DurationSec := 45;
  FScenes[0].CharactersCsv := 'Protagonista';
  FScenes[0].ObjectsCsv := 'Carta antiga, Lanterna';
  FScenes[0].CostumesCsv := 'Casaco escuro';
  FScenes[0].ActionText := 'Baseado na sinopse: ' + Copy(FSynopsisMemo.Text, 1, 200);
  FScenes[0].DialogueText := 'Protagonista: Preciso descobrir quem enviou isto.';

  FScenes[1].SceneId := GenerateMmpId('sc');
  FScenes[1].Sequence := 2;
  FScenes[1].Heading := 'EXT. RUA CENTRAL - AMANHECER';
  FScenes[1].LocationRef := 'Rua Central';
  FScenes[1].TimeOfDay := 'AMANHECER';
  FScenes[1].Mood := 'Tenso';
  FScenes[1].DurationSec := 60;
  FScenes[1].CharactersCsv := 'Protagonista, Aliado';
  FScenes[1].ObjectsCsv := 'Chave, Pasta';
  FScenes[1].CostumesCsv := 'Casaco escuro, Jaqueta';
  FScenes[1].ActionText := 'Encontro rapido na esquina vazia.';
  FScenes[1].DialogueText := 'Aliado: O arquivo original foi movido.';

  FScenes[2].SceneId := GenerateMmpId('sc');
  FScenes[2].Sequence := 3;
  FScenes[2].Heading := 'INT. ESTUDIO - DIA';
  FScenes[2].LocationRef := 'Estudio';
  FScenes[2].TimeOfDay := 'DIA';
  FScenes[2].Mood := 'Resolucao';
  FScenes[2].DurationSec := 50;
  FScenes[2].CharactersCsv := 'Protagonista, Aliado';
  FScenes[2].ObjectsCsv := 'Projetor';
  FScenes[2].CostumesCsv := 'Casaco escuro, Jaqueta';
  FScenes[2].ActionText := 'Eles revelam a verdade na tela.';
  FScenes[2].DialogueText := 'Protagonista: Agora a historia esta completa.';
end;

procedure TMscriptMainForm.PopulateFromAiJson(const RawJson: string);
var
  Cleaned: string;
  Data: TJSONData;
  Obj, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Cleaned := StripMarkdownJsonFence(RawJson);
  Data := GetJSON(Cleaned);
  if not (Data is TJSONObject) then begin Data.Free; raise Exception.Create('JSON raiz invalido'); end;
  Obj := TJSONObject(Data);
  try
    if Obj.Find('scenes') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('scenes'));
      SetLength(FScenes, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := TJSONObject(Arr.Items[I]);
        FScenes[I].SceneId := GenerateMmpId('sc');
        FScenes[I].Sequence := I + 1;
        FScenes[I].Heading := Item.Get('heading', 'CENA ' + IntToStr(I + 1));
        FScenes[I].LocationRef := Item.Get('location', 'Local');
        FScenes[I].TimeOfDay := Item.Get('time_of_day', 'DIA');
        FScenes[I].Mood := Item.Get('mood', 'Neutro');
        FScenes[I].DurationSec := Item.Get('estimated_duration', 40);
        FScenes[I].CharactersCsv := Item.Get('characters', '');
        FScenes[I].ObjectsCsv := Item.Get('objects', '');
        FScenes[I].CostumesCsv := Item.Get('costumes', '');
        FScenes[I].ActionText := Item.Get('action', '');
        FScenes[I].DialogueText := Item.Get('dialogue', '');
      end;
    end;
  finally
    Obj.Free;
  end;
end;

function TMscriptMainForm.BuildScriptJsonText: string;
var
  Root, SObj, CObj: TJSONObject;
  SArr, CArr: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.mscript.script/1');
    Root.Add('title', FTitleEdit.Text);
    Root.Add('genre', FGenreEdit.Text);
    Root.Add('target_minutes', StrToIntDef(FTargetMinEdit.Text, 10));
    Root.Add('synopsis', FSynopsisMemo.Text);
    Root.Add('validated', FValidated);
    Root.Add('updated_at', CurrentIsoUtc);

    SArr := TJSONArray.Create;
    for I := 0 to High(FScenes) do
    begin
      SObj := TJSONObject.Create;
      SObj.Add('scene_id', FScenes[I].SceneId);
      SObj.Add('sequence', FScenes[I].Sequence);
      SObj.Add('heading', FScenes[I].Heading);
      SObj.Add('location_ref', FScenes[I].LocationRef);
      SObj.Add('time_of_day', FScenes[I].TimeOfDay);
      SObj.Add('mood', FScenes[I].Mood);
      SObj.Add('estimated_duration', FScenes[I].DurationSec);
      SObj.Add('characters_csv', FScenes[I].CharactersCsv);
      SObj.Add('objects_csv', FScenes[I].ObjectsCsv);
      SObj.Add('costumes_csv', FScenes[I].CostumesCsv);
      SObj.Add('action', FScenes[I].ActionText);
      SObj.Add('dialogue_text', FScenes[I].DialogueText);
      SArr.Add(SObj);
    end;
    Root.Add('scenes', SArr);

    CArr := TJSONArray.Create;
    for I := 0 to High(FChars) do
    begin
      CObj := TJSONObject.Create;
      CObj.Add('character_id', FChars[I].CharacterId);
      CObj.Add('name', FChars[I].Name);
      CObj.Add('description', FChars[I].PhysicalDesc);
      CObj.Add('wardrobe', FChars[I].WardrobeDesc);
      CObj.Add('scenes_csv', FChars[I].ScenesCsv);
      CArr.Add(CObj);
    end;
    Root.Add('characters', CArr);

    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

function TMscriptMainForm.BuildScriptMarkdownText: string;
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('# ' + FTitleEdit.Text);
    SL.Add('Genero: ' + FGenreEdit.Text);
    SL.Add('');
    SL.Add('## Sinopse');
    SL.Add(FSynopsisMemo.Text);
    SL.Add('');
    for I := 0 to High(FScenes) do
    begin
      SL.Add(Format('## Cena %d (%s) - %s', [FScenes[I].Sequence, FScenes[I].SceneId, FScenes[I].Heading]));
      SL.Add('Local: ' + FScenes[I].LocationRef + ' | Periodo: ' + FScenes[I].TimeOfDay +
        ' | Clima: ' + FScenes[I].Mood + ' | Duracao: ' + IntToStr(FScenes[I].DurationSec) + 's');
      SL.Add('Personagens: ' + FScenes[I].CharactersCsv);
      SL.Add('');
      SL.Add(FScenes[I].ActionText);
      SL.Add('');
      SL.Add(FScenes[I].DialogueText);
      SL.Add('');
    end;
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TMscriptMainForm.OnOpenProdClick(Sender: TObject);
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

procedure TMscriptMainForm.OnAiConfigClick(Sender: TObject);
begin
  if FAi.ShowConfigDialog(Self) then
    LogMsg('Configuracao de IA atualizada: ' + FAi.ProviderDisplayName);
end;

procedure TMscriptMainForm.OnGenerateAiClick(Sender: TObject);
var
  SysPrompt, UserPrompt, Resp, Err: string;
begin
  if Trim(FSynopsisMemo.Text) = '' then
  begin
    MessageDlg('Escreva uma sinopse antes de gerar o roteiro.', mtWarning, [mbOK], 0);
    Exit;
  end;

  SysPrompt := 'Voce e um roteirista profissional. Responda APENAS com JSON valido no formato: ' +
    '{"scenes":[{"heading":"...","location":"...","time_of_day":"DIA|NOITE","mood":"...",' +
    '"estimated_duration":45,"characters":"Nome1, Nome2","objects":"...","costumes":"...",' +
    '"action":"...","dialogue":"Nome1: fala"}]}.';
  UserPrompt := 'Titulo: ' + FTitleEdit.Text + LineEnding +
    'Genero: ' + FGenreEdit.Text + LineEnding +
    'Duracao alvo (min): ' + FTargetMinEdit.Text + LineEnding +
    'Sinopse: ' + FSynopsisMemo.Text + LineEnding +
    'Instrucoes extras: ' + FAiPromptEdit.Text;

  if FAi.IsConfigured then
  begin
    LogMsg('Solicitando roteiro via ' + FAi.ProviderDisplayName + '...');
    Application.ProcessMessages;
    if FAi.Ask(SysPrompt, UserPrompt, Resp, Err) then
    begin
      try
        PopulateFromAiJson(Resp);
        FValidated := False;
        ExtractCharacterMap;
        RefreshUI;
        FPageControl.ActivePageIndex := 1;
        LogMsg('Roteiro gerado pela IA (rascunho, aguardando validacao humana).');
        Exit;
      except
        on E: Exception do
          LogMsg('Resposta da IA nao veio em JSON estruturado (' + E.Message + ').');
      end;
    end
    else
      LogMsg('Falha na IA: ' + Err);
  end;

  if MessageDlg('IA nao configurada ou indisponivel. Deseja gerar um esboco estruturado local a partir da sinopse?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    GenerateOfflineTemplateScenes;
    FValidated := False;
    ExtractCharacterMap;
    RefreshUI;
    FPageControl.ActivePageIndex := 1;
    LogMsg('Esboco estruturado local criado (rascunho).');
  end;
end;

procedure TMscriptMainForm.OnRewriteSceneAiClick(Sender: TObject);
var
  Instr, Resp, Err: string;
begin
  if (FSelectedScene < 0) or (FSelectedScene > High(FScenes)) then Exit;
  Instr := 'Melhore a tensao dramatica e dialogos';
  if not InputQuery('Reescrever Cena com IA', 'Instrucao de reescrita:', Instr) then Exit;

  if not FAi.IsConfigured then
  begin
    MessageDlg('Configure o provedor de IA primeiro em "Configurar IA...".', mtInformation, [mbOK], 0);
    Exit;
  end;

  if FAi.Ask('Reescreva a cena mantendo clareza cinematografica. Devolva acao e dialogos em texto.',
    'Cena: ' + FSceneHeadingEdit.Text + LineEnding +
    'Acao atual: ' + FSceneActionMemo.Text + LineEnding +
    'Dialogos: ' + FSceneDialogueMemo.Text + LineEnding +
    'Instrucao: ' + Instr, Resp, Err) then
  begin
    FSceneActionMemo.Text := Resp;
    SaveEditorToScene;
    RefreshScenesGrid;
    LogMsg('Cena ' + FScenes[FSelectedScene].SceneId + ' reescrita via IA.');
  end
  else
    MessageDlg('Erro na IA: ' + Err, mtError, [mbOK], 0);
end;

procedure TMscriptMainForm.OnAddSceneClick(Sender: TObject);
var
  N: Integer;
begin
  N := Length(FScenes);
  SetLength(FScenes, N + 1);
  FScenes[N].SceneId := GenerateMmpId('sc');
  FScenes[N].Sequence := N + 1;
  FScenes[N].Heading := 'INT. NOVO LOCAL - DIA';
  FScenes[N].LocationRef := 'Novo Local';
  FScenes[N].TimeOfDay := 'DIA';
  FScenes[N].Mood := 'Neutro';
  FScenes[N].DurationSec := 30;
  FSelectedScene := N;
  FValidated := False;
  RefreshScenesGrid;
end;

procedure TMscriptMainForm.OnSaveSceneEditClick(Sender: TObject);
begin
  SaveEditorToScene;
  RefreshScenesGrid;
  LogMsg('Alteracoes manuais aplicadas na cena.');
end;

procedure TMscriptMainForm.OnScenesGridSelection(Sender: TObject; aCol, aRow: Integer);
begin
  if (aRow >= 1) and (aRow <= Length(FScenes)) then
  begin
    FSelectedScene := aRow - 1;
    LoadSceneToEditor(FSelectedScene);
  end;
end;

procedure TMscriptMainForm.OnExtractCharsClick(Sender: TObject);
begin
  SaveEditorToScene;
  ExtractCharacterMap;
  LogMsg('Mapa textual de personagens extraido (' + IntToStr(Length(FChars)) + ' personagens).');
end;

procedure TMscriptMainForm.SaveRevision(const NewState: string);
var
  PrepRev, RevDir, NewRev, ErrMsg: string;
  Arts: array of TMmpArtifactInput;
  Srcs: array of TMmpSourceRef;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra uma producao primeiro.', mtWarning, [mbOK], 0);
    Exit;
  end;
  SaveEditorToScene;
  ExtractCharacterMap;
  FValidated := (NewState = 'approved');

  if not PrepareNextRevisionDir(FProj.ProjectFilePath, PrepRev, RevDir) then
  begin
    MessageDlg('Falha ao preparar diretorio de revisao.', mtError, [mbOK], 0);
    Exit;
  end;

  AtomicWriteTextFile(RevDir + PathDelim + 'scripts' + PathDelim + 'roteiro.json',
    BuildScriptJsonText, False);
  AtomicWriteTextFile(RevDir + PathDelim + 'scripts' + PathDelim + 'roteiro.md',
    BuildScriptMarkdownText, False);

  SetLength(Srcs, 0);
  SetLength(Arts, 2);
  Arts[0].ArtifactId := GenerateMmpId('a');
  Arts[0].Kind := 'script.scene';
  Arts[0].RelUri := 'scripts/roteiro.json';
  Arts[0].MimeType := 'application/json';
  Arts[0].Status := NewState;

  Arts[1].ArtifactId := GenerateMmpId('a');
  Arts[1].Kind := 'script.character';
  Arts[1].RelUri := 'scripts/roteiro.md';
  Arts[1].MimeType := 'text/markdown';
  Arts[1].Status := NewState;

  if PublishProjectRevision(FProd.ProductionId, FProj.ProjectFilePath, 'MScript',
    FCurrentRevId, NewState, '', Srcs, Arts, NewRev, ErrMsg, PrepRev) then
  begin
    LogMsg('Revisao publicada (' + NewState + '): ' + NewRev);
    LoadProductionAndRevision(FProd.RootDir, FProj.ProjectId, NewRev);
  end
  else
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
end;

procedure TMscriptMainForm.OnSaveDraftClick(Sender: TObject);
begin
  SaveRevision('draft');
end;

procedure TMscriptMainForm.OnValidatePublishClick(Sender: TObject);
begin
  if Length(FScenes) = 0 then
  begin
    MessageDlg('Adicione ou gere ao menos uma cena antes de validar.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Confirmar validacao editorial desta revisao do roteiro?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  SaveRevision('approved');
end;

procedure TMscriptMainForm.OnRevListDblClick(Sender: TObject);
var
  S: string;
  P: SizeInt;
begin
  if FRevList.ItemIndex < 0 then Exit;
  S := FRevList.Items[FRevList.ItemIndex];
  P := Pos(' ', S);
  if P > 1 then S := Copy(S, 1, P - 1);
  LoadScriptFromRevision(S);
  RefreshUI;
  LogMsg('Revisao carregada para leitura/edicao: ' + S);
end;

function RunMScriptHeadlessEvent(const Args: TMMLaunchArgs): Integer;
var
  Prod: TMmpProduction;
  Proj: TMmpProjectRef;
  ProjDir, RevId, ErrMsg, EvtStr, ScriptStr, PrepRev, RevDir, NewRev, ArchivePath: string;
  EvtData, ScriptData: TJSONData;
  EvtObj, ScriptObj, ReqObj, OpObj, SceneObj: TJSONObject;
  OpsArr, ScenesArr: TJSONArray;
  EvtId, SceneId, FieldName, FromTxt, ToTxt, ActionTxt: string;
  I, J: Integer;
  AppliedAny, FoundTarget: Boolean;
  Arts: array of TMmpArtifactInput;
  Srcs: array of TMmpSourceRef;
begin
  Result := EXIT_UNEXPECTED_ERROR;
  if (Args.Production = '') or (Args.EventFile = '') then
  begin
    WriteCliLine('Uso headless: mscript --production <pasta> --headless --event <arquivo>');
    Exit(EXIT_INVALID_ARGS);
  end;
  if not FileExists(Args.EventFile) then Exit(EXIT_NOT_FOUND);
  if not ResolveAppProject(Args.Production, 1, Args.ProjectId, Args.Revision,
    Prod, Proj, ProjDir, RevId, ErrMsg) then
  begin
    WriteCliLine(ErrMsg);
    Exit(EXIT_NOT_FOUND);
  end;

  if not ReadTextFileUtf8(Args.EventFile, EvtStr) then Exit(EXIT_NOT_FOUND);
  EvtData := GetJSON(EvtStr);
  if not (EvtData is TJSONObject) then begin EvtData.Free; Exit(EXIT_INVALID_ARGS); end;
  EvtObj := TJSONObject(EvtData);
  try
    EvtId := EvtObj.Get('event_id', '');
    // Idempotency check across published revisions
    for I := 0 to High(Proj.Revisions) do
    begin
      if SameText(Proj.Revisions[I].ChangeEventId, EvtId) then
      begin
        WriteCliLine('Evento ' + EvtId + ' ja aplicado em ' + Proj.Revisions[I].RevisionId);
        Exit(EXIT_OK);
      end;
    end;

    if not ReadTextFileUtf8(IncludeTrailingPathDelimiter(ProjDir) + 'revisions' +
      PathDelim + RevId + PathDelim + 'scripts' + PathDelim + 'roteiro.json', ScriptStr) then
      Exit(EXIT_NOT_FOUND);

    ScriptData := GetJSON(ScriptStr);
    if not (ScriptData is TJSONObject) then begin ScriptData.Free; Exit(EXIT_INTEGRITY_ERROR); end;
    ScriptObj := TJSONObject(ScriptData);
    try
      AppliedAny := False;
      if (EvtObj.Find('requested_change') is TJSONObject) and
         (ScriptObj.Find('scenes') is TJSONArray) then
      begin
        ReqObj := TJSONObject(EvtObj.Find('requested_change'));
        ScenesArr := TJSONArray(ScriptObj.Find('scenes'));
        if ReqObj.Find('operations') is TJSONArray then
        begin
          OpsArr := TJSONArray(ReqObj.Find('operations'));
          for I := 0 to OpsArr.Count - 1 do
          begin
            OpObj := TJSONObject(OpsArr.Items[I]);
            SceneId := OpObj.Get('scene_id', '');
            FieldName := OpObj.Get('field', 'action');
            FromTxt := OpObj.Get('from', '');
            ToTxt := OpObj.Get('to', OpObj.Get('to_name', ''));
            FoundTarget := False;
            for J := 0 to ScenesArr.Count - 1 do
            begin
              SceneObj := TJSONObject(ScenesArr.Items[J]);
              if (SceneId = '') or SameText(SceneObj.Get('scene_id', ''), SceneId) then
              begin
                ActionTxt := SceneObj.Get(FieldName, '');
                if (FromTxt <> '') and (Pos(FromTxt, ActionTxt) > 0) then
                begin
                  SceneObj.Strings[FieldName] := StringReplace(ActionTxt, FromTxt, ToTxt, [rfReplaceAll]);
                  FoundTarget := True;
                  AppliedAny := True;
                end;
              end;
            end;
            if (FromTxt <> '') and not FoundTarget then
            begin
              WriteCliLine('Mudanca ambigua/nao encontrada: ' + FromTxt);
              Exit(EXIT_EVENT_AMBIGUOUS);
            end;
          end;
        end;
      end;

      if not PrepareNextRevisionDir(Proj.ProjectFilePath, PrepRev, RevDir) then
        Exit(EXIT_UNEXPECTED_ERROR);

      AtomicWriteTextFile(RevDir + PathDelim + 'scripts' + PathDelim + 'roteiro.json',
        ScriptObj.FormatJSON, False);

      SetLength(Srcs, 0);
      SetLength(Arts, 1);
      Arts[0].ArtifactId := GenerateMmpId('a');
      Arts[0].Kind := 'script.scene';
      Arts[0].RelUri := 'scripts/roteiro.json';
      Arts[0].MimeType := 'application/json';
      Arts[0].Status := 'approved';

      if not PublishProjectRevision(Prod.ProductionId, Proj.ProjectFilePath, 'MScript',
        RevId, 'approved', EvtId, Srcs, Arts, NewRev, ErrMsg, PrepRev) then
      begin
        WriteCliLine(ErrMsg);
        Exit(EXIT_UNEXPECTED_ERROR);
      end;

      EvtObj.Strings['status'] := 'published';
      ArchivePath := IncludeTrailingPathDelimiter(Prod.RootDir) + 'shared' + PathDelim +
        'events' + PathDelim + 'archive' + PathDelim + ExtractFileName(Args.EventFile);
      AtomicWriteTextFile(ArchivePath, EvtObj.FormatJSON, False);
      DeleteFile(Args.EventFile);
      AppendJsonLogLine(Prod.RootDir, 'MScript', 'info',
        'Headless patch ' + EvtId + ' aplicado -> ' + NewRev + ' (applied=' + BoolToStr(AppliedAny, True) + ')');
      Result := EXIT_OK;
    finally
      ScriptObj.Free;
    end;
  finally
    EvtObj.Free;
  end;
end;

end.
