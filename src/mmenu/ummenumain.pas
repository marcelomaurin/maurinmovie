unit ummenumain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Math, Types, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, Grids, Menus, LCLProc, Process, IniFiles,
  mmpcommon, mmpsettings, ummpdb, ummpprotocol, ummpappbase, ummenusettings;

const
  // Paleta Azul & Branco (formato BGR do LCL: $00BBGGRR)
  CLR_NAVY_HEADER   = $006E3B16; // #163B6E - Azul marinho cabecalho/banners
  CLR_BLUE_PRIMARY  = $009E541B; // #1B549E - Azul principal (faixas alternadas / botoes)
  CLR_BLUE_DARK     = $007D3F12; // #123F7D - Azul escuro (bordas / destaque)
  CLR_BLUE_ACCENT   = $00D47E2B; // #2B7ED4 - Azul vivo (hover / realce)
  CLR_BLUE_SOFT     = $00FAEFDE; // #DEEFFA - Azul claro suave
  CLR_BLUE_ICE      = $00FCF7F1; // #F1F7FC - Fundo branco-azulado limpo
  CLR_BLUE_BORDER   = $00E8CFAF; // #AFCFE8 - Borda azul suave
  CLR_TEXT_NAVY     = $00472812; // #122847 - Texto principal sobre branco
  CLR_TEXT_MUTED    = $008C684C; // #4C688C - Texto secundario sobre branco
  CLR_ICE_SUB       = $00FFE2C4; // #C4E2FF - Texto secundario sobre azul
  CLR_STATUS_OK     = $002E7D32; // #327D2E - Verde status OK sobre branco
  CLR_STATUS_WARN   = $000068B8; // #B86800 - Ambar aviso sobre branco
  CLR_STATUS_ERR    = $002828B8; // #B82828 - Vermelho erro sobre branco

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
    FVisibleProjectIndices: array of Integer;

    // Menu suspenso e Popup da Engrenagem
    FMainMenu: TMainMenu;
    FMenuCloseProd: TMenuItem;
    FMenuSwitchUser: TMenuItem;
    FMenuAplicativos: TMenuItem;
    FMenuExibir: TMenuItem;
    FMenuFerramentas: TMenuItem;
    FMenuConfig: TMenuItem;
    FHasLoggedUser: Boolean;
    FCurrentUser: TMmpAccessUser;
    FGearPopup: TPopupMenu;
    FGearHover: Boolean;
    FGearDropHover: Boolean;
    FHeaderGearPanel: TPanel;
    FGearPaintBox: TPaintBox;
    FGearArrowBox: TPaintBox;

    // Header
    FHeaderProdLabel: TLabel;
    FHeaderStatusBadge: TLabel;
    FExeVersionLabel: TLabel;

    // Sidebar
    FActiveProdTitleLabel: TLabel;
    FActiveProdIdLabel: TLabel;
    FActiveProdPathLabel: TLabel;
    FBtnCloseProdHead: TButton;
    FBtnCloseProdSide: TButton;
    FRecentsList: TListBox;
    FSummaryLabel: TLabel;

    // Gerenciador de Projetos (quando nenhuma producao esta aberta)
    FManagerPanel: TPanel;
    FManagerGrid: TStringGrid;
    FBtnMgrOpenSel: TButton;
    FBtnMgrLocate: TButton;
    FBtnMgrRemove: TButton;

    // Central Tabs (somente com producao aberta)
    FPageControl: TPageControl;
    FTabPortal: TTabSheet;
    FTabHistory: TTabSheet;
    FTabProjects: TTabSheet;
    FTabSync: TTabSheet;
    FTabArtifacts: TTabSheet;
    FTabLog: TTabSheet;

    // Tab 1b: Historico & Controle
    FHistoryEntries: TMmpHistoryEntryArray;
    FHistoryFilteredIndices: array of Integer;
    FHistorySummaryLabel: TLabel;
    FHistoryAppFilter: TComboBox;
    FHistoryKindFilter: TComboBox;
    FHistorySearchEdit: TEdit;
    FHistoryGrid: TStringGrid;
    FHistoryDetailMemo: TMemo;

    // Portal (Menu visual alternado azul e branco inspirado no cardapio)
    FPortalScroll: TScrollBox;
    FPortalContent: TPanel;
    FPortalBanner: TPanel;
    FPortalBannerBadge: TLabel;
    FPortalFooter: TPanel;
    FPortalFooterBadge: TLabel;
    FCardPanels: array[1..6] of TPanel;
    FCardIllustBoxes: array[1..6] of TPaintBox;
    FCardActionBoxes: array[1..6] of TPaintBox;
    FCardActionHover: array[1..6] of Boolean;
    FCardActionLabels: array[1..6] of string;
    FCardActionSubLabels: array[1..6] of string;
    FCardActionOkFlag: array[1..6] of Integer; // 1=ok, 0=detectado, -1=ausente
    FCardProjInfoLabels: array[1..6] of TLabel;
    FCardExeInfoLabels: array[1..6] of TLabel;
    FCardRevButtons: array[1..6] of TLabel;

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
    FBtnResumeTx: TButton;
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

    // Tab 5: Log Centralizado (SQLite)
    FLogEntries: TMmpCentralLogArray;
    FLogSummaryLabel: TLabel;
    FLogAppFilter: TComboBox;
    FLogLevelFilter: TComboBox;
    FLogResolvedFilter: TComboBox;
    FLogSearchEdit: TEdit;
    FCentralLogGrid: TStringGrid;
    FLogMemo: TMemo;

    // Footer
    FStatusLabel: TLabel;
    FProgressBar: TProgressBar;

    procedure BuildMainMenu;
    procedure BuildSettingsMenuItems(ParentItem: TMenuItem);
    procedure BuildHeader(AParent: TWinControl);
    procedure BuildFooter(AParent: TWinControl);
    procedure BuildSidebar(AParent: TWinControl);
    procedure BuildCenterTabs(AParent: TWinControl);
    procedure BuildProjectManager(AParent: TWinControl);
    procedure BuildPortalTab;
    procedure BuildHistoryTab;
    procedure BuildProjectsTab;
    procedure BuildSyncTab;
    procedure BuildArtifactsTab;
    procedure BuildLogTab;

    procedure LayoutPortalContent;
    procedure DrawGearIcon(ACanvas: TCanvas; CX, CY: Integer; ROuter: Double; IconColor, BgColor: TColor);
    procedure DrawAppIllustration(ACanvas: TCanvas; W, H, AppIdx: Integer; DarkBg: Boolean);

    procedure LoadConfig;
    procedure SaveConfig;
    procedure AddOrUpdateRecent(const Prod: TMmpProduction);
    procedure RefreshRecentsList;

    procedure LogMsg(const Msg: string);
    procedure SetStatus(const Msg: string; ProgressPercent: Integer = 0);

    function FindExecutable(const AppName: string): string;
    function LaunchApplication(AppIdx: Integer; const ProjectId, RevisionId: string): Boolean;

    procedure OpenProductionPath(const PathOrJson: string; CheckHashes: Boolean;
      ShowIntegrityAlert: Boolean = True);
    procedure OpenRecentByIndex(Idx: Integer);
    procedure LocateMovedRecentByIndex(Idx: Integer);
    procedure RemoveRecentByIndex(Idx: Integer);
    procedure RefreshManagerGrid;
    procedure RefreshAllViews;
    procedure RefreshPortalCards;
    procedure RefreshProjectsGrid;
    procedure DisplayRevisionDetails(const Proj: TMmpProjectRef; RevIdx: Integer);
    procedure RefreshSelectedProjectDetails;
    procedure RefreshSyncTab;
    procedure RefreshArtifactsGrid;
    procedure RefreshHistoryTab;
    procedure PopulateHistoryGrid;
    procedure RefreshCentralLogTab;
    function IsAdminAllowed: Boolean;
    function CheckAdminAccess(const ActionDesc: string): Boolean;
    function CurrentSessionUserName: string;

    // Event handlers - Menu & Gear
    procedure OnMenuExitClick(Sender: TObject);
    procedure OnMenuLaunchAppClick(Sender: TObject);
    procedure OnMenuSwitchTabClick(Sender: TObject);
    procedure OnMenuSettingsTabClick(Sender: TObject);
    procedure OnAboutClick(Sender: TObject);

    procedure OnGearPaint(Sender: TObject);
    procedure OnGearArrowPaint(Sender: TObject);
    procedure OnGearMouseEnter(Sender: TObject);
    procedure OnGearMouseLeave(Sender: TObject);
    procedure OnGearArrowMouseEnter(Sender: TObject);
    procedure OnGearArrowMouseLeave(Sender: TObject);
    procedure OnGearArrowClick(Sender: TObject);

    // Event handlers - Portal visual
    procedure OnPortalScrollResize(Sender: TObject);
    procedure OnStripBorderPaint(Sender: TObject);
    procedure OnCardBorderPaint(Sender: TObject);
    procedure OnIllustPaint(Sender: TObject);
    procedure OnActionPillPaint(Sender: TObject);
    procedure OnActionPillMouseEnter(Sender: TObject);
    procedure OnActionPillMouseLeave(Sender: TObject);
    procedure OnRevLinkMouseEnter(Sender: TObject);
    procedure OnRevLinkMouseLeave(Sender: TObject);
    procedure OnQuickSyncTabClick(Sender: TObject);

    // Event handlers - Core
    procedure OnNewProductionClick(Sender: TObject);
    procedure OnOpenProductionClick(Sender: TObject);
    procedure OnCloseProductionClick(Sender: TObject);
    procedure OnRefreshClick(Sender: TObject);
    procedure OnOpenSettingsClick(Sender: TObject);
    procedure OnRecentDblClick(Sender: TObject);
    procedure OnLocateMovedRecentClick(Sender: TObject);
    procedure OnRemoveRecentClick(Sender: TObject);
    procedure OnManagerGridDblClick(Sender: TObject);
    procedure OnManagerOpenSelectedClick(Sender: TObject);
    procedure OnManagerLocateClick(Sender: TObject);
    procedure OnManagerRemoveClick(Sender: TObject);

    procedure OnPortalOpenAppClick(Sender: TObject);
    procedure OnPortalViewRevisionsClick(Sender: TObject);

    procedure OnProjectsGridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnRevComboChange(Sender: TObject);
    procedure OnOpenSelectedRevClick(Sender: TObject);
    procedure OnRelinkSelectedProjectClick(Sender: TObject);

    procedure OnGoToResponsibleAppClick(Sender: TObject);
    procedure OnCancelSyncClick(Sender: TObject);
    procedure OnResumeSyncClick(Sender: TObject);
    procedure OnAuditWithHashesClick(Sender: TObject);
    procedure OnRelinkMissingClick(Sender: TObject);
    procedure OnMonitorTimer(Sender: TObject);
    procedure OpenSettingsTab(const TabName: string);

    procedure OnArtifactsFilterChange(Sender: TObject);
    procedure OnRebuildCatalogClick(Sender: TObject);
    procedure OnHistoryFilterChange(Sender: TObject);
    procedure OnHistoryGridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnExportHistoryClick(Sender: TObject);

    procedure OnClearLogClick(Sender: TObject);
    procedure OnSaveLogClick(Sender: TObject);
    procedure OnCentralLogFilterChange(Sender: TObject);
    procedure OnCentralLogGridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnResolveCentralLogClick(Sender: TObject);
    procedure OnOpenLogAppClick(Sender: TObject);
    procedure OnSwitchUserClick(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mmenuMainForm: TMmenuMainForm;
  GMMenuHasLoggedUser: Boolean = False;
  GMMenuLoggedUser: TMmpAccessUser;

implementation

const
  SETTINGS_TAB_COUNT = 17;
  SettingsTabLabels: array[0..SETTINGS_TAB_COUNT - 1] of string = (
    'Geral e Ambiente...',
    'Producao Atual...',
    'IA: Texto...',
    'IA: Imagem / Foto...',
    'IA: Som - Voz...',
    'IA: Som - Efeitos...',
    'IA: Video...',
    'IA: Visao (opcional)...',
    'IA: Transcricao (opcional)...',
    'Programas (MScript..MCut)...',
    'Prompts...',
    'Midia e Render...',
    'Predefinicoes...',
    'Politicas...',
    'Ferramentas e Executaveis...',
    'Rede, Interface e Log...',
    'Controle de Acesso (Perfis)...'
  );
  SettingsTabKeys: array[0..SETTINGS_TAB_COUNT - 1] of string = (
    'geral',
    'producao',
    'ia-texto',
    'ia-imagem',
    'ia-voz',
    'ia-efeitos',
    'ia-video',
    'ia-visao',
    'ia-transcricao',
    'programas',
    'prompts',
    'midia',
    'predefinicoes',
    'politicas',
    'ferramentas',
    'rede',
    'acesso'
  );

function CompactMiddlePath(const S: string; MaxLen: Integer): string;
var
  Half: Integer;
begin
  if (MaxLen < 12) or (Length(S) <= MaxLen) then
    Exit(S);
  Half := (MaxLen - 3) div 2;
  Result := Copy(S, 1, Half) + '...' + Copy(S, Length(S) - Half + 1, Half);
end;

constructor TMmenuMainForm.Create(TheOwner: TComponent);
var
  Args: TMMLaunchArgs;
begin
  inherited CreateNew(TheOwner, 1);
  Randomize;
  Caption := 'MMenu - Portal MaurinMovie';
  Width := 1220;
  Height := 800;
  Position := poScreenCenter;
  Constraints.MinWidth := 940;
  Constraints.MinHeight := 640;
  Color := CLR_BLUE_ICE;
  DoubleBuffered := True;

  FSelectedProjectIndex := -1;
  FSettings := TMMSettings.Create;
  FHasLoggedUser := GMMenuHasLoggedUser;
  if FHasLoggedUser then
  begin
    FCurrentUser := GMMenuLoggedUser;
    FSettings.UserName := FCurrentUser.Username;
    FSettings.UserRole := MmpUserProfileToStr(FCurrentUser.Profile);
  end;
  FConfigPath := FSettings.MachineIniPath;
  FDefaultProductionsDir := FSettings.ProductionsDir;

  BuildMainMenu;
  BuildHeader(Self);
  BuildFooter(Self);
  BuildSidebar(Self);
  BuildCenterTabs(Self);

  LoadConfig;
  RefreshRecentsList;

  Args := ParseLaunchArgs;
  LogMsg('MMenu v' + MMP_EXECUTABLE_VERSION + ' iniciado (protocolo MMP v1).');
  if Args.Production <> '' then
    OpenProductionPath(Args.Production, True, True)
  else if FProd.RootDir <> '' then
    OpenProductionPath(FProd.RootDir, True, True)
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

procedure TMmenuMainForm.BuildSettingsMenuItems(ParentItem: TMenuItem);
var
  I: Integer;
  Item, IaSub: TMenuItem;
begin
  IaSub := nil;
  for I := 0 to SETTINGS_TAB_COUNT - 1 do
  begin
    if (I >= 2) and (I <= 8) then
    begin
      if IaSub = nil then
      begin
        IaSub := TMenuItem.Create(Self);
        IaSub.Caption := 'Provedores de IA';
        ParentItem.Add(IaSub);
      end;
      Item := TMenuItem.Create(Self);
      Item.Caption := SettingsTabLabels[I];
      Item.Tag := I;
      Item.OnClick := @OnMenuSettingsTabClick;
      IaSub.Add(Item);
    end
    else
    begin
      if I = 9 then
      begin
        Item := TMenuItem.Create(Self);
        Item.Caption := '-';
        ParentItem.Add(Item);
      end;
      Item := TMenuItem.Create(Self);
      Item.Caption := SettingsTabLabels[I];
      Item.Tag := I;
      Item.OnClick := @OnMenuSettingsTabClick;
      ParentItem.Add(Item);
    end;
  end;
end;

procedure TMmenuMainForm.BuildMainMenu;
var
  MArquivo, MAplicativos, MExibir, MFerramentas, MConfig, MAjuda, Item: TMenuItem;
  I: Integer;
begin
  FMainMenu := TMainMenu.Create(Self);
  Self.Menu := FMainMenu;

  // Arquivo
  MArquivo := TMenuItem.Create(Self);
  MArquivo.Caption := '&Arquivo';
  FMainMenu.Items.Add(MArquivo);

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Nova Producao...';
  Item.ShortCut := TextToShortCut('Ctrl+N');
  Item.OnClick := @OnNewProductionClick;
  MArquivo.Add(Item);

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Abrir Producao...';
  Item.ShortCut := TextToShortCut('Ctrl+O');
  Item.OnClick := @OnOpenProductionClick;
  MArquivo.Add(Item);

  FMenuCloseProd := TMenuItem.Create(Self);
  FMenuCloseProd.Caption := 'Fechar Producao';
  FMenuCloseProd.ShortCut := TextToShortCut('Ctrl+W');
  FMenuCloseProd.OnClick := @OnCloseProductionClick;
  MArquivo.Add(FMenuCloseProd);

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Atualizar';
  Item.ShortCut := TextToShortCut('F5');
  Item.OnClick := @OnRefreshClick;
  MArquivo.Add(Item);

  Item := TMenuItem.Create(Self);
  Item.Caption := '-';
  MArquivo.Add(Item);

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Localizar Producao Movida...';
  Item.OnClick := @OnLocateMovedRecentClick;
  MArquivo.Add(Item);

  Item := TMenuItem.Create(Self);
  Item.Caption := '-';
  MArquivo.Add(Item);

  FMenuSwitchUser := TMenuItem.Create(Self);
  FMenuSwitchUser.Caption := 'Trocar Usuario (Login)...';
  FMenuSwitchUser.OnClick := @OnSwitchUserClick;
  MArquivo.Add(FMenuSwitchUser);

  Item := TMenuItem.Create(Self);
  Item.Caption := '-';
  MArquivo.Add(Item);

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Sair';
  Item.OnClick := @OnMenuExitClick;
  MArquivo.Add(Item);

  // Aplicativos
  FMenuAplicativos := TMenuItem.Create(Self);
  FMenuAplicativos.Caption := 'A&plicativos';
  FMainMenu.Items.Add(FMenuAplicativos);
  MAplicativos := FMenuAplicativos;

  for I := 1 to 6 do
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := IntToStr(I) + ' - ' + MmpAppNames[I] + ' (' + MmpAppDescriptions[I] + ')';
    Item.Tag := I;
    Item.OnClick := @OnMenuLaunchAppClick;
    MAplicativos.Add(Item);
  end;

  // Exibir
  FMenuExibir := TMenuItem.Create(Self);
  FMenuExibir.Caption := '&Exibir';
  FMainMenu.Items.Add(FMenuExibir);
  MExibir := FMenuExibir;

  for I := 0 to 5 do
  begin
    Item := TMenuItem.Create(Self);
    case I of
      0: Item.Caption := 'Portal (Aplicativos)';
      1: Item.Caption := 'Historico && Controle';
      2: Item.Caption := 'Projetos && Revisoes';
      3: Item.Caption := 'Sincronizacoes && Pendencias';
      4: Item.Caption := 'Artefatos && Catalogo';
      5: Item.Caption := 'Log Centralizado (SQLite)';
    end;
    Item.Tag := I;
    Item.OnClick := @OnMenuSwitchTabClick;
    MExibir.Add(Item);
  end;

  // Ferramentas
  FMenuFerramentas := TMenuItem.Create(Self);
  FMenuFerramentas.Caption := '&Ferramentas';
  FMainMenu.Items.Add(FMenuFerramentas);
  MFerramentas := FMenuFerramentas;

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Auditar Integridade (SHA-256)';
  Item.OnClick := @OnAuditWithHashesClick;
  MFerramentas.Add(Item);

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Reconstruir catalog.json';
  Item.OnClick := @OnRebuildCatalogClick;
  MFerramentas.Add(Item);

  // Configuracoes
  FMenuConfig := TMenuItem.Create(Self);
  FMenuConfig.Caption := '&Configuracoes';
  FMainMenu.Items.Add(FMenuConfig);
  MConfig := FMenuConfig;
  BuildSettingsMenuItems(MConfig);

  // Ajuda
  MAjuda := TMenuItem.Create(Self);
  MAjuda.Caption := 'A&juda';
  FMainMenu.Items.Add(MAjuda);

  Item := TMenuItem.Create(Self);
  Item.Caption := 'Sobre o MMenu / MaurinMovie...';
  Item.OnClick := @OnAboutClick;
  MAjuda.Add(Item);

  // Popup da Engrenagem (canto superior direito)
  FGearPopup := TPopupMenu.Create(Self);
  BuildSettingsMenuItems(FGearPopup.Items);
end;

procedure TMmenuMainForm.BuildHeader(AParent: TWinControl);
var
  Head, BrandPanel, RightPanel, CenterPanel, AccentLine: TPanel;
  TitleLbl: TLabel;
  BtnNew, BtnOpen, BtnRefresh: TButton;
  GearDivider: TPanel;
begin
  Head := TPanel.Create(Self);
  Head.Parent := AParent;
  Head.Align := alTop; MmpPrepareAligned(Head);
  Head.Height := 66;
  Head.Caption := '';
  Head.BevelOuter := bvNone;
  Head.Color := CLR_NAVY_HEADER;
  Head.ParentBackground := False;

  AccentLine := TPanel.Create(Self);
  AccentLine.Parent := Head;
  AccentLine.Align := alBottom; MmpPrepareAligned(AccentLine);
  AccentLine.Height := 3;
  AccentLine.Caption := '';
  AccentLine.BevelOuter := bvNone;
  AccentLine.Color := CLR_BLUE_ACCENT;
  AccentLine.ParentBackground := False;

  // Bloco esquerdo: Identidade MaurinMovie
  BrandPanel := TPanel.Create(Self);
  BrandPanel.Parent := Head;
  BrandPanel.Align := alLeft; MmpPrepareAligned(BrandPanel);
  BrandPanel.Width := 272;
  BrandPanel.Caption := '';
  BrandPanel.BevelOuter := bvNone;
  BrandPanel.Color := CLR_NAVY_HEADER;
  BrandPanel.ParentBackground := False;

  TitleLbl := TLabel.Create(Self);
  TitleLbl.Parent := BrandPanel;
  TitleLbl.Caption := 'MaurinMovie  |  MMenu';
  TitleLbl.Font.Size := 16;
  TitleLbl.Font.Style := [fsBold];
  TitleLbl.Font.Color := clWhite;
  TitleLbl.SetBounds(16, 10, 250, 26);

  FExeVersionLabel := TLabel.Create(Self);
  FExeVersionLabel.Parent := BrandPanel;
  FExeVersionLabel.Caption := 'Suite v' + MMP_EXECUTABLE_VERSION + '  •  Protocolo MMP v1';
  FExeVersionLabel.Font.Size := 8;
  FExeVersionLabel.Font.Color := CLR_ICE_SUB;
  FExeVersionLabel.SetBounds(16, 39, 250, 16);

  // Bloco direito ancorado por Align=alRight (nunca some fora da janela!)
  RightPanel := TPanel.Create(Self);
  RightPanel.Parent := Head;
  RightPanel.Align := alRight; MmpPrepareAligned(RightPanel);
  RightPanel.Width := 424;
  RightPanel.Caption := '';
  RightPanel.BevelOuter := bvNone;
  RightPanel.Color := CLR_NAVY_HEADER;
  RightPanel.ParentBackground := False;

  BtnNew := TButton.Create(Self);
  BtnNew.Parent := RightPanel;
  BtnNew.Caption := '+ Nova';
  BtnNew.SetBounds(4, 15, 76, 34);
  BtnNew.OnClick := @OnNewProductionClick;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := RightPanel;
  BtnOpen.Caption := 'Abrir...';
  BtnOpen.SetBounds(86, 15, 76, 34);
  BtnOpen.OnClick := @OnOpenProductionClick;

  FBtnCloseProdHead := TButton.Create(Self);
  FBtnCloseProdHead.Parent := RightPanel;
  FBtnCloseProdHead.Caption := 'Fechar';
  FBtnCloseProdHead.SetBounds(168, 15, 72, 34);
  FBtnCloseProdHead.OnClick := @OnCloseProductionClick;

  BtnRefresh := TButton.Create(Self);
  BtnRefresh.Parent := RightPanel;
  BtnRefresh.Caption := 'Atualizar';
  BtnRefresh.SetBounds(246, 15, 82, 34);
  BtnRefresh.OnClick := @OnRefreshClick;

  // Botao de Configuracoes com icone de Engrenagem + seta dropdown no canto direito superior
  FHeaderGearPanel := TPanel.Create(Self);
  FHeaderGearPanel.Parent := RightPanel;
  FHeaderGearPanel.SetBounds(336, 14, 74, 36);
  FHeaderGearPanel.BevelOuter := bvNone;
  FHeaderGearPanel.Color := CLR_BLUE_PRIMARY;
  FHeaderGearPanel.ParentBackground := False;
  FHeaderGearPanel.Caption := '';
  FHeaderGearPanel.ShowHint := True;
  FHeaderGearPanel.Hint := 'Configuracoes da Suite (clique na engrenagem para abrir ou na seta para opcoes)';

  FGearArrowBox := TPaintBox.Create(Self);
  FGearArrowBox.Parent := FHeaderGearPanel;
  FGearArrowBox.Align := alRight; MmpPrepareAligned(FGearArrowBox);
  FGearArrowBox.Width := 24;
  FGearArrowBox.Cursor := crHandPoint;
  FGearArrowBox.ShowHint := True;
  FGearArrowBox.Hint := 'Menu rapido de configuracoes';
  FGearArrowBox.OnPaint := @OnGearArrowPaint;
  FGearArrowBox.OnMouseEnter := @OnGearArrowMouseEnter;
  FGearArrowBox.OnMouseLeave := @OnGearArrowMouseLeave;
  FGearArrowBox.OnClick := @OnGearArrowClick;

  GearDivider := TPanel.Create(Self);
  GearDivider.Parent := FHeaderGearPanel;
  GearDivider.Align := alRight; MmpPrepareAligned(GearDivider);
  GearDivider.Width := 1;
  GearDivider.BevelOuter := bvNone;
  GearDivider.Color := CLR_BLUE_ACCENT;
  GearDivider.ParentBackground := False;
  GearDivider.Caption := '';

  FGearPaintBox := TPaintBox.Create(Self);
  FGearPaintBox.Parent := FHeaderGearPanel;
  FGearPaintBox.Align := alClient; MmpPrepareAligned(FGearPaintBox);
  FGearPaintBox.Cursor := crHandPoint;
  FGearPaintBox.ShowHint := True;
  FGearPaintBox.Hint := 'Abrir Configuracoes Centralizadas...';
  FGearPaintBox.OnPaint := @OnGearPaint;
  FGearPaintBox.OnMouseEnter := @OnGearMouseEnter;
  FGearPaintBox.OnMouseLeave := @OnGearMouseLeave;
  FGearPaintBox.OnClick := @OnOpenSettingsClick;

  // Bloco central: Contexto da producao ativa
  CenterPanel := TPanel.Create(Self);
  CenterPanel.Parent := Head;
  CenterPanel.Align := alClient; MmpPrepareAligned(CenterPanel);
  CenterPanel.Caption := '';
  CenterPanel.BevelOuter := bvNone;
  CenterPanel.Color := CLR_NAVY_HEADER;
  CenterPanel.ParentBackground := False;

  FHeaderProdLabel := TLabel.Create(Self);
  FHeaderProdLabel.Parent := CenterPanel;
  FHeaderProdLabel.Caption := 'Nenhuma producao ativa';
  FHeaderProdLabel.Font.Size := 11;
  FHeaderProdLabel.Font.Style := [fsBold];
  FHeaderProdLabel.Font.Color := clWhite;
  FHeaderProdLabel.Anchors := [akLeft, akTop, akRight];
  FHeaderProdLabel.SetBounds(10, 12, 560, 22);

  FHeaderStatusBadge := TLabel.Create(Self);
  FHeaderStatusBadge.Parent := CenterPanel;
  FHeaderStatusBadge.Caption := 'Selecione ou crie uma producao';
  FHeaderStatusBadge.Font.Size := 9;
  FHeaderStatusBadge.Font.Color := CLR_ICE_SUB;
  FHeaderStatusBadge.Anchors := [akLeft, akTop, akRight];
  FHeaderStatusBadge.SetBounds(10, 36, 560, 18);
end;

procedure TMmenuMainForm.BuildFooter(AParent: TWinControl);
var
  Bottom, TopLine: TPanel;
begin
  Bottom := TPanel.Create(Self);
  Bottom.Parent := AParent;
  Bottom.Align := alBottom; MmpPrepareAligned(Bottom);
  Bottom.Height := 34;
  Bottom.Caption := '';
  Bottom.BevelOuter := bvNone;
  Bottom.Color := clWhite;
  Bottom.ParentBackground := False;

  TopLine := TPanel.Create(Self);
  TopLine.Parent := Bottom;
  TopLine.Align := alTop; MmpPrepareAligned(TopLine);
  TopLine.Height := 1;
  TopLine.Caption := '';
  TopLine.BevelOuter := bvNone;
  TopLine.Color := CLR_BLUE_BORDER;
  TopLine.ParentBackground := False;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Bottom;
  FStatusLabel.Left := 14;
  FStatusLabel.Top := 9;
  FStatusLabel.Width := 900;
  FStatusLabel.Anchors := [akLeft, akTop, akRight];
  FStatusLabel.Font.Color := CLR_TEXT_NAVY;
  FStatusLabel.Caption := 'Pronto.';

  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := Bottom;
  FProgressBar.Anchors := [akTop, akRight];
  FProgressBar.SetBounds(980, 8, 224, 18);
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;
  FProgressBar.Position := 0;
end;

procedure TMmenuMainForm.BuildSidebar(AParent: TWinControl);
var
  Sidebar, SepLine, CardWrap, ProdCard, Stripe, RecentsWrap, RecentsBottom: TPanel;
  L: TLabel;
  BtnNew, BtnOpen, BtnLocate, BtnRemove: TButton;
begin
  Sidebar := TPanel.Create(Self);
  Sidebar.Parent := AParent;
  Sidebar.Align := alLeft; MmpPrepareAligned(Sidebar);
  Sidebar.Width := 258;
  Sidebar.Caption := '';
  Sidebar.BevelOuter := bvNone;
  Sidebar.Color := CLR_BLUE_ICE;
  Sidebar.ParentBackground := False;

  SepLine := TPanel.Create(Self);
  SepLine.Parent := Sidebar;
  SepLine.Align := alRight; MmpPrepareAligned(SepLine);
  SepLine.Width := 1;
  SepLine.Caption := '';
  SepLine.BevelOuter := bvNone;
  SepLine.Color := CLR_BLUE_BORDER;
  SepLine.ParentBackground := False;

  // Cartao limpo da Producao Ativa
  CardWrap := TPanel.Create(Self);
  CardWrap.Parent := Sidebar;
  CardWrap.Align := alTop; MmpPrepareAligned(CardWrap);
  CardWrap.Height := 204;
  CardWrap.Caption := '';
  CardWrap.BevelOuter := bvNone;
  CardWrap.Color := CLR_BLUE_ICE;
  CardWrap.ParentBackground := False;

  ProdCard := TPanel.Create(Self);
  ProdCard.Parent := CardWrap;
  ProdCard.SetBounds(12, 12, 232, 184);
  ProdCard.Anchors := [akLeft, akTop, akRight];
  ProdCard.BevelOuter := bvNone;
  ProdCard.Color := clWhite;
  ProdCard.ParentBackground := False;
  ProdCard.Caption := '';
  ProdCard.OnPaint := @OnCardBorderPaint;

  Stripe := TPanel.Create(Self);
  Stripe.Parent := ProdCard;
  Stripe.Align := alLeft; MmpPrepareAligned(Stripe);
  Stripe.Width := 4;
  Stripe.BevelOuter := bvNone;
  Stripe.Color := CLR_BLUE_PRIMARY;
  Stripe.ParentBackground := False;
  Stripe.Caption := '';

  L := TLabel.Create(Self);
  L.Parent := ProdCard;
  L.Caption := 'PRODUCAO ATIVA';
  L.Font.Size := 8;
  L.Font.Style := [fsBold];
  L.Font.Color := CLR_BLUE_PRIMARY;
  L.SetBounds(14, 10, 206, 16);

  FActiveProdTitleLabel := TLabel.Create(Self);
  FActiveProdTitleLabel.Parent := ProdCard;
  FActiveProdTitleLabel.Caption := '(nenhuma producao)';
  FActiveProdTitleLabel.Font.Size := 11;
  FActiveProdTitleLabel.Font.Style := [fsBold];
  FActiveProdTitleLabel.Font.Color := CLR_TEXT_NAVY;
  FActiveProdTitleLabel.SetBounds(14, 28, 206, 22);

  FActiveProdIdLabel := TLabel.Create(Self);
  FActiveProdIdLabel.Parent := ProdCard;
  FActiveProdIdLabel.Caption := 'ID: -';
  FActiveProdIdLabel.Font.Size := 8;
  FActiveProdIdLabel.Font.Color := CLR_TEXT_MUTED;
  FActiveProdIdLabel.ShowHint := True;
  FActiveProdIdLabel.SetBounds(14, 52, 206, 16);

  FActiveProdPathLabel := TLabel.Create(Self);
  FActiveProdPathLabel.Parent := ProdCard;
  FActiveProdPathLabel.Caption := 'Pasta: -';
  FActiveProdPathLabel.Font.Size := 8;
  FActiveProdPathLabel.Font.Color := CLR_TEXT_MUTED;
  FActiveProdPathLabel.ShowHint := True;
  FActiveProdPathLabel.SetBounds(14, 70, 206, 16);

  FSummaryLabel := TLabel.Create(Self);
  FSummaryLabel.Parent := ProdCard;
  FSummaryLabel.WordWrap := True;
  FSummaryLabel.Font.Size := 8;
  FSummaryLabel.Font.Style := [fsBold];
  FSummaryLabel.Font.Color := CLR_BLUE_PRIMARY;
  FSummaryLabel.SetBounds(14, 94, 206, 36);
  FSummaryLabel.Caption := 'Abra ou crie uma producao.';

  BtnNew := TButton.Create(Self);
  BtnNew.Parent := ProdCard;
  BtnNew.Caption := 'Nova...';
  BtnNew.SetBounds(14, 140, 64, 30);
  BtnNew.OnClick := @OnNewProductionClick;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := ProdCard;
  BtnOpen.Caption := 'Abrir...';
  BtnOpen.SetBounds(84, 140, 68, 30);
  BtnOpen.OnClick := @OnOpenProductionClick;

  FBtnCloseProdSide := TButton.Create(Self);
  FBtnCloseProdSide.Parent := ProdCard;
  FBtnCloseProdSide.Caption := 'Fechar';
  FBtnCloseProdSide.SetBounds(158, 140, 62, 30);
  FBtnCloseProdSide.OnClick := @OnCloseProductionClick;

  // Lista de Producoes Recentes (com rodape sempre visivel!)
  RecentsWrap := TPanel.Create(Self);
  RecentsWrap.Parent := Sidebar;
  RecentsWrap.Align := alClient; MmpPrepareAligned(RecentsWrap);
  RecentsWrap.Caption := '';
  RecentsWrap.BevelOuter := bvNone;
  RecentsWrap.Color := CLR_BLUE_ICE;
  RecentsWrap.ParentBackground := False;
  RecentsWrap.BorderWidth := 12;

  L := TLabel.Create(Self);
  L.Parent := RecentsWrap;
  L.Align := alTop; MmpPrepareAligned(L);
  L.Height := 22;
  L.Caption := 'RECENTES (duplo clique)';
  L.Font.Size := 8;
  L.Font.Style := [fsBold];
  L.Font.Color := CLR_BLUE_PRIMARY;

  RecentsBottom := TPanel.Create(Self);
  RecentsBottom.Parent := RecentsWrap;
  RecentsBottom.Align := alBottom; MmpPrepareAligned(RecentsBottom);
  RecentsBottom.Height := 38;
  RecentsBottom.Caption := '';
  RecentsBottom.BevelOuter := bvNone;
  RecentsBottom.Color := CLR_BLUE_ICE;
  RecentsBottom.ParentBackground := False;

  BtnLocate := TButton.Create(Self);
  BtnLocate.Parent := RecentsBottom;
  BtnLocate.Caption := 'Localizar...';
  BtnLocate.SetBounds(0, 8, 114, 28);
  BtnLocate.OnClick := @OnLocateMovedRecentClick;

  BtnRemove := TButton.Create(Self);
  BtnRemove.Parent := RecentsBottom;
  BtnRemove.Caption := 'Remover';
  BtnRemove.SetBounds(120, 8, 112, 28);
  BtnRemove.OnClick := @OnRemoveRecentClick;

  FRecentsList := TListBox.Create(Self);
  FRecentsList.Parent := RecentsWrap;
  FRecentsList.Align := alClient; MmpPrepareAligned(FRecentsList);
  FRecentsList.Color := clWhite;
  FRecentsList.Font.Color := CLR_TEXT_NAVY;
  FRecentsList.OnDblClick := @OnRecentDblClick;
end;

procedure TMmenuMainForm.BuildProjectManager(AParent: TWinControl);
var
  Banner, BodyCard, ActionsBar, GridBottom: TPanel;
  BannerTitle, BannerSub, ListHeader: TLabel;
  BtnNew, BtnOpen, BtnSettings: TButton;
begin
  FManagerPanel := TPanel.Create(Self);
  FManagerPanel.Parent := AParent;
  FManagerPanel.Align := alClient; MmpPrepareAligned(FManagerPanel);
  FManagerPanel.BevelOuter := bvNone;
  FManagerPanel.Color := CLR_BLUE_ICE;
  FManagerPanel.ParentBackground := False;
  FManagerPanel.Caption := '';
  FManagerPanel.BorderWidth := 16;

  Banner := TPanel.Create(Self);
  Banner.Parent := FManagerPanel;
  Banner.Align := alTop; MmpPrepareAligned(Banner);
  Banner.Height := 84;
  Banner.BevelOuter := bvNone;
  Banner.Color := CLR_BLUE_PRIMARY;
  Banner.ParentBackground := False;
  Banner.Caption := '';

  BannerTitle := TLabel.Create(Self);
  BannerTitle.Parent := Banner;
  BannerTitle.Caption := 'Gerenciador de Projetos  •  MaurinMovie';
  BannerTitle.Font.Size := 15;
  BannerTitle.Font.Style := [fsBold];
  BannerTitle.Font.Color := clWhite;
  BannerTitle.SetBounds(20, 14, 580, 26);

  BannerSub := TLabel.Create(Self);
  BannerSub.Parent := Banner;
  BannerSub.Caption := 'Nenhum projeto aberto. Crie uma nova producao ou selecione uma producao existente para liberar as etapas da suite.';
  BannerSub.Font.Size := 9;
  BannerSub.Font.Color := CLR_ICE_SUB;
  BannerSub.WordWrap := True;
  BannerSub.Anchors := [akLeft, akTop, akRight];
  BannerSub.SetBounds(20, 44, 780, 28);

  ActionsBar := TPanel.Create(Self);
  ActionsBar.Parent := FManagerPanel;
  ActionsBar.Align := alTop; MmpPrepareAligned(ActionsBar);
  ActionsBar.Height := 62;
  ActionsBar.BevelOuter := bvNone;
  ActionsBar.Color := CLR_BLUE_ICE;
  ActionsBar.ParentBackground := False;
  ActionsBar.Caption := '';

  BtnNew := TButton.Create(Self);
  BtnNew.Parent := ActionsBar;
  BtnNew.Caption := '+ Nova Producao...';
  BtnNew.SetBounds(0, 14, 170, 36);
  BtnNew.OnClick := @OnNewProductionClick;

  BtnOpen := TButton.Create(Self);
  BtnOpen.Parent := ActionsBar;
  BtnOpen.Caption := 'Abrir Producao...';
  BtnOpen.SetBounds(182, 14, 170, 36);
  BtnOpen.OnClick := @OnOpenProductionClick;

  BtnSettings := TButton.Create(Self);
  BtnSettings.Parent := ActionsBar;
  BtnSettings.Caption := 'Configuracoes da Suite...';
  BtnSettings.SetBounds(364, 14, 200, 36);
  BtnSettings.OnClick := @OnOpenSettingsClick;

  BodyCard := TPanel.Create(Self);
  BodyCard.Parent := FManagerPanel;
  BodyCard.Align := alClient; MmpPrepareAligned(BodyCard);
  BodyCard.BevelOuter := bvNone;
  BodyCard.Color := clWhite;
  BodyCard.ParentBackground := False;
  BodyCard.Caption := '';
  BodyCard.BorderWidth := 12;
  BodyCard.OnPaint := @OnCardBorderPaint;

  ListHeader := TLabel.Create(Self);
  ListHeader.Parent := BodyCard;
  ListHeader.Align := alTop; MmpPrepareAligned(ListHeader);
  ListHeader.Height := 26;
  ListHeader.Caption := 'PRODUCOES RECENTES (duplo clique para abrir)';
  ListHeader.Font.Size := 9;
  ListHeader.Font.Style := [fsBold];
  ListHeader.Font.Color := CLR_TEXT_NAVY;

  GridBottom := TPanel.Create(Self);
  GridBottom.Parent := BodyCard;
  GridBottom.Align := alBottom; MmpPrepareAligned(GridBottom);
  GridBottom.Height := 46;
  GridBottom.BevelOuter := bvNone;
  GridBottom.Color := clWhite;
  GridBottom.ParentBackground := False;
  GridBottom.Caption := '';

  FBtnMgrOpenSel := TButton.Create(Self);
  FBtnMgrOpenSel.Parent := GridBottom;
  FBtnMgrOpenSel.Caption := 'Abrir Selecionado';
  FBtnMgrOpenSel.SetBounds(0, 10, 155, 32);
  FBtnMgrOpenSel.OnClick := @OnManagerOpenSelectedClick;

  FBtnMgrLocate := TButton.Create(Self);
  FBtnMgrLocate.Parent := GridBottom;
  FBtnMgrLocate.Caption := 'Localizar Pasta...';
  FBtnMgrLocate.SetBounds(165, 10, 145, 32);
  FBtnMgrLocate.OnClick := @OnManagerLocateClick;

  FBtnMgrRemove := TButton.Create(Self);
  FBtnMgrRemove.Parent := GridBottom;
  FBtnMgrRemove.Caption := 'Remover da Lista';
  FBtnMgrRemove.SetBounds(320, 10, 145, 32);
  FBtnMgrRemove.OnClick := @OnManagerRemoveClick;

  FManagerGrid := TStringGrid.Create(Self);
  FManagerGrid.Parent := BodyCard;
  FManagerGrid.Align := alClient; MmpPrepareAligned(FManagerGrid);
  FManagerGrid.FixedCols := 0;
  FManagerGrid.FixedRows := 1;
  FManagerGrid.ColCount := 4;
  FManagerGrid.RowCount := 2;
  FManagerGrid.Options := FManagerGrid.Options + [goRowSelect, goColSizing];
  FManagerGrid.Cells[0, 0] := 'Titulo';
  FManagerGrid.Cells[1, 0] := 'Production ID';
  FManagerGrid.Cells[2, 0] := 'Status';
  FManagerGrid.Cells[3, 0] := 'Pasta da Producao';
  FManagerGrid.ColWidths[0] := 180;
  FManagerGrid.ColWidths[1] := 210;
  FManagerGrid.ColWidths[2] := 130;
  FManagerGrid.ColWidths[3] := 340;
  FManagerGrid.OnDblClick := @OnManagerGridDblClick;
end;

procedure TMmenuMainForm.BuildCenterTabs(AParent: TWinControl);
begin
  BuildProjectManager(AParent);

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := AParent;
  FPageControl.Align := alClient; MmpPrepareAligned(FPageControl);
  FPageControl.Visible := False;

  FTabPortal := TTabSheet.Create(FPageControl);
  FTabPortal.PageControl := FPageControl; MmpPrepareTabSheet(FTabPortal);
  FTabPortal.Caption := 'Portal (Aplicativos)';

  FTabHistory := TTabSheet.Create(FPageControl);
  FTabHistory.PageControl := FPageControl; MmpPrepareTabSheet(FTabHistory);
  FTabHistory.Caption := 'Historico && Controle';

  FTabProjects := TTabSheet.Create(FPageControl);
  FTabProjects.PageControl := FPageControl; MmpPrepareTabSheet(FTabProjects);
  FTabProjects.Caption := 'Projetos && Revisoes';

  FTabSync := TTabSheet.Create(FPageControl);
  FTabSync.PageControl := FPageControl; MmpPrepareTabSheet(FTabSync);
  FTabSync.Caption := 'Sincronizacoes && Pendencias';

  FTabArtifacts := TTabSheet.Create(FPageControl);
  FTabArtifacts.PageControl := FPageControl; MmpPrepareTabSheet(FTabArtifacts);
  FTabArtifacts.Caption := 'Artefatos && Catalogo';

  FTabLog := TTabSheet.Create(FPageControl);
  FTabLog.PageControl := FPageControl; MmpPrepareTabSheet(FTabLog);
  FTabLog.Caption := 'Log Centralizado (SQLite)';

  BuildPortalTab;
  BuildHistoryTab;
  BuildProjectsTab;
  BuildSyncTab;
  BuildArtifactsTab;
  BuildLogTab;
end;

procedure TMmenuMainForm.BuildPortalTab;
var
  I: Integer;
  Strip, TextZone: TPanel;
  IllustBox, ActionBox: TPaintBox;
  TitleL, DescL, ProjL, ExeL, RevBtn, BannerTitle, BannerSub, BannerLine1, BannerLine2: TLabel;
  FooterTitle: TLabel;
  BtnAudit, BtnPending, BtnCfg: TButton;
  IsBlueStrip: Boolean;
begin
  FPortalScroll := TScrollBox.Create(Self);
  FPortalScroll.Parent := FTabPortal;
  FPortalScroll.Align := alClient; MmpPrepareAligned(FPortalScroll);
  FPortalScroll.BorderStyle := bsNone;
  FPortalScroll.Color := CLR_BLUE_ICE;
  FPortalScroll.ParentBackground := False;
  FPortalScroll.VertScrollBar.Tracking := True;
  FPortalScroll.OnResize := @OnPortalScrollResize;

  FPortalContent := TPanel.Create(Self);
  FPortalContent.Parent := FPortalScroll;
  FPortalContent.BevelOuter := bvNone;
  FPortalContent.Color := CLR_BLUE_ICE;
  FPortalContent.ParentBackground := False;
  FPortalContent.Caption := '';
  FPortalContent.DoubleBuffered := True;

  // 1) Faixa Superior (inspirada no bloco "ENTRADAS" do cardapio)
  FPortalBanner := TPanel.Create(Self);
  FPortalBanner.Parent := FPortalContent;
  FPortalBanner.BevelOuter := bvNone;
  FPortalBanner.Color := CLR_NAVY_HEADER;
  FPortalBanner.ParentBackground := False;
  FPortalBanner.Caption := '';

  BannerTitle := TLabel.Create(Self);
  BannerTitle.Parent := FPortalBanner;
  BannerTitle.Caption := 'SUITE';
  BannerTitle.Font.Size := 17;
  BannerTitle.Font.Style := [fsBold];
  BannerTitle.Font.Color := clWhite;
  BannerTitle.SetBounds(20, 10, 120, 28);

  BannerSub := TLabel.Create(Self);
  BannerSub.Parent := FPortalBanner;
  BannerSub.Caption := 'FLUXO DE PRODUCAO';
  BannerSub.Font.Size := 8;
  BannerSub.Font.Style := [fsBold];
  BannerSub.Font.Color := CLR_ICE_SUB;
  BannerSub.SetBounds(20, 39, 140, 16);

  BannerLine1 := TLabel.Create(Self);
  BannerLine1.Parent := FPortalBanner;
  BannerLine1.Caption := '1. MScript (Roteiro)    ->    2. MVisual (Biblioteca)    ->    3. MBoard (Storyboard)';
  BannerLine1.Font.Size := 9;
  BannerLine1.Font.Style := [fsBold];
  BannerLine1.Font.Color := clWhite;
  BannerLine1.SetBounds(174, 13, 560, 18);

  BannerLine2 := TLabel.Create(Self);
  BannerLine2.Parent := FPortalBanner;
  BannerLine2.Caption := '4. MSound (Voz/SFX)    ->    5. MScene (Cenas)         ->    6. MCut (Montagem Final)';
  BannerLine2.Font.Size := 9;
  BannerLine2.Font.Color := CLR_ICE_SUB;
  BannerLine2.SetBounds(174, 36, 560, 18);

  FPortalBannerBadge := TLabel.Create(Self);
  FPortalBannerBadge.Parent := FPortalBanner;
  FPortalBannerBadge.Alignment := taRightJustify;
  FPortalBannerBadge.Anchors := [akTop, akRight];
  FPortalBannerBadge.Font.Size := 9;
  FPortalBannerBadge.Font.Style := [fsBold];
  FPortalBannerBadge.Font.Color := CLR_ICE_SUB;
  FPortalBannerBadge.Caption := 'Selecione um modulo';
  FPortalBannerBadge.SetBounds(710, 24, 180, 20);

  // 2) 6 Faixas Alternadas (Branco / Azul) com Imagem Sugestiva + Pilula + Descricao
  for I := 1 to 6 do
  begin
    IsBlueStrip := (I mod 2 = 0); // 1,3,5 Brancos | 2,4,6 Azuis

    Strip := TPanel.Create(Self);
    Strip.Parent := FPortalContent;
    Strip.Tag := I;
    Strip.BevelOuter := bvNone;
    Strip.ParentBackground := False;
    Strip.Caption := '';
    Strip.DoubleBuffered := True;
    Strip.ChildSizing.LeftRightSpacing := 1;
    Strip.ChildSizing.TopBottomSpacing := 1;
    if IsBlueStrip then
      Strip.Color := CLR_BLUE_PRIMARY
    else
      Strip.Color := clWhite;
    Strip.OnPaint := @OnStripBorderPaint;
    FCardPanels[I] := Strip;

    // Zona da Imagem Sugestiva
    IllustBox := TPaintBox.Create(Self);
    IllustBox.Parent := Strip;
    IllustBox.Tag := I;
    IllustBox.Width := 134;
    IllustBox.Cursor := crHandPoint;
    IllustBox.ShowHint := True;
    IllustBox.Hint := 'Clique para abrir ' + MmpAppNames[I];
    IllustBox.OnPaint := @OnIllustPaint;
    IllustBox.OnClick := @OnPortalOpenAppClick;
    FCardIllustBoxes[I] := IllustBox;

    // Zona Central (Pilula de acao + linha conectora, estilo preco do cardapio)
    ActionBox := TPaintBox.Create(Self);
    ActionBox.Parent := Strip;
    ActionBox.Tag := I;
    ActionBox.Width := 214;
    ActionBox.Cursor := crHandPoint;
    ActionBox.ShowHint := True;
    ActionBox.Hint := 'Abrir ' + MmpAppNames[I] + ' na revisao ativa';
    ActionBox.OnPaint := @OnActionPillPaint;
    ActionBox.OnMouseEnter := @OnActionPillMouseEnter;
    ActionBox.OnMouseLeave := @OnActionPillMouseLeave;
    ActionBox.OnClick := @OnPortalOpenAppClick;
    FCardActionBoxes[I] := ActionBox;
    FCardActionHover[I] := False;
    FCardActionLabels[I] := 'Abrir ' + MmpAppNames[I];
    FCardActionSubLabels[I] := 'Sem producao';
    FCardActionOkFlag[I] := 0;

    // Zona de Texto (Titulo + Descricao curta + Status limpo + Link Revisoes)
    TextZone := TPanel.Create(Self);
    TextZone.Parent := Strip;
    TextZone.BevelOuter := bvNone;
    TextZone.ParentBackground := False;
    TextZone.Caption := '';
    if IsBlueStrip then
      TextZone.Color := CLR_BLUE_PRIMARY
    else
      TextZone.Color := clWhite;

    // Ordem alternada exatamente como o cardapio:
    // Impar (Branco): Imagem na Esquerda -> Pilula no Centro -> Texto na Direita
    // Par (Azul):     Texto na Esquerda -> Pilula no Centro -> Imagem na Direita
    if IsBlueStrip then
    begin
      IllustBox.Align := alRight; MmpPrepareAligned(IllustBox);
      ActionBox.Align := alRight; MmpPrepareAligned(ActionBox);
      TextZone.Align := alClient; MmpPrepareAligned(TextZone);
    end
    else
    begin
      IllustBox.Align := alLeft; MmpPrepareAligned(IllustBox);
      ActionBox.Align := alLeft; MmpPrepareAligned(ActionBox);
      TextZone.Align := alClient; MmpPrepareAligned(TextZone);
    end;

    TitleL := TLabel.Create(Self);
    TitleL.Parent := TextZone;
    TitleL.Caption := IntToStr(I) + '  -  ' + MmpAppNames[I];
    TitleL.Font.Size := 13;
    TitleL.Font.Style := [fsBold];
    if IsBlueStrip then
      TitleL.Font.Color := clWhite
    else
      TitleL.Font.Color := CLR_TEXT_NAVY;
    TitleL.SetBounds(16, 10, 300, 24);

    DescL := TLabel.Create(Self);
    DescL.Parent := TextZone;
    DescL.Caption := MmpAppDescriptions[I];
    DescL.Font.Size := 9;
    if IsBlueStrip then
      DescL.Font.Color := CLR_ICE_SUB
    else
      DescL.Font.Color := CLR_TEXT_MUTED;
    DescL.SetBounds(16, 35, 320, 18);

    ProjL := TLabel.Create(Self);
    ProjL.Parent := TextZone;
    ProjL.Caption := 'Abra ou crie uma producao';
    ProjL.Font.Size := 8;
    ProjL.ShowHint := True;
    if IsBlueStrip then
      ProjL.Font.Color := clWhite
    else
      ProjL.Font.Color := CLR_TEXT_NAVY;
    ProjL.SetBounds(16, 56, 360, 16);
    FCardProjInfoLabels[I] := ProjL;

    ExeL := TLabel.Create(Self);
    ExeL.Parent := TextZone;
    ExeL.Caption := 'Executavel: verificando...';
    ExeL.Font.Size := 8;
    if IsBlueStrip then
      ExeL.Font.Color := CLR_ICE_SUB
    else
      ExeL.Font.Color := CLR_TEXT_MUTED;
    ExeL.SetBounds(16, 73, 250, 16);
    FCardExeInfoLabels[I] := ExeL;

    RevBtn := TLabel.Create(Self);
    RevBtn.Parent := TextZone;
    RevBtn.Tag := I;
    RevBtn.Caption := 'Ver revisoes >';
    RevBtn.Font.Size := 8;
    RevBtn.Font.Style := [fsBold, fsUnderline];
    RevBtn.Cursor := crHandPoint;
    RevBtn.Anchors := [akRight, akBottom];
    RevBtn.Alignment := taRightJustify;
    if IsBlueStrip then
      RevBtn.Font.Color := clWhite
    else
      RevBtn.Font.Color := CLR_BLUE_PRIMARY;
    RevBtn.SetBounds(280, 72, 110, 16);
    RevBtn.OnMouseEnter := @OnRevLinkMouseEnter;
    RevBtn.OnMouseLeave := @OnRevLinkMouseLeave;
    RevBtn.OnClick := @OnPortalViewRevisionsClick;
    FCardRevButtons[I] := RevBtn;
  end;

  // 3) Faixa Inferior de Acoes Rapidas (inspirada no rodape do cardapio)
  FPortalFooter := TPanel.Create(Self);
  FPortalFooter.Parent := FPortalContent;
  FPortalFooter.BevelOuter := bvNone;
  FPortalFooter.Color := CLR_BLUE_SOFT;
  FPortalFooter.ParentBackground := False;
  FPortalFooter.Caption := '';
  FPortalFooter.OnPaint := @OnCardBorderPaint;

  FooterTitle := TLabel.Create(Self);
  FooterTitle.Parent := FPortalFooter;
  FooterTitle.Caption := 'ACOES RAPIDAS';
  FooterTitle.Font.Size := 9;
  FooterTitle.Font.Style := [fsBold];
  FooterTitle.Font.Color := CLR_BLUE_PRIMARY;
  FooterTitle.SetBounds(16, 18, 115, 18);

  BtnAudit := TButton.Create(Self);
  BtnAudit.Parent := FPortalFooter;
  BtnAudit.Caption := 'Auditar SHA-256';
  BtnAudit.SetBounds(140, 11, 134, 30);
  BtnAudit.OnClick := @OnAuditWithHashesClick;

  BtnPending := TButton.Create(Self);
  BtnPending.Parent := FPortalFooter;
  BtnPending.Caption := 'Ver Pendencias';
  BtnPending.SetBounds(282, 11, 126, 30);
  BtnPending.OnClick := @OnQuickSyncTabClick;

  BtnCfg := TButton.Create(Self);
  BtnCfg.Parent := FPortalFooter;
  BtnCfg.Caption := 'Configuracoes...';
  BtnCfg.SetBounds(416, 11, 124, 30);
  BtnCfg.OnClick := @OnOpenSettingsClick;

  FPortalFooterBadge := TLabel.Create(Self);
  FPortalFooterBadge.Parent := FPortalFooter;
  FPortalFooterBadge.Alignment := taRightJustify;
  FPortalFooterBadge.Anchors := [akTop, akRight];
  FPortalFooterBadge.Font.Size := 9;
  FPortalFooterBadge.Font.Style := [fsBold];
  FPortalFooterBadge.Font.Color := CLR_TEXT_NAVY;
  FPortalFooterBadge.Caption := 'Pronto';
  FPortalFooterBadge.SetBounds(620, 17, 270, 18);

  LayoutPortalContent;
end;

procedure TMmenuMainForm.LayoutPortalContent;
var
  AvailW, ContentW, LeftX, Y, I: Integer;
begin
  if (FPortalScroll = nil) or (FPortalContent = nil) then Exit;

  AvailW := FPortalScroll.ClientWidth;
  if AvailW < 620 then AvailW := 620;
  ContentW := Min(940, AvailW - 32);
  LeftX := Max(16, (AvailW - ContentW) div 2);

  Y := 14;
  FPortalBanner.SetBounds(0, Y, ContentW, 66);
  Inc(Y, 76);

  for I := 1 to 6 do
  begin
    if FCardPanels[I] <> nil then
      FCardPanels[I].SetBounds(0, Y, ContentW, 96);
    Inc(Y, 106);
  end;

  FPortalFooter.SetBounds(0, Y, ContentW, 52);
  Inc(Y, 68);

  FPortalContent.SetBounds(LeftX, 0, ContentW, Y);
end;

procedure TMmenuMainForm.DrawGearIcon(ACanvas: TCanvas; CX, CY: Integer;
  ROuter: Double; IconColor, BgColor: TColor);
var
  Pts: array[0..31] of TPoint;
  I, N: Integer;
  Ang, RInner, RBase, R: Double;
begin
  RBase := ROuter * 0.76;
  RInner := ROuter * 0.34;
  N := 0;
  for I := 0 to 7 do
  begin
    Ang := (I * 2 * Pi / 8) - Pi / 2;
    R := ROuter;
    Pts[N] := Point(CX + Round(Cos(Ang - 0.14) * R), CY + Round(Sin(Ang - 0.14) * R)); Inc(N);
    Pts[N] := Point(CX + Round(Cos(Ang + 0.14) * R), CY + Round(Sin(Ang + 0.14) * R)); Inc(N);
    R := RBase;
    Pts[N] := Point(CX + Round(Cos(Ang + 0.23) * R), CY + Round(Sin(Ang + 0.23) * R)); Inc(N);
    Pts[N] := Point(CX + Round(Cos(Ang + (2 * Pi / 8) - 0.23) * R),
                    CY + Round(Sin(Ang + (2 * Pi / 8) - 0.23) * R)); Inc(N);
  end;

  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Width := 1;
  ACanvas.Pen.Color := IconColor;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := IconColor;
  ACanvas.Polygon(Pts);

  ACanvas.Brush.Color := BgColor;
  ACanvas.Pen.Color := BgColor;
  ACanvas.Ellipse(CX - Round(RInner), CY - Round(RInner),
                  CX + Round(RInner), CY + Round(RInner));
end;

procedure TMmenuMainForm.DrawAppIllustration(ACanvas: TCanvas; W, H, AppIdx: Integer;
  DarkBg: Boolean);
var
  CX, CY, I, BarH: Integer;
  Fg, Soft, Accent, CardFill: TColor;
  Poly: array[0..3] of TPoint;
  Tri: array[0..2] of TPoint;
begin
  CX := W div 2;
  CY := H div 2;

  if DarkBg then
  begin
    Fg := clWhite;
    Soft := CLR_ICE_SUB;
    Accent := CLR_BLUE_ACCENT;
    CardFill := CLR_BLUE_DARK;
  end
  else
  begin
    Fg := CLR_BLUE_PRIMARY;
    Soft := CLR_BLUE_SOFT;
    Accent := CLR_BLUE_ACCENT;
    CardFill := clWhite;
  end;

  // Circulo suave de fundo para dar unidade visual (estilo badge)
  ACanvas.Pen.Style := psClear;
  ACanvas.Brush.Style := bsSolid;
  if DarkBg then
    ACanvas.Brush.Color := CLR_BLUE_DARK
  else
    ACanvas.Brush.Color := CLR_BLUE_ICE;
  ACanvas.Ellipse(CX - 38, CY - 38, CX + 38, CY + 38);

  ACanvas.Pen.Style := psSolid;

  case AppIdx of
    1: // MScript: Pagina de roteiro + caneta + icone de personagem
      begin
        // Folha de roteiro
        ACanvas.Brush.Color := CardFill;
        ACanvas.Pen.Color := Fg;
        ACanvas.Pen.Width := 2;
        ACanvas.RoundRect(CX - 22, CY - 26, CX + 14, CY + 24, 5, 5);

        // Linhas do roteiro
        ACanvas.Pen.Width := 2;
        ACanvas.Pen.Color := Accent;
        ACanvas.MoveTo(CX - 14, CY - 14); ACanvas.LineTo(CX + 5, CY - 14);
        ACanvas.Pen.Color := Fg;
        ACanvas.MoveTo(CX - 14, CY - 5);  ACanvas.LineTo(CX + 6, CY - 5);
        ACanvas.MoveTo(CX - 14, CY + 4);  ACanvas.LineTo(CX + 3, CY + 4);
        ACanvas.MoveTo(CX - 14, CY + 13); ACanvas.LineTo(CX - 2, CY + 13);

        // Badge personagem no canto inferior direito
        ACanvas.Brush.Color := Fg;
        ACanvas.Pen.Color := CardFill;
        ACanvas.Pen.Width := 2;
        ACanvas.Ellipse(CX + 6, CY - 2, CX + 28, CY + 20);
        ACanvas.Brush.Color := CardFill;
        ACanvas.Pen.Style := psClear;
        ACanvas.Ellipse(CX + 13, CY + 3, CX + 21, CY + 11);
        ACanvas.Chord(CX + 10, CY + 11, CX + 24, CY + 23, 0, 180*16);
        ACanvas.Pen.Style := psSolid;
      end;

    2: // MVisual: Molduras de galeria + paisagem (montanhas + sol)
      begin
        // Moldura traseira
        ACanvas.Brush.Color := Soft;
        ACanvas.Pen.Color := Fg;
        ACanvas.Pen.Width := 2;
        ACanvas.RoundRect(CX - 28, CY - 22, CX + 14, CY + 14, 5, 5);

        // Moldura frontal
        ACanvas.Brush.Color := CardFill;
        ACanvas.Pen.Color := Fg;
        ACanvas.Pen.Width := 2;
        ACanvas.RoundRect(CX - 14, CY - 12, CX + 28, CY + 24, 5, 5);

        // Sol
        ACanvas.Brush.Color := Accent;
        ACanvas.Pen.Style := psClear;
        ACanvas.Ellipse(CX + 12, CY - 6, CX + 21, CY + 3);

        // Montanhas
        ACanvas.Brush.Color := Fg;
        Tri[0] := Point(CX - 10, CY + 19);
        Tri[1] := Point(CX + 2,  CY + 3);
        Tri[2] := Point(CX + 14, CY + 19);
        ACanvas.Polygon(Tri);

        Tri[0] := Point(CX + 4,  CY + 19);
        Tri[1] := Point(CX + 15, CY + 7);
        Tri[2] := Point(CX + 24, CY + 19);
        ACanvas.Polygon(Tri);
        ACanvas.Pen.Style := psSolid;
      end;

    3: // MBoard: Grade 2x2 de Storyboard + setas de sincronizacao
      begin
        ACanvas.Pen.Color := Fg;
        ACanvas.Pen.Width := 2;
        ACanvas.Brush.Color := CardFill;
        ACanvas.RoundRect(CX - 26, CY - 22, CX - 2, CY - 2, 4, 4);
        ACanvas.RoundRect(CX + 2,  CY - 22, CX + 26, CY - 2, 4, 4);
        ACanvas.RoundRect(CX - 26, CY + 2,  CX - 2, CY + 22, 4, 4);
        ACanvas.Brush.Color := Soft;
        ACanvas.RoundRect(CX + 2,  CY + 2,  CX + 26, CY + 22, 4, 4);

        // Mini cenas dentro dos quadros
        ACanvas.Pen.Color := Accent;
        ACanvas.MoveTo(CX - 21, CY - 8); ACanvas.LineTo(CX - 7, CY - 16);
        ACanvas.MoveTo(CX + 7,  CY - 12); ACanvas.LineTo(CX + 21, CY - 12);
        ACanvas.MoveTo(CX - 21, CY + 12); ACanvas.LineTo(CX - 7, CY + 12);
        // Seta sync no ultimo quadro
        ACanvas.Pen.Color := Fg;
        ACanvas.MoveTo(CX + 9, CY + 12); ACanvas.LineTo(CX + 20, CY + 12);
        ACanvas.MoveTo(CX + 16, CY + 8); ACanvas.LineTo(CX + 20, CY + 12);
        ACanvas.LineTo(CX + 16, CY + 16);
      end;

    4: // MSound: Ondas sonoras / Equalizador de voz e audio
      begin
        ACanvas.Pen.Style := psClear;
        for I := -3 to 3 do
        begin
          case Abs(I) of
            0: BarH := 24;
            1: BarH := 18;
            2: BarH := 12;
          else
            BarH := 7;
          end;
          if (I mod 2 = 0) then
            ACanvas.Brush.Color := Fg
          else
            ACanvas.Brush.Color := Accent;
          ACanvas.RoundRect(CX + I * 8 - 3, CY - BarH, CX + I * 8 + 3, CY + BarH, 4, 4);
        end;
        ACanvas.Pen.Style := psSolid;
      end;

    5: // MScene: Claquete de cinema + botao Play
      begin
        // Corpo da claquete
        ACanvas.Brush.Color := CardFill;
        ACanvas.Pen.Color := Fg;
        ACanvas.Pen.Width := 2;
        ACanvas.RoundRect(CX - 24, CY - 10, CX + 24, CY + 22, 5, 5);

        // Barra superior da claquete
        ACanvas.Brush.Color := Fg;
        Poly[0] := Point(CX - 25, CY - 12);
        Poly[1] := Point(CX + 22, CY - 22);
        Poly[2] := Point(CX + 24, CY - 13);
        Poly[3] := Point(CX - 23, CY - 5);
        ACanvas.Polygon(Poly);

        // Triangulo Play no centro
        ACanvas.Brush.Color := Accent;
        ACanvas.Pen.Style := psClear;
        Tri[0] := Point(CX - 6, CY - 3);
        Tri[1] := Point(CX + 10, CY + 6);
        Tri[2] := Point(CX - 6, CY + 15);
        ACanvas.Polygon(Tri);
        ACanvas.Pen.Style := psSolid;
      end;

    6: // MCut: Tira de filme / Timeline com corte
      begin
        // Tira de filme
        ACanvas.Brush.Color := CardFill;
        ACanvas.Pen.Color := Fg;
        ACanvas.Pen.Width := 2;
        ACanvas.RoundRect(CX - 26, CY - 16, CX + 26, CY + 16, 4, 4);

        // Perfurações superior e inferior
        ACanvas.Brush.Color := Fg;
        ACanvas.Pen.Style := psClear;
        for I := -2 to 2 do
        begin
          ACanvas.Rectangle(CX + I * 10 - 2, CY - 13, CX + I * 10 + 3, CY - 9);
          ACanvas.Rectangle(CX + I * 10 - 2, CY + 9,  CX + I * 10 + 3, CY + 13);
        end;

        // Blocos de cena na timeline
        ACanvas.Brush.Color := Soft;
        ACanvas.Rectangle(CX - 21, CY - 6, CX - 3, CY + 6);
        ACanvas.Brush.Color := Accent;
        ACanvas.Rectangle(CX + 3, CY - 6, CX + 21, CY + 6);

        // Linha de corte vertical (playhead)
        ACanvas.Pen.Style := psSolid;
        ACanvas.Pen.Color := Fg;
        ACanvas.Pen.Width := 2;
        ACanvas.MoveTo(CX, CY - 23);
        ACanvas.LineTo(CX, CY + 23);
      end;
  end;
end;

procedure TMmenuMainForm.BuildProjectsTab;
var
  DetailPanel: TPanel;
  L1, L2: TLabel;
begin
  FProjectsGrid := TStringGrid.Create(Self);
  FProjectsGrid.Parent := FTabProjects;
  FProjectsGrid.Align := alClient; MmpPrepareAligned(FProjectsGrid);
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
  DetailPanel.Align := alBottom; MmpPrepareAligned(DetailPanel);
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
  TopBar.Align := alTop; MmpPrepareAligned(TopBar);
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

  FBtnResumeTx := TButton.Create(Self);
  FBtnResumeTx.Parent := TopBar;
  FBtnResumeTx.Caption := 'Retomar transacao';
  FBtnResumeTx.Anchors := [akTop, akRight];
  FBtnResumeTx.SetBounds(902, 8, 158, 30);
  FBtnResumeTx.OnClick := @OnResumeSyncClick;

  FSyncJobsGrid := TStringGrid.Create(Self);
  FSyncJobsGrid.Parent := FTabSync;
  FSyncJobsGrid.Align := alClient; MmpPrepareAligned(FSyncJobsGrid);
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
  MissingPanel.Align := alBottom; MmpPrepareAligned(MissingPanel);
  MissingPanel.Height := 260;
  MissingPanel.Caption := '';
  MissingPanel.BevelOuter := bvNone;

  MidBar := TPanel.Create(Self);
  MidBar.Parent := MissingPanel;
  MidBar.Align := alTop; MmpPrepareAligned(MidBar);
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
  FMissingGrid.Align := alClient; MmpPrepareAligned(FMissingGrid);
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
  FilterBar.Align := alTop; MmpPrepareAligned(FilterBar);
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
  FArtifactsGrid.Align := alClient; MmpPrepareAligned(FArtifactsGrid);
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
  SumBar, FilterBar, BottomBox: TPanel;
  LApp, LLvl, LRes, LSearch, LDtl: TLabel;
  BtnRefresh, BtnResolve, BtnOpenApp, BtnSave: TButton;
  Split: TSplitter;
  I: Integer;
begin
  SumBar := TPanel.Create(Self);
  SumBar.Parent := FTabLog;
  SumBar.Align := alTop; MmpPrepareAligned(SumBar);
  SumBar.Height := 42;
  SumBar.BevelOuter := bvNone;
  SumBar.Color := CLR_BLUE_ICE;

  FLogSummaryLabel := TLabel.Create(Self);
  FLogSummaryLabel.Parent := SumBar;
  FLogSummaryLabel.SetBounds(12, 12, 860, 18);
  FLogSummaryLabel.Font.Style := [fsBold];
  FLogSummaryLabel.Font.Color := CLR_TEXT_NAVY;
  FLogSummaryLabel.Caption := 'Log Centralizado SQLite: todas as operacoes dos 7 executaveis.';

  FilterBar := TPanel.Create(Self);
  FilterBar.Parent := FTabLog;
  FilterBar.Align := alTop; MmpPrepareAligned(FilterBar);
  FilterBar.Height := 44;
  FilterBar.Caption := '';
  FilterBar.BevelOuter := bvNone;

  LApp := TLabel.Create(Self); LApp.Parent := FilterBar; LApp.Caption := 'App:'; LApp.SetBounds(12, 13, 28, 18);
  FLogAppFilter := TComboBox.Create(Self); FLogAppFilter.Parent := FilterBar;
  FLogAppFilter.Style := csDropDownList;
  FLogAppFilter.Items.Add('Todos');
  for I := 0 to 6 do FLogAppFilter.Items.Add(MmpAppNames[I]);
  FLogAppFilter.ItemIndex := 0;
  FLogAppFilter.SetBounds(42, 9, 98, 26);
  FLogAppFilter.OnChange := @OnCentralLogFilterChange;

  LLvl := TLabel.Create(Self); LLvl.Parent := FilterBar; LLvl.Caption := 'Nivel:'; LLvl.SetBounds(146, 13, 35, 18);
  FLogLevelFilter := TComboBox.Create(Self); FLogLevelFilter.Parent := FilterBar;
  FLogLevelFilter.Style := csDropDownList;
  FLogLevelFilter.Items.Add('Todos');
  FLogLevelFilter.Items.Add('info');
  FLogLevelFilter.Items.Add('warn');
  FLogLevelFilter.Items.Add('error');
  FLogLevelFilter.ItemIndex := 0;
  FLogLevelFilter.SetBounds(184, 9, 78, 26);
  FLogLevelFilter.OnChange := @OnCentralLogFilterChange;

  LRes := TLabel.Create(Self); LRes.Parent := FilterBar; LRes.Caption := 'Situacao:'; LRes.SetBounds(268, 13, 55, 18);
  FLogResolvedFilter := TComboBox.Create(Self); FLogResolvedFilter.Parent := FilterBar;
  FLogResolvedFilter.Style := csDropDownList;
  FLogResolvedFilter.Items.Add('Todos');
  FLogResolvedFilter.Items.Add('Pendentes / Nao resolvidos');
  FLogResolvedFilter.Items.Add('Corrigidos / Resolvidos');
  FLogResolvedFilter.ItemIndex := 0;
  FLogResolvedFilter.SetBounds(326, 9, 155, 26);
  FLogResolvedFilter.OnChange := @OnCentralLogFilterChange;

  LSearch := TLabel.Create(Self); LSearch.Parent := FilterBar; LSearch.Caption := 'Buscar:'; LSearch.SetBounds(488, 13, 44, 18);
  FLogSearchEdit := TEdit.Create(Self); FLogSearchEdit.Parent := FilterBar;
  FLogSearchEdit.SetBounds(534, 9, 130, 26);
  FLogSearchEdit.OnChange := @OnCentralLogFilterChange;

  BtnRefresh := TButton.Create(Self); BtnRefresh.Parent := FilterBar; BtnRefresh.Caption := 'Atualizar';
  BtnRefresh.SetBounds(670, 8, 74, 28); BtnRefresh.OnClick := @OnCentralLogFilterChange;

  BtnResolve := TButton.Create(Self); BtnResolve.Parent := FilterBar; BtnResolve.Caption := 'Marcar Corrigido...';
  BtnResolve.SetBounds(748, 8, 128, 28); BtnResolve.OnClick := @OnResolveCentralLogClick;

  BtnOpenApp := TButton.Create(Self); BtnOpenApp.Parent := FilterBar; BtnOpenApp.Caption := 'Abrir Etapa';
  BtnOpenApp.SetBounds(880, 8, 88, 28); BtnOpenApp.OnClick := @OnOpenLogAppClick;

  BtnSave := TButton.Create(Self); BtnSave.Parent := FilterBar; BtnSave.Caption := 'Exportar...';
  BtnSave.SetBounds(972, 8, 82, 28); BtnSave.OnClick := @OnSaveLogClick;

  BottomBox := TPanel.Create(Self);
  BottomBox.Parent := FTabLog;
  BottomBox.Align := alBottom; MmpPrepareAligned(BottomBox);
  BottomBox.Height := 165;
  BottomBox.BevelOuter := bvNone;

  LDtl := TLabel.Create(Self);
  LDtl.Parent := BottomBox;
  LDtl.Align := alTop; MmpPrepareAligned(LDtl);
  LDtl.Height := 24;
  LDtl.Layout := tlCenter;
  LDtl.Font.Style := [fsBold];
  LDtl.Caption := '  Detalhes da entrada selecionada / Nota de correcao:';

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := BottomBox;
  FLogMemo.Align := alClient; MmpPrepareAligned(FLogMemo);
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssBoth;

  Split := TSplitter.Create(Self);
  Split.Parent := FTabLog;
  Split.Align := alBottom; MmpPrepareAligned(Split);
  Split.Height := 5;

  FCentralLogGrid := TStringGrid.Create(Self);
  FCentralLogGrid.Parent := FTabLog;
  FCentralLogGrid.Align := alClient; MmpPrepareAligned(FCentralLogGrid);
  FCentralLogGrid.ColCount := 7;
  FCentralLogGrid.RowCount := 2;
  FCentralLogGrid.FixedRows := 1;
  FCentralLogGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goColSizing];
  FCentralLogGrid.Cells[0, 0] := 'ID';
  FCentralLogGrid.Cells[1, 0] := 'Data/Hora';
  FCentralLogGrid.Cells[2, 0] := 'App';
  FCentralLogGrid.Cells[3, 0] := 'Nivel';
  FCentralLogGrid.Cells[4, 0] := 'Revisao';
  FCentralLogGrid.Cells[5, 0] := 'Estado';
  FCentralLogGrid.Cells[6, 0] := 'Mensagem';
  FCentralLogGrid.ColWidths[0] := 48;
  FCentralLogGrid.ColWidths[1] := 142;
  FCentralLogGrid.ColWidths[2] := 74;
  FCentralLogGrid.ColWidths[3] := 58;
  FCentralLogGrid.ColWidths[4] := 65;
  FCentralLogGrid.ColWidths[5] := 92;
  FCentralLogGrid.ColWidths[6] := 470;
  FCentralLogGrid.OnSelection := @OnCentralLogGridSelection;
end;

procedure TMmenuMainForm.BuildHistoryTab;
var
  SummaryBar, FilterBar, BottomBox: TPanel;
  LApp, LKind, LSearch, LDtlTitle: TLabel;
  BtnRefresh, BtnExport: TButton;
  Split: TSplitter;
  I: Integer;
begin
  SummaryBar := TPanel.Create(Self);
  SummaryBar.Parent := FTabHistory;
  SummaryBar.Align := alTop; MmpPrepareAligned(SummaryBar);
  SummaryBar.Height := 46;
  SummaryBar.BevelOuter := bvNone;
  SummaryBar.Color := CLR_BLUE_ICE;

  FHistorySummaryLabel := TLabel.Create(Self);
  FHistorySummaryLabel.Parent := SummaryBar;
  FHistorySummaryLabel.SetBounds(12, 13, 860, 20);
  FHistorySummaryLabel.Font.Style := [fsBold];
  FHistorySummaryLabel.Font.Color := CLR_TEXT_NAVY;
  FHistorySummaryLabel.Caption := 'Controle do que ja foi feito na producao.';

  FilterBar := TPanel.Create(Self);
  FilterBar.Parent := FTabHistory;
  FilterBar.Align := alTop; MmpPrepareAligned(FilterBar);
  FilterBar.Height := 42;
  FilterBar.BevelOuter := bvNone;

  LApp := TLabel.Create(Self);
  LApp.Parent := FilterBar;
  LApp.Caption := 'Etapa/App:';
  LApp.SetBounds(12, 13, 66, 18);

  FHistoryAppFilter := TComboBox.Create(Self);
  FHistoryAppFilter.Parent := FilterBar;
  FHistoryAppFilter.Style := csDropDownList;
  FHistoryAppFilter.SetBounds(80, 9, 110, 26);
  FHistoryAppFilter.Items.Add('Todos');
  for I := 0 to 6 do
    FHistoryAppFilter.Items.Add(MmpAppNames[I]);
  FHistoryAppFilter.ItemIndex := 0;
  FHistoryAppFilter.OnChange := @OnHistoryFilterChange;

  LKind := TLabel.Create(Self);
  LKind.Parent := FilterBar;
  LKind.Caption := 'Tipo:';
  LKind.SetBounds(202, 13, 35, 18);

  FHistoryKindFilter := TComboBox.Create(Self);
  FHistoryKindFilter.Parent := FilterBar;
  FHistoryKindFilter.Style := csDropDownList;
  FHistoryKindFilter.SetBounds(240, 9, 120, 26);
  FHistoryKindFilter.Items.Add('Todos');
  FHistoryKindFilter.Items.Add('Revisao');
  FHistoryKindFilter.Items.Add('Log');
  FHistoryKindFilter.Items.Add('Sincronizacao');
  FHistoryKindFilter.ItemIndex := 0;
  FHistoryKindFilter.OnChange := @OnHistoryFilterChange;

  LSearch := TLabel.Create(Self);
  LSearch.Parent := FilterBar;
  LSearch.Caption := 'Buscar:';
  LSearch.SetBounds(372, 13, 46, 18);

  FHistorySearchEdit := TEdit.Create(Self);
  FHistorySearchEdit.Parent := FilterBar;
  FHistorySearchEdit.SetBounds(420, 9, 200, 26);
  FHistorySearchEdit.OnChange := @OnHistoryFilterChange;

  BtnRefresh := TButton.Create(Self);
  BtnRefresh.Parent := FilterBar;
  BtnRefresh.Caption := 'Atualizar';
  BtnRefresh.SetBounds(630, 8, 92, 28);
  BtnRefresh.OnClick := @OnRefreshClick;

  BtnExport := TButton.Create(Self);
  BtnExport.Parent := FilterBar;
  BtnExport.Caption := 'Exportar...';
  BtnExport.SetBounds(728, 8, 102, 28);
  BtnExport.OnClick := @OnExportHistoryClick;

  BottomBox := TPanel.Create(Self);
  BottomBox.Parent := FTabHistory;
  BottomBox.Align := alBottom; MmpPrepareAligned(BottomBox);
  BottomBox.Height := 175;
  BottomBox.BevelOuter := bvNone;

  LDtlTitle := TLabel.Create(Self);
  LDtlTitle.Parent := BottomBox;
  LDtlTitle.Align := alTop; MmpPrepareAligned(LDtlTitle);
  LDtlTitle.Caption := '  Detalhes da acao selecionada (o que foi feito, versao, sinopse e artefatos):';
  LDtlTitle.Font.Style := [fsBold];
  LDtlTitle.Layout := tlCenter;
  LDtlTitle.Height := 24;

  FHistoryDetailMemo := TMemo.Create(Self);
  FHistoryDetailMemo.Parent := BottomBox;
  FHistoryDetailMemo.Align := alClient; MmpPrepareAligned(FHistoryDetailMemo);
  FHistoryDetailMemo.ReadOnly := True;
  FHistoryDetailMemo.ScrollBars := ssBoth;

  Split := TSplitter.Create(Self);
  Split.Parent := FTabHistory;
  Split.Align := alBottom; MmpPrepareAligned(Split);
  Split.Height := 5;

  FHistoryGrid := TStringGrid.Create(Self);
  FHistoryGrid.Parent := FTabHistory;
  FHistoryGrid.Align := alClient; MmpPrepareAligned(FHistoryGrid);
  FHistoryGrid.ColCount := 6;
  FHistoryGrid.RowCount := 2;
  FHistoryGrid.FixedRows := 1;
  FHistoryGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goColSizing];
  FHistoryGrid.Cells[0, 0] := 'Data/Hora';
  FHistoryGrid.Cells[1, 0] := 'Etapa/App';
  FHistoryGrid.Cells[2, 0] := 'Tipo';
  FHistoryGrid.Cells[3, 0] := 'Versao';
  FHistoryGrid.Cells[4, 0] := 'Estado';
  FHistoryGrid.Cells[5, 0] := 'Resumo do que foi feito';
  FHistoryGrid.ColWidths[0] := 145;
  FHistoryGrid.ColWidths[1] := 85;
  FHistoryGrid.ColWidths[2] := 95;
  FHistoryGrid.ColWidths[3] := 85;
  FHistoryGrid.ColWidths[4] := 90;
  FHistoryGrid.ColWidths[5] := 460;
  FHistoryGrid.OnSelection := @OnHistoryGridSelection;
end;

// === Event handlers de desenho e menus ===

procedure TMmenuMainForm.OnMenuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMmenuMainForm.OnMenuLaunchAppClick(Sender: TObject);
var
  AppIdx, I: Integer;
  ProjId, RevId: string;
begin
  AppIdx := (Sender as TComponent).Tag;
  ProjId := '';
  RevId := '';
  if FProd.Loaded then
  begin
    for I := 0 to High(FProd.Projects) do
    begin
      if (FProd.Projects[I].SoftwareIndex = AppIdx) and (FProd.Projects[I].SceneId = '') then
      begin
        ProjId := FProd.Projects[I].ProjectId;
        RevId := FProd.Projects[I].ActiveRevision;
        Break;
      end;
    end;
  end;
  LaunchApplication(AppIdx, ProjId, RevId);
end;

procedure TMmenuMainForm.OnMenuSwitchTabClick(Sender: TObject);
var
  TabIdx: Integer;
begin
  TabIdx := (Sender as TComponent).Tag;
  if (TabIdx >= 0) and (TabIdx < FPageControl.PageCount) then
    FPageControl.ActivePageIndex := TabIdx;
end;

procedure TMmenuMainForm.OnMenuSettingsTabClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := (Sender as TComponent).Tag;
  if (Idx >= 0) and (Idx < SETTINGS_TAB_COUNT) then
    OpenSettingsTab(SettingsTabKeys[Idx])
  else
    OpenSettingsTab('geral');
end;

procedure TMmenuMainForm.OnAboutClick(Sender: TObject);
begin
  MessageDlg(
    'MaurinMovie  |  MMenu (Portal da Suite)' + LineEnding +
    'Versao: ' + MMP_EXECUTABLE_VERSION + LineEnding +
    'Protocolo: MMP v1' + LineEnding + LineEnding +
    'Aplicativos: MScript -> MVisual -> MBoard -> MSound -> MScene -> MCut',
    mtInformation, [mbOK], 0);
end;

procedure TMmenuMainForm.OnGearPaint(Sender: TObject);
var
  PB: TPaintBox;
  Bg: TColor;
begin
  PB := Sender as TPaintBox;
  if FGearHover then Bg := CLR_BLUE_ACCENT else Bg := CLR_BLUE_PRIMARY;
  PB.Canvas.Brush.Style := bsSolid;
  PB.Canvas.Brush.Color := Bg;
  PB.Canvas.FillRect(0, 0, PB.Width, PB.Height);
  DrawGearIcon(PB.Canvas, PB.Width div 2, PB.Height div 2, 11.5, clWhite, Bg);
end;

procedure TMmenuMainForm.OnGearArrowPaint(Sender: TObject);
var
  PB: TPaintBox;
  Bg: TColor;
  CX, CY: Integer;
  Tri: array[0..2] of TPoint;
begin
  PB := Sender as TPaintBox;
  if FGearDropHover then Bg := CLR_BLUE_ACCENT else Bg := CLR_BLUE_PRIMARY;
  PB.Canvas.Brush.Style := bsSolid;
  PB.Canvas.Brush.Color := Bg;
  PB.Canvas.FillRect(0, 0, PB.Width, PB.Height);

  CX := PB.Width div 2;
  CY := PB.Height div 2;
  Tri[0] := Point(CX - 4, CY - 2);
  Tri[1] := Point(CX + 4, CY - 2);
  Tri[2] := Point(CX, CY + 3);
  PB.Canvas.Pen.Style := psClear;
  PB.Canvas.Brush.Color := clWhite;
  PB.Canvas.Polygon(Tri);
end;

procedure TMmenuMainForm.OnGearMouseEnter(Sender: TObject);
begin
  FGearHover := True;
  if FGearPaintBox <> nil then FGearPaintBox.Invalidate;
end;

procedure TMmenuMainForm.OnGearMouseLeave(Sender: TObject);
begin
  FGearHover := False;
  if FGearPaintBox <> nil then FGearPaintBox.Invalidate;
end;

procedure TMmenuMainForm.OnGearArrowMouseEnter(Sender: TObject);
begin
  FGearDropHover := True;
  if FGearArrowBox <> nil then FGearArrowBox.Invalidate;
end;

procedure TMmenuMainForm.OnGearArrowMouseLeave(Sender: TObject);
begin
  FGearDropHover := False;
  if FGearArrowBox <> nil then FGearArrowBox.Invalidate;
end;

procedure TMmenuMainForm.OnGearArrowClick(Sender: TObject);
var
  P: TPoint;
begin
  if (FHeaderGearPanel <> nil) and (FGearPopup <> nil) then
  begin
    P := FHeaderGearPanel.ClientToScreen(Point(0, FHeaderGearPanel.Height));
    FGearPopup.Popup(P.X, P.Y);
  end;
end;

procedure TMmenuMainForm.OnPortalScrollResize(Sender: TObject);
begin
  LayoutPortalContent;
end;

procedure TMmenuMainForm.OnStripBorderPaint(Sender: TObject);
var
  P: TPanel;
begin
  P := Sender as TPanel;
  P.Canvas.Brush.Style := bsClear;
  P.Canvas.Pen.Style := psSolid;
  P.Canvas.Pen.Width := 1;
  if (P.Tag mod 2 = 0) then
    P.Canvas.Pen.Color := CLR_BLUE_DARK
  else
    P.Canvas.Pen.Color := CLR_BLUE_BORDER;
  P.Canvas.Rectangle(0, 0, P.Width, P.Height);
end;

procedure TMmenuMainForm.OnCardBorderPaint(Sender: TObject);
var
  P: TPanel;
begin
  P := Sender as TPanel;
  P.Canvas.Brush.Style := bsClear;
  P.Canvas.Pen.Style := psSolid;
  P.Canvas.Pen.Width := 1;
  P.Canvas.Pen.Color := CLR_BLUE_BORDER;
  P.Canvas.Rectangle(0, 0, P.Width, P.Height);
end;

procedure TMmenuMainForm.OnIllustPaint(Sender: TObject);
var
  PB: TPaintBox;
  AppIdx: Integer;
  DarkBg: Boolean;
begin
  PB := Sender as TPaintBox;
  AppIdx := PB.Tag;
  DarkBg := (AppIdx mod 2 = 0);
  PB.Canvas.Brush.Style := bsSolid;
  if DarkBg then
    PB.Canvas.Brush.Color := CLR_BLUE_PRIMARY
  else
    PB.Canvas.Brush.Color := clWhite;
  PB.Canvas.FillRect(0, 0, PB.Width, PB.Height);
  DrawAppIllustration(PB.Canvas, PB.Width, PB.Height, AppIdx, DarkBg);
end;

procedure TMmenuMainForm.OnActionPillPaint(Sender: TObject);
var
  PB: TPaintBox;
  AppIdx, PillW, PillH, PillX, PillY, MidY: Integer;
  DarkBg, IsHover: Boolean;
  PillBg, PillBorder, PillText, LineCol, SubCol: TColor;
  S, SubS: string;
  TS: TSize;
begin
  PB := Sender as TPaintBox;
  AppIdx := PB.Tag;
  DarkBg := (AppIdx mod 2 = 0);
  IsHover := FCardActionHover[AppIdx];

  // Fundo da faixa
  PB.Canvas.Brush.Style := bsSolid;
  if DarkBg then
    PB.Canvas.Brush.Color := CLR_BLUE_PRIMARY
  else
    PB.Canvas.Brush.Color := clWhite;
  PB.Canvas.FillRect(0, 0, PB.Width, PB.Height);

  PillW := 168;
  PillH := 36;
  PillX := (PB.Width - PillW) div 2;
  PillY := 20;
  MidY := PillY + (PillH div 2);

  // Linha conectora estilo cardapio ligando a imagem a pilula
  if DarkBg then
    LineCol := CLR_ICE_SUB
  else
    LineCol := CLR_BLUE_BORDER;
  PB.Canvas.Pen.Style := psSolid;
  PB.Canvas.Pen.Width := 2;
  PB.Canvas.Pen.Color := LineCol;
  if DarkBg then
  begin
    PB.Canvas.MoveTo(PillX + PillW, MidY);
    PB.Canvas.LineTo(PB.Width - 4, MidY);
  end
  else
  begin
    PB.Canvas.MoveTo(4, MidY);
    PB.Canvas.LineTo(PillX, MidY);
  end;

  // Cores da pilula
  if FCardActionOkFlag[AppIdx] = -2 then
  begin
    PillBg := $00D8DDE4;
    PillBorder := $008C96A4;
    PillText := $00505864;
  end
  else if FCardActionOkFlag[AppIdx] = 2 then
  begin
    if DarkBg then
    begin
      if IsHover then PillBg := $00C8ECFF else PillBg := $00E8F6FF;
      PillBorder := $0060C0FF;
      PillText := $000058A8;
    end
    else
    begin
      if IsHover then PillBg := $00188AE8 else PillBg := $00006EC8;
      PillBorder := $00004C8C;
      PillText := clWhite;
    end;
  end
  else if DarkBg then
  begin
    if IsHover then PillBg := CLR_BLUE_SOFT else PillBg := clWhite;
    PillBorder := clWhite;
    PillText := CLR_BLUE_PRIMARY;
  end
  else
  begin
    if IsHover then PillBg := CLR_BLUE_ACCENT else PillBg := CLR_BLUE_PRIMARY;
    PillBorder := CLR_BLUE_DARK;
    PillText := clWhite;
  end;

  PB.Canvas.Brush.Style := bsSolid;
  PB.Canvas.Brush.Color := PillBg;
  PB.Canvas.Pen.Color := PillBorder;
  PB.Canvas.Pen.Width := 2;
  PB.Canvas.RoundRect(PillX, PillY, PillX + PillW, PillY + PillH, 18, 18);

  S := FCardActionLabels[AppIdx];
  PB.Canvas.Font.Size := 10;
  PB.Canvas.Font.Style := [fsBold];
  PB.Canvas.Font.Color := PillText;
  PB.Canvas.Brush.Style := bsClear;
  TS := PB.Canvas.TextExtent(S);
  PB.Canvas.TextOut(PillX + (PillW - TS.cx) div 2, PillY + (PillH - TS.cy) div 2, S);

  // Sub-badge de revisao/status abaixo da pilula
  SubS := FCardActionSubLabels[AppIdx];
  PB.Canvas.Font.Size := 8;
  PB.Canvas.Font.Style := [fsBold];
  if DarkBg then
    SubCol := CLR_ICE_SUB
  else
  begin
    case FCardActionOkFlag[AppIdx] of
      1: SubCol := CLR_STATUS_OK;
      2: SubCol := CLR_STATUS_WARN;
      -1: SubCol := CLR_STATUS_ERR;
      -2: SubCol := CLR_TEXT_MUTED;
    else
      SubCol := CLR_TEXT_MUTED;
    end;
  end;
  PB.Canvas.Font.Color := SubCol;
  TS := PB.Canvas.TextExtent(SubS);
  PB.Canvas.TextOut((PB.Width - TS.cx) div 2, PillY + PillH + 7, SubS);
end;

procedure TMmenuMainForm.OnActionPillMouseEnter(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := (Sender as TPaintBox).Tag;
  FCardActionHover[Idx] := True;
  (Sender as TPaintBox).Invalidate;
end;

procedure TMmenuMainForm.OnActionPillMouseLeave(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := (Sender as TPaintBox).Tag;
  FCardActionHover[Idx] := False;
  (Sender as TPaintBox).Invalidate;
end;

procedure TMmenuMainForm.OnRevLinkMouseEnter(Sender: TObject);
var
  L: TLabel;
begin
  L := Sender as TLabel;
  if (L.Tag mod 2 = 0) then
    L.Font.Color := CLR_ICE_SUB
  else
    L.Font.Color := CLR_BLUE_ACCENT;
end;

procedure TMmenuMainForm.OnRevLinkMouseLeave(Sender: TObject);
var
  L: TLabel;
begin
  L := Sender as TLabel;
  if (L.Tag mod 2 = 0) then
    L.Font.Color := clWhite
  else
    L.Font.Color := CLR_BLUE_PRIMARY;
end;

procedure TMmenuMainForm.OnQuickSyncTabClick(Sender: TObject);
begin
  FPageControl.ActivePage := FTabSync;
end;

// === Logica existente preservada ===

procedure TMmenuMainForm.LogMsg(const Msg: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
  if not (csDestroying in ComponentState) then
    MmpLogAppOperation(FProd.RootDir, FProd.ProductionId, 'MMenu', Msg, '', 'menu', CurrentSessionUserName);
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
      FRecentsList.Items.Add(FRecents[I].Title + TagStr);
    end;
  finally
    FRecentsList.Items.EndUpdate;
  end;
  RefreshManagerGrid;
end;

procedure TMmenuMainForm.RefreshManagerGrid;
var
  I, Row: Integer;
  HasAny, ExistsOk: Boolean;
begin
  if FManagerGrid = nil then Exit;
  HasAny := Length(FRecents) > 0;
  if FBtnMgrOpenSel <> nil then FBtnMgrOpenSel.Enabled := HasAny;
  if FBtnMgrLocate <> nil then FBtnMgrLocate.Enabled := HasAny;
  if FBtnMgrRemove <> nil then FBtnMgrRemove.Enabled := HasAny;

  if not HasAny then
  begin
    FManagerGrid.RowCount := 2;
    for I := 0 to FManagerGrid.ColCount - 1 do
      FManagerGrid.Cells[I, 1] := '';
    FManagerGrid.Cells[0, 1] := '(nenhuma producao recente)';
    Exit;
  end;

  FManagerGrid.RowCount := Length(FRecents) + 1;
  for I := 0 to High(FRecents) do
  begin
    Row := I + 1;
    ExistsOk := FileExists(IncludeTrailingPathDelimiter(FRecents[I].RootDir) + MMP_PRODUCTION_FILE);
    FManagerGrid.Cells[0, Row] := FRecents[I].Title;
    FManagerGrid.Cells[1, Row] := FRecents[I].ProductionId;
    if ExistsOk then
      FManagerGrid.Cells[2, Row] := 'Disponivel'
    else
      FManagerGrid.Cells[2, Row] := 'Movida / Ausente';
    FManagerGrid.Cells[3, Row] := FRecents[I].RootDir;
  end;
  if (FManagerGrid.Row < 1) or (FManagerGrid.Row >= FManagerGrid.RowCount) then
    FManagerGrid.Row := 1;
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
  Executable, ArgLine, ProjDir, LockInfo, EffProjId, EffRevId, EffSceneId: string;
  P: TProcess;
  I, K, AskRes: Integer;
  Eval, UpEval: TMmpStageStatus;
begin
  Result := False;
  if (AppIdx < 1) or (AppIdx > 6) then
  begin
    MessageDlg('Aplicativo destino invalido ou proprio MMenu.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if (not FProd.Loaded) or (FProd.RootDir = '') or
     (not FileExists(IncludeTrailingPathDelimiter(FProd.RootDir) + MMP_PRODUCTION_FILE)) then
  begin
    MessageDlg('Abra ou crie uma producao no MMenu antes de iniciar ' + MmpAppNames[AppIdx] + '.' +
      LineEnding + LineEnding +
      'Os aplicativos da suite dependem do contexto de producao e projeto fornecido pelo MMenu.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  Eval := MmpEvaluateStageStatus(FProd, AppIdx);
  if not Eval.CanOpen then
  begin
    LogMsg('Bloqueado ' + MmpAppNames[AppIdx] + ': etapas anteriores nao geradas (' + Eval.MissingPrereqs + ').');
    MessageDlg('Nao e possivel abrir ' + MmpAppNames[AppIdx] + ' ainda.' + LineEnding + LineEnding +
      'Etapa(s) anterior(es) ainda nao gerada(s): ' + Eval.MissingPrereqs + '.' + LineEnding +
      'Execute e salve as etapas na ordem da suite antes de continuar.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  for K := 1 to AppIdx - 1 do
  begin
    UpEval := MmpEvaluateStageStatus(FProd, K);
    if UpEval.NeedsAdjustment then
    begin
      AskRes := MessageDlg(
        'A etapa anterior "' + MmpAppNames[K] + '" tambem precisa ser reajustada (' +
        UpEval.StaleReason + ').' + LineEnding + LineEnding +
        'Deseja abrir ' + MmpAppNames[K] + ' primeiro para reajustar em ordem?' + LineEnding +
        '(Clique em Nao para abrir ' + MmpAppNames[AppIdx] + ' diretamente.)',
        mtConfirmation, [mbYes, mbNo, mbCancel], 0);
      if AskRes = mrYes then
      begin
        Result := LaunchApplication(K, '', '');
        Exit;
      end
      else if AskRes <> mrNo then
        Exit;
      Break;
    end;
  end;

  if Eval.NeedsAdjustment then
    LogMsg('Abrindo ' + MmpAppNames[AppIdx] + ' para reajuste: ' + Eval.StaleReason);

  EffProjId := Trim(ProjectId);
  EffRevId := Trim(RevisionId);
  if EffProjId = '' then
  begin
    for I := 0 to High(FProd.Projects) do
      if (FProd.Projects[I].SoftwareIndex = AppIdx) and (FProd.Projects[I].SceneId = '') then
      begin
        EffProjId := FProd.Projects[I].ProjectId;
        if EffRevId = '' then
          EffRevId := FProd.Projects[I].ActiveRevision;
        Break;
      end;
  end;
  if EffProjId = '' then
  begin
    for I := 0 to High(FProd.Projects) do
      if FProd.Projects[I].SoftwareIndex = AppIdx then
      begin
        EffProjId := FProd.Projects[I].ProjectId;
        if EffRevId = '' then
          EffRevId := FProd.Projects[I].ActiveRevision;
        Break;
      end;
  end;
  if EffProjId = '' then
  begin
    MessageDlg('Nenhum projeto de ' + MmpAppNames[AppIdx] +
      ' foi encontrado na producao ativa (' + FProd.Title + ').', mtWarning, [mbOK], 0);
    Exit;
  end;
  if EffRevId = '' then
    EffRevId := 'r0001';

  { Projeto por cena do MScene: o aplicativo precisa receber --scene-id
    (docs/specs/01-mmenu RF-MM-06). }
  EffSceneId := '';
  for I := 0 to High(FProd.Projects) do
    if SameText(FProd.Projects[I].ProjectId, EffProjId) then
    begin
      EffSceneId := FProd.Projects[I].SceneId;
      Break;
    end;

  if IsAppInstanceRunning(AppIndexToEnum(AppIdx)) then
  begin
    FocusAppInstanceWindow(AppIndexToEnum(AppIdx));
    LogMsg('Instancia unica: ' + MmpAppNames[AppIdx] + ' ja esta em execucao.');
    SetStatus(MmpAppNames[AppIdx] + ' ja esta aberto.', 100);
    MessageDlg('O aplicativo ' + MmpAppNames[AppIdx] +
      ' ja esta em execucao (permitida apenas 1 instancia).' + LineEnding +
      'A janela existente foi trazida para frente.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  ProjDir := IncludeTrailingPathDelimiter(FProd.RootDir) + 'projects' +
    PathDelim + MmpAppFolders[AppIdx];
  if IsProjectLocked(ProjDir, LockInfo) then
  begin
    if MessageDlg('O aplicativo ' + MmpAppNames[AppIdx] + ' ja possui lock ativo (' +
      LockInfo + ').' + LineEnding + 'Deseja abrir mesmo assim?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;

  Executable := FAppPaths[AppIdx];
  if (Executable = '') or (not FileExists(Executable)) then
    Executable := FindExecutable(MmpAppNames[AppIdx]);

  if Executable = '' then
  begin
    MessageDlg('Executavel de ' + MmpAppNames[AppIdx] +
      ' nao encontrado. Configure o caminho na engrenagem (Configuracoes).', mtWarning, [mbOK], 0);
    LogMsg('FALHA ao iniciar ' + MmpAppNames[AppIdx] + ': executavel ausente.');
    Exit;
  end;

  P := TProcess.Create(nil);
  try
    P.Executable := Executable;
    BuildLaunchArgs(FProd.RootDir, EffProjId, EffRevId, P.Parameters, FProd.ProductionId,
      EffSceneId);
    P.Options := [];

    ArgLine := Executable;
    for I := 0 to P.Parameters.Count - 1 do
      ArgLine := ArgLine + ' "' + P.Parameters[I] + '"';

    try
      P.Execute;
      AppendJsonLogLine(FProd.RootDir, 'MMenu', 'info',
        'Iniciado ' + MmpAppNames[AppIdx] + ' (projeto ' + EffProjId +
        ', revisao ' + EffRevId + ')');
      LogMsg('Iniciado (MMenu v' + MAURINMOVIE_VERSION + ', proj=' + EffProjId +
        ', rev=' + EffRevId + '): ' + ArgLine);
      SetStatus(MmpAppNames[AppIdx] + ' iniciado (projeto ' + EffProjId +
        ', revisao ' + EffRevId + ').', 100);
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
  CheckHashes: Boolean; ShowIntegrityAlert: Boolean);
var
  LoadedProd: TMmpProduction;
  I, MaxShow: Integer;
  WarnLines: string;
begin
  SetStatus('Verificando integridade e carregando producao...', 20);
  Application.ProcessMessages;

  if LoadProduction(PathOrJson, CheckHashes, LoadedProd) then
  begin
    FProd := LoadedProd;
    FSettings.Load(FProd.RootDir, maMMenu);
    AddOrUpdateRecent(FProd);
    SaveConfig;
    LogMsg('Producao carregada: "' + FProd.Title + '" (' + FProd.ProductionId +
      ') em ' + FProd.RootDir + ' | ' + FProd.OverallStatusText);
    AppendJsonLogLine(FProd.RootDir, 'MMenu', 'info',
      'Producao aberta (hashCheck=' + BoolToStr(CheckHashes, True) + '): ' + FProd.Title);
    if CheckHashes and (not FProd.HasFailures) then
      LogMsg('Verificacao de integridade OK: ' + IntToStr(Length(FProd.Artifacts)) + ' artefato(s) integro(s).');
    SetStatus('Producao carregada: ' + FProd.Title, 100);
    RefreshAllViews;

    if FProd.HasFailures and ShowIntegrityAlert then
    begin
      WarnLines := '';
      MaxShow := Length(FProd.MissingLinks);
      if MaxShow > 6 then MaxShow := 6;
      for I := 0 to MaxShow - 1 do
        WarnLines := WarnLines + '• [' + FProd.MissingLinks[I].AppName + ' / ' +
          FProd.MissingLinks[I].Status + '] ' + FProd.MissingLinks[I].Detail + LineEnding;
      if Length(FProd.MissingLinks) > 6 then
        WarnLines := WarnLines + '... e mais ' + IntToStr(Length(FProd.MissingLinks) - 6) + ' ocorrencia(s).' + LineEnding;
      if WarnLines = '' then
        WarnLines := '• Existem falhas registradas em sincronizacoes ou manifestos.' + LineEnding;

      LogMsg('ALERTA DE INTEGRIDADE ao abrir "' + FProd.Title + '": ' +
        IntToStr(Length(FProd.MissingLinks)) + ' problema(s) encontrado(s).');
      FPageControl.ActivePage := FTabSync;
      MessageDlg('A verificacao de integridade detectou problemas ao abrir "' + FProd.Title + '":' +
        LineEnding + LineEnding + WarnLines + LineEnding +
        'Confira os detalhes na aba Sincronizacoes & Pendencias.',
        mtWarning, [mbOK], 0);
    end;
  end
  else
  begin
    Finalize(FProd);
    FillChar(FProd, SizeOf(FProd), 0);
    FSelectedProjectIndex := -1;
    SetLength(FVisibleProjectIndices, 0);
    LogMsg('FALHA DE INTEGRIDADE ao abrir producao: ' + LoadedProd.ErrorMessage);
    SetStatus(LoadedProd.ErrorMessage, 0);
    RefreshAllViews;
    if ShowIntegrityAlert then
      MessageDlg('Nao foi possivel abrir a producao porque os arquivos de controle estao ausentes ou corrompidos:' +
        LineEnding + LineEnding + LoadedProd.ErrorMessage,
        mtError, [mbOK], 0);
  end;
end;

procedure TMmenuMainForm.RefreshAllViews;
var
  I, VisibleProjCount: Integer;
  Eval: TMmpStageStatus;
  TagSuffix: string;
begin
  if FProd.Loaded then
  begin
    VisibleProjCount := 0;
    for I := 0 to High(FProd.Projects) do
      if MmpProjectHasActivity(FProd.Projects[I]) then
        Inc(VisibleProjCount);
    FHeaderProdLabel.Caption := FProd.Title + '  (' + FProd.ProductionId + ')';
    FHeaderStatusBadge.Caption := FProd.OverallStatusText;
    if FProd.HasFailures then
    begin
      FHeaderStatusBadge.Font.Color := $008080FF;
      FPortalBannerBadge.Caption := 'Atencao: falhas';
      FPortalBannerBadge.Font.Color := $008080FF;
      FPortalFooterBadge.Caption := FProd.OverallStatusText;
      FPortalFooterBadge.Font.Color := CLR_STATUS_ERR;
    end
    else if FProd.HasPendingWork then
    begin
      FHeaderStatusBadge.Font.Color := $0066D9FF;
      FPortalBannerBadge.Caption := 'Pendencias ativas';
      FPortalBannerBadge.Font.Color := $0066D9FF;
      FPortalFooterBadge.Caption := FProd.OverallStatusText;
      FPortalFooterBadge.Font.Color := CLR_STATUS_WARN;
    end
    else
    begin
      FHeaderStatusBadge.Font.Color := $0090EE90;
      FPortalBannerBadge.Caption := 'Suite integra';
      FPortalBannerBadge.Font.Color := $0090EE90;
      FPortalFooterBadge.Caption := FProd.OverallStatusText;
      FPortalFooterBadge.Font.Color := CLR_STATUS_OK;
    end;

    FActiveProdTitleLabel.Caption := FProd.Title;
    FActiveProdIdLabel.Caption := 'ID: ' + CompactMiddlePath(FProd.ProductionId, 24);
    FActiveProdIdLabel.Hint := FProd.ProductionId;
    FActiveProdPathLabel.Caption := 'Pasta: ' + CompactMiddlePath(FProd.RootDir, 24);
    FActiveProdPathLabel.Hint := FProd.RootDir;
    FSummaryLabel.Caption := Format(
      'Projetos: %d  •  Artefatos: %d' + LineEnding +
      'Sync: %d  •  Alertas: %d',
      [VisibleProjCount, Length(FProd.Artifacts),
       Length(FProd.SyncJobs), Length(FProd.MissingLinks)]);
  end
  else
  begin
    FHeaderProdLabel.Caption := 'Nenhuma producao ativa';
    FHeaderStatusBadge.Caption := 'Crie ou abra uma producao para iniciar';
    FHeaderStatusBadge.Font.Color := CLR_ICE_SUB;
    FPortalBannerBadge.Caption := 'Sem producao';
    FPortalBannerBadge.Font.Color := CLR_ICE_SUB;
    FPortalFooterBadge.Caption := 'Nenhuma producao carregada';
    FPortalFooterBadge.Font.Color := CLR_TEXT_MUTED;

    FActiveProdTitleLabel.Caption := '(nenhuma)';
    FActiveProdIdLabel.Caption := 'ID: -';
    FActiveProdIdLabel.Hint := '';
    FActiveProdPathLabel.Caption := 'Pasta: -';
    FActiveProdPathLabel.Hint := '';
    FSummaryLabel.Caption := 'Abra ou crie uma producao.';
  end;

  if FMenuCloseProd <> nil then FMenuCloseProd.Enabled := FProd.Loaded;
  if FMenuAplicativos <> nil then
  begin
    FMenuAplicativos.Enabled := FProd.Loaded;
    for I := 0 to FMenuAplicativos.Count - 1 do
    begin
      if (I + 1 >= 1) and (I + 1 <= 6) then
      begin
        if FProd.Loaded then
        begin
          Eval := MmpEvaluateStageStatus(FProd, I + 1);
          FMenuAplicativos.Items[I].Enabled := Eval.CanOpen;
          if not Eval.CanOpen then
            TagSuffix := ' [Bloqueado]'
          else if Eval.NeedsAdjustment then
            TagSuffix := ' [Reajustar]'
          else
            TagSuffix := '';
        end
        else
        begin
          FMenuAplicativos.Items[I].Enabled := False;
          TagSuffix := '';
        end;
        FMenuAplicativos.Items[I].Caption := IntToStr(I + 1) + ' - ' +
          MmpAppNames[I + 1] + ' (' + MmpAppDescriptions[I + 1] + ')' + TagSuffix;
      end;
    end;
  end;
  if FMenuExibir <> nil then FMenuExibir.Enabled := FProd.Loaded;
  if FMenuFerramentas <> nil then FMenuFerramentas.Enabled := FProd.Loaded;
  if FMenuConfig <> nil then FMenuConfig.Enabled := IsAdminAllowed;
  if FMenuSwitchUser <> nil then FMenuSwitchUser.Enabled := (FSettings.AccessMode = amRestricted);
  if FHeaderGearPanel <> nil then FHeaderGearPanel.Enabled := IsAdminAllowed;
  if FExeVersionLabel <> nil then
  begin
    if FSettings.AccessMode = amRestricted then
      FExeVersionLabel.Caption := 'Suite v' + MMP_EXECUTABLE_VERSION + '  •  Usuario: ' +
        CurrentSessionUserName + ' (' + MmpUserProfileToStr(FCurrentUser.Profile) + ')'
    else
      FExeVersionLabel.Caption := 'Suite v' + MMP_EXECUTABLE_VERSION + '  •  Acesso Aberto';
  end;
  if FBtnCloseProdHead <> nil then FBtnCloseProdHead.Enabled := FProd.Loaded;
  if FBtnCloseProdSide <> nil then FBtnCloseProdSide.Enabled := FProd.Loaded;
  if FManagerPanel <> nil then FManagerPanel.Visible := not FProd.Loaded;
  if FPageControl <> nil then FPageControl.Visible := FProd.Loaded;

  RefreshManagerGrid;
  RefreshPortalCards;
  RefreshHistoryTab;
  RefreshProjectsGrid;
  RefreshSyncTab;
  RefreshArtifactsGrid;
  RefreshCentralLogTab;
end;

procedure TMmenuMainForm.RefreshPortalCards;
var
  I, PIdx: Integer;
  ProjId, RevStr, StatusStr, ExePath: string;
  IsBlue, ExeOk: Boolean;
  Eval: TMmpStageStatus;
begin
  for I := 1 to 6 do
  begin
    IsBlue := (I mod 2 = 0);
    ProjId := '-';
    RevStr := '-';
    StatusStr := 'sem producao';
    FillChar(Eval, SizeOf(Eval), 0);

    if FProd.Loaded then
    begin
      Eval := MmpEvaluateStageStatus(FProd, I);
      for PIdx := 0 to High(FProd.Projects) do
      begin
        if (FProd.Projects[PIdx].SoftwareIndex = I) and
           (FProd.Projects[PIdx].SceneId = '') then
        begin
          ProjId := FProd.Projects[PIdx].ProjectId;
          Break;
        end;
      end;
      if Eval.HasActivity then
      begin
        RevStr := 'Versao ' + IntToStr(RevisionVersionNumber(Eval.ActiveRevision)) +
          ' (' + Eval.ActiveRevision + ')';
        StatusStr := Eval.StatusText;
      end;
    end;

    ExeOk := True;
    ExePath := FAppPaths[I];
    if (ExePath <> '') and FileExists(ExePath) then
    begin
      FCardExeInfoLabels[I].Caption := 'Executavel configurado (' + ExtractFileName(ExePath) + ')';
      if IsBlue then FCardExeInfoLabels[I].Font.Color := CLR_ICE_SUB
      else FCardExeInfoLabels[I].Font.Color := CLR_STATUS_OK;
    end
    else
    begin
      ExePath := FindExecutable(MmpAppNames[I]);
      if ExePath <> '' then
      begin
        FCardExeInfoLabels[I].Caption := 'Pronto (' + ExtractFileName(ExePath) + ')';
        if IsBlue then FCardExeInfoLabels[I].Font.Color := CLR_ICE_SUB
        else FCardExeInfoLabels[I].Font.Color := CLR_BLUE_PRIMARY;
      end
      else
      begin
        FCardExeInfoLabels[I].Caption := 'Executavel nao encontrado (configure na engrenagem)';
        if IsBlue then FCardExeInfoLabels[I].Font.Color := $00B0C4FF
        else FCardExeInfoLabels[I].Font.Color := CLR_STATUS_ERR;
        ExeOk := False;
      end;
    end;

    if FProd.Loaded then
    begin
      FCardProjInfoLabels[I].Hint := 'Project ID: ' + ProjId;
      if not ExeOk then
      begin
        FCardActionOkFlag[I] := -1;
        FCardActionLabels[I] := 'Abrir ' + MmpAppNames[I];
        FCardActionSubLabels[I] := 'Exe ausente';
        if Eval.HasActivity then
          FCardProjInfoLabels[I].Caption := Format('%s  •  Estado: %s', [RevStr, StatusStr])
        else
          FCardProjInfoLabels[I].Caption := 'Nao iniciado';
      end
      else if not Eval.CanOpen then
      begin
        FCardActionOkFlag[I] := -2;
        FCardActionLabels[I] := 'Bloqueado';
        FCardActionSubLabels[I] := 'Falta ' + Eval.MissingPrereqs;
        FCardProjInfoLabels[I].Caption := 'Bloqueado: gere ' + Eval.MissingPrereqs + ' primeiro';
      end
      else if Eval.NeedsAdjustment then
      begin
        FCardActionOkFlag[I] := 2;
        FCardActionLabels[I] := 'Reajustar ' + MmpAppNames[I];
        FCardActionSubLabels[I] := 'Requer reajuste';
        FCardProjInfoLabels[I].Caption := 'REAJUSTE: ' + Eval.StaleReason;
      end
      else if Eval.HasActivity then
      begin
        FCardActionOkFlag[I] := 1;
        FCardActionLabels[I] := 'Abrir ' + MmpAppNames[I];
        FCardActionSubLabels[I] := RevStr + '  •  ' + StatusStr;
        FCardProjInfoLabels[I].Caption := Format('%s  •  Estado: %s', [RevStr, StatusStr]);
      end
      else
      begin
        FCardActionOkFlag[I] := 1;
        FCardActionLabels[I] := 'Iniciar ' + MmpAppNames[I];
        FCardActionSubLabels[I] := 'Pronto para iniciar';
        FCardProjInfoLabels[I].Caption := 'Etapas anteriores OK  •  Pronto para criar';
      end;
    end
    else
    begin
      FCardProjInfoLabels[I].Caption := 'Abra ou crie uma producao para editar';
      FCardProjInfoLabels[I].Hint := '';
      FCardActionLabels[I] := 'Abrir ' + MmpAppNames[I];
      if ExeOk then
      begin
        FCardActionOkFlag[I] := 1;
        FCardActionSubLabels[I] := 'Sem producao';
      end
      else
      begin
        FCardActionOkFlag[I] := -1;
        FCardActionSubLabels[I] := 'Exe ausente';
      end;
    end;

    if FCardActionBoxes[I] <> nil then
      FCardActionBoxes[I].Invalidate;
  end;
end;

procedure TMmenuMainForm.RefreshProjectsGrid;
var
  I, Row, SelGridRow: Integer;
  Eval: TMmpStageStatus;
begin
  SetLength(FVisibleProjectIndices, 0);
  if (not FProd.Loaded) or (Length(FProd.Projects) = 0) then
  begin
    FProjectsGrid.RowCount := 2;
    for I := 0 to FProjectsGrid.ColCount - 1 do
      FProjectsGrid.Cells[I, 1] := '';
    FSelectedProjectIndex := -1;
    RefreshSelectedProjectDetails;
    Exit;
  end;

  for I := 0 to High(FProd.Projects) do
    if MmpProjectHasActivity(FProd.Projects[I]) then
    begin
      Row := Length(FVisibleProjectIndices);
      SetLength(FVisibleProjectIndices, Row + 1);
      FVisibleProjectIndices[Row] := I;
    end;

  if Length(FVisibleProjectIndices) = 0 then
  begin
    FProjectsGrid.RowCount := 2;
    for I := 0 to FProjectsGrid.ColCount - 1 do
      FProjectsGrid.Cells[I, 1] := '';
    FSelectedProjectIndex := -1;
    RefreshSelectedProjectDetails;
    Exit;
  end;

  FProjectsGrid.RowCount := Length(FVisibleProjectIndices) + 1;
  SelGridRow := -1;
  for I := 0 to High(FVisibleProjectIndices) do
  begin
    Row := I + 1;
    with FProd.Projects[FVisibleProjectIndices[I]] do
    begin
      FProjectsGrid.Cells[0, Row] := AppName;
      FProjectsGrid.Cells[1, Row] := ProjectId;
      FProjectsGrid.Cells[2, Row] := SceneId;
      FProjectsGrid.Cells[3, Row] := 'Versao ' + IntToStr(RevisionVersionNumber(ActiveRevision)) +
        ' (' + ActiveRevision + ')';
      FProjectsGrid.Cells[4, Row] := Status;
      FProjectsGrid.Cells[5, Row] := UpdatedAt;
      if (SoftwareIndex >= 1) and (SoftwareIndex <= 6) then
      begin
        Eval := MmpEvaluateStageStatus(FProd, SoftwareIndex);
        if Eval.NeedsAdjustment then
          FProjectsGrid.Cells[6, Row] := IntegrityMessage + ' | Reajuste necessario (' + Eval.StaleReason + ')'
        else
          FProjectsGrid.Cells[6, Row] := IntegrityMessage;
      end
      else
        FProjectsGrid.Cells[6, Row] := IntegrityMessage;
      FProjectsGrid.Cells[7, Row] := ProjectFilePath;
    end;
    if FVisibleProjectIndices[I] = FSelectedProjectIndex then
      SelGridRow := Row;
  end;

  if SelGridRow < 0 then
  begin
    FSelectedProjectIndex := FVisibleProjectIndices[0];
    SelGridRow := 1;
  end;
  FProjectsGrid.Row := SelGridRow;
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
    FRevCombo.Items.Add('Versao ' + IntToStr(RevisionVersionNumber(Proj.Revisions[I].RevisionId)) +
      ' (' + Proj.Revisions[I].RevisionId + ')');

  if FRevCombo.Items.Count > 0 then
  begin
    RevIdx := -1;
    for I := 0 to High(Proj.Revisions) do
      if SameText(Proj.Revisions[I].RevisionId, Proj.ActiveRevision) then
      begin
        RevIdx := I;
        Break;
      end;
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
      FSyncSummaryLabel.Caption := 'Nenhum job de sincronizacao registrado (shared/transactions, shared/events).'
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

procedure TMmenuMainForm.RefreshHistoryTab;
var
  StageDoneCount, RevCount, I: Integer;
  Eval: TMmpStageStatus;
  LatestStr: string;
begin
  SetLength(FHistoryEntries, 0);
  SetLength(FHistoryFilteredIndices, 0);

  if not FProd.Loaded then
  begin
    FHistorySummaryLabel.Caption := 'Nenhuma producao aberta.';
    PopulateHistoryGrid;
    Exit;
  end;

  FHistoryEntries := MmpLoadProductionHistory(FProd);

  StageDoneCount := 0;
  for I := 1 to 6 do
  begin
    Eval := MmpEvaluateStageStatus(FProd, I);
    if Eval.HasActivity then
      Inc(StageDoneCount);
  end;

  RevCount := 0;
  for I := 0 to High(FHistoryEntries) do
    if SameText(FHistoryEntries[I].Kind, 'Revisao') then
      Inc(RevCount);

  if Length(FHistoryEntries) > 0 then
    LatestStr := FHistoryEntries[0].AppName + ' (' + FHistoryEntries[0].Timestamp + ')'
  else
    LatestStr := 'nenhuma ainda';

  FHistorySummaryLabel.Caption := Format(
    'Etapas concluidas: %d/6  |  Versoes publicadas: %d  |  Eventos registrados: %d  |  Ultima acao: %s',
    [StageDoneCount, RevCount, Length(FHistoryEntries), LatestStr]);

  PopulateHistoryGrid;
end;

procedure TMmenuMainForm.PopulateHistoryGrid;
var
  AppF, KindF, SearchF, VerStr: string;
  I, Row, N: Integer;
  MatchApp, MatchKind, MatchSearch: Boolean;
begin
  SetLength(FHistoryFilteredIndices, 0);
  AppF := '';
  if FHistoryAppFilter.ItemIndex > 0 then
    AppF := FHistoryAppFilter.Text;
  KindF := '';
  if FHistoryKindFilter.ItemIndex > 0 then
    KindF := FHistoryKindFilter.Text;
  SearchF := LowerCase(Trim(FHistorySearchEdit.Text));

  for I := 0 to High(FHistoryEntries) do
  begin
    MatchApp := (AppF = '') or SameText(FHistoryEntries[I].AppName, AppF);
    MatchKind := (KindF = '') or SameText(FHistoryEntries[I].Kind, KindF);
    MatchSearch := (SearchF = '') or
      (Pos(SearchF, LowerCase(FHistoryEntries[I].Summary)) > 0) or
      (Pos(SearchF, LowerCase(FHistoryEntries[I].Details)) > 0) or
      (Pos(SearchF, LowerCase(FHistoryEntries[I].RevisionId)) > 0) or
      (Pos(SearchF, LowerCase(FHistoryEntries[I].AppName)) > 0);
    if MatchApp and MatchKind and MatchSearch then
    begin
      N := Length(FHistoryFilteredIndices);
      SetLength(FHistoryFilteredIndices, N + 1);
      FHistoryFilteredIndices[N] := I;
    end;
  end;

  if Length(FHistoryFilteredIndices) = 0 then
  begin
    FHistoryGrid.RowCount := 2;
    for I := 0 to FHistoryGrid.ColCount - 1 do
      FHistoryGrid.Cells[I, 1] := '';
    FHistoryDetailMemo.Lines.Text := 'Nenhum registro encontrado para os filtros atuais.';
    Exit;
  end;

  FHistoryGrid.RowCount := Length(FHistoryFilteredIndices) + 1;
  for I := 0 to High(FHistoryFilteredIndices) do
  begin
    Row := I + 1;
    N := FHistoryFilteredIndices[I];
    FHistoryGrid.Cells[0, Row] := FHistoryEntries[N].Timestamp;
    FHistoryGrid.Cells[1, Row] := FHistoryEntries[N].AppName;
    FHistoryGrid.Cells[2, Row] := FHistoryEntries[N].Kind;
    if (FHistoryEntries[N].RevisionId <> '') and (FHistoryEntries[N].RevisionId <> '-') then
      VerStr := 'v' + IntToStr(RevisionVersionNumber(FHistoryEntries[N].RevisionId)) +
        ' (' + FHistoryEntries[N].RevisionId + ')'
    else
      VerStr := '-';
    FHistoryGrid.Cells[3, Row] := VerStr;
    FHistoryGrid.Cells[4, Row] := FHistoryEntries[N].State;
    FHistoryGrid.Cells[5, Row] := FHistoryEntries[N].Summary;
  end;

  FHistoryGrid.Row := 1;
  OnHistoryGridSelection(FHistoryGrid, 0, 1);
end;

procedure TMmenuMainForm.OnHistoryFilterChange(Sender: TObject);
begin
  PopulateHistoryGrid;
  if Sender <> nil then;
end;

procedure TMmenuMainForm.OnHistoryGridSelection(Sender: TObject; aCol, aRow: Integer);
var
  Idx, EntryIdx: Integer;
begin
  Idx := aRow - 1;
  if (Idx < 0) or (Idx > High(FHistoryFilteredIndices)) then
  begin
    FHistoryDetailMemo.Lines.Clear;
    Exit;
  end;
  EntryIdx := FHistoryFilteredIndices[Idx];
  if (EntryIdx >= 0) and (EntryIdx <= High(FHistoryEntries)) then
    FHistoryDetailMemo.Lines.Text := FHistoryEntries[EntryIdx].Details
  else
    FHistoryDetailMemo.Lines.Clear;
  if Sender <> nil then;
  if aCol >= 0 then;
end;

procedure TMmenuMainForm.OnExportHistoryClick(Sender: TObject);
var
  D: TSaveDialog;
  Lines: TStringList;
  I, EntryIdx: Integer;
  IsMd: Boolean;
begin
  if not FProd.Loaded then Exit;
  D := TSaveDialog.Create(Self);
  Lines := TStringList.Create;
  try
    D.Title := 'Exportar Historico & Controle';
    D.Filter := 'Markdown (*.md)|*.md|Texto (*.txt)|*.txt';
    D.DefaultExt := 'md';
    D.FileName := 'historico_' + FProd.ProductionId + '.md';
    if not D.Execute then Exit;

    IsMd := SameText(ExtractFileExt(D.FileName), '.md');
    if IsMd then
    begin
      Lines.Add('# Historico & Controle - ' + FProd.Title);
      Lines.Add('');
      Lines.Add('- Production ID: `' + FProd.ProductionId + '`');
      Lines.Add('- ' + FHistorySummaryLabel.Caption);
      Lines.Add('');
      Lines.Add('| Data/Hora | Etapa/App | Tipo | Versao | Estado | Resumo |');
      Lines.Add('|---|---|---|---|---|---|');
    end
    else
    begin
      Lines.Add('Historico & Controle - ' + FProd.Title + ' (' + FProd.ProductionId + ')');
      Lines.Add(FHistorySummaryLabel.Caption);
      Lines.Add(StringOfChar('-', 80));
    end;

    for I := 0 to High(FHistoryFilteredIndices) do
    begin
      EntryIdx := FHistoryFilteredIndices[I];
      if IsMd then
        Lines.Add('| ' + FHistoryEntries[EntryIdx].Timestamp + ' | ' +
          FHistoryEntries[EntryIdx].AppName + ' | ' +
          FHistoryEntries[EntryIdx].Kind + ' | ' +
          FHistoryEntries[EntryIdx].RevisionId + ' | ' +
          FHistoryEntries[EntryIdx].State + ' | ' +
          StringReplace(FHistoryEntries[EntryIdx].Summary, '|', '/', [rfReplaceAll]) + ' |')
      else
      begin
        Lines.Add('[' + FHistoryEntries[EntryIdx].Timestamp + '] [' +
          FHistoryEntries[EntryIdx].AppName + ' / ' + FHistoryEntries[EntryIdx].Kind + '] ' +
          FHistoryEntries[EntryIdx].RevisionId + ' (' + FHistoryEntries[EntryIdx].State + '): ' +
          FHistoryEntries[EntryIdx].Summary);
        if FHistoryEntries[EntryIdx].Details <> '' then
          Lines.Add(FHistoryEntries[EntryIdx].Details);
        Lines.Add('');
      end;
    end;

    Lines.SaveToFile(D.FileName);
    LogMsg('Historico exportado para: ' + D.FileName);
    SetStatus('Historico exportado com sucesso.', 100);
  finally
    Lines.Free;
    D.Free;
  end;
  if Sender <> nil then;
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
      OpenProductionPath(CreatedRoot, True, True);
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
    D.Title := 'Selecione maurinmovie.db ou production.json da producao';
    D.Filter := 'Banco SQLite / Producao (maurinmovie.db;production.json)|maurinmovie.db;production.json|Banco SQLite (*.db)|*.db|JSON (*.json)|*.json';
    D.Options := [ofFileMustExist, ofPathMustExist];
    if DirectoryExists(FDefaultProductionsDir) then
      D.InitialDir := FDefaultProductionsDir;
    if D.Execute then
    begin
      if (not SameText(ExtractFileName(D.FileName), MMP_DB_FILENAME)) and
         (not SameText(ExtractFileName(D.FileName), 'production.json')) then
      begin
        MessageDlg('Selecione maurinmovie.db ou production.json da producao.', mtWarning, [mbOK], 0);
        Exit;
      end;
      OpenProductionPath(D.FileName, True, True);
    end;
  finally
    D.Free;
  end;
end;

procedure TMmenuMainForm.OnCloseProductionClick(Sender: TObject);
var
  OldTitle: string;
begin
  if not FProd.Loaded then Exit;
  OldTitle := FProd.Title;
  Finalize(FProd);
  FillChar(FProd, SizeOf(FProd), 0);
  FSelectedProjectIndex := -1;
  SetLength(FVisibleProjectIndices, 0);
  FSettings.Load('', maMMenu);
  SaveConfig;
  RefreshAllViews;
  LogMsg('Producao fechada: ' + OldTitle + '. Nenhuma producao ativa.');
  SetStatus('Nenhuma producao aberta.', 0);
  if Sender <> nil then;
end;

procedure TMmenuMainForm.OnRefreshClick(Sender: TObject);
begin
  if FProd.RootDir <> '' then
    OpenProductionPath(FProd.RootDir, True, False)
  else
  begin
    RefreshRecentsList;
    RefreshAllViews;
  end;
end;

procedure TMmenuMainForm.OpenSettingsTab(const TabName: string);
var
  Dlg: TMmenuSettingsForm;
  I: Integer;
  NewUser: TMmpAccessUser;
  DummyErr: string;
begin
  if not CheckAdminAccess('alterar Configuracoes e Controle de Acesso') then Exit;
  FSettings.Load(FProd.RootDir, maMMenu);
  Dlg := TMmenuSettingsForm.CreateForSettings(Self, FSettings, FProd.Loaded, TabName);
  try
    if Dlg.ShowModal = mrOK then
    begin
      FDefaultProductionsDir := FSettings.ProductionsDir;
      for I := 1 to 6 do
        FAppPaths[I] := FSettings.GetAppExe(AppIndexToEnum(I));
      SaveConfig;

      if (FSettings.AccessMode = amRestricted) and (not FHasLoggedUser) then
      begin
        if PromptMMenuLogin(FSettings, NewUser) then
        begin
          FCurrentUser := NewUser;
          FHasLoggedUser := True;
        end
        else
        begin
          FSettings.AccessMode := amOpen;
          FSettings.SaveAccessControl(DummyErr);
        end;
      end;

      RefreshAllViews;
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

procedure TMmenuMainForm.OpenRecentByIndex(Idx: Integer);
begin
  if (Idx < 0) or (Idx > High(FRecents)) then Exit;
  if FileExists(FRecents[Idx].RootDir + PathDelim + 'production.json') then
    OpenProductionPath(FRecents[Idx].RootDir, True, True)
  else
  begin
    MessageDlg('A pasta desta producao nao foi encontrada em:' + LineEnding +
      FRecents[Idx].RootDir + LineEnding + LineEnding +
      'Use "Localizar..." para buscar pelo ID ' + FRecents[Idx].ProductionId + '.',
      mtWarning, [mbOK], 0);
  end;
end;

procedure TMmenuMainForm.LocateMovedRecentByIndex(Idx: Integer);
var
  DirDlg: TSelectDirectoryDialog;
  FoundRoot: string;
begin
  if (Idx < 0) or (Idx > High(FRecents)) then
  begin
    MessageDlg('Selecione uma producao na lista.', mtInformation, [mbOK], 0);
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
      OpenProductionPath(FoundRoot, True, True);
    end
    else
      MessageDlg('Nenhuma producao com ID ' + FRecents[Idx].ProductionId +
        ' foi encontrada nesta pasta.', mtWarning, [mbOK], 0);
  finally
    DirDlg.Free;
  end;
end;

procedure TMmenuMainForm.RemoveRecentByIndex(Idx: Integer);
var
  I: Integer;
begin
  if (Idx < 0) or (Idx > High(FRecents)) then Exit;
  for I := Idx to High(FRecents) - 1 do
    FRecents[I] := FRecents[I + 1];
  SetLength(FRecents, Length(FRecents) - 1);
  RefreshRecentsList;
  SaveConfig;
end;

procedure TMmenuMainForm.OnRecentDblClick(Sender: TObject);
begin
  OpenRecentByIndex(FRecentsList.ItemIndex);
end;

procedure TMmenuMainForm.OnLocateMovedRecentClick(Sender: TObject);
begin
  LocateMovedRecentByIndex(FRecentsList.ItemIndex);
end;

procedure TMmenuMainForm.OnRemoveRecentClick(Sender: TObject);
begin
  if not CheckAdminAccess('remover producao dos recentes') then Exit;
  RemoveRecentByIndex(FRecentsList.ItemIndex);
end;

procedure TMmenuMainForm.OnManagerGridDblClick(Sender: TObject);
begin
  if FManagerGrid <> nil then
    OpenRecentByIndex(FManagerGrid.Row - 1);
end;

procedure TMmenuMainForm.OnManagerOpenSelectedClick(Sender: TObject);
begin
  if FManagerGrid <> nil then
    OpenRecentByIndex(FManagerGrid.Row - 1);
end;

procedure TMmenuMainForm.OnManagerLocateClick(Sender: TObject);
begin
  if FManagerGrid <> nil then
    LocateMovedRecentByIndex(FManagerGrid.Row - 1);
end;

procedure TMmenuMainForm.OnManagerRemoveClick(Sender: TObject);
begin
  if not CheckAdminAccess('remover producao da lista') then Exit;
  if FManagerGrid <> nil then
    RemoveRecentByIndex(FManagerGrid.Row - 1);
end;

procedure TMmenuMainForm.OnPortalOpenAppClick(Sender: TObject);
var
  AppIdx, I: Integer;
  ProjId, RevId: string;
begin
  AppIdx := (Sender as TComponent).Tag;
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
  AppIdx, I, RealIdx: Integer;
begin
  AppIdx := (Sender as TComponent).Tag;
  FPageControl.ActivePage := FTabProjects;
  if not FProd.Loaded then Exit;
  for I := 0 to High(FVisibleProjectIndices) do
  begin
    RealIdx := FVisibleProjectIndices[I];
    if (FProd.Projects[RealIdx].SoftwareIndex = AppIdx) and
       (FProd.Projects[RealIdx].SceneId = '') then
    begin
      FSelectedProjectIndex := RealIdx;
      FProjectsGrid.Row := I + 1;
      RefreshSelectedProjectDetails;
      Exit;
    end;
  end;
  MessageDlg(MmpAppNames[AppIdx] + ' ainda nao possui revisoes criadas nesta producao.' +
    LineEnding + 'Abra o aplicativo pelo Portal para gerar a primeira versao.',
    mtInformation, [mbOK], 0);
end;

procedure TMmenuMainForm.OnProjectsGridSelection(Sender: TObject; aCol, aRow: Integer);
var
  VisIdx: Integer;
begin
  if not FProd.Loaded then Exit;
  VisIdx := aRow - 1;
  if (VisIdx >= 0) and (VisIdx <= High(FVisibleProjectIndices)) then
  begin
    FSelectedProjectIndex := FVisibleProjectIndices[VisIdx];
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
  if (FRevCombo.ItemIndex >= 0) and (FRevCombo.ItemIndex <= High(Proj.Revisions)) then
    RevId := Proj.Revisions[FRevCombo.ItemIndex].RevisionId
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

{ docs/specs/00-comum 7.3: "Retomar" executa <origem> --headless
  --resume-transaction <tx>. Hoje so o MBoard orquestra cascatas. }
procedure TMmenuMainForm.OnResumeSyncClick(Sender: TObject);
var
  RowIdx, Code: Integer;
  Job: TMmpSyncJob;
  TxPath, Origin, ErrMsg, TxStatus: string;
begin
  if (not FProd.Loaded) or (Length(FProd.SyncJobs) = 0) then Exit;
  RowIdx := FSyncJobsGrid.Row - 1;
  if (RowIdx < 0) or (RowIdx > High(FProd.SyncJobs)) then RowIdx := 0;
  Job := FProd.SyncJobs[RowIdx];
  if Job.TransactionId = '' then
  begin
    MessageDlg('O item selecionado nao pertence a uma transacao de cascata.', mtInformation, [mbOK], 0);
    Exit;
  end;
  TxPath := IncludeTrailingPathDelimiter(FProd.RootDir) + 'shared' + PathDelim + 'transactions' +
    PathDelim + Job.TransactionId + '.json';
  TxStatus := MmpJsonFileGet(TxPath, 'status');
  if SameText(TxStatus, 'complete') or SameText(TxStatus, 'cancelled') then
  begin
    MessageDlg('A transacao ' + Job.TransactionId + ' ja esta ' + TxStatus + '.', mtInformation, [mbOK], 0);
    Exit;
  end;
  Origin := Job.OriginApp;
  if not SameText(Origin, 'MBoard') then
  begin
    MessageDlg('A transacao ' + Job.TransactionId + ' foi iniciada pelo ' + Origin + ', que ainda nao ' +
      'retoma cascatas sem janela. Abra o ' + Job.TargetApp + ' para processar o pedido.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    Code := MmpRunHeadlessResume(maMBoard, FProd.RootDir, Job.TransactionId, ErrMsg);
  finally
    Screen.Cursor := crDefault;
  end;
  OpenProductionPath(FProd.RootDir, False);
  TxStatus := MmpJsonFileGet(TxPath, 'status');
  if Code = EXIT_OK then
  begin
    LogMsg('Transacao retomada e concluida: ' + Job.TransactionId);
    MessageDlg('Transacao ' + Job.TransactionId + ' retomada: ' + TxStatus + '.', mtInformation, [mbOK], 0);
  end
  else
  begin
    if Code = EXIT_LOCKED then
      ErrMsg := 'O MBoard esta aberto; feche-o e tente de novo.'
    else if ErrMsg = '' then
      ErrMsg := 'O MBoard terminou com codigo ' + IntToStr(Code) + '. Veja os erros da transacao.';
    LogMsg('Retomada da transacao ' + Job.TransactionId + ' falhou: ' + ErrMsg);
    MessageDlg('A transacao ' + Job.TransactionId + ' nao foi concluida (' + TxStatus + '):' +
      LineEnding + ErrMsg, mtWarning, [mbOK], 0);
  end;
end;

function BuildProdFingerprint(const P: TMmpProduction): string;
var
  I: Integer;
begin
  Result := P.OverallStatusText + '|' + IntToStr(Length(P.SyncJobs)) + '|' +
    IntToStr(Length(P.Artifacts)) + '|' + IntToStr(Length(P.MissingLinks));
  for I := 0 to High(P.Projects) do
    Result := Result + ';' + P.Projects[I].ProjectId + ':' + P.Projects[I].ActiveRevision +
      ':' + P.Projects[I].Status + ':' + P.Projects[I].UpdatedAt;
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
    if BuildProdFingerprint(LoadedProd) <> BuildProdFingerprint(FProd) then
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
  if not CheckAdminAccess('reconstruir catalog.json') then Exit;
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
  Lines: TStringList;
  I: Integer;
begin
  D := TSaveDialog.Create(Self);
  Lines := TStringList.Create;
  try
    D.Title := 'Exportar Log Centralizado do MMenu';
    D.Filter := 'Texto (*.txt)|*.txt|Log (*.log)|*.log';
    D.DefaultExt := 'log';
    D.FileName := 'mmenu_central_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.log';
    if D.Execute then
    begin
      Lines.Add(FLogSummaryLabel.Caption);
      Lines.Add(StringOfChar('-', 80));
      for I := 0 to High(FLogEntries) do
      begin
        Lines.Add(Format('[#%d] [%s] [%s] [%s] (%s): %s',
          [FLogEntries[I].Id, FLogEntries[I].Timestamp, FLogEntries[I].AppName,
           FLogEntries[I].Level, IfThen(FLogEntries[I].Resolved, 'CORRIGIDO', 'PENDENTE'),
           FLogEntries[I].Message]));
      end;
      Lines.SaveToFile(D.FileName);
      SetStatus('Log centralizado salvo em ' + D.FileName, 100);
    end;
  finally
    Lines.Free;
    D.Free;
  end;
end;

function TMmenuMainForm.IsAdminAllowed: Boolean;
begin
  if FSettings = nil then Exit(True);
  if FSettings.AccessMode = amOpen then Exit(True);
  Result := FHasLoggedUser and (FCurrentUser.Profile = upAdministrador);
end;

function TMmenuMainForm.CheckAdminAccess(const ActionDesc: string): Boolean;
begin
  Result := IsAdminAllowed;
  if not Result then
    MessageDlg('Acesso restrito ao perfil Administrador.' + LineEnding +
      'Operacao bloqueada para o perfil User: ' + ActionDesc + '.',
      mtWarning, [mbOK], 0);
end;

function TMmenuMainForm.CurrentSessionUserName: string;
begin
  if (FSettings <> nil) and (FSettings.AccessMode = amRestricted) and FHasLoggedUser then
    Result := FCurrentUser.Username
  else if (FSettings <> nil) and (Trim(FSettings.UserName) <> '') then
    Result := FSettings.UserName
  else
    Result := 'Aberto';
end;

procedure TMmenuMainForm.RefreshCentralLogTab;
var
  DbPath, AppF, LvlF, SearchF: string;
  ResF, I, Row, ErrOpen, ResCount: Integer;
begin
  if FCentralLogGrid = nil then Exit;
  if FProd.Loaded then
    DbPath := MmpProductionDbPath(FProd.RootDir)
  else
    DbPath := MmpGlobalCentralLogDbPath;

  AppF := '';
  if FLogAppFilter.ItemIndex > 0 then AppF := FLogAppFilter.Text;
  LvlF := '';
  if FLogLevelFilter.ItemIndex > 0 then LvlF := FLogLevelFilter.Text;
  case FLogResolvedFilter.ItemIndex of
    1: ResF := 0;
    2: ResF := 1;
  else
    ResF := -1;
  end;
  SearchF := Trim(FLogSearchEdit.Text);

  FLogEntries := MmpDbListCentralLogs(DbPath, AppF, LvlF, SearchF, ResF, 500);

  ErrOpen := 0;
  ResCount := 0;
  for I := 0 to High(FLogEntries) do
  begin
    if FLogEntries[I].Resolved then
      Inc(ResCount)
    else if SameText(FLogEntries[I].Level, 'error') or SameText(FLogEntries[I].Level, 'warn') then
      Inc(ErrOpen);
  end;

  FLogSummaryLabel.Caption := Format(
    'Registros: %d  |  Alertas/Erros em aberto: %d  |  Corrigidos: %d  |  Banco: %s',
    [Length(FLogEntries), ErrOpen, ResCount, ExtractFileName(DbPath)]);

  if Length(FLogEntries) = 0 then
  begin
    FCentralLogGrid.RowCount := 2;
    for I := 0 to FCentralLogGrid.ColCount - 1 do
      FCentralLogGrid.Cells[I, 1] := '';
    Exit;
  end;

  FCentralLogGrid.RowCount := Length(FLogEntries) + 1;
  for I := 0 to High(FLogEntries) do
  begin
    Row := I + 1;
    FCentralLogGrid.Cells[0, Row] := IntToStr(FLogEntries[I].Id);
    FCentralLogGrid.Cells[1, Row] := FLogEntries[I].Timestamp;
    FCentralLogGrid.Cells[2, Row] := FLogEntries[I].AppName;
    FCentralLogGrid.Cells[3, Row] := FLogEntries[I].Level;
    FCentralLogGrid.Cells[4, Row] := FLogEntries[I].RevisionId;
    if FLogEntries[I].Resolved then
      FCentralLogGrid.Cells[5, Row] := 'Corrigido'
    else if SameText(FLogEntries[I].Level, 'error') then
      FCentralLogGrid.Cells[5, Row] := 'Pendente (ERRO)'
    else if SameText(FLogEntries[I].Level, 'warn') then
      FCentralLogGrid.Cells[5, Row] := 'Atencao'
    else
      FCentralLogGrid.Cells[5, Row] := 'Registrado';
    FCentralLogGrid.Cells[6, Row] := FLogEntries[I].Message;
  end;

  FCentralLogGrid.Row := 1;
  OnCentralLogGridSelection(FCentralLogGrid, 0, 1);
end;

procedure TMmenuMainForm.OnCentralLogFilterChange(Sender: TObject);
begin
  RefreshCentralLogTab;
  if Sender <> nil then;
end;

procedure TMmenuMainForm.OnCentralLogGridSelection(Sender: TObject; aCol, aRow: Integer);
var
  Idx: Integer;
  E: TMmpCentralLogEntry;
begin
  Idx := aRow - 1;
  if (Idx < 0) or (Idx > High(FLogEntries)) then
  begin
    FLogMemo.Lines.Clear;
    Exit;
  end;
  E := FLogEntries[Idx];
  FLogMemo.Lines.Clear;
  FLogMemo.Lines.Add('ID: #' + IntToStr(E.Id) + ' | Data/Hora: ' + E.Timestamp +
    ' | App: ' + E.AppName + ' | Nivel: ' + E.Level);
  if (E.UserName <> '') or (E.RevisionId <> '') then
    FLogMemo.Lines.Add('Usuario: ' + E.UserName + ' | Revisao: ' + E.RevisionId);
  FLogMemo.Lines.Add('Mensagem: ' + E.Message);
  if E.Details <> '' then
    FLogMemo.Lines.Add('Detalhes: ' + E.Details);
  if E.Resolved then
    FLogMemo.Lines.Add('CORRIGIDO por ' + E.ResolvedBy + ' em ' + E.ResolvedAt +
      IfThen(E.ResolutionNote <> '', ': ' + E.ResolutionNote, ''))
  else if SameText(E.Level, 'error') or SameText(E.Level, 'warn') then
    FLogMemo.Lines.Add('Situacao: Pendente / Nao marcado como corrigido.')
  else
    FLogMemo.Lines.Add('Situacao: Registro informativo.');
  if Sender <> nil then;
  if aCol >= 0 then;
end;

procedure TMmenuMainForm.OnResolveCentralLogClick(Sender: TObject);
var
  Idx: Integer;
  Note, DbPath: string;
begin
  Idx := FCentralLogGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FLogEntries)) then
  begin
    MessageDlg('Selecione uma entrada do log primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;
  Note := FLogEntries[Idx].ResolutionNote;
  if not InputQuery('Marcar Operacao / Erro como Corrigido',
    'Descreva a acao ou correcao aplicada:', Note) then
    Exit;
  if FProd.Loaded then
    DbPath := MmpProductionDbPath(FProd.RootDir)
  else
    DbPath := MmpGlobalCentralLogDbPath;

  if MmpDbResolveCentralLog(DbPath, FLogEntries[Idx].Id, CurrentSessionUserName, Note, True) then
  begin
    RefreshCentralLogTab;
    RefreshHistoryTab;
    SetStatus('Log #' + IntToStr(FLogEntries[Idx].Id) + ' marcado como corrigido.', 100);
  end
  else
    MessageDlg('Falha ao atualizar status do log no banco SQLite.', mtError, [mbOK], 0);
  if Sender <> nil then;
end;

procedure TMmenuMainForm.OnOpenLogAppClick(Sender: TObject);
var
  Idx, AppIdx: Integer;
begin
  Idx := FCentralLogGrid.Row - 1;
  if (Idx < 0) or (Idx > High(FLogEntries)) then
  begin
    MessageDlg('Selecione uma entrada do log primeiro.', mtInformation, [mbOK], 0);
    Exit;
  end;
  AppIdx := AppNameToIndex(FLogEntries[Idx].AppName);
  if (AppIdx >= 1) and (AppIdx <= 6) then
    LaunchApplication(AppIdx, '', FLogEntries[Idx].RevisionId)
  else
    MessageDlg('Entrada pertence ao proprio MMenu.', mtInformation, [mbOK], 0);
  if Sender <> nil then;
end;

procedure TMmenuMainForm.OnSwitchUserClick(Sender: TObject);
var
  NewUser: TMmpAccessUser;
begin
  FSettings.LoadAccessControl;
  if FSettings.AccessMode <> amRestricted then
  begin
    MessageDlg('O MMenu esta em modo Aberto. Ative "Restrito por usuarios" em Configuracoes -> Controle de Acesso.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if PromptMMenuLogin(FSettings, NewUser) then
  begin
    FCurrentUser := NewUser;
    FHasLoggedUser := True;
    RefreshAllViews;
    LogMsg('Usuario alterado para: ' + NewUser.Username + ' (' + MmpUserProfileToStr(NewUser.Profile) + ')');
  end;
  if Sender <> nil then;
end;

end.
