unit ummenusettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, fpjson, jsonparser,
  aillmmodelcatalog, aiimagemodelcatalog, aisoundmodelcatalog, aivideomodelcatalog,
  aisoundruntime,
  mmpcommon, mmpsettings, ummpaibridge;

type
  TMmenuSettingsForm = class(TForm)
  private
    FSettings: TMMSettings;
    FHasProduction: Boolean;
    FNavTree: TTreeView;
    FPageControl: TPageControl;

    // Geral
    FUserNameEdit: TEdit;
    FUserRoleEdit: TEdit;
    FUserEmailEdit: TEdit;
    FEnvMemo: TMemo;

    // Producao
    FProdNameBaseEdit: TEdit;
    FProdLangEdit: TEdit;
    FProdResCombo: TComboBox;
    FProdFpsEdit: TEdit;
    FProdWidthEdit: TEdit;
    FProdHeightEdit: TEdit;
    FProdAspectEdit: TEdit;
    FProdStyleEdit: TEdit;
    FProdFormatCombo: TComboBox;

    // Provedor IA (editando o tipo selecionado)
    FKindTabs: array[0..6] of string; // text, image, voice, sfx, video, vision, asr
    FCurrentKind: string;
    FProvKindLabel: TLabel;
    FProvCatalogProvCombo: TComboBox;
    FProvCatalogModelCombo: TComboBox;
    FProvCatalogHintLabel: TLabel;
    FProvAdapterCombo: TComboBox;
    FProvBaseUrlEdit: TEdit;
    FProvModelEdit: TEdit;
    FProvSecretRefEdit: TEdit;
    FProvSecretValEdit: TEdit;
    FProvShowSecretBtn: TButton;
    FProvTempEdit: TEdit;
    FProvMaxTokensEdit: TEdit;
    FProvResCombo: TComboBox;
    FProvWidthEdit: TEdit;
    FProvHeightEdit: TEdit;
    FProvMaxSegEdit: TEdit;
    FProvEnabledChk: TCheckBox;
    FProvTestLabel: TLabel;
    FBtnScanAudioServers: TButton;

    // Programas
    FAppCombo: TComboBox;
    FAppTextProvEdit: TEdit;
    FAppImgProvEdit: TEdit;
    FAppVoiceProvEdit: TEdit;
    FAppSfxProvEdit: TEdit;
    FAppVideoProvEdit: TEdit;
    FAppSceneCountEdit: TEdit;
    FAppApprovedOnlyChk: TCheckBox;

    // Politicas
    FPolReqBoardChk: TCheckBox;
    FPolReqVoiceChk: TCheckBox;
    FPolRatingScaleEdit: TEdit;
    FPolBudgetEdit: TEdit;
    FPolAutosaveEdit: TEdit;
    FPolMonitorEdit: TEdit;

    // Ferramentas e Executaveis
    FDefaultRootEdit: TEdit;
    FAppPathEdits: array[1..6] of TEdit;
    FAppStatusLabels: array[1..6] of TLabel;
    FFfmpegEdit: TEdit;
    FFfprobeEdit: TEdit;
    FMpvEdit: TEdit;

    // Rede & Interface
    FProxyEdit: TEdit;
    FProxyUserEdit: TEdit;
    FCABundleEdit: TEdit;
    FOfflineChk: TCheckBox;
    FUiLangEdit: TEdit;
    FFontScaleEdit: TEdit;
    FThemeCombo: TComboBox;
    FConfirmDestructiveChk: TCheckBox;
    FLogLevelCombo: TComboBox;
    FLogRetentionEdit: TEdit;

    // Prompts (settings/prompts/<app>/<nome>.txt)
    FPromptAppCombo: TComboBox;
    FPromptNameCombo: TComboBox;
    FPromptMemo: TMemo;
    FPromptStatusLabel: TLabel;

    // Midia e Render (settings/media-profiles.json)
    FMediaImgFmtEdit: TEdit;
    FMediaResCombo: TComboBox;
    FMediaImgWEdit: TEdit;
    FMediaImgHEdit: TEdit;
    FMediaAudioRateEdit: TEdit;
    FMediaAudioBitsEdit: TEdit;
    FMediaVidCodecEdit: TEdit;
    FMediaVidCrfEdit: TEdit;

    // Predefinicoes (settings/presets.json)
    FPresetsStylesMemo: TMemo;
    FPresetsTransMemo: TMemo;

    // Pastas adicionais de Ferramentas
    FSoundLibDirEdit: TEdit;
    FMusicLibDirEdit: TEdit;

    // Controle de Acesso (Perfis e Usuarios)
    FAccessModeCombo: TComboBox;
    FAccessInfoLabel: TLabel;
    FAccessUsersGrid: TStringGrid;
    FAccessUserEdit: TEdit;
    FAccessProfileCombo: TComboBox;
    FAccessPassEdit: TEdit;
    FAccessActiveChk: TCheckBox;

    procedure BuildUI(const InitialTab: string);
    procedure LoadFieldsFromSettings;
    procedure RefreshAccessUsersGrid;
    procedure LoadAccessControlFields;
    procedure PopulateCatalogProvidersForKind(const Kind: string);
    procedure PopulateCatalogModelsForSelectedProvider;
    procedure LoadProviderKindFields(const Kind: string);
    procedure SaveProviderKindFields;
    procedure LoadSelectedAppFields;
    procedure SaveSelectedAppFields;
    procedure LoadPromptsForSelectedApp;
    procedure LoadSelectedPromptText;
    procedure LoadMediaAndPresets;
    procedure SaveMediaAndPresets;
    procedure UpdateToolBadges;

    procedure OnTreeSelectionChanged(Sender: TObject; Node: TTreeNode);
    procedure OnProdResChanged(Sender: TObject);
    procedure OnProvResChanged(Sender: TObject);
    procedure OnMediaResChanged(Sender: TObject);
    procedure OnPromptAppChanged(Sender: TObject);
    procedure OnPromptNameChanged(Sender: TObject);
    procedure OnSavePromptClick(Sender: TObject);
    procedure OnRestorePromptClick(Sender: TObject);
    procedure OnCatalogProvChanged(Sender: TObject);
    procedure OnCatalogModelChanged(Sender: TObject);
    procedure OnApplyPresetClick(Sender: TObject);
    procedure OnScanAudioServersClick(Sender: TObject);
    procedure OnVerifyEnvClick(Sender: TObject);
    procedure OnToggleSecretClick(Sender: TObject);
    procedure OnTestProviderClick(Sender: TObject);
    procedure OnAppComboChanged(Sender: TObject);
    procedure OnBrowseDirClick(Sender: TObject);
    procedure OnBrowseAppClick(Sender: TObject);
    procedure OnBrowseToolClick(Sender: TObject);
    procedure OnDetectAllClick(Sender: TObject);
    procedure OnAccessModeChanged(Sender: TObject);
    procedure OnAccessGridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure OnAccessSaveUserClick(Sender: TObject);
    procedure OnAccessRemoveUserClick(Sender: TObject);
    procedure OnAccessClearUserClick(Sender: TObject);
    procedure OnAccessResetAdminClick(Sender: TObject);
    procedure OnSaveClick(Sender: TObject);
  public
    constructor CreateForSettings(TheOwner: TComponent;
      Settings: TMMSettings; HasProduction: Boolean; const InitialTab: string = '');
  end;

function PromptMMenuLogin(Settings: TMMSettings;
  out LoggedUser: TMmpAccessUser): Boolean;

implementation

constructor TMmenuSettingsForm.CreateForSettings(TheOwner: TComponent;
  Settings: TMMSettings; HasProduction: Boolean; const InitialTab: string);
begin
  inherited CreateNew(TheOwner, 1);
  FSettings := Settings;
  FHasProduction := HasProduction;

  FKindTabs[0] := 'text';
  FKindTabs[1] := 'image';
  FKindTabs[2] := 'voice';
  FKindTabs[3] := 'sfx';
  FKindTabs[4] := 'video';
  FKindTabs[5] := 'vision';
  FKindTabs[6] := 'asr';
  FCurrentKind := 'text';

  Caption := 'Configuracoes Centralizadas da Suite - MMenu (' + MAURINMOVIE_VERSION + ')';
  Width := 940;
  Height := 650;
  Position := poScreenCenter;
  Constraints.MinWidth := 820;
  Constraints.MinHeight := 560;

  BuildUI(InitialTab);
  LoadFieldsFromSettings;
end;

procedure TMmenuSettingsForm.BuildUI(const InitialTab: string);
var
  Head, Footer, LeftPanel: TPanel;
  TabGeral, TabProd, TabIA, TabApps, TabPrompts, TabMidia, TabPresets, TabPol, TabTools, TabNet, TabAcesso: TTabSheet;
  L: TLabel;
  BtnSave, BtnCancel, BtnEnv, BtnTest, BtnDetect, BtnPreset, BtnSavePrompt, BtnRestorePrompt, B: TButton;
  BtnAccSave, BtnAccRem, BtnAccClear, BtnAccReset: TButton;
  I, Y, SelIdx: Integer;
  Node, RootIA, TargetNode: TTreeNode;
  TargetTabLower: string;
begin
  Head := TPanel.Create(Self); Head.Parent := Self; Head.Align := alTop; Head.Height := 56;
  Head.BevelOuter := bvNone; Head.Color := $006E3B16; Head.ParentBackground := False;

  L := TLabel.Create(Self); L.Parent := Head;
  L.Caption := 'Configuracoes Centralizadas (MMenu — Unica fonte de gravacao)';
  L.Font.Size := 13; L.Font.Style := [fsBold]; L.Font.Color := clWhite;
  L.SetBounds(16, 16, 650, 24);

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom; Footer.Height := 52;
  Footer.BevelOuter := bvLowered; Footer.Color := $00FCF7F1; Footer.ParentBackground := False;

  BtnSave := TButton.Create(Self); BtnSave.Parent := Footer; BtnSave.Caption := 'Salvar';
  BtnSave.Anchors := [akTop, akRight]; BtnSave.SetBounds(726, 10, 96, 32);
  BtnSave.OnClick := @OnSaveClick;

  BtnCancel := TButton.Create(Self); BtnCancel.Parent := Footer; BtnCancel.Caption := 'Cancelar';
  BtnCancel.ModalResult := mrCancel; BtnCancel.Cancel := True;
  BtnCancel.Anchors := [akTop, akRight]; BtnCancel.SetBounds(830, 10, 96, 32);

  LeftPanel := TPanel.Create(Self); LeftPanel.Parent := Self; LeftPanel.Align := alLeft; LeftPanel.Width := 215;
  LeftPanel.BevelOuter := bvNone;

  FNavTree := TTreeView.Create(Self); FNavTree.Parent := LeftPanel; FNavTree.Align := alClient;
  FNavTree.ReadOnly := True;
  FNavTree.HideSelection := False;
  FNavTree.OnChange := @OnTreeSelectionChanged;

  FPageControl := TPageControl.Create(Self); FPageControl.Parent := Self; FPageControl.Align := alClient;
  FPageControl.ShowTabs := False;

  TabGeral := TTabSheet.Create(FPageControl); TabGeral.PageControl := FPageControl; TabGeral.Caption := 'Geral';
  TabProd := TTabSheet.Create(FPageControl); TabProd.PageControl := FPageControl; TabProd.Caption := 'Producao';
  TabIA := TTabSheet.Create(FPageControl); TabIA.PageControl := FPageControl; TabIA.Caption := 'Provedores IA';
  TabApps := TTabSheet.Create(FPageControl); TabApps.PageControl := FPageControl; TabApps.Caption := 'Programas';
  TabPrompts := TTabSheet.Create(FPageControl); TabPrompts.PageControl := FPageControl; TabPrompts.Caption := 'Prompts';
  TabMidia := TTabSheet.Create(FPageControl); TabMidia.PageControl := FPageControl; TabMidia.Caption := 'Midia e Render';
  TabPresets := TTabSheet.Create(FPageControl); TabPresets.PageControl := FPageControl; TabPresets.Caption := 'Predefinicoes';
  TabPol := TTabSheet.Create(FPageControl); TabPol.PageControl := FPageControl; TabPol.Caption := 'Politicas';
  TabTools := TTabSheet.Create(FPageControl); TabTools.PageControl := FPageControl; TabTools.Caption := 'Ferramentas';
  TabNet := TTabSheet.Create(FPageControl); TabNet.PageControl := FPageControl; TabNet.Caption := 'Rede e Interface';
  TabAcesso := TTabSheet.Create(FPageControl); TabAcesso.PageControl := FPageControl; TabAcesso.Caption := 'Controle de Acesso';

  // Tree nodes with Data = tab marker (PageIndex ou 10..16 para tipos IA, 20 para Controle de Acesso)
  TargetNode := FNavTree.Items.AddObject(nil, 'Geral e Ambiente', Pointer(0));
  FNavTree.Items.AddObject(nil, 'Producao', Pointer(1));
  RootIA := FNavTree.Items.AddObject(nil, 'IA: Texto', Pointer(10));
  FNavTree.Items.AddObject(RootIA, 'IA: Imagem / Foto', Pointer(11));
  FNavTree.Items.AddObject(RootIA, 'IA: Som - Voz', Pointer(12));
  FNavTree.Items.AddObject(RootIA, 'IA: Som - Efeitos', Pointer(13));
  FNavTree.Items.AddObject(RootIA, 'IA: Video', Pointer(14));
  FNavTree.Items.AddObject(RootIA, 'IA: Visao (opcional)', Pointer(15));
  FNavTree.Items.AddObject(RootIA, 'IA: Transcricao (opcional)', Pointer(16));
  RootIA.Expand(True);
  FNavTree.Items.AddObject(nil, 'Programas (MScript..MCut)', Pointer(3));
  FNavTree.Items.AddObject(nil, 'Prompts', Pointer(4));
  FNavTree.Items.AddObject(nil, 'Midia e Render', Pointer(5));
  FNavTree.Items.AddObject(nil, 'Predefinicoes', Pointer(6));
  FNavTree.Items.AddObject(nil, 'Politicas', Pointer(7));
  FNavTree.Items.AddObject(nil, 'Ferramentas e Executaveis', Pointer(8));
  FNavTree.Items.AddObject(nil, 'Rede, Interface e Log', Pointer(9));
  FNavTree.Items.AddObject(nil, 'Controle de Acesso (Perfis)', Pointer(20));

  // Tab 0: Geral
  L := TLabel.Create(Self); L.Parent := TabGeral; L.Caption := 'Usuario autor/revisor (obrigatorio para aprovacoes):'; L.SetBounds(16, 16, 360, 18);
  FUserNameEdit := TEdit.Create(Self); FUserNameEdit.Parent := TabGeral; FUserNameEdit.SetBounds(16, 36, 300, 26);
  L := TLabel.Create(Self); L.Parent := TabGeral; L.Caption := 'Papel:'; L.SetBounds(330, 16, 120, 18);
  FUserRoleEdit := TEdit.Create(Self); FUserRoleEdit.Parent := TabGeral; FUserRoleEdit.SetBounds(330, 36, 160, 26);
  L := TLabel.Create(Self); L.Parent := TabGeral; L.Caption := 'E-mail (opcional, nunca exportado):'; L.SetBounds(16, 72, 260, 18);
  FUserEmailEdit := TEdit.Create(Self); FUserEmailEdit.Parent := TabGeral; FUserEmailEdit.SetBounds(16, 92, 300, 26);

  BtnEnv := TButton.Create(Self); BtnEnv.Parent := TabGeral; BtnEnv.Caption := 'Verificar ambiente agora';
  BtnEnv.SetBounds(16, 134, 210, 32); BtnEnv.OnClick := @OnVerifyEnvClick;

  FEnvMemo := TMemo.Create(Self); FEnvMemo.Parent := TabGeral; FEnvMemo.ReadOnly := True;
  FEnvMemo.ScrollBars := ssBoth; FEnvMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  FEnvMemo.SetBounds(16, 178, 670, 330);

  // Tab 1: Producao
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Nome-base (rotulos <NomeBase>_<Tipo>_RNNN):'; L.SetBounds(16, 16, 360, 18);
  FProdNameBaseEdit := TEdit.Create(Self); FProdNameBaseEdit.Parent := TabProd; FProdNameBaseEdit.SetBounds(16, 36, 320, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Idioma do roteiro/falas:'; L.SetBounds(354, 16, 180, 18);
  FProdLangEdit := TEdit.Create(Self); FProdLangEdit.Parent := TabProd; FProdLangEdit.SetBounds(354, 36, 120, 26);

  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Resolucao padronizada (VGA .. 8K):'; L.SetBounds(16, 76, 220, 18);
  FProdResCombo := TComboBox.Create(Self); FProdResCombo.Parent := TabProd; FProdResCombo.Style := csDropDownList;
  MmpPopulateResolutionCombo(FProdResCombo.Items);
  FProdResCombo.SetBounds(16, 96, 215, 26); FProdResCombo.OnChange := @OnProdResChanged;

  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Largura:'; L.SetBounds(244, 76, 75, 18);
  FProdWidthEdit := TEdit.Create(Self); FProdWidthEdit.Parent := TabProd; FProdWidthEdit.ReadOnly := True; FProdWidthEdit.Color := $00F4F6F9;
  FProdWidthEdit.SetBounds(244, 96, 76, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Altura:'; L.SetBounds(330, 76, 75, 18);
  FProdHeightEdit := TEdit.Create(Self); FProdHeightEdit.Parent := TabProd; FProdHeightEdit.ReadOnly := True; FProdHeightEdit.Color := $00F4F6F9;
  FProdHeightEdit.SetBounds(330, 96, 76, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Proporcao:'; L.SetBounds(416, 76, 75, 18);
  FProdAspectEdit := TEdit.Create(Self); FProdAspectEdit.Parent := TabProd; FProdAspectEdit.ReadOnly := True; FProdAspectEdit.Color := $00F4F6F9;
  FProdAspectEdit.SetBounds(416, 96, 68, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'FPS:'; L.SetBounds(496, 76, 60, 18);
  FProdFpsEdit := TEdit.Create(Self); FProdFpsEdit.Parent := TabProd; FProdFpsEdit.SetBounds(496, 96, 72, 26);

  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Estilo visual padrao:'; L.SetBounds(16, 136, 200, 18);
  FProdStyleEdit := TEdit.Create(Self); FProdStyleEdit.Parent := TabProd; FProdStyleEdit.SetBounds(16, 156, 300, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Formato:'; L.SetBounds(332, 136, 100, 18);
  FProdFormatCombo := TComboBox.Create(Self); FProdFormatCombo.Parent := TabProd; FProdFormatCombo.Style := csDropDownList;
  FProdFormatCombo.Items.Add('short'); FProdFormatCombo.Items.Add('medium'); FProdFormatCombo.Items.Add('feature');
  FProdFormatCombo.SetBounds(332, 156, 140, 26);

  TabProd.Enabled := FHasProduction;

  // Tab 2: Provedor IA
  FProvKindLabel := TLabel.Create(Self); FProvKindLabel.Parent := TabIA;
  FProvKindLabel.Font.Size := 12; FProvKindLabel.Font.Style := [fsBold];
  FProvKindLabel.SetBounds(16, 12, 540, 24);

  FProvEnabledChk := TCheckBox.Create(Self); FProvEnabledChk.Parent := TabIA;
  FProvEnabledChk.Caption := 'Provedor habilitado'; FProvEnabledChk.SetBounds(16, 42, 220, 22);

  // Selecao rapida via Catalogo CHATGPT (Provedor + Modelo)
  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Catalogo Provedor:'; L.SetBounds(16, 74, 126, 18);
  FProvCatalogProvCombo := TComboBox.Create(Self); FProvCatalogProvCombo.Parent := TabIA;
  FProvCatalogProvCombo.Style := csDropDownList;
  FProvCatalogProvCombo.SetBounds(150, 70, 190, 26);
  FProvCatalogProvCombo.OnChange := @OnCatalogProvChanged;

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Modelo:'; L.SetBounds(348, 74, 52, 18);
  FProvCatalogModelCombo := TComboBox.Create(Self); FProvCatalogModelCombo.Parent := TabIA;
  FProvCatalogModelCombo.Style := csDropDownList;
  FProvCatalogModelCombo.SetBounds(402, 70, 180, 26);
  FProvCatalogModelCombo.OnChange := @OnCatalogModelChanged;

  BtnPreset := TButton.Create(Self); BtnPreset.Parent := TabIA; BtnPreset.Caption := 'Aplicar';
  BtnPreset.SetBounds(588, 69, 76, 28); BtnPreset.OnClick := @OnApplyPresetClick;

  FProvCatalogHintLabel := TLabel.Create(Self); FProvCatalogHintLabel.Parent := TabIA;
  FProvCatalogHintLabel.Font.Color := $009E541B;
  FProvCatalogHintLabel.SetBounds(150, 100, 514, 18);
  FProvCatalogHintLabel.Caption := 'Selecione um provedor/modelo do catalogo CHATGPT e clique em Aplicar.';

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Adaptador:'; L.SetBounds(16, 128, 120, 18);
  FProvAdapterCombo := TComboBox.Create(Self); FProvAdapterCombo.Parent := TabIA; FProvAdapterCombo.Style := csDropDownList;
  FProvAdapterCombo.Items.Add('mock');
  FProvAdapterCombo.Items.Add('chatgpt-lib');
  FProvAdapterCombo.Items.Add('openai-compatible');
  FProvAdapterCombo.Items.Add('parakeet');
  FProvAdapterCombo.Items.Add('kokoro-fastapi');
  FProvAdapterCombo.Items.Add('piper-http');
  FProvAdapterCombo.Items.Add('openedai-speech');
  FProvAdapterCombo.Items.Add('coqui-xtts');
  FProvAdapterCombo.Items.Add('alltalk-tts');
  FProvAdapterCombo.Items.Add('openvoice-v2');
  FProvAdapterCombo.Items.Add('f5-tts-server');
  FProvAdapterCombo.Items.Add('chatterbox');
  FProvAdapterCombo.Items.Add('audiocraft-bark');
  FProvAdapterCombo.Items.Add('local-cpu-runtime');
  FProvAdapterCombo.Items.Add('system-os');
  FProvAdapterCombo.Items.Add('comfyui');
  FProvAdapterCombo.Items.Add('automatic1111');
  FProvAdapterCombo.Items.Add('stability');
  FProvAdapterCombo.Items.Add('bfl-flux');
  FProvAdapterCombo.Items.Add('huggingface');
  FProvAdapterCombo.Items.Add('elevenlabs');
  FProvAdapterCombo.Items.Add('google-veo');
  FProvAdapterCombo.Items.Add('runway');
  FProvAdapterCombo.Items.Add('kling');
  FProvAdapterCombo.Items.Add('luma');
  FProvAdapterCombo.Items.Add('openai-sora');
  FProvAdapterCombo.Items.Add('ffmpeg-cpu');
  FProvAdapterCombo.Items.Add('local-cli');
  FProvAdapterCombo.Items.Add('http-generic');
  FProvAdapterCombo.SetBounds(150, 124, 240, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'URL Base:'; L.SetBounds(16, 162, 120, 18);
  FProvBaseUrlEdit := TEdit.Create(Self); FProvBaseUrlEdit.Parent := TabIA; FProvBaseUrlEdit.SetBounds(150, 158, 514, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Modelo ativo:'; L.SetBounds(16, 196, 120, 18);
  FProvModelEdit := TEdit.Create(Self); FProvModelEdit.Parent := TabIA; FProvModelEdit.SetBounds(150, 192, 340, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'secret_ref:'; L.SetBounds(16, 230, 120, 18);
  FProvSecretRefEdit := TEdit.Create(Self); FProvSecretRefEdit.Parent := TabIA; FProvSecretRefEdit.SetBounds(150, 226, 220, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Chave (cofre local):'; L.SetBounds(16, 264, 130, 18);
  FProvSecretValEdit := TEdit.Create(Self); FProvSecretValEdit.Parent := TabIA; FProvSecretValEdit.PasswordChar := '*';
  FProvSecretValEdit.SetBounds(150, 260, 340, 26);

  FProvShowSecretBtn := TButton.Create(Self); FProvShowSecretBtn.Parent := TabIA; FProvShowSecretBtn.Caption := 'Mostrar';
  FProvShowSecretBtn.SetBounds(498, 259, 90, 28); FProvShowSecretBtn.OnClick := @OnToggleSecretClick;

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Temperatura:'; L.SetBounds(16, 300, 95, 18);
  FProvTempEdit := TEdit.Create(Self); FProvTempEdit.Parent := TabIA; FProvTempEdit.SetBounds(150, 296, 80, 26);
  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Max Tokens:'; L.SetBounds(250, 300, 90, 18);
  FProvMaxTokensEdit := TEdit.Create(Self); FProvMaxTokensEdit.Parent := TabIA; FProvMaxTokensEdit.SetBounds(342, 296, 95, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Resolucao padrao:'; L.SetBounds(16, 336, 125, 18);
  FProvResCombo := TComboBox.Create(Self); FProvResCombo.Parent := TabIA; FProvResCombo.Style := csDropDownList;
  MmpPopulateResolutionCombo(FProvResCombo.Items);
  FProvResCombo.SetBounds(150, 332, 220, 26); FProvResCombo.OnChange := @OnProvResChanged;

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Largura / Altura:'; L.SetBounds(16, 372, 120, 18);
  FProvWidthEdit := TEdit.Create(Self); FProvWidthEdit.Parent := TabIA; FProvWidthEdit.SetBounds(150, 368, 80, 26);
  FProvHeightEdit := TEdit.Create(Self); FProvHeightEdit.Parent := TabIA; FProvHeightEdit.SetBounds(238, 368, 80, 26);
  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Max Seg(s):'; L.SetBounds(336, 372, 85, 18);
  FProvMaxSegEdit := TEdit.Create(Self); FProvMaxSegEdit.Parent := TabIA; FProvMaxSegEdit.SetBounds(424, 368, 70, 26);

  BtnTest := TButton.Create(Self); BtnTest.Parent := TabIA; BtnTest.Caption := 'Testar Provedor';
  BtnTest.SetBounds(16, 408, 160, 32); BtnTest.OnClick := @OnTestProviderClick;

  FBtnScanAudioServers := TButton.Create(Self); FBtnScanAudioServers.Parent := TabIA;
  FBtnScanAudioServers.Caption := 'Detectar Servidores Locais...';
  FBtnScanAudioServers.SetBounds(184, 408, 210, 32);
  FBtnScanAudioServers.OnClick := @OnScanAudioServersClick;

  FProvTestLabel := TLabel.Create(Self); FProvTestLabel.Parent := TabIA;
  FProvTestLabel.WordWrap := True; FProvTestLabel.SetBounds(16, 448, 650, 56);
  FProvTestLabel.Caption := 'As chaves ficam em secrets.ini e nunca sao gravadas na pasta da producao.';

  TabIA.Enabled := FHasProduction;

  // Tab 3: Programas
  L := TLabel.Create(Self); L.Parent := TabApps; L.Caption := 'Programa:'; L.SetBounds(16, 18, 90, 18);
  FAppCombo := TComboBox.Create(Self); FAppCombo.Parent := TabApps; FAppCombo.Style := csDropDownList;
  for I := 1 to 6 do FAppCombo.Items.Add(MMAppNames[AppIndexToEnum(I)]);
  FAppCombo.ItemIndex := 0; FAppCombo.SetBounds(112, 14, 200, 26); FAppCombo.OnChange := @OnAppComboChanged;

  L := TLabel.Create(Self); L.Parent := TabApps; L.Caption := 'Provedor Texto:'; L.SetBounds(16, 62, 130, 18);
  FAppTextProvEdit := TEdit.Create(Self); FAppTextProvEdit.Parent := TabApps; FAppTextProvEdit.SetBounds(160, 58, 220, 26);
  L := TLabel.Create(Self); L.Parent := TabApps; L.Caption := 'Provedor Imagem:'; L.SetBounds(16, 98, 130, 18);
  FAppImgProvEdit := TEdit.Create(Self); FAppImgProvEdit.Parent := TabApps; FAppImgProvEdit.SetBounds(160, 94, 220, 26);
  L := TLabel.Create(Self); L.Parent := TabApps; L.Caption := 'Provedor Voz:'; L.SetBounds(16, 134, 130, 18);
  FAppVoiceProvEdit := TEdit.Create(Self); FAppVoiceProvEdit.Parent := TabApps; FAppVoiceProvEdit.SetBounds(160, 130, 220, 26);
  L := TLabel.Create(Self); L.Parent := TabApps; L.Caption := 'Provedor Efeitos:'; L.SetBounds(16, 170, 130, 18);
  FAppSfxProvEdit := TEdit.Create(Self); FAppSfxProvEdit.Parent := TabApps; FAppSfxProvEdit.SetBounds(160, 166, 220, 26);
  L := TLabel.Create(Self); L.Parent := TabApps; L.Caption := 'Provedor Video:'; L.SetBounds(16, 206, 130, 18);
  FAppVideoProvEdit := TEdit.Create(Self); FAppVideoProvEdit.Parent := TabApps; FAppVideoProvEdit.SetBounds(160, 202, 220, 26);

  L := TLabel.Create(Self); L.Parent := TabApps; L.Caption := 'Cenas padrao (MScript):'; L.SetBounds(16, 250, 160, 18);
  FAppSceneCountEdit := TEdit.Create(Self); FAppSceneCountEdit.Parent := TabApps; FAppSceneCountEdit.SetBounds(184, 246, 80, 26);
  FAppApprovedOnlyChk := TCheckBox.Create(Self); FAppApprovedOnlyChk.Parent := TabApps;
  FAppApprovedOnlyChk.Caption := 'Usar somente referencias aprovadas'; FAppApprovedOnlyChk.SetBounds(16, 286, 300, 22);
  TabApps.Enabled := FHasProduction;

  // Tab 4: Prompts (docs/specs/08 §8 - settings/prompts/<app>/<nome>.txt)
  L := TLabel.Create(Self); L.Parent := TabPrompts; L.Caption := 'Programa:'; L.SetBounds(16, 18, 80, 18);
  FPromptAppCombo := TComboBox.Create(Self); FPromptAppCombo.Parent := TabPrompts;
  FPromptAppCombo.Style := csDropDownList;
  for I := 1 to 6 do FPromptAppCombo.Items.Add(MMAppNames[AppIndexToEnum(I)]);
  FPromptAppCombo.ItemIndex := 0;
  FPromptAppCombo.SetBounds(100, 14, 150, 26);
  FPromptAppCombo.OnChange := @OnPromptAppChanged;

  L := TLabel.Create(Self); L.Parent := TabPrompts; L.Caption := 'Modelo de prompt:'; L.SetBounds(268, 18, 120, 18);
  FPromptNameCombo := TComboBox.Create(Self); FPromptNameCombo.Parent := TabPrompts;
  FPromptNameCombo.Style := csDropDownList;
  FPromptNameCombo.SetBounds(392, 14, 240, 26);
  FPromptNameCombo.OnChange := @OnPromptNameChanged;

  FPromptStatusLabel := TLabel.Create(Self); FPromptStatusLabel.Parent := TabPrompts;
  FPromptStatusLabel.Font.Color := $009E541B;
  FPromptStatusLabel.SetBounds(16, 48, 640, 18);
  FPromptStatusLabel.Caption := 'Substituicoes gravadas em settings/prompts/<app>/<nome>.txt';

  FPromptMemo := TMemo.Create(Self); FPromptMemo.Parent := TabPrompts;
  FPromptMemo.ScrollBars := ssBoth;
  FPromptMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  FPromptMemo.SetBounds(16, 74, 660, 380);

  BtnSavePrompt := TButton.Create(Self); BtnSavePrompt.Parent := TabPrompts;
  BtnSavePrompt.Caption := 'Salvar substituicao';
  BtnSavePrompt.Anchors := [akLeft, akBottom];
  BtnSavePrompt.SetBounds(16, 466, 170, 32);
  BtnSavePrompt.OnClick := @OnSavePromptClick;

  BtnRestorePrompt := TButton.Create(Self); BtnRestorePrompt.Parent := TabPrompts;
  BtnRestorePrompt.Caption := 'Restaurar original';
  BtnRestorePrompt.Anchors := [akLeft, akBottom];
  BtnRestorePrompt.SetBounds(196, 466, 170, 32);
  BtnRestorePrompt.OnClick := @OnRestorePromptClick;
  TabPrompts.Enabled := FHasProduction;

  // Tab 5: Midia e Render (docs/specs/08 §5 - settings/media-profiles.json)
  L := TLabel.Create(Self); L.Parent := TabMidia; L.Caption := 'Perfis de Midia (settings/media-profiles.json)';
  L.Font.Size := 11; L.Font.Style := [fsBold]; L.SetBounds(16, 14, 480, 22);

  L := TLabel.Create(Self); L.Parent := TabMidia; L.Caption := 'Imagem/Render - Formato / Resolucao padronizada / Largura / Altura:'; L.SetBounds(16, 54, 480, 18);
  FMediaImgFmtEdit := TEdit.Create(Self); FMediaImgFmtEdit.Parent := TabMidia; FMediaImgFmtEdit.SetBounds(16, 74, 70, 26);
  FMediaResCombo := TComboBox.Create(Self); FMediaResCombo.Parent := TabMidia; FMediaResCombo.Style := csDropDownList;
  MmpPopulateResolutionCombo(FMediaResCombo.Items);
  FMediaResCombo.SetBounds(94, 74, 210, 26); FMediaResCombo.OnChange := @OnMediaResChanged;
  FMediaImgWEdit := TEdit.Create(Self); FMediaImgWEdit.Parent := TabMidia; FMediaImgWEdit.SetBounds(312, 74, 76, 26);
  FMediaImgHEdit := TEdit.Create(Self); FMediaImgHEdit.Parent := TabMidia; FMediaImgHEdit.SetBounds(396, 74, 76, 26);

  L := TLabel.Create(Self); L.Parent := TabMidia; L.Caption := 'Audio de trabalho - Taxa (Hz) / Bits:'; L.SetBounds(16, 118, 300, 18);
  FMediaAudioRateEdit := TEdit.Create(Self); FMediaAudioRateEdit.Parent := TabMidia; FMediaAudioRateEdit.SetBounds(16, 138, 100, 26);
  FMediaAudioBitsEdit := TEdit.Create(Self); FMediaAudioBitsEdit.Parent := TabMidia; FMediaAudioBitsEdit.SetBounds(126, 138, 80, 26);

  L := TLabel.Create(Self); L.Parent := TabMidia; L.Caption := 'Video de trabalho - Codec / CRF:'; L.SetBounds(16, 182, 300, 18);
  FMediaVidCodecEdit := TEdit.Create(Self); FMediaVidCodecEdit.Parent := TabMidia; FMediaVidCodecEdit.SetBounds(16, 202, 100, 26);
  FMediaVidCrfEdit := TEdit.Create(Self); FMediaVidCrfEdit.Parent := TabMidia; FMediaVidCrfEdit.SetBounds(126, 202, 80, 26);
  TabMidia.Enabled := FHasProduction;

  // Tab 6: Predefinicoes (docs/specs/08 §6 - settings/presets.json)
  L := TLabel.Create(Self); L.Parent := TabPresets; L.Caption := 'Estilos visuais (um por linha):'; L.SetBounds(16, 16, 280, 18);
  FPresetsStylesMemo := TMemo.Create(Self); FPresetsStylesMemo.Parent := TabPresets;
  FPresetsStylesMemo.ScrollBars := ssBoth; FPresetsStylesMemo.SetBounds(16, 36, 310, 260);

  L := TLabel.Create(Self); L.Parent := TabPresets; L.Caption := 'Transicoes de montagem (uma por linha):'; L.SetBounds(346, 16, 300, 18);
  FPresetsTransMemo := TMemo.Create(Self); FPresetsTransMemo.Parent := TabPresets;
  FPresetsTransMemo.ScrollBars := ssBoth; FPresetsTransMemo.SetBounds(346, 36, 310, 260);
  TabPresets.Enabled := FHasProduction;

  // Tab 7: Politicas
  FPolReqBoardChk := TCheckBox.Create(Self); FPolReqBoardChk.Parent := TabPol;
  FPolReqBoardChk.Caption := 'Exigir referencias aprovadas no MBoard'; FPolReqBoardChk.SetBounds(16, 20, 340, 22);
  FPolReqVoiceChk := TCheckBox.Create(Self); FPolReqVoiceChk.Parent := TabPol;
  FPolReqVoiceChk.Caption := 'Exigir perfil vocal aprovado no MScene'; FPolReqVoiceChk.SetBounds(16, 52, 340, 22);
  L := TLabel.Create(Self); L.Parent := TabPol; L.Caption := 'Escala de notas do publico (MCut):'; L.SetBounds(16, 92, 240, 18);
  FPolRatingScaleEdit := TEdit.Create(Self); FPolRatingScaleEdit.Parent := TabPol; FPolRatingScaleEdit.SetBounds(268, 88, 70, 26);
  L := TLabel.Create(Self); L.Parent := TabPol; L.Caption := 'Orcamento limite IA (0=livre):'; L.SetBounds(16, 128, 240, 18);
  FPolBudgetEdit := TEdit.Create(Self); FPolBudgetEdit.Parent := TabPol; FPolBudgetEdit.SetBounds(268, 124, 90, 26);
  L := TLabel.Create(Self); L.Parent := TabPol; L.Caption := 'Autosave (s):'; L.SetBounds(16, 164, 140, 18);
  FPolAutosaveEdit := TEdit.Create(Self); FPolAutosaveEdit.Parent := TabPol; FPolAutosaveEdit.SetBounds(268, 160, 70, 26);
  L := TLabel.Create(Self); L.Parent := TabPol; L.Caption := 'Intervalo monitor MMenu (s):'; L.SetBounds(16, 200, 240, 18);
  FPolMonitorEdit := TEdit.Create(Self); FPolMonitorEdit.Parent := TabPol; FPolMonitorEdit.SetBounds(268, 196, 70, 26);
  TabPol.Enabled := FHasProduction;

  // Tab 5: Ferramentas e Executaveis
  L := TLabel.Create(Self); L.Parent := TabTools; L.Caption := 'Pasta padrao de producoes:'; L.SetBounds(16, 14, 220, 18);
  FDefaultRootEdit := TEdit.Create(Self); FDefaultRootEdit.Parent := TabTools; FDefaultRootEdit.SetBounds(16, 34, 540, 26);
  B := TButton.Create(Self); B.Parent := TabTools; B.Caption := 'Pasta...'; B.SetBounds(564, 33, 96, 28);
  B.OnClick := @OnBrowseDirClick;

  Y := 74;
  for I := 1 to 6 do
  begin
    L := TLabel.Create(Self); L.Parent := TabTools; L.Caption := MMAppNames[AppIndexToEnum(I)];
    L.SetBounds(16, Y + 4, 80, 18);
    FAppPathEdits[I] := TEdit.Create(Self); FAppPathEdits[I].Parent := TabTools; FAppPathEdits[I].SetBounds(100, Y, 370, 26);
    B := TButton.Create(Self); B.Parent := TabTools; B.Caption := '...'; B.Tag := I; B.SetBounds(476, Y - 1, 44, 28);
    B.OnClick := @OnBrowseAppClick;
    FAppStatusLabels[I] := TLabel.Create(Self); FAppStatusLabels[I].Parent := TabTools; FAppStatusLabels[I].SetBounds(528, Y + 5, 150, 18);
    Inc(Y, 36);
  end;

  L := TLabel.Create(Self); L.Parent := TabTools; L.Caption := 'ffmpeg:'; L.SetBounds(16, Y + 12, 80, 18);
  FFfmpegEdit := TEdit.Create(Self); FFfmpegEdit.Parent := TabTools; FFfmpegEdit.SetBounds(100, Y + 8, 370, 26);
  B := TButton.Create(Self); B.Parent := TabTools; B.Caption := '...'; B.Tag := 1; B.SetBounds(476, Y + 7, 44, 28);
  B.OnClick := @OnBrowseToolClick;
  Inc(Y, 36);

  L := TLabel.Create(Self); L.Parent := TabTools; L.Caption := 'ffprobe:'; L.SetBounds(16, Y + 12, 80, 18);
  FFfprobeEdit := TEdit.Create(Self); FFfprobeEdit.Parent := TabTools; FFfprobeEdit.SetBounds(100, Y + 8, 370, 26);
  B := TButton.Create(Self); B.Parent := TabTools; B.Caption := '...'; B.Tag := 2; B.SetBounds(476, Y + 7, 44, 28);
  B.OnClick := @OnBrowseToolClick;
  Inc(Y, 36);

  L := TLabel.Create(Self); L.Parent := TabTools; L.Caption := 'mpv:'; L.SetBounds(16, Y + 12, 80, 18);
  FMpvEdit := TEdit.Create(Self); FMpvEdit.Parent := TabTools; FMpvEdit.SetBounds(100, Y + 8, 370, 26);
  B := TButton.Create(Self); B.Parent := TabTools; B.Caption := '...'; B.Tag := 3; B.SetBounds(476, Y + 7, 44, 28);
  B.OnClick := @OnBrowseToolClick;
  Inc(Y, 36);

  L := TLabel.Create(Self); L.Parent := TabTools; L.Caption := 'Banco de efeitos (SoundLibraryDir):'; L.SetBounds(16, Y + 12, 230, 18);
  FSoundLibDirEdit := TEdit.Create(Self); FSoundLibDirEdit.Parent := TabTools; FSoundLibDirEdit.SetBounds(252, Y + 8, 308, 26);
  Inc(Y, 36);

  L := TLabel.Create(Self); L.Parent := TabTools; L.Caption := 'Banco de musicas (MusicLibraryDir):'; L.SetBounds(16, Y + 12, 230, 18);
  FMusicLibDirEdit := TEdit.Create(Self); FMusicLibDirEdit.Parent := TabTools; FMusicLibDirEdit.SetBounds(252, Y + 8, 308, 26);

  BtnDetect := TButton.Create(Self); BtnDetect.Parent := TabTools; BtnDetect.Caption := 'Autodetectar tudo';
  BtnDetect.SetBounds(16, Y + 48, 170, 32); BtnDetect.OnClick := @OnDetectAllClick;

  // Tab 9: Rede, Interface e Log
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Proxy HTTP/HTTPS (opcional):'; L.SetBounds(16, 18, 220, 18);
  FProxyEdit := TEdit.Create(Self); FProxyEdit.Parent := TabNet; FProxyEdit.SetBounds(16, 38, 300, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Usuario proxy:'; L.SetBounds(330, 18, 150, 18);
  FProxyUserEdit := TEdit.Create(Self); FProxyUserEdit.Parent := TabNet; FProxyUserEdit.SetBounds(330, 38, 180, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'CA Bundle TLS (opcional):'; L.SetBounds(16, 74, 220, 18);
  FCABundleEdit := TEdit.Create(Self); FCABundleEdit.Parent := TabNet; FCABundleEdit.SetBounds(16, 94, 380, 26);
  FOfflineChk := TCheckBox.Create(Self); FOfflineChk.Parent := TabNet;
  FOfflineChk.Caption := 'Modo Offline (forca provedor simulado e bloqueia rede)'; FOfflineChk.SetBounds(16, 130, 420, 22);

  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Idioma da interface:'; L.SetBounds(16, 168, 160, 18);
  FUiLangEdit := TEdit.Create(Self); FUiLangEdit.Parent := TabNet; FUiLangEdit.SetBounds(184, 164, 120, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Escala da fonte (%):'; L.SetBounds(16, 204, 160, 18);
  FFontScaleEdit := TEdit.Create(Self); FFontScaleEdit.Parent := TabNet; FFontScaleEdit.SetBounds(184, 200, 80, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Tema:'; L.SetBounds(16, 240, 120, 18);
  FThemeCombo := TComboBox.Create(Self); FThemeCombo.Parent := TabNet; FThemeCombo.Style := csDropDownList;
  FThemeCombo.Items.Add('claro'); FThemeCombo.Items.Add('escuro'); FThemeCombo.SetBounds(184, 236, 120, 26);
  FConfirmDestructiveChk := TCheckBox.Create(Self); FConfirmDestructiveChk.Parent := TabNet;
  FConfirmDestructiveChk.Caption := 'Confirmar acoes destrutivas'; FConfirmDestructiveChk.SetBounds(330, 238, 240, 22);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Nivel de log:'; L.SetBounds(16, 276, 120, 18);
  FLogLevelCombo := TComboBox.Create(Self); FLogLevelCombo.Parent := TabNet; FLogLevelCombo.Style := csDropDownList;
  FLogLevelCombo.Items.Add('debug'); FLogLevelCombo.Items.Add('info'); FLogLevelCombo.Items.Add('warn'); FLogLevelCombo.Items.Add('error');
  FLogLevelCombo.SetBounds(184, 272, 120, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Retencao de log (dias):'; L.SetBounds(330, 276, 160, 18);
  FLogRetentionEdit := TEdit.Create(Self); FLogRetentionEdit.Parent := TabNet; FLogRetentionEdit.SetBounds(498, 272, 70, 26);

  // Tab 10: Controle de Acesso (Perfis)
  L := TLabel.Create(Self); L.Parent := TabAcesso; L.Caption := 'Modo de Controle de Acesso do MMenu:';
  L.Font.Style := [fsBold]; L.SetBounds(16, 16, 300, 18);
  FAccessModeCombo := TComboBox.Create(Self); FAccessModeCombo.Parent := TabAcesso;
  FAccessModeCombo.Style := csDropDownList;
  FAccessModeCombo.Items.Add('Aberto (sem autenticacao - padrao)');
  FAccessModeCombo.Items.Add('Restrito por usuarios (Administrador / User)');
  FAccessModeCombo.SetBounds(16, 38, 360, 26);
  FAccessModeCombo.OnChange := @OnAccessModeChanged;

  FAccessInfoLabel := TLabel.Create(Self); FAccessInfoLabel.Parent := TabAcesso;
  FAccessInfoLabel.WordWrap := True;
  FAccessInfoLabel.Font.Color := $007D3F12;
  FAccessInfoLabel.SetBounds(16, 72, 660, 36);
  FAccessInfoLabel.Caption :=
    'Perfis no modo Restrito: Administrador (padrao: usuario ADMIN / senha 123456) ' +
    'e User (sem usuario padrao - crie usuarios abaixo conforme necessario).';

  L := TLabel.Create(Self); L.Parent := TabAcesso; L.Caption := 'Usuarios cadastrados:';
  L.Font.Style := [fsBold]; L.SetBounds(16, 114, 240, 18);

  FAccessUsersGrid := TStringGrid.Create(Self); FAccessUsersGrid.Parent := TabAcesso;
  FAccessUsersGrid.SetBounds(16, 136, 660, 170);
  FAccessUsersGrid.Anchors := [akLeft, akTop, akRight];
  FAccessUsersGrid.ColCount := 4;
  FAccessUsersGrid.RowCount := 2;
  FAccessUsersGrid.FixedRows := 1;
  FAccessUsersGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goColSizing];
  FAccessUsersGrid.Cells[0, 0] := 'Usuario';
  FAccessUsersGrid.Cells[1, 0] := 'Perfil';
  FAccessUsersGrid.Cells[2, 0] := 'Ativo';
  FAccessUsersGrid.Cells[3, 0] := 'Atualizado em';
  FAccessUsersGrid.ColWidths[0] := 180;
  FAccessUsersGrid.ColWidths[1] := 140;
  FAccessUsersGrid.ColWidths[2] := 80;
  FAccessUsersGrid.ColWidths[3] := 210;
  FAccessUsersGrid.OnSelection := @OnAccessGridSelection;

  L := TLabel.Create(Self); L.Parent := TabAcesso; L.Caption := 'Usuario:'; L.SetBounds(16, 320, 140, 18);
  FAccessUserEdit := TEdit.Create(Self); FAccessUserEdit.Parent := TabAcesso;
  FAccessUserEdit.SetBounds(16, 340, 190, 26);

  L := TLabel.Create(Self); L.Parent := TabAcesso; L.Caption := 'Perfil:'; L.SetBounds(220, 320, 140, 18);
  FAccessProfileCombo := TComboBox.Create(Self); FAccessProfileCombo.Parent := TabAcesso;
  FAccessProfileCombo.Style := csDropDownList;
  FAccessProfileCombo.Items.Add('Administrador');
  FAccessProfileCombo.Items.Add('User');
  FAccessProfileCombo.ItemIndex := 1;
  FAccessProfileCombo.SetBounds(220, 340, 150, 26);

  L := TLabel.Create(Self); L.Parent := TabAcesso;
  L.Caption := 'Senha (em edicao deixe vazio p/ manter):'; L.SetBounds(384, 320, 260, 18);
  FAccessPassEdit := TEdit.Create(Self); FAccessPassEdit.Parent := TabAcesso;
  FAccessPassEdit.PasswordChar := '*';
  FAccessPassEdit.SetBounds(384, 340, 180, 26);

  FAccessActiveChk := TCheckBox.Create(Self); FAccessActiveChk.Parent := TabAcesso;
  FAccessActiveChk.Caption := 'Ativo';
  FAccessActiveChk.Checked := True;
  FAccessActiveChk.SetBounds(576, 342, 80, 22);

  BtnAccSave := TButton.Create(Self); BtnAccSave.Parent := TabAcesso;
  BtnAccSave.Caption := 'Adicionar / Atualizar';
  BtnAccSave.SetBounds(16, 380, 165, 30);
  BtnAccSave.OnClick := @OnAccessSaveUserClick;

  BtnAccRem := TButton.Create(Self); BtnAccRem.Parent := TabAcesso;
  BtnAccRem.Caption := 'Remover Selecionado';
  BtnAccRem.SetBounds(188, 380, 155, 30);
  BtnAccRem.OnClick := @OnAccessRemoveUserClick;

  BtnAccClear := TButton.Create(Self); BtnAccClear.Parent := TabAcesso;
  BtnAccClear.Caption := 'Limpar';
  BtnAccClear.SetBounds(350, 380, 90, 30);
  BtnAccClear.OnClick := @OnAccessClearUserClick;

  BtnAccReset := TButton.Create(Self); BtnAccReset.Parent := TabAcesso;
  BtnAccReset.Caption := 'Restaurar ADMIN (123456)';
  BtnAccReset.SetBounds(448, 380, 195, 30);
  BtnAccReset.OnClick := @OnAccessResetAdminClick;

  // Select initial tab
  TargetTabLower := LowerCase(Trim(InitialTab));
  SelIdx := 0;
  if TargetTabLower = 'producao' then SelIdx := 1
  else if TargetTabLower = 'ia-texto' then SelIdx := 2
  else if TargetTabLower = 'ia-imagem' then SelIdx := 3
  else if TargetTabLower = 'ia-voz' then SelIdx := 4
  else if TargetTabLower = 'ia-efeitos' then SelIdx := 5
  else if TargetTabLower = 'ia-video' then SelIdx := 6
  else if TargetTabLower = 'ia-visao' then SelIdx := 7
  else if TargetTabLower = 'ia-transcricao' then SelIdx := 8
  else if (TargetTabLower = 'programas') or (TargetTabLower = 'mscript') or
          (TargetTabLower = 'mvisual') or (TargetTabLower = 'mboard') or
          (TargetTabLower = 'msound') or (TargetTabLower = 'mscene') or
          (TargetTabLower = 'mcut') then SelIdx := 9
  else if TargetTabLower = 'prompts' then SelIdx := 10
  else if TargetTabLower = 'midia' then SelIdx := 11
  else if TargetTabLower = 'predefinicoes' then SelIdx := 12
  else if TargetTabLower = 'politicas' then SelIdx := 13
  else if TargetTabLower = 'ferramentas' then SelIdx := 14
  else if (TargetTabLower = 'rede') or (TargetTabLower = 'interface') then SelIdx := 15
  else if TargetTabLower = 'acesso' then SelIdx := 16;

  if (SelIdx >= 0) and (SelIdx < FNavTree.Items.Count) then
    FNavTree.Selected := FNavTree.Items[SelIdx]
  else
    FNavTree.Selected := TargetNode;

  for I := 1 to 6 do
    if SameText(TargetTabLower, MMAppNames[AppIndexToEnum(I)]) then
      FAppCombo.ItemIndex := I - 1;
end;

procedure TMmenuSettingsForm.LoadFieldsFromSettings;
var
  I: Integer;
begin
  FUserNameEdit.Text := FSettings.UserName;
  FUserRoleEdit.Text := FSettings.UserRole;
  FUserEmailEdit.Text := FSettings.UserEmail;

  FProdNameBaseEdit.Text := FSettings.ProdNameBase;
  FProdLangEdit.Text := FSettings.ProdLanguage;
  FProdFpsEdit.Text := IntToStr(FSettings.ProdFps);
  I := MmpFindResolutionPresetIndex(FSettings.ProdWidth, FSettings.ProdHeight);
  if I < 0 then I := 2; // Padrao Full HD (1920x1080)
  FProdResCombo.ItemIndex := I;
  OnProdResChanged(nil);
  FProdStyleEdit.Text := FSettings.ProdVisualStyle;
  FProdFormatCombo.ItemIndex := FProdFormatCombo.Items.IndexOf(FSettings.ProdFormat);
  if FProdFormatCombo.ItemIndex < 0 then FProdFormatCombo.ItemIndex := 0;

  FPolReqBoardChk.Checked := FSettings.RequireApprovedRefsForBoard;
  FPolReqVoiceChk.Checked := FSettings.RequireVoiceApprovalForScene;
  FPolRatingScaleEdit.Text := IntToStr(FSettings.PolicyRatingScale);
  FPolBudgetEdit.Text := FloatToStr(FSettings.BudgetTotal);
  FPolAutosaveEdit.Text := IntToStr(FSettings.AutosaveSec);
  FPolMonitorEdit.Text := IntToStr(FSettings.MonitorIntervalSec);

  FDefaultRootEdit.Text := FSettings.ProductionsDir;
  for I := 1 to 6 do
    FAppPathEdits[I].Text := FSettings.GetAppExe(AppIndexToEnum(I));
  FFfmpegEdit.Text := FSettings.ToolFfmpeg;
  FFfprobeEdit.Text := FSettings.ToolFfprobe;
  FMpvEdit.Text := FSettings.ToolMpv;
  FSoundLibDirEdit.Text := FSettings.SoundLibraryDir;
  FMusicLibDirEdit.Text := FSettings.MusicLibraryDir;

  FProxyEdit.Text := FSettings.ProxyUrl;
  FProxyUserEdit.Text := FSettings.ProxyUser;
  FCABundleEdit.Text := FSettings.CABundle;
  FOfflineChk.Checked := FSettings.OfflineMode;
  FUiLangEdit.Text := FSettings.UiLanguage;
  FFontScaleEdit.Text := IntToStr(FSettings.FontScale);
  FThemeCombo.ItemIndex := FThemeCombo.Items.IndexOf(FSettings.UiTheme);
  if FThemeCombo.ItemIndex < 0 then FThemeCombo.ItemIndex := 0;
  FConfirmDestructiveChk.Checked := FSettings.ConfirmDestructive;
  FLogLevelCombo.ItemIndex := FLogLevelCombo.Items.IndexOf(FSettings.LogLevel);
  if FLogLevelCombo.ItemIndex < 0 then FLogLevelCombo.ItemIndex := 1;
  FLogRetentionEdit.Text := IntToStr(FSettings.LogRetentionDays);

  LoadProviderKindFields(FCurrentKind);
  LoadSelectedAppFields;
  LoadPromptsForSelectedApp;
  LoadMediaAndPresets;
  LoadAccessControlFields;
  UpdateToolBadges;
  OnVerifyEnvClick(nil);
end;

procedure TMmenuSettingsForm.PopulateCatalogProvidersForKind(const Kind: string);
var
  I: Integer;
  LInfo: TAILLMModelInfo;
begin
  FProvCatalogProvCombo.Items.BeginUpdate;
  try
    FProvCatalogProvCombo.Items.Clear;
    if (Kind = 'text') or (Kind = 'vision') or (Kind = 'asr') then
    begin
      for I := 0 to AILLMModelCount - 1 do
        if GetAILLMModelInfo(I, LInfo) and (not LInfo.IsLegacy) and
           (FProvCatalogProvCombo.Items.IndexOf(LInfo.Provider) < 0) then
          FProvCatalogProvCombo.Items.Add(LInfo.Provider);
    end
    else if Kind = 'image' then
      GetAIImageProviders(FProvCatalogProvCombo.Items)
    else if (Kind = 'voice') or (Kind = 'sfx') then
      GetAISoundProviders(FProvCatalogProvCombo.Items)
    else if Kind = 'video' then
      GetAIVideoProviders(FProvCatalogProvCombo.Items);

    if FProvCatalogProvCombo.Items.Count > 0 then
      FProvCatalogProvCombo.ItemIndex := 0;
  finally
    FProvCatalogProvCombo.Items.EndUpdate;
  end;
  PopulateCatalogModelsForSelectedProvider;
  if FBtnScanAudioServers <> nil then
    FBtnScanAudioServers.Visible := (Kind = 'voice') or (Kind = 'sfx');
end;

procedure TMmenuSettingsForm.PopulateCatalogModelsForSelectedProvider;
var
  ProvName: string;
begin
  FProvCatalogModelCombo.Items.BeginUpdate;
  try
    FProvCatalogModelCombo.Items.Clear;
    ProvName := FProvCatalogProvCombo.Text;
    if ProvName = '' then Exit;

    if (FCurrentKind = 'text') or (FCurrentKind = 'vision') or (FCurrentKind = 'asr') then
      GetAILLMModelsForProvider(ProvName, FProvCatalogModelCombo.Items, False)
    else if FCurrentKind = 'image' then
      GetAIImageModelsForProvider(ProvName, FProvCatalogModelCombo.Items, False)
    else if (FCurrentKind = 'voice') or (FCurrentKind = 'sfx') then
      GetAISoundModelsForProvider(ProvName, FProvCatalogModelCombo.Items, False)
    else if FCurrentKind = 'video' then
      GetAIVideoModelsForProvider(ProvName, FProvCatalogModelCombo.Items, False);

    if FProvCatalogModelCombo.Items.Count > 0 then
      FProvCatalogModelCombo.ItemIndex := 0;
  finally
    FProvCatalogModelCombo.Items.EndUpdate;
  end;
  OnCatalogModelChanged(nil);
end;

procedure TMmenuSettingsForm.OnCatalogProvChanged(Sender: TObject);
begin
  PopulateCatalogModelsForSelectedProvider;
  if Sender <> nil then
    OnApplyPresetClick(nil);
end;

procedure TMmenuSettingsForm.OnCatalogModelChanged(Sender: TObject);
var
  ProvName, ModName, Flags: string;
  ImgInfo: TAIImageModelInfo;
  SndInfo: TAISoundModelInfo;
  VidInfo: TAIVideoModelInfo;
  LlmInfo: TAILLMModelInfo;
begin
  ProvName := FProvCatalogProvCombo.Text;
  ModName := FProvCatalogModelCombo.Text;
  if (ProvName = '') or (ModName = '') then Exit;

  Flags := '';
  if (FCurrentKind = 'text') or (FCurrentKind = 'vision') or (FCurrentKind = 'asr') then
  begin
    if FindAILLMModel(ProvName, ModName, LlmInfo) then
    begin
      if LlmInfo.RequiresAPIKey then Flags := 'Requer API Key' else Flags := 'Local sem API Key';
      FProvCatalogHintLabel.Caption := LlmInfo.FriendlyName + ' | ' + Flags;
    end;
  end
  else if FCurrentKind = 'image' then
  begin
    if FindAIImageModel(ProvName, ModName, ImgInfo) then
    begin
      if ImgInfo.RunsOnCPUWithoutGPU then Flags := 'CPU sem GPU OK' else Flags := 'Requer GPU/Nuvem';
      FProvCatalogHintLabel.Caption := ImgInfo.FriendlyName + ' | ' + Flags;
    end;
  end
  else if (FCurrentKind = 'voice') or (FCurrentKind = 'sfx') then
  begin
    if FindAISoundModel(ProvName, ModName, SndInfo) then
    begin
      if SndInfo.RunsOnCPUWithoutGPU then Flags := 'CPU sem GPU' else Flags := 'Nuvem';
      if SndInfo.SupportsVoiceCloning then Flags := Flags + ' | Clonagem de Voz';
      if SndInfo.SupportsSFX then Flags := Flags + ' | SFX';
      if SndInfo.SupportsMusic then Flags := Flags + ' | Musica';
      FProvCatalogHintLabel.Caption := SndInfo.FriendlyName + ' | ' + Flags;
    end;
  end
  else if FCurrentKind = 'video' then
  begin
    if FindAIVideoModel(ProvName, ModName, VidInfo) then
    begin
      if VidInfo.RunsOnCPUWithoutGPU then Flags := 'CPU sem GPU OK' else Flags := 'GPU/Nuvem';
      if VidInfo.SupportsImageToVideo then Flags := Flags + ' | Imagem->Video';
      FProvCatalogHintLabel.Caption := VidInfo.FriendlyName + ' | ' + Flags;
    end;
  end;
  if Sender <> nil then
    OnApplyPresetClick(nil);
end;

procedure TMmenuSettingsForm.OnApplyPresetClick(Sender: TObject);
var
  ProvName, ModName, AdapterName, Ep: string;
  ImgInfo: TAIImageModelInfo;
  SndInfo: TAISoundModelInfo;
  VidInfo: TAIVideoModelInfo;
  LlmInfo: TAILLMModelInfo;

  procedure SelectAdapter(const AName: string);
  var
    Idx: Integer;
  begin
    Idx := FProvAdapterCombo.Items.IndexOf(AName);
    if Idx >= 0 then FProvAdapterCombo.ItemIndex := Idx;
  end;

begin
  ProvName := FProvCatalogProvCombo.Text;
  ModName := FProvCatalogModelCombo.Text;
  if (ProvName = '') or (ModName = '') then Exit;

  if (FCurrentKind = 'text') or (FCurrentKind = 'vision') or (FCurrentKind = 'asr') then
  begin
    if FindAILLMModel(ProvName, ModName, LlmInfo) then
    begin
      SelectAdapter('chatgpt-lib');
      FProvBaseUrlEdit.Text := LlmInfo.DefaultEndpoint;
      FProvModelEdit.Text := LlmInfo.InternalName;
      FProvTempEdit.Text := FloatToStr(LlmInfo.DefaultTemperature);
      FProvMaxTokensEdit.Text := IntToStr(LlmInfo.MaxTokens);
    end;
  end
  else if FCurrentKind = 'image' then
  begin
    if FindAIImageModel(ProvName, ModName, ImgInfo) then
    begin
      AdapterName := LowerCase(ProvName);
      if AdapterName = 'blackforestlabs' then AdapterName := 'bfl-flux'
      else if AdapterName = 'gemini' then AdapterName := 'openai-compatible'
      else if AdapterName = 'openai' then AdapterName := 'openai-compatible';
      SelectAdapter(AdapterName);
      FProvBaseUrlEdit.Text := ImgInfo.DefaultEndpoint;
      FProvModelEdit.Text := ImgInfo.InternalName;
      FProvWidthEdit.Text := IntToStr(ImgInfo.DefaultWidth);
      FProvHeightEdit.Text := IntToStr(ImgInfo.DefaultHeight);
    end;
  end
  else if (FCurrentKind = 'voice') or (FCurrentKind = 'sfx') then
  begin
    if FindAISoundModel(ProvName, ModName, SndInfo) then
    begin
      AdapterName := LowerCase(ProvName);
      if AdapterName = 'openai' then AdapterName := 'openai-compatible'
      else if AdapterName = 'audiocraft-bark' then AdapterName := 'audiocraft-bark'
      else if AdapterName = 'geminitts' then AdapterName := 'openai-compatible';
      SelectAdapter(AdapterName);
      FProvBaseUrlEdit.Text := SndInfo.DefaultEndpoint;
      FProvModelEdit.Text := SndInfo.InternalName;
    end;
  end
  else if FCurrentKind = 'video' then
  begin
    if FindAIVideoModel(ProvName, ModName, VidInfo) then
    begin
      AdapterName := LowerCase(ProvName);
      if AdapterName = 'comfyui-video' then AdapterName := 'comfyui';
      SelectAdapter(AdapterName);
      Ep := VidInfo.DefaultEndpoint;
      FProvBaseUrlEdit.Text := Ep;
      FProvModelEdit.Text := VidInfo.InternalName;
      FProvWidthEdit.Text := IntToStr(VidInfo.DefaultWidth);
      FProvHeightEdit.Text := IntToStr(VidInfo.DefaultHeight);
      FProvMaxSegEdit.Text := IntToStr(VidInfo.MaxDurationSec);
    end;
  end;
  FProvEnabledChk.Checked := True;
end;

procedure TMmenuSettingsForm.OnScanAudioServersClick(Sender: TObject);
var
  SL: TStringList;
  PyOut, PyErr: string;
begin
  SL := TStringList.Create;
  try
    DiscoverLocalSoundServers(SL);
    if PrepareParakeetRuntime('', PyOut, PyErr) then
      SL.Add('Parakeet Runtime Preparado: ' + PyOut);
    if CheckAISoundCpuRuntimeHealth('', '', PyOut, PyErr) then
      SL.Add('Runtime Python CPU: ' + PyOut)
    else
      SL.Add('Runtime Python CPU: ' + PyErr);
    MessageDlg('Servidores Locais Abertos e Runtime CPU (Som / Clonagem / SFX):' +
      LineEnding + LineEnding + SL.Text, mtInformation, [mbOK], 0);
  finally
    SL.Free;
  end;
end;

procedure TMmenuSettingsForm.LoadProviderKindFields(const Kind: string);
var
  Prov: TMmpAiProviderCfg;
begin
  FCurrentKind := Kind;
  PopulateCatalogProvidersForKind(Kind);
  FSettings.ResolveProvider(Kind, maMMenu, Prov);
  FProvKindLabel.Caption := 'Provedor padrao para: ' + UpperCase(Kind) + ' (' + Prov.Id + ')';
  FProvEnabledChk.Checked := Prov.Enabled;
  FProvAdapterCombo.ItemIndex := FProvAdapterCombo.Items.IndexOf(Prov.Adapter);
  if FProvAdapterCombo.ItemIndex < 0 then FProvAdapterCombo.ItemIndex := 0;
  FProvBaseUrlEdit.Text := Prov.BaseUrl;
  FProvModelEdit.Text := Prov.Model;
  if Prov.SecretRef = '' then
    FProvSecretRefEdit.Text := 'MAURINMOVIE_' + UpperCase(Kind) + '_KEY'
  else
    FProvSecretRefEdit.Text := Prov.SecretRef;
  FProvSecretValEdit.Text := FSettings.ResolveSecret(FProvSecretRefEdit.Text);
  FProvTempEdit.Text := FloatToStr(Prov.Temperature);
  FProvMaxTokensEdit.Text := IntToStr(Prov.MaxTokens);
  FProvWidthEdit.Text := IntToStr(Prov.Width);
  FProvHeightEdit.Text := IntToStr(Prov.Height);
  FProvResCombo.ItemIndex := MmpFindResolutionPresetIndex(Prov.Width, Prov.Height);
  FProvMaxSegEdit.Text := IntToStr(Prov.MaxSegmentSec);
end;

procedure TMmenuSettingsForm.SaveProviderKindFields;
var
  Prov: TMmpAiProviderCfg;
begin
  FSettings.ResolveProvider(FCurrentKind, maMMenu, Prov);
  if Trim(Prov.Id) = '' then
    Prov.Id := FCurrentKind + '.default';
  Prov.Kind := FCurrentKind;
  Prov.Enabled := FProvEnabledChk.Checked;
  Prov.Adapter := FProvAdapterCombo.Text;
  Prov.BaseUrl := Trim(FProvBaseUrlEdit.Text);
  Prov.Model := Trim(FProvModelEdit.Text);
  Prov.SecretRef := Trim(FProvSecretRefEdit.Text);
  Prov.Temperature := StrToFloatDef(FProvTempEdit.Text, 0.7);
  Prov.MaxTokens := StrToIntDef(FProvMaxTokensEdit.Text, 8000);
  Prov.Width := StrToIntDef(FProvWidthEdit.Text, 1024);
  Prov.Height := StrToIntDef(FProvHeightEdit.Text, 1024);
  Prov.MaxSegmentSec := StrToIntDef(FProvMaxSegEdit.Text, 10);
  FSettings.SetOrAddProvider(Prov, True);
  if (Prov.SecretRef <> '') and (Trim(FProvSecretValEdit.Text) <> '') then
    FSettings.SaveSecret(Prov.SecretRef, Trim(FProvSecretValEdit.Text));
end;

procedure TMmenuSettingsForm.LoadSelectedAppFields;
var
  A: TMMApp;
  Cfg: TMmpAppSettingsCfg;
begin
  A := AppIndexToEnum(FAppCombo.ItemIndex + 1);
  Cfg := FSettings.GetAppConfig(A);
  FAppTextProvEdit.Text := FSettings.GetAppProviderId(A, 'text');
  FAppImgProvEdit.Text := FSettings.GetAppProviderId(A, 'image');
  FAppVoiceProvEdit.Text := FSettings.GetAppProviderId(A, 'voice');
  FAppSfxProvEdit.Text := FSettings.GetAppProviderId(A, 'sfx');
  FAppVideoProvEdit.Text := FSettings.GetAppProviderId(A, 'video');
  FAppSceneCountEdit.Text := IntToStr(Cfg.SceneCount);
  FAppApprovedOnlyChk.Checked := Cfg.ApprovedRefsOnly;
end;

procedure TMmenuSettingsForm.SaveSelectedAppFields;
var
  A: TMMApp;
  Cfg: TMmpAppSettingsCfg;
begin
  A := AppIndexToEnum(FAppCombo.ItemIndex + 1);
  if Trim(FAppTextProvEdit.Text) <> '' then FSettings.SetAppProvider(A, 'text', Trim(FAppTextProvEdit.Text));
  if Trim(FAppImgProvEdit.Text) <> '' then FSettings.SetAppProvider(A, 'image', Trim(FAppImgProvEdit.Text));
  if Trim(FAppVoiceProvEdit.Text) <> '' then FSettings.SetAppProvider(A, 'voice', Trim(FAppVoiceProvEdit.Text));
  if Trim(FAppSfxProvEdit.Text) <> '' then FSettings.SetAppProvider(A, 'sfx', Trim(FAppSfxProvEdit.Text));
  if Trim(FAppVideoProvEdit.Text) <> '' then FSettings.SetAppProvider(A, 'video', Trim(FAppVideoProvEdit.Text));
  Cfg := FSettings.GetAppConfig(A);
  Cfg.SceneCount := StrToIntDef(FAppSceneCountEdit.Text, 5);
  Cfg.ApprovedRefsOnly := FAppApprovedOnlyChk.Checked;
  FSettings.SetAppConfig(A, Cfg);
end;

procedure TMmenuSettingsForm.UpdateToolBadges;
var
  I: Integer;
  P, AutoP: string;
begin
  for I := 1 to 6 do
  begin
    P := Trim(FAppPathEdits[I].Text);
    if (P <> '') and FileExists(P) then
    begin
      FAppStatusLabels[I].Caption := 'OK (config.)';
      FAppStatusLabels[I].Font.Color := $00007A00;
    end
    else
    begin
      AutoP := FSettings.DetectAppPath(AppIndexToEnum(I));
      if AutoP <> '' then
      begin
        FAppStatusLabels[I].Caption := 'Auto (bin/)';
        FAppStatusLabels[I].Font.Color := $00805000;
      end
      else
      begin
        FAppStatusLabels[I].Caption := 'Ausente';
        FAppStatusLabels[I].Font.Color := clMaroon;
      end;
    end;
  end;
end;

procedure TMmenuSettingsForm.OnTreeSelectionChanged(Sender: TObject; Node: TTreeNode);
var
  TagVal: PtrInt;
begin
  if Node = nil then Exit;
  TagVal := PtrInt(Node.Data);
  if (TagVal >= 10) and (TagVal <= 16) then
  begin
    SaveProviderKindFields;
    FPageControl.ActivePageIndex := 2;
    LoadProviderKindFields(FKindTabs[TagVal - 10]);
  end
  else if TagVal = 20 then
    FPageControl.ActivePageIndex := 10
  else if (TagVal >= 0) and (TagVal < FPageControl.PageCount) then
    FPageControl.ActivePageIndex := TagVal;
end;

procedure TMmenuSettingsForm.OnProdResChanged(Sender: TObject);
var
  W, H: Integer;
  Asp: string;
begin
  if MmpGetResolutionPreset(FProdResCombo.ItemIndex, W, H, Asp) then
  begin
    FProdWidthEdit.Text := IntToStr(W);
    FProdHeightEdit.Text := IntToStr(H);
    FProdAspectEdit.Text := Asp;
  end;
end;

procedure TMmenuSettingsForm.OnProvResChanged(Sender: TObject);
var
  W, H: Integer;
  Asp: string;
begin
  if MmpGetResolutionPreset(FProvResCombo.ItemIndex, W, H, Asp) then
  begin
    FProvWidthEdit.Text := IntToStr(W);
    FProvHeightEdit.Text := IntToStr(H);
  end;
end;

procedure TMmenuSettingsForm.OnMediaResChanged(Sender: TObject);
var
  W, H: Integer;
  Asp: string;
begin
  if MmpGetResolutionPreset(FMediaResCombo.ItemIndex, W, H, Asp) then
  begin
    FMediaImgWEdit.Text := IntToStr(W);
    FMediaImgHEdit.Text := IntToStr(H);
  end;
end;

procedure TMmenuSettingsForm.OnVerifyEnvClick(Sender: TObject);
var
  Rep: string;
begin
  FSettings.UserName := Trim(FUserNameEdit.Text);
  FSettings.VerifyEnvironment(Rep);
  FEnvMemo.Text := Rep;
end;

procedure TMmenuSettingsForm.OnToggleSecretClick(Sender: TObject);
begin
  if FProvSecretValEdit.PasswordChar = '*' then
  begin
    if MessageDlg('Exibir chave secreta na tela?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      FProvSecretValEdit.PasswordChar := #0;
      FProvShowSecretBtn.Caption := 'Ocultar';
    end;
  end
  else
  begin
    FProvSecretValEdit.PasswordChar := '*';
    FProvShowSecretBtn.Caption := 'Mostrar';
  end;
end;

procedure TMmenuSettingsForm.OnTestProviderClick(Sender: TObject);
var
  Bridge: TMmpAiBridge;
  Info, Err: string;
begin
  SaveProviderKindFields;
  if SameText(FProvAdapterCombo.Text, 'mock') or FOfflineChk.Checked then
  begin
    FProvTestLabel.Caption := 'MODO SIMULADO (mock): selecione um provedor real no Catalogo acima e clique em Aplicar antes de salvar.';
    FProvTestLabel.Font.Color := $000068B8;
    Exit;
  end;
  Bridge := TMmpAiBridge.Create('MMenu');
  try
    if FHasProduction then Bridge.LoadForProduction(FSettings.ProductionRoot);
    if Bridge.TestProviderByKind(FCurrentKind, Info, Err) then
    begin
      FProvTestLabel.Caption := Info;
      FProvTestLabel.Font.Color := $00007A00;
    end
    else
    begin
      FProvTestLabel.Caption := 'FALHA: ' + Err;
      FProvTestLabel.Font.Color := clMaroon;
    end;
  finally
    Bridge.Free;
  end;
end;

procedure TMmenuSettingsForm.OnAppComboChanged(Sender: TObject);
begin
  LoadSelectedAppFields;
end;

procedure TMmenuSettingsForm.OnBrowseDirClick(Sender: TObject);
var
  D: TSelectDirectoryDialog;
begin
  D := TSelectDirectoryDialog.Create(Self);
  try
    D.InitialDir := FDefaultRootEdit.Text;
    if D.Execute then FDefaultRootEdit.Text := D.FileName;
  finally
    D.Free;
  end;
end;

procedure TMmenuSettingsForm.OnBrowseAppClick(Sender: TObject);
var
  Idx: Integer;
  D: TOpenDialog;
begin
  Idx := (Sender as TButton).Tag;
  D := TOpenDialog.Create(Self);
  try
    D.FileName := FAppPathEdits[Idx].Text;
    D.Options := [ofFileMustExist, ofPathMustExist];
    if D.Execute then
    begin
      FAppPathEdits[Idx].Text := D.FileName;
      UpdateToolBadges;
    end;
  finally
    D.Free;
  end;
end;

procedure TMmenuSettingsForm.OnBrowseToolClick(Sender: TObject);
var
  Idx: Integer;
  D: TOpenDialog;
begin
  Idx := (Sender as TButton).Tag;
  D := TOpenDialog.Create(Self);
  try
    D.Options := [ofFileMustExist, ofPathMustExist];
    if D.Execute then
    begin
      case Idx of
        1: FFfmpegEdit.Text := D.FileName;
        2: FFfprobeEdit.Text := D.FileName;
        3: FMpvEdit.Text := D.FileName;
      end;
    end;
  finally
    D.Free;
  end;
end;

procedure TMmenuSettingsForm.OnDetectAllClick(Sender: TObject);
var
  I: Integer;
  P: string;
begin
  for I := 1 to 6 do
  begin
    P := FSettings.DetectAppPath(AppIndexToEnum(I));
    if P <> '' then FAppPathEdits[I].Text := P;
  end;
  P := FSettings.DetectToolPath('ffmpeg'); if P <> '' then FFfmpegEdit.Text := P;
  P := FSettings.DetectToolPath('ffprobe'); if P <> '' then FFfprobeEdit.Text := P;
  P := FSettings.DetectToolPath('mpv'); if P <> '' then FMpvEdit.Text := P;
  UpdateToolBadges;
end;

procedure TMmenuSettingsForm.LoadPromptsForSelectedApp;
var
  AppIdx: Integer;
begin
  FPromptNameCombo.Items.Clear;
  AppIdx := FPromptAppCombo.ItemIndex + 1;
  case AppIdx of
    1: begin // MScript
      FPromptNameCombo.Items.Add('gerar_roteiro');
      FPromptNameCombo.Items.Add('reescrever_cena');
      FPromptNameCombo.Items.Add('extrair_personagens');
      FPromptNameCombo.Items.Add('consistencia');
    end;
    2: begin // MVisual
      FPromptNameCombo.Items.Add('indexar_cena');
      FPromptNameCombo.Items.Add('vista_personagem');
      FPromptNameCombo.Items.Add('vista_objeto');
      FPromptNameCombo.Items.Add('vista_local');
      FPromptNameCombo.Items.Add('figurino');
    end;
    3: begin // MBoard
      FPromptNameCombo.Items.Add('quadro_inicial');
      FPromptNameCombo.Items.Add('quadro_final');
      FPromptNameCombo.Items.Add('quadro_fronteira');
    end;
    4: begin // MSound
      FPromptNameCombo.Items.Add('perfil_vocal');
      FPromptNameCombo.Items.Add('indexar_efeitos');
    end;
    5: FPromptNameCombo.Items.Add('segmento_video');
    6: FPromptNameCombo.Items.Add('agrupar_comentarios');
  end;
  if FPromptNameCombo.Items.Count > 0 then
    FPromptNameCombo.ItemIndex := 0;
  LoadSelectedPromptText;
end;

procedure TMmenuSettingsForm.LoadSelectedPromptText;
var
  AppFolder, PName, OverridePath, Txt: string;
begin
  FPromptMemo.Lines.Clear;
  if (not FHasProduction) or (FPromptNameCombo.Text = '') then Exit;
  AppFolder := LowerCase(FPromptAppCombo.Text);
  PName := FPromptNameCombo.Text;
  OverridePath := IncludeTrailingPathDelimiter(FSettings.ProductionRoot) +
    'settings' + PathDelim + 'prompts' + PathDelim + AppFolder + PathDelim + PName + '.txt';
  if SafeReadFileUtf8(OverridePath, Txt) then
  begin
    FPromptMemo.Text := Txt;
    FPromptStatusLabel.Caption := 'Substituicao ativa da producao: ' + OverridePath;
  end
  else
  begin
    FPromptMemo.Text := '# Modelo padrao embutido (' + AppFolder + '/' + PName + ')' + LineEnding +
      '# Edite e clique em "Salvar substituicao" para customizar nesta producao.' + LineEnding +
      'Contexto: {{contexto}}';
    FPromptStatusLabel.Caption := 'Usando prompt embutido (sem substituicao em settings/prompts/).';
  end;
end;

procedure TMmenuSettingsForm.OnPromptAppChanged(Sender: TObject);
begin
  LoadPromptsForSelectedApp;
end;

procedure TMmenuSettingsForm.OnPromptNameChanged(Sender: TObject);
begin
  LoadSelectedPromptText;
end;

procedure TMmenuSettingsForm.OnSavePromptClick(Sender: TObject);
var
  AppFolder, PName, OverridePath: string;
begin
  if (not FHasProduction) or (FPromptNameCombo.Text = '') then Exit;
  AppFolder := LowerCase(FPromptAppCombo.Text);
  PName := FPromptNameCombo.Text;
  OverridePath := IncludeTrailingPathDelimiter(FSettings.ProductionRoot) +
    'settings' + PathDelim + 'prompts' + PathDelim + AppFolder + PathDelim + PName + '.txt';
  if SafeWriteFileAtomic(OverridePath, FPromptMemo.Text, True) then
    FPromptStatusLabel.Caption := 'Salvo em: ' + OverridePath
  else
    MessageDlg('Falha ao salvar prompt em ' + OverridePath, mtError, [mbOK], 0);
end;

procedure TMmenuSettingsForm.OnRestorePromptClick(Sender: TObject);
var
  AppFolder, PName, OverridePath: string;
begin
  if (not FHasProduction) or (FPromptNameCombo.Text = '') then Exit;
  AppFolder := LowerCase(FPromptAppCombo.Text);
  PName := FPromptNameCombo.Text;
  OverridePath := IncludeTrailingPathDelimiter(FSettings.ProductionRoot) +
    'settings' + PathDelim + 'prompts' + PathDelim + AppFolder + PathDelim + PName + '.txt';
  if FileExists(OverridePath) then
    DeleteFile(OverridePath);
  LoadSelectedPromptText;
end;

procedure TMmenuSettingsForm.LoadMediaAndPresets;
var
  SetDir, Content: string;
  Data: TJSONData;
  Obj, Sub: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  FMediaImgFmtEdit.Text := 'png'; FMediaImgWEdit.Text := '1024'; FMediaImgHEdit.Text := '1024';
  FMediaAudioRateEdit.Text := '48000'; FMediaAudioBitsEdit.Text := '24';
  FMediaVidCodecEdit.Text := 'h264'; FMediaVidCrfEdit.Text := '16';
  FPresetsStylesMemo.Lines.Clear;
  FPresetsTransMemo.Lines.Clear;
  if not FHasProduction then Exit;

  SetDir := IncludeTrailingPathDelimiter(FSettings.ProductionRoot) + 'settings' + PathDelim;
  if SafeReadFileUtf8(SetDir + 'media-profiles.json', Content) then
  begin
    Data := nil;
    try
      Data := GetJSON(Content);
      if Data is TJSONObject then
      begin
        Obj := TJSONObject(Data);
        if Obj.Find('image.reference') is TJSONObject then
        begin
          Sub := TJSONObject(Obj.Find('image.reference'));
          FMediaImgFmtEdit.Text := Sub.Get('format', 'png');
          FMediaImgWEdit.Text := IntToStr(Sub.Get('width', 1024));
          FMediaImgHEdit.Text := IntToStr(Sub.Get('height', 1024));
          FMediaResCombo.ItemIndex := MmpFindResolutionPresetIndex(
            StrToIntDef(FMediaImgWEdit.Text, 1920),
            StrToIntDef(FMediaImgHEdit.Text, 1080));
        end;
        if Obj.Find('audio.work') is TJSONObject then
        begin
          Sub := TJSONObject(Obj.Find('audio.work'));
          FMediaAudioRateEdit.Text := IntToStr(Sub.Get('sample_rate', 48000));
          FMediaAudioBitsEdit.Text := IntToStr(Sub.Get('bit_depth', 24));
        end;
        if Obj.Find('video.work') is TJSONObject then
        begin
          Sub := TJSONObject(Obj.Find('video.work'));
          FMediaVidCodecEdit.Text := Sub.Get('codec', 'h264');
          FMediaVidCrfEdit.Text := IntToStr(Sub.Get('crf', 16));
        end;
      end;
    except
    end;
    if Data <> nil then Data.Free;
  end;

  if SafeReadFileUtf8(SetDir + 'presets.json', Content) then
  begin
    Data := nil;
    try
      Data := GetJSON(Content);
      if Data is TJSONObject then
      begin
        Obj := TJSONObject(Data);
        if Obj.Find('visual_styles') is TJSONArray then
        begin
          Arr := TJSONArray(Obj.Find('visual_styles'));
          for I := 0 to Arr.Count - 1 do FPresetsStylesMemo.Lines.Add(Arr.Strings[I]);
        end;
        if Obj.Find('transitions') is TJSONArray then
        begin
          Arr := TJSONArray(Obj.Find('transitions'));
          for I := 0 to Arr.Count - 1 do FPresetsTransMemo.Lines.Add(Arr.Strings[I]);
        end;
      end;
    except
    end;
    if Data <> nil then Data.Free;
  end;
end;

procedure TMmenuSettingsForm.SaveMediaAndPresets;
var
  SetDir, NowIso, S: string;
  Root, Sub: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  if not FHasProduction then Exit;
  SetDir := IncludeTrailingPathDelimiter(FSettings.ProductionRoot) + 'settings' + PathDelim;
  NowIso := CurrentUtcIso;

  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.media-profiles/1');
    Root.Add('updated_at', NowIso);
    Sub := TJSONObject.Create;
    Sub.Add('format', Trim(FMediaImgFmtEdit.Text));
    Sub.Add('width', StrToIntDef(FMediaImgWEdit.Text, 1024));
    Sub.Add('height', StrToIntDef(FMediaImgHEdit.Text, 1024));
    Sub.Add('background', '#808080');
    Root.Add('image.reference', Sub);
    Sub := TJSONObject.Create;
    Sub.Add('format', 'wav');
    Sub.Add('sample_rate', StrToIntDef(FMediaAudioRateEdit.Text, 48000));
    Sub.Add('bit_depth', StrToIntDef(FMediaAudioBitsEdit.Text, 24));
    Root.Add('audio.work', Sub);
    Sub := TJSONObject.Create;
    Sub.Add('container', 'mp4');
    Sub.Add('codec', Trim(FMediaVidCodecEdit.Text));
    Sub.Add('crf', StrToIntDef(FMediaVidCrfEdit.Text, 16));
    Root.Add('video.work', Sub);
    SafeWriteFileAtomic(SetDir + 'media-profiles.json', Root.FormatJSON, True);
  finally
    Root.Free;
  end;

  Root := TJSONObject.Create;
  try
    Root.Add('schema', 'mmp.presets/1');
    Root.Add('updated_at', NowIso);
    Arr := TJSONArray.Create;
    for I := 0 to FPresetsStylesMemo.Lines.Count - 1 do
    begin
      S := Trim(FPresetsStylesMemo.Lines[I]);
      if S <> '' then Arr.Add(S);
    end;
    Root.Add('visual_styles', Arr);
    Arr := TJSONArray.Create;
    for I := 0 to FPresetsTransMemo.Lines.Count - 1 do
    begin
      S := Trim(FPresetsTransMemo.Lines[I]);
      if S <> '' then Arr.Add(S);
    end;
    Root.Add('transitions', Arr);
    SafeWriteFileAtomic(SetDir + 'presets.json', Root.FormatJSON, True);
  finally
    Root.Free;
  end;
end;

procedure TMmenuSettingsForm.OnSaveClick(Sender: TObject);
var
  I: Integer;
  ErrMsg: string;
begin
  FSettings.UserName := Trim(FUserNameEdit.Text);
  FSettings.UserRole := Trim(FUserRoleEdit.Text);
  FSettings.UserEmail := Trim(FUserEmailEdit.Text);

  FSettings.ProductionsDir := Trim(FDefaultRootEdit.Text);
  for I := 1 to 6 do
    FSettings.SetAppExe(AppIndexToEnum(I), Trim(FAppPathEdits[I].Text));
  FSettings.ToolFfmpeg := Trim(FFfmpegEdit.Text);
  FSettings.ToolFfprobe := Trim(FFfprobeEdit.Text);
  FSettings.ToolMpv := Trim(FMpvEdit.Text);
  FSettings.SoundLibraryDir := Trim(FSoundLibDirEdit.Text);
  FSettings.MusicLibraryDir := Trim(FMusicLibDirEdit.Text);

  FSettings.ProxyUrl := Trim(FProxyEdit.Text);
  FSettings.ProxyUser := Trim(FProxyUserEdit.Text);
  FSettings.CABundle := Trim(FCABundleEdit.Text);
  FSettings.OfflineMode := FOfflineChk.Checked;
  FSettings.UiLanguage := Trim(FUiLangEdit.Text);
  FSettings.FontScale := StrToIntDef(FFontScaleEdit.Text, 100);
  FSettings.UiTheme := FThemeCombo.Text;
  FSettings.ConfirmDestructive := FConfirmDestructiveChk.Checked;
  FSettings.LogLevel := FLogLevelCombo.Text;
  FSettings.LogRetentionDays := StrToIntDef(FLogRetentionEdit.Text, 30);

  if FAccessModeCombo.ItemIndex = 1 then
    FSettings.AccessMode := amRestricted
  else
    FSettings.AccessMode := amOpen;
  if not FSettings.SaveAccessControl(ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  SaveProviderKindFields;
  SaveSelectedAppFields;
  FSettings.SaveMachineIni;
  if not FSettings.SaveMachineAiSettings(ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;

  if FHasProduction then
  begin
    FSettings.ProdNameBase := Trim(FProdNameBaseEdit.Text);
    FSettings.ProdLanguage := Trim(FProdLangEdit.Text);
    FSettings.ProdFps := StrToIntDef(FProdFpsEdit.Text, 24);
    FSettings.ProdWidth := StrToIntDef(FProdWidthEdit.Text, 1920);
    FSettings.ProdHeight := StrToIntDef(FProdHeightEdit.Text, 1080);
    FSettings.ProdAspect := Trim(FProdAspectEdit.Text);
    FSettings.ProdVisualStyle := Trim(FProdStyleEdit.Text);
    FSettings.ProdFormat := FProdFormatCombo.Text;

    FSettings.RequireApprovedRefsForBoard := FPolReqBoardChk.Checked;
    FSettings.RequireVoiceApprovalForScene := FPolReqVoiceChk.Checked;
    FSettings.PolicyRatingScale := StrToIntDef(FPolRatingScaleEdit.Text, 5);
    FSettings.BudgetTotal := StrToFloatDef(FPolBudgetEdit.Text, 0);
    FSettings.AutosaveSec := StrToIntDef(FPolAutosaveEdit.Text, 60);
    FSettings.MonitorIntervalSec := StrToIntDef(FPolMonitorEdit.Text, 5);

    SaveMediaAndPresets;

    if not FSettings.SaveProductionSettings(ErrMsg) then
    begin
      MessageDlg(ErrMsg, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  ModalResult := mrOK;
end;

procedure TMmenuSettingsForm.LoadAccessControlFields;
begin
  FSettings.LoadAccessControl;
  if FSettings.AccessMode = amRestricted then
    FAccessModeCombo.ItemIndex := 1
  else
    FAccessModeCombo.ItemIndex := 0;
  RefreshAccessUsersGrid;
  OnAccessClearUserClick(nil);
end;

procedure TMmenuSettingsForm.RefreshAccessUsersGrid;
var
  Users: TMmpAccessUserArray;
  I, Row: Integer;
begin
  Users := FSettings.GetAccessUsers;
  if Length(Users) = 0 then
  begin
    FAccessUsersGrid.RowCount := 2;
    for I := 0 to FAccessUsersGrid.ColCount - 1 do
      FAccessUsersGrid.Cells[I, 1] := '';
    Exit;
  end;
  FAccessUsersGrid.RowCount := Length(Users) + 1;
  for I := 0 to High(Users) do
  begin
    Row := I + 1;
    FAccessUsersGrid.Cells[0, Row] := Users[I].Username;
    FAccessUsersGrid.Cells[1, Row] := MmpUserProfileToStr(Users[I].Profile);
    if Users[I].Active then
      FAccessUsersGrid.Cells[2, Row] := 'Sim'
    else
      FAccessUsersGrid.Cells[2, Row] := 'Nao';
    FAccessUsersGrid.Cells[3, Row] := Users[I].UpdatedAt;
  end;
end;

procedure TMmenuSettingsForm.OnAccessModeChanged(Sender: TObject);
begin
  if Sender <> nil then;
end;

procedure TMmenuSettingsForm.OnAccessGridSelection(Sender: TObject; aCol, aRow: Integer);
var
  Users: TMmpAccessUserArray;
  Idx: Integer;
begin
  Idx := aRow - 1;
  Users := FSettings.GetAccessUsers;
  if (Idx < 0) or (Idx > High(Users)) then Exit;
  FAccessUserEdit.Text := Users[Idx].Username;
  if Users[Idx].Profile = upAdministrador then
    FAccessProfileCombo.ItemIndex := 0
  else
    FAccessProfileCombo.ItemIndex := 1;
  FAccessPassEdit.Text := '';
  FAccessActiveChk.Checked := Users[Idx].Active;
  if Sender <> nil then;
  if aCol >= 0 then;
end;

procedure TMmenuSettingsForm.OnAccessSaveUserClick(Sender: TObject);
var
  UName, Pass, ErrMsg: string;
  Prof: TMmpUserProfile;
  ExistingIdx: Integer;
  IsExisting: Boolean;
begin
  UName := Trim(FAccessUserEdit.Text);
  if FAccessProfileCombo.ItemIndex = 0 then
    Prof := upAdministrador
  else
    Prof := upUser;
  Pass := FAccessPassEdit.Text;
  IsExisting := FSettings.FindAccessUser(UName, ExistingIdx);

  if not FSettings.AddOrUpdateAccessUser(UName, Prof, Pass, FAccessActiveChk.Checked, IsExisting, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtWarning, [mbOK], 0);
    Exit;
  end;
  FAccessPassEdit.Text := '';
  RefreshAccessUsersGrid;
  MessageDlg('Usuario "' + UName + '" salvo com perfil ' + MmpUserProfileToStr(Prof) + '.',
    mtInformation, [mbOK], 0);
  if Sender <> nil then;
end;

procedure TMmenuSettingsForm.OnAccessRemoveUserClick(Sender: TObject);
var
  UName, ErrMsg: string;
begin
  UName := Trim(FAccessUserEdit.Text);
  if UName = '' then
  begin
    MessageDlg('Selecione um usuario para remover.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Remover usuario "' + UName + '"?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  if not FSettings.RemoveAccessUser(UName, ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtWarning, [mbOK], 0);
    Exit;
  end;
  RefreshAccessUsersGrid;
  OnAccessClearUserClick(nil);
  if Sender <> nil then;
end;

procedure TMmenuSettingsForm.OnAccessClearUserClick(Sender: TObject);
begin
  FAccessUserEdit.Text := '';
  FAccessProfileCombo.ItemIndex := 1; // User
  FAccessPassEdit.Text := '';
  FAccessActiveChk.Checked := True;
  if Sender <> nil then;
end;

procedure TMmenuSettingsForm.OnAccessResetAdminClick(Sender: TObject);
var
  ErrMsg: string;
begin
  if MessageDlg('Restaurar usuario ADMIN com senha padrao 123456 e perfil Administrador?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  if not FSettings.ResetDefaultAdminUser(ErrMsg) then
  begin
    MessageDlg(ErrMsg, mtError, [mbOK], 0);
    Exit;
  end;
  RefreshAccessUsersGrid;
  MessageDlg('Usuario ADMIN restaurado (senha padrao: 123456).', mtInformation, [mbOK], 0);
  if Sender <> nil then;
end;

function PromptMMenuLogin(Settings: TMMSettings;
  out LoggedUser: TMmpAccessUser): Boolean;
var
  Frm: TForm;
  Head: TPanel;
  LTitle, LSub, LU, LP, LHint: TLabel;
  EdUser, EdPass: TEdit;
  BtnOk, BtnCancel: TButton;
  ErrMsg: string;
begin
  Result := False;
  FillChar(LoggedUser, SizeOf(LoggedUser), 0);
  if Settings = nil then Exit;
  Settings.LoadAccessControl;

  Frm := TForm.CreateNew(nil, 1);
  try
    Frm.Caption := 'MMenu - Acesso Restrito por Usuarios';
    Frm.Width := 420;
    Frm.Height := 275;
    Frm.Position := poScreenCenter;
    Frm.BorderStyle := bsDialog;

    Head := TPanel.Create(Frm);
    Head.Parent := Frm;
    Head.Align := alTop;
    Head.Height := 58;
    Head.BevelOuter := bvNone;
    Head.Color := $006E3B16;
    Head.ParentBackground := False;

    LTitle := TLabel.Create(Frm);
    LTitle.Parent := Head;
    LTitle.Caption := 'MaurinMovie | Autenticacao';
    LTitle.Font.Size := 13;
    LTitle.Font.Style := [fsBold];
    LTitle.Font.Color := clWhite;
    LTitle.SetBounds(16, 10, 380, 22);

    LSub := TLabel.Create(Frm);
    LSub.Parent := Head;
    LSub.Caption := 'Perfis: Administrador ou User';
    LSub.Font.Color := $00FFE2C4;
    LSub.SetBounds(16, 34, 380, 16);

    LU := TLabel.Create(Frm);
    LU.Parent := Frm;
    LU.Caption := 'Usuario:';
    LU.SetBounds(24, 76, 120, 18);

    EdUser := TEdit.Create(Frm);
    EdUser.Parent := Frm;
    EdUser.SetBounds(24, 96, 366, 26);
    EdUser.Text := 'ADMIN';

    LP := TLabel.Create(Frm);
    LP.Parent := Frm;
    LP.Caption := 'Senha:';
    LP.SetBounds(24, 132, 120, 18);

    EdPass := TEdit.Create(Frm);
    EdPass.Parent := Frm;
    EdPass.PasswordChar := '*';
    EdPass.SetBounds(24, 152, 366, 26);

    LHint := TLabel.Create(Frm);
    LHint.Parent := Frm;
    LHint.Caption := 'Padrao inicial: ADMIN / 123456';
    LHint.Font.Color := $008C684C;
    LHint.SetBounds(24, 184, 240, 16);

    BtnOk := TButton.Create(Frm);
    BtnOk.Parent := Frm;
    BtnOk.Caption := 'Entrar';
    BtnOk.Default := True;
    BtnOk.ModalResult := mrOK;
    BtnOk.SetBounds(206, 214, 90, 32);

    BtnCancel := TButton.Create(Frm);
    BtnCancel.Parent := Frm;
    BtnCancel.Caption := 'Cancelar';
    BtnCancel.Cancel := True;
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.SetBounds(302, 214, 90, 32);

    Frm.ActiveControl := EdPass;

    while Frm.ShowModal = mrOK do
    begin
      if Settings.AuthenticateUser(EdUser.Text, EdPass.Text, LoggedUser, ErrMsg) then
      begin
        Settings.UserName := LoggedUser.Username;
        Settings.UserRole := MmpUserProfileToStr(LoggedUser.Profile);
        Exit(True);
      end;
      MessageDlg(ErrMsg, mtWarning, [mbOK], 0);
      EdPass.Text := '';
      EdPass.SetFocus;
    end;
  finally
    Frm.Free;
  end;
end;

end.
