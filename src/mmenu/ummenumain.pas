unit ummenumain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, Grids, Process, IniFiles,
  mmpcommon, mmpsettings, ummpprotocol, ummenusettings;

type
  TRecentProduction = record
    Title: string;
    ProductionId: string;
    RootDir: string;
  end;

  TMmenuMainForm = class(TForm)
  private
    FConfigPath: string;
    FDefaultProductionsDir: string;
    FAppPaths: array[1..6] of string;
    FRecents: array of TRecentProduction;
    FProd: TMmpProduction;
    FSettings: TMMSettings;
    FMonitorTimer: TTimer;
    FSelectedProjectIndex: Integer;

    // Header
    FHeaderProdLabel: TLabel;
    FHeaderStatusBadge: TLabel;
    FExeVersionLabel: TLabel;

    // Sidebar
    FActiveProdTitleEdit: TEdit;
    FActiveProdIdEdit: TEdit;
    FActiveProdPathEdit: TEdit;
    FRecentsList: TListBox;
    FSummaryLabel: TLabel;

    // Central Tabs
    FPageControl: TPageControl;
    FTabPortal: TTabSheet;
    FTabProjects: TTabSheet;
    FTabSync: TTabSheet;
    FTabArtifacts: TTabSheet;
    FTabLog: TTabSheet;

    // Portal Cards (1..6)
    FCardPanels: array[1..6] of TPanel;
    FCardProjInfoLabels: array[1..6] of TLabel;
    FCardExeInfoLabels: array[1..6] of TLabel;
    FCardOpenButtons: array[1..6] of TButton;

    // Tab 2: Projects & Revisions
    FProjectsGrid: TStringGrid;
    FRevCombo: TComboBox;
    FRevDetailsMemo: TMemo;
    FBtnOpenProjectRev: TButton;
    FBtnRelinkProject: TButton;

    // Tab 3: Sync & Missing Links
    FSyncSummaryLabel: TLabel;
    FSyncJobsGrid: TStringGrid;
    FBtnGoToFailedApp: TButton;
    FBtnCancelTx: TButton;
    FMissingGrid: TStringGrid;
    FBtnRelinkMissing: TButton;
    FBtnAuditHashes: TButton;

    // Tab 4: Artifacts & Catalog
    FFilterAppCombo: TComboBox;
    FFilterStatusCombo: TComboBox;
    FFilterSearchEdit: TEdit;
    FArtifactsGrid: TStringGrid;
    FBtnVerifyArtifacts: TButton;
    FBtnRebuildCatalog: TButton;

    // Tab 5: Log
    FLogMemo: TMemo;

    // Footer
    FStatusLabel: TLabel;
    FProgressBar: TProgressBar;

    procedure BuildHeader(AParent: TWinControl);
    procedure BuildSidebar(AParent: TWinControl);
    procedure BuildFooter(AParent: TWinControl);
    procedure BuildCenterTabs(AParent: TWinControl);
    procedure BuildPortalTab;
    procedure BuildProjectsTab;
    procedure BuildSyncTab;
    procedure BuildArtifactsTab;
    procedure BuildLogTab;

    procedure LoadConfig;
    procedure SaveConfig;
    procedure AddOrUpdateRecent(const Prod: TMmpProduction);
    procedure RefreshRecentsList;

    procedure LogMsg(const Msg: string);
    procedure SetStatus(const Msg: string; ProgressPercent: Integer = 0);

    function FindExecutable(const AppName: string): string;
    function LaunchApplication(AppIdx: Integer; const ProjectId, RevisionId: string): Boolean;

    procedure OpenProductionPath(const PathOrJson: string; CheckHashes: Boolean);
    procedure RefreshAllViews;
    procedure RefreshPortalCards;
    procedure RefreshProjectsGrid;
    procedure DisplayRevisionDetails(const Proj: TMmpProjectRef; RevIdx: Integer);
    procedure RefreshSelectedProjectDetails;
    procedure RefreshSyncTab;
    procedure RefreshArtifactsGrid;

    // Event handlers
    procedure OnNewProductionClick(Sender: TObject);
    procedure OnOpenProductionClick(Sender: TObject);
    procedure OnRefreshClick(Sender: TObject);
    procedure OnOpenSettingsClick(Sender: TObject);
    procedure OnRecentDblClick(Sender: TObject);
    procedure OnLocateMovedRecentClick(Sender: TObject);
    procedure OnRemoveRecentClick(Sender: TObject);

    procedure OnPortalOpenAppClick(Sender: TObject);
    procedure OnPortalViewRevisionsClick(Sender: TObject);

    procedure OnProjectsGridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnRevComboChange(Sender: TObject);
    procedure OnOpenSelectedRevClick(Sender: TObject);
    procedure OnRelinkSelectedProjectClick(Sender: TObject);

    procedure OnGoToResponsibleAppClick(Sender: TObject);
    procedure OnCancelSyncClick(Sender: TObject);
    procedure OnAuditWithHashesClick(Sender: TObject);
    procedure OnRelinkMissingClick(Sender: TObject);
    procedure OnMonitorTimer(Sender: TObject);
    procedure OpenSettingsTab(const TabName: string);

    procedure OnArtifactsFilterChange(Sender: TObject);
    procedure OnRebuildCatalogClick(Sender: TObject);

    procedure OnClearLogClick(Sender: TObject);
    procedure OnSaveLogClick(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mmenuMainForm: TMmenuMainForm;

implementation

constructor TMmenuMainForm.Create(TheOwner: TComponent);
var
  Args: TMMLaunchArgs;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MMenu - Portal MaurinMovie';
  Width := 1220;
  Height := 780;
  Position := poScreenCenter;
  Constraints.MinWidth := 940;
  Constraints.MinHeight := 640;

  FSelectedProjectIndex := -1;
  FSettings := TMMSettings.Create;
  FConfigPath := FSettings.MachineIniPath;
  FDefaultProductionsDir := FSettings.ProductionsDir;

  BuildHeader(Self);
  BuildFooter(Self);
  BuildSidebar(Self);
  BuildCenterTabs(Self);

  LoadConfig;
  RefreshRecentsList;

  Args := ParseLaunchArgs;
  LogMsg('MMenu v' + MMP_EXECUTABLE_VERSION + ' iniciado (protocolo MMP v1).');
  if Args.Production <> '' then
    OpenProductionPath(Args.Production, False)
  else if FProd.RootDir <> '' then
    OpenProductionPath(FProd.RootDir, False)
  else
    RefreshAllViews;

  FMonitorTimer := TTimer.Create(Self);
  FMonitorTimer.Interval := 5000;
  FMonitorTimer.OnTimer := @OnMonitorTimer;
  FMonitorTimer.Enabled := True;

  if Args.OpenSettings then
    OpenSettingsTab(Args.SettingsTab);
end;

destructor TMmenuMainForm.Destroy;
begin
  SaveConfig;
  FSettings.Free;
  inherited Destroy;
end;

procedure TMmenuMainForm.BuildHeader(AParent: TWinControl);
var
  Head: TPanel;
  TitleLbl: TLabel;
  BtnNew, BtnOpen, BtnRefresh, BtnCfg: TButton;
begin
  Head := TPanel.Create(Self);
  Head.Parent := AParent;
  Head.Align := alTop;
  Head.Height := 72;
  Head.Caption := '';
  Head.BevelOuter := bvNone;
  Head.Color := $003A3028;
  Head.ParentBackground := False;

  TitleLbl := TLabel.Create(Self);
  TitleLbl.Parent := Head;
  TitleLbl.Caption := 'MaurinMovie  |  MMenu';
  TitleLbl.Font.Size := 18;
  TitleLbl.Font.Style := [fsBold];
  TitleLbl.Font.Color := clWhite;
  TitleLbl.SetBounds(18, 12, 340, 28);

  FExeVersionLabel := TLabel.Create(Self);
  FExeVersionLabel.Parent := Head;
  FExeVersionLabel.Caption := 'Executavel v' + MMP_EXECUTABLE_VERSION + '  |  Protocolo MMP v1';
  FExeVersionLabel.Font.Size := 9;
  FExeVersionLabel.Font.Color := $00D0D0D0;
  FExeVersionLabel.SetBounds(18, 44, 340, 18);

  FHeaderProdLabel := TLabel.Create(Self);
  FHeaderProdLabel.Parent := Head;
  FHeaderProdLabel.Caption := 'Nenhuma producao ativa';
  FHeaderProdLabel.Font.Size := 11;
  FHeaderProdLabel.Font.Style := [fsBold];
  FHeaderProdLabel.Font.Color := clWhite;
  FHeaderProdLabel.SetBounds(370, 14, 420, 22);

  FHeaderStatusBadge := TLabel.Create(Self);
  FHeaderStatusBadge.Parent := Head;
  FHeaderStatusBadge.Caption := 'Selecione ou crie uma producao';
  FHeaderStatusBadge.Font.Size := 9;
  FHeaderStatusBadge.Font.Color := $0099E6FF;
  FHeaderStatusBadge.SetBounds(370, 42, 420, 18);

  BtnCfg := TButton.Create(Self);
  BtnCfg.Parent := Head;
  BtnCfg.Caption := 'Configuracoes...';
  BtnCfg.Anchors := [akTop, akRight];
  BtnCfg.SetBounds(1090, 18, 114, 34);
  BtnCfg.OnClick := @OnOpenSettingsClick;

  BtnRefresh := TButton.Create(Self);
  BtnRefresh.Parent := Head;
  BtnRefresh.Caption := 'Atualizar';
  BtnRefresh.Anchors := [akTop, akRight];
  BtnRefresh.SetBounds(996, 18, 86, 34);
  BtnRefresh.OnClick := @OnRefreshClick;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := Head;
  BtnOpen.Caption := 'Abrir...';
  BtnOpen.Anchors := [akTop, akRight];
  BtnOpen.SetBounds(902, 18, 86, 34);
  BtnOpen.OnClick := @OnOpenProductionClick;

  BtnNew := TButton.Create(Self);
  BtnNew.Parent := Head;
  BtnNew.Caption := 'Nova Producao...';
  BtnNew.Anchors := [akTop, akRight];
  BtnNew.SetBounds(774, 18, 120, 34);
  BtnNew.OnClick := @OnNewProductionClick;
end;

procedure TMmenuMainForm.BuildFooter(AParent: TWinControl);
var
  Bottom: TPanel;
begin
  Bottom := TPanel.Create(Self);
  Bottom.Parent := AParent;
  Bottom.Align := alBottom;
  Bottom.Height := 36;
  Bottom.Caption := '';
  Bottom.BevelOuter := bvLowered;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Bottom;
  FStatusLabel.Left := 12;
  FStatusLabel.Top := 10;
  FStatusLabel.Width := 900;
  FStatusLabel.Anchors := [akLeft, akTop, akRight];
  FStatusLabel.Caption := 'Pronto.';

  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := Bottom;
  FProgressBar.Anchors := [akTop, akRight];
  FProgressBar.SetBounds(980, 9, 224, 18);
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;
  FProgressBar.Position := 0;
end;

procedure TMmenuMainForm.BuildSidebar(AParent: TWinControl);
var
  Sidebar: TPanel;
  L: TLabel;
  BtnNew, BtnOpen, BtnLocate, BtnRemove: TButton;
begin
  Sidebar := TPanel.Create(Self);
  Sidebar.Parent := AParent;
  Sidebar.Align := alLeft;
  Sidebar.Width := 285;
  Sidebar.Caption := '';
  Sidebar.BevelOuter := bvNone;
  Sidebar.Color := $00EFEFEF;
  Sidebar.ParentBackground := False;

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'PRODUCAO ATIVA';
  L.Font.Style := [fsBold];
  L.SetBounds(14, 14, 250, 18);

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'Titulo:';
  L.SetBounds(14, 38, 60, 18);

  FActiveProdTitleEdit := TEdit.Create(Self);
  FActiveProdTitleEdit.Parent := Sidebar;
  FActiveProdTitleEdit.ReadOnly := True;
  FActiveProdTitleEdit.SetBounds(14, 56, 257, 24);
  FActiveProdTitleEdit.Text := '(nenhuma)';

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'ID da Producao:';
  L.SetBounds(14, 86, 150, 18);

  FActiveProdIdEdit := TEdit.Create(Self);
  FActiveProdIdEdit.Parent := Sidebar;
  FActiveProdIdEdit.ReadOnly := True;
  FActiveProdIdEdit.SetBounds(14, 104, 257, 24);
  FActiveProdIdEdit.Text := '-';

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'Pasta raiz:';
  L.SetBounds(14, 134, 150, 18);

  FActiveProdPathEdit := TEdit.Create(Self);
  FActiveProdPathEdit.Parent := Sidebar;
  FActiveProdPathEdit.ReadOnly := True;
  FActiveProdPathEdit.SetBounds(14, 152, 257, 24);
  FActiveProdPathEdit.Text := '-';

  BtnNew := TButton.Create(Self);
  BtnNew.Parent := Sidebar;
  BtnNew.Caption := 'Nova producao...';
  BtnNew.SetBounds(14, 186, 124, 32);
  BtnNew.OnClick := @OnNewProductionClick;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := Sidebar;
  BtnOpen.Caption := 'Abrir...';
  BtnOpen.SetBounds(146, 186, 125, 32);
  BtnOpen.OnClick := @OnOpenProductionClick;

  FSummaryLabel := TLabel.Create(Self);
  FSummaryLabel.Parent := Sidebar;
  FSummaryLabel.WordWrap := True;
  FSummaryLabel.SetBounds(14, 228, 257, 68);
  FSummaryLabel.Caption := 'Nenhuma producao carregada.';

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'PRODUCOES RECENTES (duplo clique)';
  L.Font.Style := [fsBold];
  L.SetBounds(14, 304, 257, 18);

  FRecentsList := TListBox.Create(Self);
  FRecentsList.Parent := Sidebar;
  FRecentsList.Anchors := [akLeft, akTop, akRight, akBottom];
  FRecentsList.SetBounds(14, 326, 257, 280);
  FRecentsList.OnDblClick := @OnRecentDblClick;

  BtnLocate := TButton.Create(Self);
  BtnLocate.Parent := Sidebar;
  BtnLocate.Caption := 'Localizar movida...';
  BtnLocate.Anchors := [akLeft, akBottom];
  BtnLocate.SetBounds(14, 616, 135, 30);
  BtnLocate.OnClick := @OnLocateMovedRecentClick;

  BtnRemove := TButton.Create(Self);
  BtnRemove.Parent := Sidebar;
  BtnRemove.Caption := 'Remover';
  BtnRemove.Anchors := [akLeft, akBottom];
  BtnRemove.SetBounds(156, 616, 115, 30);
  BtnRemove.OnClick := @OnRemoveRecentClick;
end;

procedure TMmenuMainForm.BuildCenterTabs(AParent: TWinControl);
begin
  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := AParent;
  FPageControl.Align := alClient;

  FTabPortal := TTabSheet.Create(FPageControl);
  FTabPortal.PageControl := FPageControl;
  FTabPortal.Caption := 'Portal (Aplicativos)';

  FTabProjects := TTabSheet.Create(FPageControl);
  FTabProjects.PageControl := FPageControl;
  FTabProjects.Caption := 'Projetos & Revisoes';

  FTabSync := TTabSheet.Create(FPageControl);
  FTabSync.PageControl := FPageControl;
  FTabSync.Caption := 'Sincronizacoes & Pendencias';

  FTabArtifacts := TTabSheet.Create(FPageControl);
  FTabArtifacts.PageControl := FPageControl;
  FTabArtifacts.Caption := 'Artefatos & Catalogo';

  FTabLog := TTabSheet.Create(FPageControl);
  FTabLog.PageControl := FPageControl;
  FTabLog.Caption := 'Log Operacional';

  BuildPortalTab;
  BuildProjectsTab;
  BuildSyncTab;
  BuildArtifactsTab;
  BuildLogTab;
end;

procedure TMmenuMainForm.BuildPortalTab;
var
  Scroll: TScrollBox;
  Intro: TLabel;
  I, Col, Row, X, Y: Integer;
  Card: TPanel;
  TitleL, DescL: TLabel;
  BtnRev: TButton;
begin
  Scroll := TScrollBox.Create(Self);
  Scroll.Parent := FTabPortal;
  Scroll.Align := alClient;
  Scroll.BorderStyle := bsNone;

  Intro := TLabel.Create(Self);
  Intro.Parent := Scroll;
  Intro.Caption := 'Aplicativos independentes da suite MaurinMovie (MScript -> MVisual -> MBoard -> MSound -> MScene -> MCut)';
  Intro.Font.Size := 11;
  Intro.Font.Style := [fsBold];
  Intro.SetBounds(18, 14, 860, 24);

  for I := 1 to 6 do
  begin
    Col := (I - 1) mod 2;
    Row := (I - 1) div 2;
    X := 18 + Col * 430;
    Y := 50 + Row * 168;

    Card := TPanel.Create(Self);
    Card.Parent := Scroll;
    Card.SetBounds(X, Y, 412, 152);
    Card.BevelOuter := bvRaised;
    Card.Color := clWhite;
    Card.ParentBackground := False;
    Card.Caption := '';
    FCardPanels[I] := Card;

    TitleL := TLabel.Create(Self);
    TitleL.Parent := Card;
    TitleL.Caption := IntToStr(I) + '  -  ' + MmpAppNames[I];
    TitleL.Font.Size := 13;
    TitleL.Font.Style := [fsBold];
    TitleL.Font.Color := $003A3028;
    TitleL.SetBounds(14, 10, 240, 24);

    DescL := TLabel.Create(Self);
    DescL.Parent := Card;
    DescL.Caption := MmpAppDescriptions[I];
    DescL.Font.Color := clGrayText;
    DescL.SetBounds(14, 34, 380, 18);

    FCardProjInfoLabels[I] := TLabel.Create(Self);
    FCardProjInfoLabels[I].Parent := Card;
    FCardProjInfoLabels[I].Caption := 'Projeto: (nenhuma producao)';
    FCardProjInfoLabels[I].SetBounds(14, 58, 384, 18);

    FCardExeInfoLabels[I] := TLabel.Create(Self);
    FCardExeInfoLabels[I].Parent := Card;
    FCardExeInfoLabels[I].Caption := 'Executavel: verificando...';
    FCardExeInfoLabels[I].SetBounds(14, 80, 384, 18);

    FCardOpenButtons[I] := TButton.Create(Self);
    FCardOpenButtons[I].Parent := Card;
    FCardOpenButtons[I].Tag := I;
    FCardOpenButtons[I].Caption := 'Abrir ' + MmpAppNames[I];
    FCardOpenButtons[I].SetBounds(14, 108, 186, 32);
    FCardOpenButtons[I].OnClick := @OnPortalOpenAppClick;

    BtnRev := TButton.Create(Self);
    BtnRev.Parent := Card;
    BtnRev.Tag := I;
    BtnRev.Caption := 'Ver revisoes e vinculos';
    BtnRev.SetBounds(210, 108, 186, 32);
    BtnRev.OnClick := @OnPortalViewRevisionsClick;
  end;
end;

procedure TMmenuMainForm.BuildProjectsTab;
var
  DetailPanel: TPanel;
  L1, L2: TLabel;
begin
  FProjectsGrid := TStringGrid.Create(Self);
  FProjectsGrid.Parent := FTabProjects;
  FProjectsGrid.Align := alClient;
  FProjectsGrid.FixedCols := 0;
  FProjectsGrid.FixedRows := 1;
  FProjectsGrid.ColCount := 8;
  FProjectsGrid.RowCount := 2;
  FProjectsGrid.Options := FProjectsGrid.Options + [goRowSelect, goColSizing];
  FProjectsGrid.Cells[0, 0] := 'Software';
  FProjectsGrid.Cells[1, 0] := 'Project ID';
  FProjectsGrid.Cells[2, 0] := 'Cena';
  FProjectsGrid.Cells[3, 0] := 'Revisao Ativa';
  FProjectsGrid.Cells[4, 0] := 'Status';
  FProjectsGrid.Cells[5, 0] := 'Atualizado em';
  FProjectsGrid.Cells[6, 0] := 'Integridade';
  FProjectsGrid.Cells[7, 0] := 'Caminho';
  FProjectsGrid.ColWidths[0] := 90;
  FProjectsGrid.ColWidths[1] := 175;
  FProjectsGrid.ColWidths[2] := 80;
  FProjectsGrid.ColWidths[3] := 95;
  FProjectsGrid.ColWidths[4] := 90;
  FProjectsGrid.ColWidths[5] := 150;
  FProjectsGrid.ColWidths[6] := 170;
  FProjectsGrid.ColWidths[7] := 300;
  FProjectsGrid.OnSelection := @OnProjectsGridSelection;

  DetailPanel := TPanel.Create(Self);
  DetailPanel.Parent := FTabProjects;
  DetailPanel.Align := alBottom;
  DetailPanel.Height := 250;
  DetailPanel.Caption := '';
  DetailPanel.BevelOuter := bvLowered;

  L1 := TLabel.Create(Self);
  L1.Parent := DetailPanel;
  L1.Caption := 'Revisao exata para abrir / inspecionar:';
  L1.Font.Style := [fsBold];
  L1.SetBounds(14, 12, 260, 18);

  FRevCombo := TComboBox.Create(Self);
  FRevCombo.Parent := DetailPanel;
  FRevCombo.Style := csDropDownList;
  FRevCombo.SetBounds(280, 8, 160, 26);
  FRevCombo.OnChange := @OnRevComboChange;

  FBtnOpenProjectRev := TButton.Create(Self);
  FBtnOpenProjectRev.Parent := DetailPanel;
  FBtnOpenProjectRev.Caption := 'Abrir revisao no aplicativo';
  FBtnOpenProjectRev.SetBounds(454, 7, 210, 28);
  FBtnOpenProjectRev.OnClick := @OnOpenSelectedRevClick;

  FBtnRelinkProject := TButton.Create(Self);
  FBtnRelinkProject.Parent := DetailPanel;
  FBtnRelinkProject.Caption := 'Revincular project.json...';
  FBtnRelinkProject.SetBounds(674, 7, 190, 28);
  FBtnRelinkProject.OnClick := @OnRelinkSelectedProjectClick;

  L2 := TLabel.Create(Self);
  L2.Parent := DetailPanel;
  L2.Caption := 'Historico, manifesto e vinculos de origem (sources[]) — MMenu nao sobrescreve projetos:';
  L2.SetBounds(14, 42, 650, 18);

  FRevDetailsMemo := TMemo.Create(Self);
  FRevDetailsMemo.Parent := DetailPanel;
  FRevDetailsMemo.ReadOnly := True;
  FRevDetailsMemo.ScrollBars := ssBoth;
  FRevDetailsMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  FRevDetailsMemo.SetBounds(14, 64, 886, 174);
end;

procedure TMmenuMainForm.BuildSyncTab;
var
  TopBar, MidBar, MissingPanel: TPanel;
  L: TLabel;
begin
  TopBar := TPanel.Create(Self);
  TopBar.Parent := FTabSync;
  TopBar.Align := alTop;
  TopBar.Height := 46;
  TopBar.Caption := '';
  TopBar.BevelOuter := bvNone;

  FSyncSummaryLabel := TLabel.Create(Self);
  FSyncSummaryLabel.Parent := TopBar;
  FSyncSummaryLabel.Font.Style := [fsBold];
  FSyncSummaryLabel.SetBounds(14, 14, 460, 20);
  FSyncSummaryLabel.Caption := 'Jobs de sincronizacao em cascata:';

  FBtnGoToFailedApp := TButton.Create(Self);
  FBtnGoToFailedApp.Parent := TopBar;
  FBtnGoToFailedApp.Caption := 'Ir para aplicativo responsavel';
  FBtnGoToFailedApp.Anchors := [akTop, akRight];
  FBtnGoToFailedApp.SetBounds(504, 8, 224, 30);
  FBtnGoToFailedApp.OnClick := @OnGoToResponsibleAppClick;

  FBtnCancelTx := TButton.Create(Self);
  FBtnCancelTx.Parent := TopBar;
  FBtnCancelTx.Caption := 'Cancelar transacao';
  FBtnCancelTx.Anchors := [akTop, akRight];
  FBtnCancelTx.SetBounds(736, 8, 158, 30);
  FBtnCancelTx.OnClick := @OnCancelSyncClick;

  FSyncJobsGrid := TStringGrid.Create(Self);
  FSyncJobsGrid.Parent := FTabSync;
  FSyncJobsGrid.Align := alClient;
  FSyncJobsGrid.FixedCols := 0;
  FSyncJobsGrid.FixedRows := 1;
  FSyncJobsGrid.ColCount := 7;
  FSyncJobsGrid.RowCount := 2;
  FSyncJobsGrid.Options := FSyncJobsGrid.Options + [goRowSelect, goColSizing];
  FSyncJobsGrid.Cells[0, 0] := 'Event ID';
  FSyncJobsGrid.Cells[1, 0] := 'Origem';
  FSyncJobsGrid.Cells[2, 0] := 'Destino';
  FSyncJobsGrid.Cells[3, 0] := 'Etapa';
  FSyncJobsGrid.Cells[4, 0] := 'Revisao Fonte';
  FSyncJobsGrid.Cells[5, 0] := 'Status';
  FSyncJobsGrid.Cells[6, 0] := 'Erro / Alteracao';
  FSyncJobsGrid.ColWidths[0] := 140;
  FSyncJobsGrid.ColWidths[1] := 90;
  FSyncJobsGrid.ColWidths[2] := 90;
  FSyncJobsGrid.ColWidths[3] := 110;
  FSyncJobsGrid.ColWidths[4] := 100;
  FSyncJobsGrid.ColWidths[5] := 110;
  FSyncJobsGrid.ColWidths[6] := 320;

  MissingPanel := TPanel.Create(Self);
  MissingPanel.Parent := FTabSync;
  MissingPanel.Align := alBottom;
  MissingPanel.Height := 260;
  MissingPanel.Caption := '';
  MissingPanel.BevelOuter := bvNone;

  MidBar := TPanel.Create(Self);
  MidBar.Parent := MissingPanel;
  MidBar.Align := alTop;
  MidBar.Height := 42;
  MidBar.Caption := '';
  MidBar.BevelOuter := bvNone;

  L := TLabel.Create(Self);
  L.Parent := MidBar;
  L.Caption := 'Links ausentes, arquivos movidos e divergencias de integridade:';
  L.Font.Style := [fsBold];
  L.SetBounds(14, 12, 460, 20);

  FBtnAuditHashes := TButton.Create(Self);
  FBtnAuditHashes.Parent := MidBar;
  FBtnAuditHashes.Caption := 'Auditar SHA-256 agora';
  FBtnAuditHashes.Anchors := [akTop, akRight];
  FBtnAuditHashes.SetBounds(520, 6, 174, 30);
  FBtnAuditHashes.OnClick := @OnAuditWithHashesClick;

  FBtnRelinkMissing := TButton.Create(Self);
  FBtnRelinkMissing.Parent := MidBar;
  FBtnRelinkMissing.Caption := 'Revincular item...';
  FBtnRelinkMissing.Anchors := [akTop, akRight];
  FBtnRelinkMissing.SetBounds(704, 6, 190, 30);
  FBtnRelinkMissing.OnClick := @OnRelinkMissingClick;

  FMissingGrid := TStringGrid.Create(Self);
  FMissingGrid.Parent := MissingPanel;
  FMissingGrid.Align := alClient;
  FMissingGrid.FixedCols := 0;
  FMissingGrid.FixedRows := 1;
  FMissingGrid.ColCount := 7;
  FMissingGrid.RowCount := 2;
  FMissingGrid.Options := FMissingGrid.Options + [goRowSelect, goColSizing];
  FMissingGrid.Cells[0, 0] := 'Tipo';
  FMissingGrid.Cells[1, 0] := 'App';
  FMissingGrid.Cells[2, 0] := 'Projeto';
  FMissingGrid.Cells[3, 0] := 'Revisao';
  FMissingGrid.Cells[4, 0] := 'Alvo ID';
  FMissingGrid.Cells[5, 0] := 'Status';
  FMissingGrid.Cells[6, 0] := 'Detalhe / Localizacao';
  FMissingGrid.ColWidths[0] := 105;
  FMissingGrid.ColWidths[1] := 80;
  FMissingGrid.ColWidths[2] := 140;
  FMissingGrid.ColWidths[3] := 75;
  FMissingGrid.ColWidths[4] := 140;
  FMissingGrid.ColWidths[5] := 115;
  FMissingGrid.ColWidths[6] := 340;
end;

procedure TMmenuMainForm.BuildArtifactsTab;
var
  FilterBar: TPanel;
  L: TLabel;
  I: Integer;
begin
  FilterBar := TPanel.Create(Self);
  FilterBar.Parent := FTabArtifacts;
  FilterBar.Align := alTop;
  FilterBar.Height := 50;
  FilterBar.Caption := '';
  FilterBar.BevelOuter := bvNone;

  L := TLabel.Create(Self);
  L.Parent := FilterBar;
  L.Caption := 'App:';
  L.SetBounds(12, 16, 36, 18);

  FFilterAppCombo := TComboBox.Create(Self);
  FFilterAppCombo.Parent := FilterBar;
  FFilterAppCombo.Style := csDropDownList;
  FFilterAppCombo.Items.Add('Todos');
  for I := 0 to 6 do
    FFilterAppCombo.Items.Add(MmpAppNames[I]);
  FFilterAppCombo.ItemIndex := 0;
  FFilterAppCombo.SetBounds(48, 12, 110, 26);
  FFilterAppCombo.OnChange := @OnArtifactsFilterChange;

  L := TLabel.Create(Self);
  L.Parent := FilterBar;
  L.Caption := 'Integridade:';
  L.SetBounds(168, 16, 78, 18);

  FFilterStatusCombo := TComboBox.Create(Self);
  FFilterStatusCombo.Parent := FilterBar;
  FFilterStatusCombo.Style := csDropDownList;
  FFilterStatusCombo.Items.Add('Todos');
  FFilterStatusCombo.Items.Add('ok');
  FFilterStatusCombo.Items.Add('missing');
  FFilterStatusCombo.Items.Add('resolved_moved');
  FFilterStatusCombo.Items.Add('hash_mismatch');
  FFilterStatusCombo.Items.Add('invalid_path');
  FFilterStatusCombo.Items.Add('no_hash');
  FFilterStatusCombo.ItemIndex := 0;
  FFilterStatusCombo.SetBounds(248, 12, 120, 26);
  FFilterStatusCombo.OnChange := @OnArtifactsFilterChange;

  L := TLabel.Create(Self);
  L.Parent := FilterBar;
  L.Caption := 'Busca:';
  L.SetBounds(378, 16, 44, 18);

  FFilterSearchEdit := TEdit.Create(Self);
  FFilterSearchEdit.Parent := FilterBar;
  FFilterSearchEdit.SetBounds(424, 12, 160, 26);
  FFilterSearchEdit.OnChange := @OnArtifactsFilterChange;

  FBtnVerifyArtifacts := TButton.Create(Self);
  FBtnVerifyArtifacts.Parent := FilterBar;
  FBtnVerifyArtifacts.Caption := 'Verificar SHA-256';
  FBtnVerifyArtifacts.Anchors := [akTop, akRight];
  FBtnVerifyArtifacts.SetBounds(596, 10, 136, 30);
  FBtnVerifyArtifacts.OnClick := @OnAuditWithHashesClick;

  FBtnRebuildCatalog := TButton.Create(Self);
  FBtnRebuildCatalog.Parent := FilterBar;
  FBtnRebuildCatalog.Caption := 'Reconstruir catalog.json';
  FBtnRebuildCatalog.Anchors := [akTop, akRight];
  FBtnRebuildCatalog.SetBounds(740, 10, 162, 30);
  FBtnRebuildCatalog.OnClick := @OnRebuildCatalogClick;

  FArtifactsGrid := TStringGrid.Create(Self);
  FArtifactsGrid.Parent := FTabArtifacts;
  FArtifactsGrid.Align := alClient;
  FArtifactsGrid.FixedCols := 0;
  FArtifactsGrid.FixedRows := 1;
  FArtifactsGrid.ColCount := 9;
  FArtifactsGrid.RowCount := 2;
  FArtifactsGrid.Options := FArtifactsGrid.Options + [goRowSelect, goColSizing];
  FArtifactsGrid.Cells[0, 0] := 'Artifact ID';
  FArtifactsGrid.Cells[1, 0] := 'App';
  FArtifactsGrid.Cells[2, 0] := 'Revisao';
  FArtifactsGrid.Cells[3, 0] := 'Tipo';
  FArtifactsGrid.Cells[4, 0] := 'Cena';
  FArtifactsGrid.Cells[5, 0] := 'URI';
  FArtifactsGrid.Cells[6, 0] := 'Bytes';
  FArtifactsGrid.Cells[7, 0] := 'Status';
  FArtifactsGrid.Cells[8, 0] := 'Integridade';
  FArtifactsGrid.ColWidths[0] := 130;
  FArtifactsGrid.ColWidths[1] := 75;
  FArtifactsGrid.ColWidths[2] := 70;
  FArtifactsGrid.ColWidths[3] := 125;
  FArtifactsGrid.ColWidths[4] := 75;
  FArtifactsGrid.ColWidths[5] := 220;
  FArtifactsGrid.ColWidths[6] := 70;
  FArtifactsGrid.ColWidths[7] := 80;
  FArtifactsGrid.ColWidths[8] := 115;
end;

procedure TMmenuMainForm.BuildLogTab;
var
  Bar: TPanel;
  BtnClear, BtnSave: TButton;
begin
  Bar := TPanel.Create(Self);
  Bar.Parent := FTabLog;
  Bar.Align := alTop;
  Bar.Height := 42;
  Bar.Caption := '';
  Bar.BevelOuter := bvNone;

  BtnClear := TButton.Create(Self);
  BtnClear.Parent := Bar;
  BtnClear.Caption := 'Limpar log';
  BtnClear.SetBounds(12, 6, 110, 30);
  BtnClear.OnClick := @OnClearLogClick;

  BtnSave := TButton.Create(Self);
  BtnSave.Parent := Bar;
  BtnSave.Caption := 'Salvar log...';
  BtnSave.SetBounds(130, 6, 120, 30);
  BtnSave.OnClick := @OnSaveLogClick;

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := FTabLog;
  FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssBoth;
end;

procedure TMmenuMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
end;

procedure TMmenuMainForm.SetStatus(const Msg: string; ProgressPercent: Integer);
begin
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Msg;
  if FProgressBar <> nil then
    FProgressBar.Position := ProgressPercent;
end;

procedure TMmenuMainForm.LoadConfig;
var
  Ini: TIniFile;
  I, Count, N: Integer;
  DirStr: string;
begin
  if not FileExists(FConfigPath) then Exit;
  Ini := TIniFile.Create(FConfigPath);
  try
    FProd.RootDir := Ini.ReadString('Production', 'Root', '');
    DirStr := Ini.ReadString('Preferences', 'DefaultProductionsDir', '');
    if DirStr <> '' then
      FDefaultProductionsDir := DirStr;

    for I := 1 to 6 do
      FAppPaths[I] := Ini.ReadString('Applications', MmpAppNames[I], '');

    Count := Ini.ReadInteger('Recents', 'Count', 0);
    SetLength(FRecents, 0);
    for I := 0 to Count - 1 do
    begin
      DirStr := Ini.ReadString('Recents', 'Root_' + IntToStr(I), '');
      if DirStr <> '' then
      begin
        N := Length(FRecents);
        SetLength(FRecents, N + 1);
        FRecents[N].RootDir := DirStr;
        FRecents[N].Title := Ini.ReadString('Recents', 'Title_' + IntToStr(I),
          ExtractFileName(DirStr));
        FRecents[N].ProductionId := Ini.ReadString('Recents', 'Id_' + IntToStr(I), '');
      end;
    end;
  finally
    Ini.Free;
  end;
end;

procedure TMmenuMainForm.SaveConfig;
var
  Ini: TIniFile;
  I: Integer;
begin
  ForceDirectories(ExtractFileDir(FConfigPath));
  Ini := TIniFile.Create(FConfigPath);
  try
    Ini.WriteString('Production', 'Root', FProd.RootDir);
    Ini.WriteString('Preferences', 'DefaultProductionsDir', FDefaultProductionsDir);
    for I := 1 to 6 do
      Ini.WriteString('Applications', MmpAppNames[I], FAppPaths[I]);

    Ini.EraseSection('Recents');
    Ini.WriteInteger('Recents', 'Count', Length(FRecents));
    for I := 0 to High(FRecents) do
    begin
      Ini.WriteString('Recents', 'Root_' + IntToStr(I), FRecents[I].RootDir);
      Ini.WriteString('Recents', 'Title_' + IntToStr(I), FRecents[I].Title);
      Ini.WriteString('Recents', 'Id_' + IntToStr(I), FRecents[I].ProductionId);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TMmenuMainForm.AddOrUpdateRecent(const Prod: TMmpProduction);
var
  I, J, N: Integer;
  Temp: array of TRecentProduction;
begin
  if (not Prod.Loaded) or (Prod.RootDir = '') then Exit;

  SetLength(Temp, 1);
  Temp[0].Title := Prod.Title;
  Temp[0].ProductionId := Prod.ProductionId;
  Temp[0].RootDir := Prod.RootDir;

  for I := 0 to High(FRecents) do
  begin
    if SameText(FRecents[I].RootDir, Prod.RootDir) then Continue;
    if (Prod.ProductionId <> '') and
       SameText(FRecents[I].ProductionId, Prod.ProductionId) and
       not DirectoryExists(FRecents[I].RootDir) then
      Continue;
    N := Length(Temp);
    if N >= 15 then Break;
    SetLength(Temp, N + 1);
    Temp[N] := FRecents[I];
  end;

  SetLength(FRecents, Length(Temp));
  for J := 0 to High(Temp) do
    FRecents[J] := Temp[J];

  RefreshRecentsList;
end;

procedure TMmenuMainForm.RefreshRecentsList;
var
  I: Integer;
  TagStr: string;
begin
  FRecentsList.Items.BeginUpdate;
  try
    FRecentsList.Items.Clear;
    for I := 0 to High(FRecents) do
    begin
      if DirectoryExists(FRecents[I].RootDir) then
        TagStr := ''
      else
        TagStr := ' [movida/ausente]';
      FRecentsList.Items.Add(FRecents[I].Title + TagStr + '  (' + FRecents[I].ProductionId + ')');
    end;
  finally
    FRecentsList.Items.EndUpdate;
  end;
end;

function TMmenuMainForm.FindExecutable(const AppName: string): string;
var
  Base, Candidate, Suffix: string;
begin
  Result := '';
  {$IFDEF WINDOWS}
  Suffix := '.exe';
  {$ELSE}
  Suffix := '';
  {$ENDIF}
  Base := ExtractFileDir(ExpandFileName(ParamStr(0)));
  Candidate := IncludeTrailingPathDelimiter(Base) + LowerCase(AppName) + Suffix;
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := ExpandFileName(Base + PathDelim + '..' + PathDelim +
    'bin' + PathDelim + LowerCase(AppName) + Suffix);
  if FileExists(Candidate) then Exit(Candidate);
end;

function TMmenuMainForm.LaunchApplication(AppIdx: Integer;
  const ProjectId, RevisionId: string): Boolean;
var
  Executable, ArgLine, ProjDir, LockInfo: string;
  P: TProcess;
  I: Integer;
begin
  Result := False;
  if (AppIdx < 1) or (AppIdx > 6) then
  begin
    MessageDlg('Aplicativo destino invalido ou proprio MMenu.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if FProd.Loaded and (FProd.RootDir <> '') then
  begin
    ProjDir := IncludeTrailingPathDelimiter(FProd.RootDir) + 'projects' +
      PathDelim + MmpAppFolders[AppIdx];
    if IsProjectLocked(ProjDir, LockInfo) then
    begin
      if MessageDlg('O aplicativo ' + MmpAppNames[AppIdx] + ' ja possui lock ativo (' +
        LockInfo + ').' + LineEnding + 'Deseja abrir mesmo assim?',
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
        Exit;
    end;
  end;

  Executable := FAppPaths[AppIdx];
  if (Executable = '') or (not FileExists(Executable)) then
    Executable := FindExecutable(MmpAppNames[AppIdx]);

  if Executable = '' then
  begin
    MessageDlg('Executavel de ' + MmpAppNames[AppIdx] +
      ' nao encontrado. Configure o caminho em Configuracoes.', mtWarning, [mbOK], 0);
    LogMsg('FALHA ao iniciar ' + MmpAppNames[AppIdx] + ': executavel ausente.');
    Exit;
  end;

  P := TProcess.Create(nil);
  try
    P.Executable := Executable;
    if FProd.Loaded and (FProd.RootDir <> '') then
      BuildLaunchArgs(FProd.RootDir, ProjectId, RevisionId, P.Parameters);
    P.Options := [];

    ArgLine := Executable;
    for I := 0 to P.Parameters.Count - 1 do
      ArgLine := ArgLine + ' "' + P.Parameters[I] + '"';

    try
      P.Execute;
      LogMsg('Iniciado: ' + ArgLine);
      SetStatus(MmpAppNames[AppIdx] + ' iniciado (revisao ' + RevisionId + ').', 100);
      Result := True;
    except
      on E: Exception do
      begin
        LogMsg('ERRO ao iniciar ' + MmpAppNames[AppIdx] + ': ' + E.Message);
        MessageDlg('Erro ao iniciar ' + MmpAppNames[AppIdx] + ': ' + E.Message,
          mtError, [mbOK], 0);
      end;
    end;
  finally
    P.Free;
  end;
end;

procedure TMmenuMainForm.OpenProductionPath(const PathOrJson: string;
  CheckHashes: Boolean);
var
  LoadedProd: TMmpProduction;
begin
  SetStatus('Carregando producao...', 20);
  Application.ProcessMessages;

  if LoadProduction(PathOrJson, CheckHashes, LoadedProd) then
  begin
    FProd := LoadedProd;
    FSettings.Load(FProd.RootDir, maMMenu);
    AddOrUpdateRecent(FProd);
    SaveConfig;
    LogMsg('Producao carregada: "' + FProd.Title + '" (' + FProd.ProductionId +
      ') em ' + FProd.RootDir + ' | ' + FProd.OverallStatusText);
    AppendJsonLogLine(FProd.RootDir, 'MMenu', 'info', 'Producao aberta: ' + FProd.Title);
    SetStatus('Producao carregada: ' + FProd.Title, 100);
  end
  else
  begin
    FProd := LoadedProd;
    LogMsg('FALHA ao abrir producao: ' + FProd.ErrorMessage);
    SetStatus(FProd.ErrorMessage, 0);
  end;

  RefreshAllViews;
end;

procedure TMmenuMainForm.RefreshAllViews;
begin
  if FProd.Loaded then
  begin
    FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
    FHeaderStatusBadge.Caption := FProd.OverallStatusText;
    if FProd.HasFailures then
      FHeaderStatusBadge.Font.Color := $008080FF
    else if FProd.HasPendingWork then
      FHeaderStatusBadge.Font.Color := $0066D9FF
    else
      FHeaderStatusBadge.Font.Color := $0090EE90;

    FActiveProdTitleEdit.Text := FProd.Title;
    FActiveProdIdEdit.Text := FProd.ProductionId;
    FActiveProdPathEdit.Text := FProd.RootDir;
    FSummaryLabel.Caption := Format(
      'Projetos: %d' + LineEnding +
      'Artefatos: %d' + LineEnding +
      'Jobs de sync: %d' + LineEnding +
      'Links/alertas: %d',
      [Length(FProd.Projects), Length(FProd.Artifacts),
       Length(FProd.SyncJobs), Length(FProd.MissingLinks)]);
  end
  else
  begin
    FHeaderProdLabel.Caption := 'Nenhuma producao ativa';
    FHeaderStatusBadge.Caption := 'Crie ou abra uma producao para iniciar';
    FHeaderStatusBadge.Font.Color := $0099E6FF;
    FActiveProdTitleEdit.Text := '(nenhuma)';
    FActiveProdIdEdit.Text := '-';
    FActiveProdPathEdit.Text := '-';
    FSummaryLabel.Caption := 'Nenhuma producao carregada.';
  end;

  RefreshPortalCards;
  RefreshProjectsGrid;
  RefreshSyncTab;
  RefreshArtifactsGrid;
end;

procedure TMmenuMainForm.RefreshPortalCards;
var
  I, PIdx: Integer;
  ProjId, RevStr, StatusStr, ExePath: string;
begin
  for I := 1 to 6 do
  begin
    ProjId := '-';
    RevStr := '-';
    StatusStr := 'sem producao';
    if FProd.Loaded then
    begin
      for PIdx := 0 to High(FProd.Projects) do
      begin
        if (FProd.Projects[PIdx].SoftwareIndex = I) and
           (FProd.Projects[PIdx].SceneId = '') then
        begin
          ProjId := FProd.Projects[PIdx].ProjectId;
          RevStr := FProd.Projects[PIdx].ActiveRevision;
          StatusStr := FProd.Projects[PIdx].Status;
          Break;
        end;
      end;
    end;

    if FProd.Loaded then
      FCardProjInfoLabels[I].Caption := Format('Projeto: %s  |  Rev: %s  |  %s',
        [ProjId, RevStr, StatusStr])
    else
      FCardProjInfoLabels[I].Caption := 'Projeto: (abra ou crie uma producao)';

    ExePath := FAppPaths[I];
    if (ExePath <> '') and FileExists(ExePath) then
    begin
      FCardExeInfoLabels[I].Caption := 'Executavel: configurado';
      FCardExeInfoLabels[I].Font.Color := $00007A00;
    end
    else
    begin
      ExePath := FindExecutable(MmpAppNames[I]);
      if ExePath <> '' then
      begin
        FCardExeInfoLabels[I].Caption := 'Executavel: detectado (' + ExtractFileName(ExePath) + ')';
        FCardExeInfoLabels[I].Font.Color := $00805000;
      end
      else
      begin
        FCardExeInfoLabels[I].Caption := 'Executavel: nao configurado';
        FCardExeInfoLabels[I].Font.Color := clMaroon;
      end;
    end;
  end;
end;

procedure TMmenuMainForm.RefreshProjectsGrid;
var
  I, Row: Integer;
begin
  if (not FProd.Loaded) or (Length(FProd.Projects) = 0) then
  begin
    FProjectsGrid.RowCount := 2;
    for I := 0 to FProjectsGrid.ColCount - 1 do
      FProjectsGrid.Cells[I, 1] := '';
    FSelectedProjectIndex := -1;
    RefreshSelectedProjectDetails;
    Exit;
  end;

  FProjectsGrid.RowCount := Length(FProd.Projects) + 1;
  for I := 0 to High(FProd.Projects) do
  begin
    Row := I + 1;
    FProjectsGrid.Cells[0, Row] := FProd.Projects[I].AppName;
    FProjectsGrid.Cells[1, Row] := FProd.Projects[I].ProjectId;
    FProjectsGrid.Cells[2, Row] := FProd.Projects[I].SceneId;
    FProjectsGrid.Cells[3, Row] := FProd.Projects[I].ActiveRevision;
    FProjectsGrid.Cells[4, Row] := FProd.Projects[I].Status;
    FProjectsGrid.Cells[5, Row] := FProd.Projects[I].UpdatedAt;
    FProjectsGrid.Cells[6, Row] := FProd.Projects[I].IntegrityMessage;
    FProjectsGrid.Cells[7, Row] := FProd.Projects[I].ProjectFilePath;
  end;

  if (FSelectedProjectIndex < 0) or (FSelectedProjectIndex > High(FProd.Projects)) then
    FSelectedProjectIndex := 0;
  FProjectsGrid.Row := FSelectedProjectIndex + 1;
  RefreshSelectedProjectDetails;
end;

procedure TMmenuMainForm.DisplayRevisionDetails(const Proj: TMmpProjectRef;
  RevIdx: Integer);
var
  I: Integer;
  Rev: TMmpRevisionInfo;
begin
  FRevDetailsMemo.Lines.Clear;
  if (RevIdx < 0) or (RevIdx > High(Proj.Revisions)) then
  begin
    FRevDetailsMemo.Lines.Add('Nenhuma revisao encontrada para este projeto. Status: ' +
      Proj.IntegrityMessage);
    Exit;
  end;

  Rev := Proj.Revisions[RevIdx];
  FRevDetailsMemo.Lines.Add('Aplicativo: ' + Proj.AppName +
    '  |  Project ID: ' + Proj.ProjectId +
    '  |  Revisao selecionada: ' + Rev.RevisionId +
    '  (Ativa no projeto: ' + Proj.ActiveRevision + ')');
  FRevDetailsMemo.Lines.Add('Arquivo do projeto: ' + Proj.ProjectFilePath);
  FRevDetailsMemo.Lines.Add('Manifesto: ' + Rev.ManifestPath +
    '  |  Estado: ' + Rev.State +
    '  |  Criado em: ' + Rev.CreatedAt);
  FRevDetailsMemo.Lines.Add('SHA-256 do manifesto: ' + Rev.ManifestSha256);
  if Rev.ParentRevisionId <> '' then
    FRevDetailsMemo.Lines.Add('Revisao pai: ' + Rev.ParentRevisionId +
      '  |  Evento: ' + Rev.ChangeEventId);
  FRevDetailsMemo.Lines.Add('Artefatos nesta revisao: ' + IntToStr(Length(Rev.Artifacts)));
  FRevDetailsMemo.Lines.Add('');
  FRevDetailsMemo.Lines.Add('Fontes vinculadas (sources[]):');
  if Length(Rev.Sources) = 0 then
    FRevDetailsMemo.Lines.Add('  (nenhuma fonte externa declarada)')
  else
    for I := 0 to High(Rev.Sources) do
      FRevDetailsMemo.Lines.Add(Format('  - %s (%s) @ %s  [%s]  sha256=%s',
        [Rev.Sources[I].ProjectId, Rev.Sources[I].ResolvedApp,
         Rev.Sources[I].RevisionId, Rev.Sources[I].Status,
         Rev.Sources[I].ManifestSha256]));
end;

procedure TMmenuMainForm.RefreshSelectedProjectDetails;
var
  Proj: TMmpProjectRef;
  I, RevIdx: Integer;
begin
  FRevCombo.Items.Clear;
  FRevDetailsMemo.Lines.Clear;

  if (not FProd.Loaded) or (FSelectedProjectIndex < 0) or
     (FSelectedProjectIndex > High(FProd.Projects)) then
  begin
    FBtnOpenProjectRev.Enabled := False;
    FBtnRelinkProject.Enabled := False;
    Exit;
  end;

  Proj := FProd.Projects[FSelectedProjectIndex];
  FBtnRelinkProject.Enabled := True;

  for I := 0 to High(Proj.Revisions) do
    FRevCombo.Items.Add(Proj.Revisions[I].RevisionId);

  if FRevCombo.Items.Count > 0 then
  begin
    RevIdx := FRevCombo.Items.IndexOf(Proj.ActiveRevision);
    if RevIdx < 0 then RevIdx := 0;
    FRevCombo.ItemIndex := RevIdx;
  end;

  FBtnOpenProjectRev.Enabled := (Proj.SoftwareIndex >= 1) and (Proj.SoftwareIndex <= 6);
  DisplayRevisionDetails(Proj, FRevCombo.ItemIndex);
end;

procedure TMmenuMainForm.RefreshSyncTab;
var
  I, Row, FailedCount, PendingCount: Integer;
begin
  FailedCount := 0;
  PendingCount := 0;

  if (not FProd.Loaded) or (Length(FProd.SyncJobs) = 0) then
  begin
    FSyncJobsGrid.RowCount := 2;
    for I := 0 to FSyncJobsGrid.ColCount - 1 do
      FSyncJobsGrid.Cells[I, 1] := '';
    if FProd.Loaded then
      FSyncSummaryLabel.Caption := 'Nenhum job de sincronizacao registrado em shared/sync/.'
    else
      FSyncSummaryLabel.Caption := 'Abra uma producao para acompanhar sincronizacoes.';
  end
  else
  begin
    FSyncJobsGrid.RowCount := Length(FProd.SyncJobs) + 1;
    for I := 0 to High(FProd.SyncJobs) do
    begin
      Row := I + 1;
      FSyncJobsGrid.Cells[0, Row] := FProd.SyncJobs[I].EventId;
      FSyncJobsGrid.Cells[1, Row] := FProd.SyncJobs[I].OriginApp;
      FSyncJobsGrid.Cells[2, Row] := FProd.SyncJobs[I].TargetApp;
      FSyncJobsGrid.Cells[3, Row] := FProd.SyncJobs[I].Stage;
      FSyncJobsGrid.Cells[4, Row] := FProd.SyncJobs[I].SourceRevision;
      FSyncJobsGrid.Cells[5, Row] := FProd.SyncJobs[I].Status;
      if FProd.SyncJobs[I].ErrorText <> '' then
        FSyncJobsGrid.Cells[6, Row] := FProd.SyncJobs[I].ErrorText
      else
        FSyncJobsGrid.Cells[6, Row] := FProd.SyncJobs[I].RequestedChange;

      if SameText(FProd.SyncJobs[I].Status, 'failed') then
        Inc(FailedCount)
      else if not SameText(FProd.SyncJobs[I].Status, 'published') and
              not SameText(FProd.SyncJobs[I].Status, 'approved') and
              not SameText(FProd.SyncJobs[I].Status, 'cancelled') then
        Inc(PendingCount);
    end;
    FSyncSummaryLabel.Caption := Format(
      'Jobs: %d  |  Falhas: %d  |  Em aberto/pendentes: %d',
      [Length(FProd.SyncJobs), FailedCount, PendingCount]);
  end;

  if (not FProd.Loaded) or (Length(FProd.MissingLinks) = 0) then
  begin
    FMissingGrid.RowCount := 2;
    for I := 0 to FMissingGrid.ColCount - 1 do
      FMissingGrid.Cells[I, 1] := '';
  end
  else
  begin
    FMissingGrid.RowCount := Length(FProd.MissingLinks) + 1;
    for I := 0 to High(FProd.MissingLinks) do
    begin
      Row := I + 1;
      FMissingGrid.Cells[0, Row] := FProd.MissingLinks[I].Kind;
      FMissingGrid.Cells[1, Row] := FProd.MissingLinks[I].AppName;
      FMissingGrid.Cells[2, Row] := FProd.MissingLinks[I].ProjectId;
      FMissingGrid.Cells[3, Row] := FProd.MissingLinks[I].RevisionId;
      FMissingGrid.Cells[4, Row] := FProd.MissingLinks[I].TargetId;
      FMissingGrid.Cells[5, Row] := FProd.MissingLinks[I].Status;
      FMissingGrid.Cells[6, Row] := FProd.MissingLinks[I].Detail;
    end;
  end;
end;

procedure TMmenuMainForm.RefreshArtifactsGrid;
var
  I, Row, MatchCount: Integer;
  AppFilter, StatusFilter, SearchFilter: string;
  Filtered: array of TMmpArtifactRef;
begin
  if (not FProd.Loaded) or (Length(FProd.Artifacts) = 0) then
  begin
    FArtifactsGrid.RowCount := 2;
    for I := 0 to FArtifactsGrid.ColCount - 1 do
      FArtifactsGrid.Cells[I, 1] := '';
    Exit;
  end;

  AppFilter := FFilterAppCombo.Text;
  StatusFilter := FFilterStatusCombo.Text;
  SearchFilter := LowerCase(Trim(FFilterSearchEdit.Text));

  SetLength(Filtered, 0);
  for I := 0 to High(FProd.Artifacts) do
  begin
    if (AppFilter <> 'Todos') and not SameText(FProd.Artifacts[I].AppName, AppFilter) then
      Continue;
    if (StatusFilter <> 'Todos') and not SameText(FProd.Artifacts[I].IntegrityStatus, StatusFilter) then
      Continue;
    if SearchFilter <> '' then
    begin
      if (Pos(SearchFilter, LowerCase(FProd.Artifacts[I].ArtifactId)) = 0) and
         (Pos(SearchFilter, LowerCase(FProd.Artifacts[I].SceneId)) = 0) and
         (Pos(SearchFilter, LowerCase(FProd.Artifacts[I].Uri)) = 0) and
         (Pos(SearchFilter, LowerCase(FProd.Artifacts[I].Kind)) = 0) then
        Continue;
    end;
    MatchCount := Length(Filtered);
    SetLength(Filtered, MatchCount + 1);
    Filtered[MatchCount] := FProd.Artifacts[I];
  end;

  if Length(Filtered) = 0 then
  begin
    FArtifactsGrid.RowCount := 2;
    for I := 0 to FArtifactsGrid.ColCount - 1 do
      FArtifactsGrid.Cells[I, 1] := '';
    Exit;
  end;

  FArtifactsGrid.RowCount := Length(Filtered) + 1;
  for I := 0 to High(Filtered) do
  begin
    Row := I + 1;
    FArtifactsGrid.Cells[0, Row] := Filtered[I].ArtifactId;
    FArtifactsGrid.Cells[1, Row] := Filtered[I].AppName;
    FArtifactsGrid.Cells[2, Row] := Filtered[I].RevisionId;
    FArtifactsGrid.Cells[3, Row] := Filtered[I].Kind;
    FArtifactsGrid.Cells[4, Row] := Filtered[I].SceneId;
    FArtifactsGrid.Cells[5, Row] := Filtered[I].Uri;
    FArtifactsGrid.Cells[6, Row] := IntToStr(Filtered[I].Bytes);
    FArtifactsGrid.Cells[7, Row] := Filtered[I].Status;
    FArtifactsGrid.Cells[8, Row] := Filtered[I].IntegrityStatus;
  end;
end;

procedure TMmenuMainForm.OnNewProductionClick(Sender: TObject);
var
  Title, CreatedRoot, ErrMsg: string;
  DirDlg: TSelectDirectoryDialog;
begin
  Title := 'Novo Filme';
  if not InputQuery('Nova Producao MaurinMovie', 'Titulo da producao:', Title) then
    Exit;
  if Trim(Title) = '' then
  begin
    MessageDlg('Informe um titulo valido.', mtWarning, [mbOK], 0);
    Exit;
  end;

  DirDlg := TSelectDirectoryDialog.Create(Self);
  try
    DirDlg.Title := 'Escolha a pasta pai onde criar a producao';
    if DirectoryExists(FDefaultProductionsDir) then
      DirDlg.InitialDir := FDefaultProductionsDir;
    if not DirDlg.Execute then Exit;

    if CreateProduction(DirDlg.FileName, Title, CreatedRoot, ErrMsg) then
    begin
      FDefaultProductionsDir := DirDlg.FileName;
      LogMsg('Nova producao criada em: ' + CreatedRoot);
      OpenProductionPath(CreatedRoot, False);
    end
    else
    begin
      LogMsg('ERRO ao criar producao: ' + ErrMsg);
      MessageDlg(ErrMsg, mtError, [mbOK], 0);
    end;
  finally
    DirDlg.Free;
  end;
end;

procedure TMmenuMainForm.OnOpenProductionClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Selecione production.json da producao';
    D.Filter := 'Projeto MaurinMovie (production.json)|production.json|JSON (*.json)|*.json';
    D.Options := [ofFileMustExist, ofPathMustExist];
    if DirectoryExists(FDefaultProductionsDir) then
      D.InitialDir := FDefaultProductionsDir;
    if D.Execute then
    begin
      if not SameText(ExtractFileName(D.FileName), 'production.json') then
      begin
        MessageDlg('Selecione o arquivo production.json da producao.', mtWarning, [mbOK], 0);
        Exit;
      end;
      OpenProductionPath(D.FileName, False);
    end;
  finally
    D.Free;
  end;
end;

procedure TMmenuMainForm.OnRefreshClick(Sender: TObject);
begin
  if FProd.RootDir <> '' then
    OpenProductionPath(FProd.RootDir, False)
  else
    RefreshAllViews;
end;

procedure TMmenuMainForm.OpenSettingsTab(const TabName: string);
var
  Dlg: TMmenuSettingsForm;
  I: Integer;
begin
  FSettings.Load(FProd.RootDir, maMMenu);
  Dlg := TMmenuSettingsForm.CreateForSettings(Self, FSettings, FProd.Loaded, TabName);
  try
    if Dlg.ShowModal = mrOK then
    begin
      FDefaultProductionsDir := FSettings.ProductionsDir;
      for I := 1 to 6 do
        FAppPaths[I] := FSettings.GetAppExe(AppIndexToEnum(I));
      SaveConfig;
      RefreshPortalCards;
      LogMsg('Configuracoes centralizadas salvas em ' + FConfigPath +
        IfThen(FProd.Loaded, ' e settings/', ''));
      if FProd.Loaded then
        AppendJsonLogLine(FProd.RootDir, 'MMenu', 'info', 'Configuracoes atualizadas no MMenu.');
      SetStatus('Configuracoes salvas.', 100);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMmenuMainForm.OnOpenSettingsClick(Sender: TObject);
begin
  OpenSettingsTab('geral');
end;

procedure TMmenuMainForm.OnRecentDblClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FRecentsList.ItemIndex;
  if (Idx < 0) or (Idx > High(FRecents)) then Exit;

  if FileExists(FRecents[Idx].RootDir + PathDelim + 'production.json') then
    OpenProductionPath(FRecents[Idx].RootDir, False)
  else
  begin
    MessageDlg('A pasta desta producao nao foi encontrada em:' + LineEnding +
      FRecents[Idx].RootDir + LineEnding + LineEnding +
      'Use "Localizar movida..." para buscar pelo ID ' + FRecents[Idx].ProductionId + '.',
      mtWarning, [mbOK], 0);
  end;
end;

procedure TMmenuMainForm.OnLocateMovedRecentClick(Sender: TObject);
var
  Idx: Integer;
  DirDlg: TSelectDirectoryDialog;
  FoundRoot: string;
begin
  Idx := FRecentsList.ItemIndex;
  if (Idx < 0) or (Idx > High(FRecents)) then
  begin
    MessageDlg('Selecione uma producao na lista de recentes.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if FRecents[Idx].ProductionId = '' then
  begin
    MessageDlg('Esta entrada nao possui production_id registrado. Abra o production.json manualmente.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  DirDlg := TSelectDirectoryDialog.Create(Self);
  try
    DirDlg.Title := 'Escolha a pasta onde procurar a producao ' + FRecents[Idx].ProductionId;
    if not DirDlg.Execute then Exit;

    if FindProductionByIdInDir(DirDlg.FileName, FRecents[Idx].ProductionId, FoundRoot) then
    begin
      LogMsg('Producao movida localizada por ID em: ' + FoundRoot);
      OpenProductionPath(FoundRoot, False);
    end
    else
      MessageDlg('Nenhuma producao com ID ' + FRecents[Idx].ProductionId +
        ' foi encontrada nesta pasta.', mtWarning, [mbOK], 0);
  finally
    DirDlg.Free;
  end;
end;

procedure TMmenuMainForm.OnRemoveRecentClick(Sender: TObject);
var
  Idx, I: Integer;
begin
  Idx := FRecentsList.ItemIndex;
  if (Idx < 0) or (Idx > High(FRecents)) then Exit;

  for I := Idx to High(FRecents) - 1 do
    FRecents[I] := FRecents[I + 1];
  SetLength(FRecents, Length(FRecents) - 1);
  RefreshRecentsList;
  SaveConfig;
end;

procedure TMmenuMainForm.OnPortalOpenAppClick(Sender: TObject);
var
  AppIdx, I: Integer;
  ProjId, RevId: string;
begin
  AppIdx := (Sender as TButton).Tag;
  ProjId := '';
  RevId := '';
  if FProd.Loaded then
  begin
    for I := 0 to High(FProd.Projects) do
    begin
      if (FProd.Projects[I].SoftwareIndex = AppIdx) and
         (FProd.Projects[I].SceneId = '') then
      begin
        ProjId := FProd.Projects[I].ProjectId;
        RevId := FProd.Projects[I].ActiveRevision;
        Break;
      end;
    end;
  end;
  LaunchApplication(AppIdx, ProjId, RevId);
end;

procedure TMmenuMainForm.OnPortalViewRevisionsClick(Sender: TObject);
var
  AppIdx, I: Integer;
begin
  AppIdx := (Sender as TButton).Tag;
  FPageControl.ActivePage := FTabProjects;
  if not FProd.Loaded then Exit;
  for I := 0 to High(FProd.Projects) do
  begin
    if (FProd.Projects[I].SoftwareIndex = AppIdx) and
       (FProd.Projects[I].SceneId = '') then
    begin
      FSelectedProjectIndex := I;
      FProjectsGrid.Row := I + 1;
      RefreshSelectedProjectDetails;
      Break;
    end;
  end;
end;

procedure TMmenuMainForm.OnProjectsGridSelection(Sender: TObject; aCol, aRow: Integer);
begin
  if not FProd.Loaded then Exit;
  if (aRow >= 1) and (aRow <= Length(FProd.Projects)) then
  begin
    FSelectedProjectIndex := aRow - 1;
    RefreshSelectedProjectDetails;
  end;
end;

procedure TMmenuMainForm.OnRevComboChange(Sender: TObject);
begin
  if (not FProd.Loaded) or (FSelectedProjectIndex < 0) or
     (FSelectedProjectIndex > High(FProd.Projects)) then Exit;
  DisplayRevisionDetails(FProd.Projects[FSelectedProjectIndex], FRevCombo.ItemIndex);
end;

procedure TMmenuMainForm.OnOpenSelectedRevClick(Sender: TObject);
var
  Proj: TMmpProjectRef;
  RevId: string;
begin
  if (not FProd.Loaded) or (FSelectedProjectIndex < 0) or
     (FSelectedProjectIndex > High(FProd.Projects)) then Exit;

  Proj := FProd.Projects[FSelectedProjectIndex];
  if FRevCombo.ItemIndex >= 0 then
    RevId := FRevCombo.Text
  else
    RevId := Proj.ActiveRevision;

  LaunchApplication(Proj.SoftwareIndex, Proj.ProjectId, RevId);
end;

procedure TMmenuMainForm.OnRelinkSelectedProjectClick(Sender: TObject);
var
  Proj: TMmpProjectRef;
  D: TOpenDialog;
  Key, ErrMsg: string;
begin
  if (not FProd.Loaded) or (FSelectedProjectIndex < 0) or
     (FSelectedProjectIndex > High(FProd.Projects)) then Exit;
  Proj := FProd.Projects[FSelectedProjectIndex];

  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Revincular project.json de ' + Proj.AppName;
    D.Filter := 'Projeto de aplicativo (project.json)|project.json|JSON (*.json)|*.json';
    D.Options := [ofFileMustExist, ofPathMustExist];
    D.InitialDir := FProd.RootDir;
    if D.Execute then
    begin
      Key := Proj.AppName;
      if SaveRelinkOverride(FProd.RootDir, Key, D.FileName, ErrMsg) then
      begin
        LogMsg('Projeto ' + Proj.AppName + ' revinculado para: ' + D.FileName);
        OpenProductionPath(FProd.RootDir, False);
      end
      else
        MessageDlg(ErrMsg, mtError, [mbOK], 0);
    end;
  finally
    D.Free;
  end;
end;

procedure TMmenuMainForm.OnGoToResponsibleAppClick(Sender: TObject);
var
  RowIdx, AppIdx, I: Integer;
  Job: TMmpSyncJob;
  ProjId, RevId: string;
begin
  if (not FProd.Loaded) or (Length(FProd.SyncJobs) = 0) then
  begin
    MessageDlg('Nao ha jobs de sincronizacao selecionados.', mtInformation, [mbOK], 0);
    Exit;
  end;

  RowIdx := FSyncJobsGrid.Row - 1;
  if (RowIdx < 0) or (RowIdx > High(FProd.SyncJobs)) then
    RowIdx := 0;

  Job := FProd.SyncJobs[RowIdx];
  AppIdx := AppNameToIndex(Job.TargetApp);
  if AppIdx < 1 then
    AppIdx := AppNameToIndex(Job.Stage);
  if AppIdx < 1 then
    AppIdx := AppNameToIndex(Job.OriginApp);

  if AppIdx < 1 then
  begin
    MessageDlg('Nao foi possivel identificar o aplicativo responsavel por esta etapa (' +
      Job.Stage + ').', mtWarning, [mbOK], 0);
    Exit;
  end;

  ProjId := Job.ProjectId;
  RevId := Job.SourceRevision;
  if ProjId = '' then
  begin
    for I := 0 to High(FProd.Projects) do
      if (FProd.Projects[I].SoftwareIndex = AppIdx) and (FProd.Projects[I].SceneId = '') then
      begin
        ProjId := FProd.Projects[I].ProjectId;
        if RevId = '' then
          RevId := FProd.Projects[I].ActiveRevision;
        Break;
      end;
  end;

  LaunchApplication(AppIdx, ProjId, RevId);
end;

procedure TMmenuMainForm.OnCancelSyncClick(Sender: TObject);
var
  RowIdx: Integer;
  Job: TMmpSyncJob;
  ErrMsg: string;
begin
  if (not FProd.Loaded) or (Length(FProd.SyncJobs) = 0) then Exit;
  RowIdx := FSyncJobsGrid.Row - 1;
  if (RowIdx < 0) or (RowIdx > High(FProd.SyncJobs)) then RowIdx := 0;
  Job := FProd.SyncJobs[RowIdx];
  if MessageDlg('Cancelar a transacao/evento "' + Job.EventId + '"?' + LineEnding +
    'Revisoes ja publicadas permanecerao intactas.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if CancelSyncTransaction(Job.SourceFile, ErrMsg) then
  begin
    LogMsg('Transacao/evento cancelado: ' + Job.EventId);
    OpenProductionPath(FProd.RootDir, False);
  end
  else
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
end;

procedure TMmenuMainForm.OnMonitorTimer(Sender: TObject);
var
  LoadedProd: TMmpProduction;
  SavedProjRow, SavedSyncRow: Integer;
begin
  if (not FProd.Loaded) or (FProd.RootDir = '') then Exit;
  SavedProjRow := FProjectsGrid.Row;
  SavedSyncRow := FSyncJobsGrid.Row;
  if LoadProduction(FProd.RootDir, False, LoadedProd) then
  begin
    if (Length(LoadedProd.SyncJobs) <> Length(FProd.SyncJobs)) or
       (LoadedProd.OverallStatusText <> FProd.OverallStatusText) or
       (Length(LoadedProd.Artifacts) <> Length(FProd.Artifacts)) then
    begin
      FProd := LoadedProd;
      RefreshAllViews;
      if (SavedProjRow >= 1) and (SavedProjRow < FProjectsGrid.RowCount) then
        FProjectsGrid.Row := SavedProjRow;
      if (SavedSyncRow >= 1) and (SavedSyncRow < FSyncJobsGrid.RowCount) then
        FSyncJobsGrid.Row := SavedSyncRow;
    end;
  end;
end;

procedure TMmenuMainForm.OnAuditWithHashesClick(Sender: TObject);
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra ou crie uma producao primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;
  LogMsg('Iniciando auditoria completa de integridade e SHA-256...');
  OpenProductionPath(FProd.RootDir, True);
end;

procedure TMmenuMainForm.OnRelinkMissingClick(Sender: TObject);
var
  RowIdx: Integer;
  Link: TMmpMissingLink;
  D: TOpenDialog;
  ErrMsg: string;
  AppIdx: Integer;
begin
  if (not FProd.Loaded) or (Length(FProd.MissingLinks) = 0) then
  begin
    MessageDlg('Nao ha links pendentes selecionados.', mtInformation, [mbOK], 0);
    Exit;
  end;

  RowIdx := FMissingGrid.Row - 1;
  if (RowIdx < 0) or (RowIdx > High(FProd.MissingLinks)) then
    RowIdx := 0;
  Link := FProd.MissingLinks[RowIdx];

  if Link.Kind = 'project' then
  begin
    D := TOpenDialog.Create(Self);
    try
      D.Title := 'Revincular project.json para ' + Link.AppName;
      D.Filter := 'Projeto (project.json)|project.json|JSON (*.json)|*.json';
      D.Options := [ofFileMustExist, ofPathMustExist];
      D.InitialDir := FProd.RootDir;
      if D.Execute then
      begin
        if SaveRelinkOverride(FProd.RootDir, Link.AppName, D.FileName, ErrMsg) then
        begin
          LogMsg('Vinculo restaurado para ' + Link.AppName + ': ' + D.FileName);
          OpenProductionPath(FProd.RootDir, False);
        end
        else
          MessageDlg(ErrMsg, mtError, [mbOK], 0);
      end;
    finally
      D.Free;
    end;
  end
  else
  begin
    D := TOpenDialog.Create(Self);
    try
      D.Title := 'Selecionar novo local de ' + Link.TargetId + ' (validado por SHA-256)';
      D.Options := [ofFileMustExist, ofPathMustExist];
      D.InitialDir := FProd.RootDir;
      if D.Execute then
      begin
        if SaveArtifactRelinkToCatalog(FProd.RootDir, Link.TargetId,
          Link.ExpectedPath, D.FileName, Link.ExpectedSha256, ErrMsg) then
        begin
          LogMsg('Artefato ' + Link.TargetId + ' revinculado no catalog.json com SHA-256 verificado.');
          MessageDlg('Revinculado em catalog.json com SHA-256 verificado.', mtInformation, [mbOK], 0);
          OpenProductionPath(FProd.RootDir, False);
          Exit;
        end
        else
          MessageDlg(ErrMsg, mtError, [mbOK], 0);
      end;
    finally
      D.Free;
    end;
    AppIdx := AppNameToIndex(Link.AppName);
    if MessageDlg('Deseja abrir ' + Link.AppName + ' na revisao ' + Link.RevisionId + '?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      if AppIdx >= 1 then
        LaunchApplication(AppIdx, Link.ProjectId, Link.RevisionId);
    end;
  end;
end;

procedure TMmenuMainForm.OnArtifactsFilterChange(Sender: TObject);
begin
  RefreshArtifactsGrid;
end;

procedure TMmenuMainForm.OnRebuildCatalogClick(Sender: TObject);
var
  ErrMsg: string;
begin
  if not FProd.Loaded then
  begin
    MessageDlg('Abra ou crie uma producao primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if RebuildCatalog(FProd, ErrMsg) then
  begin
    LogMsg('catalog.json reconstruido atomicamente com sucesso.');
    SetStatus('catalog.json reconstruido.', 100);
    MessageDlg('catalog.json reconstruido com sucesso (com copia de seguranca .bak).',
      mtInformation, [mbOK], 0);
  end
  else
  begin
    LogMsg('ERRO ao reconstruir catalog.json: ' + ErrMsg);
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
  end;
end;

procedure TMmenuMainForm.OnClearLogClick(Sender: TObject);
begin
  FLogMemo.Lines.Clear;
end;

procedure TMmenuMainForm.OnSaveLogClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Title := 'Salvar log operacional do MMenu';
    D.Filter := 'Texto (*.txt)|*.txt|Log (*.log)|*.log';
    D.DefaultExt := 'log';
    D.FileName := 'mmenu_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.log';
    if D.Execute then
    begin
      FLogMemo.Lines.SaveToFile(D.FileName);
      SetStatus('Log salvo em ' + D.FileName, 100);
    end;
  finally
    D.Free;
  end;
end;

end.
