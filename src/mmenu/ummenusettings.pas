unit ummenusettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, mmpcommon, mmpsettings, ummpaibridge;

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
    FProvAdapterCombo: TComboBox;
    FProvBaseUrlEdit: TEdit;
    FProvModelEdit: TEdit;
    FProvSecretRefEdit: TEdit;
    FProvSecretValEdit: TEdit;
    FProvShowSecretBtn: TButton;
    FProvTempEdit: TEdit;
    FProvMaxTokensEdit: TEdit;
    FProvWidthEdit: TEdit;
    FProvHeightEdit: TEdit;
    FProvMaxSegEdit: TEdit;
    FProvEnabledChk: TCheckBox;
    FProvTestLabel: TLabel;

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
    FOfflineChk: TCheckBox;
    FUiLangEdit: TEdit;
    FFontScaleEdit: TEdit;
    FThemeCombo: TComboBox;
    FLogLevelCombo: TComboBox;

    procedure BuildUI(const InitialTab: string);
    procedure LoadFieldsFromSettings;
    procedure LoadProviderKindFields(const Kind: string);
    procedure SaveProviderKindFields;
    procedure LoadSelectedAppFields;
    procedure SaveSelectedAppFields;
    procedure UpdateToolBadges;

    procedure OnTreeSelectionChanged(Sender: TObject; Node: TTreeNode);
    procedure OnVerifyEnvClick(Sender: TObject);
    procedure OnToggleSecretClick(Sender: TObject);
    procedure OnTestProviderClick(Sender: TObject);
    procedure OnAppComboChanged(Sender: TObject);
    procedure OnBrowseDirClick(Sender: TObject);
    procedure OnBrowseAppClick(Sender: TObject);
    procedure OnBrowseToolClick(Sender: TObject);
    procedure OnDetectAllClick(Sender: TObject);
    procedure OnSaveClick(Sender: TObject);
  public
    constructor CreateForSettings(TheOwner: TComponent;
      Settings: TMMSettings; HasProduction: Boolean; const InitialTab: string = '');
  end;

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
  TabGeral, TabProd, TabIA, TabApps, TabPol, TabTools, TabNet: TTabSheet;
  L: TLabel;
  BtnSave, BtnCancel, BtnEnv, BtnTest, BtnDetect, B: TButton;
  I, Y, SelIdx: Integer;
  Node, RootIA, TargetNode: TTreeNode;
  TargetTabLower: string;
begin
  Head := TPanel.Create(Self); Head.Parent := Self; Head.Align := alTop; Head.Height := 56;
  Head.BevelOuter := bvNone; Head.Color := $003A3028; Head.ParentBackground := False;

  L := TLabel.Create(Self); L.Parent := Head;
  L.Caption := 'Configuracoes Centralizadas (MMenu — Unica fonte de gravacao)';
  L.Font.Size := 13; L.Font.Style := [fsBold]; L.Font.Color := clWhite;
  L.SetBounds(16, 16, 650, 24);

  Footer := TPanel.Create(Self); Footer.Parent := Self; Footer.Align := alBottom; Footer.Height := 52;
  Footer.BevelOuter := bvLowered;

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
  TabPol := TTabSheet.Create(FPageControl); TabPol.PageControl := FPageControl; TabPol.Caption := 'Politicas';
  TabTools := TTabSheet.Create(FPageControl); TabTools.PageControl := FPageControl; TabTools.Caption := 'Ferramentas';
  TabNet := TTabSheet.Create(FPageControl); TabNet.PageControl := FPageControl; TabNet.Caption := 'Rede e Interface';

  // Tree nodes with Data = tab marker
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
  FNavTree.Items.AddObject(nil, 'Politicas', Pointer(4));
  FNavTree.Items.AddObject(nil, 'Ferramentas e Executaveis', Pointer(5));
  FNavTree.Items.AddObject(nil, 'Rede, Interface e Log', Pointer(6));

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

  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'FPS:'; L.SetBounds(16, 76, 60, 18);
  FProdFpsEdit := TEdit.Create(Self); FProdFpsEdit.Parent := TabProd; FProdFpsEdit.SetBounds(16, 96, 80, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Largura:'; L.SetBounds(112, 76, 80, 18);
  FProdWidthEdit := TEdit.Create(Self); FProdWidthEdit.Parent := TabProd; FProdWidthEdit.SetBounds(112, 96, 90, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Altura:'; L.SetBounds(216, 76, 80, 18);
  FProdHeightEdit := TEdit.Create(Self); FProdHeightEdit.Parent := TabProd; FProdHeightEdit.SetBounds(216, 96, 90, 26);
  L := TLabel.Create(Self); L.Parent := TabProd; L.Caption := 'Proporcao:'; L.SetBounds(320, 76, 80, 18);
  FProdAspectEdit := TEdit.Create(Self); FProdAspectEdit.Parent := TabProd; FProdAspectEdit.SetBounds(320, 96, 90, 26);

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
  FProvKindLabel.SetBounds(16, 14, 520, 24);

  FProvEnabledChk := TCheckBox.Create(Self); FProvEnabledChk.Parent := TabIA;
  FProvEnabledChk.Caption := 'Provedor habilitado'; FProvEnabledChk.SetBounds(16, 48, 220, 22);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Adaptador:'; L.SetBounds(16, 82, 120, 18);
  FProvAdapterCombo := TComboBox.Create(Self); FProvAdapterCombo.Parent := TabIA; FProvAdapterCombo.Style := csDropDownList;
  FProvAdapterCombo.Items.Add('mock');
  FProvAdapterCombo.Items.Add('chatgpt-lib');
  FProvAdapterCombo.Items.Add('openai-compatible');
  FProvAdapterCombo.Items.Add('local-cli');
  FProvAdapterCombo.Items.Add('http-generic');
  FProvAdapterCombo.SetBounds(150, 78, 240, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'URL Base:'; L.SetBounds(16, 118, 120, 18);
  FProvBaseUrlEdit := TEdit.Create(Self); FProvBaseUrlEdit.Parent := TabIA; FProvBaseUrlEdit.SetBounds(150, 114, 480, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Modelo:'; L.SetBounds(16, 154, 120, 18);
  FProvModelEdit := TEdit.Create(Self); FProvModelEdit.Parent := TabIA; FProvModelEdit.SetBounds(150, 150, 340, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'secret_ref:'; L.SetBounds(16, 190, 120, 18);
  FProvSecretRefEdit := TEdit.Create(Self); FProvSecretRefEdit.Parent := TabIA; FProvSecretRefEdit.SetBounds(150, 186, 220, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Chave (cofre local):'; L.SetBounds(16, 226, 130, 18);
  FProvSecretValEdit := TEdit.Create(Self); FProvSecretValEdit.Parent := TabIA; FProvSecretValEdit.PasswordChar := '*';
  FProvSecretValEdit.SetBounds(150, 222, 340, 26);

  FProvShowSecretBtn := TButton.Create(Self); FProvShowSecretBtn.Parent := TabIA; FProvShowSecretBtn.Caption := 'Mostrar';
  FProvShowSecretBtn.SetBounds(498, 221, 90, 28); FProvShowSecretBtn.OnClick := @OnToggleSecretClick;

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Temperatura:'; L.SetBounds(16, 266, 95, 18);
  FProvTempEdit := TEdit.Create(Self); FProvTempEdit.Parent := TabIA; FProvTempEdit.SetBounds(150, 262, 80, 26);
  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Max Tokens:'; L.SetBounds(250, 266, 90, 18);
  FProvMaxTokensEdit := TEdit.Create(Self); FProvMaxTokensEdit.Parent := TabIA; FProvMaxTokensEdit.SetBounds(342, 262, 95, 26);

  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Largura / Altura:'; L.SetBounds(16, 304, 120, 18);
  FProvWidthEdit := TEdit.Create(Self); FProvWidthEdit.Parent := TabIA; FProvWidthEdit.SetBounds(150, 300, 80, 26);
  FProvHeightEdit := TEdit.Create(Self); FProvHeightEdit.Parent := TabIA; FProvHeightEdit.SetBounds(238, 300, 80, 26);
  L := TLabel.Create(Self); L.Parent := TabIA; L.Caption := 'Max Seg(s):'; L.SetBounds(336, 304, 85, 18);
  FProvMaxSegEdit := TEdit.Create(Self); FProvMaxSegEdit.Parent := TabIA; FProvMaxSegEdit.SetBounds(424, 300, 70, 26);

  BtnTest := TButton.Create(Self); BtnTest.Parent := TabIA; BtnTest.Caption := 'Testar Provedor';
  BtnTest.SetBounds(16, 350, 170, 32); BtnTest.OnClick := @OnTestProviderClick;

  FProvTestLabel := TLabel.Create(Self); FProvTestLabel.Parent := TabIA;
  FProvTestLabel.WordWrap := True; FProvTestLabel.SetBounds(198, 352, 460, 48);
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

  // Tab 4: Politicas
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

  BtnDetect := TButton.Create(Self); BtnDetect.Parent := TabTools; BtnDetect.Caption := 'Autodetectar tudo';
  BtnDetect.SetBounds(16, Y + 50, 170, 32); BtnDetect.OnClick := @OnDetectAllClick;

  // Tab 6: Rede, Interface e Log
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Proxy HTTP/HTTPS (opcional):'; L.SetBounds(16, 18, 220, 18);
  FProxyEdit := TEdit.Create(Self); FProxyEdit.Parent := TabNet; FProxyEdit.SetBounds(16, 38, 380, 26);
  FOfflineChk := TCheckBox.Create(Self); FOfflineChk.Parent := TabNet;
  FOfflineChk.Caption := 'Modo Offline (forca provedor simulado e bloqueia rede)'; FOfflineChk.SetBounds(16, 76, 420, 22);

  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Idioma da interface:'; L.SetBounds(16, 118, 160, 18);
  FUiLangEdit := TEdit.Create(Self); FUiLangEdit.Parent := TabNet; FUiLangEdit.SetBounds(184, 114, 120, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Escala da fonte (%):'; L.SetBounds(16, 154, 160, 18);
  FFontScaleEdit := TEdit.Create(Self); FFontScaleEdit.Parent := TabNet; FFontScaleEdit.SetBounds(184, 150, 80, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Tema:'; L.SetBounds(16, 190, 120, 18);
  FThemeCombo := TComboBox.Create(Self); FThemeCombo.Parent := TabNet; FThemeCombo.Style := csDropDownList;
  FThemeCombo.Items.Add('claro'); FThemeCombo.Items.Add('escuro'); FThemeCombo.SetBounds(184, 186, 120, 26);
  L := TLabel.Create(Self); L.Parent := TabNet; L.Caption := 'Nivel de log:'; L.SetBounds(16, 226, 120, 18);
  FLogLevelCombo := TComboBox.Create(Self); FLogLevelCombo.Parent := TabNet; FLogLevelCombo.Style := csDropDownList;
  FLogLevelCombo.Items.Add('debug'); FLogLevelCombo.Items.Add('info'); FLogLevelCombo.Items.Add('warn'); FLogLevelCombo.Items.Add('error');
  FLogLevelCombo.SetBounds(184, 222, 120, 26);

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
  else if TargetTabLower = 'politicas' then SelIdx := 10
  else if TargetTabLower = 'ferramentas' then SelIdx := 11
  else if (TargetTabLower = 'rede') or (TargetTabLower = 'interface') then SelIdx := 12;

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
  FProdWidthEdit.Text := IntToStr(FSettings.ProdWidth);
  FProdHeightEdit.Text := IntToStr(FSettings.ProdHeight);
  FProdAspectEdit.Text := FSettings.ProdAspect;
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

  FProxyEdit.Text := FSettings.ProxyUrl;
  FOfflineChk.Checked := FSettings.OfflineMode;
  FUiLangEdit.Text := FSettings.UiLanguage;
  FFontScaleEdit.Text := IntToStr(FSettings.FontScale);
  FThemeCombo.ItemIndex := FThemeCombo.Items.IndexOf(FSettings.UiTheme);
  if FThemeCombo.ItemIndex < 0 then FThemeCombo.ItemIndex := 0;
  FLogLevelCombo.ItemIndex := FLogLevelCombo.Items.IndexOf(FSettings.LogLevel);
  if FLogLevelCombo.ItemIndex < 0 then FLogLevelCombo.ItemIndex := 1;

  LoadProviderKindFields(FCurrentKind);
  LoadSelectedAppFields;
  UpdateToolBadges;
  OnVerifyEnvClick(nil);
end;

procedure TMmenuSettingsForm.LoadProviderKindFields(const Kind: string);
var
  Prov: TMmpAiProviderCfg;
begin
  FCurrentKind := Kind;
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
  FProvMaxSegEdit.Text := IntToStr(Prov.MaxSegmentSec);
end;

procedure TMmenuSettingsForm.SaveProviderKindFields;
var
  Prov: TMmpAiProviderCfg;
begin
  if not FHasProduction then Exit;
  FSettings.ResolveProvider(FCurrentKind, maMMenu, Prov);
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
  if not FHasProduction then Exit;
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
  else if (TagVal >= 0) and (TagVal < FPageControl.PageCount) then
    FPageControl.ActivePageIndex := TagVal;
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
  T0: QWord;
  Bridge: TMmpAiBridge;
  Resp, Err: string;
begin
  SaveProviderKindFields;
  T0 := GetTickCount64;
  if SameText(FProvAdapterCombo.Text, 'mock') then
  begin
    FProvTestLabel.Caption := 'OK (simulado) - latencia ' + IntToStr(GetTickCount64 - T0) + ' ms';
    FProvTestLabel.Font.Color := $00007A00;
    Exit;
  end;

  Bridge := TMmpAiBridge.Create('MMenu');
  try
    if FHasProduction then Bridge.LoadForProduction(FSettings.ProductionRoot);
    if Bridge.Ask('Responda apenas OK.', 'Teste de conectividade.', Resp, Err) then
    begin
      FProvTestLabel.Caption := 'OK - latencia ' + IntToStr(GetTickCount64 - T0) + ' ms';
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

  FSettings.ProxyUrl := Trim(FProxyEdit.Text);
  FSettings.OfflineMode := FOfflineChk.Checked;
  FSettings.UiLanguage := Trim(FUiLangEdit.Text);
  FSettings.FontScale := StrToIntDef(FFontScaleEdit.Text, 100);
  FSettings.UiTheme := FThemeCombo.Text;
  FSettings.LogLevel := FLogLevelCombo.Text;

  FSettings.SaveMachineIni;

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

    SaveProviderKindFields;
    SaveSelectedAppFields;

    if not FSettings.SaveProductionSettings(ErrMsg) then
    begin
      MessageDlg(ErrMsg, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  ModalResult := mrOK;
end;

end.
