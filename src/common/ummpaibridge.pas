unit ummpaibridge;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  aiunifiedllm, aillmproviders, airuntimepaths;

type
  TMmpAiBridge = class
  private
    FLLM: TAIUnifiedLLM;
    FConfigFile: string;
    FAppDisplayName: string;
  public
    constructor Create(const AppDisplayName: string);
    destructor Destroy; override;

    procedure LoadConfig;
    procedure SaveConfig;
    function IsConfigured: Boolean;
    function ProviderDisplayName: string;
    function CheckOpenSSL(out InfoText: string): Boolean;
    function Ask(const SystemPrompt, UserPrompt: string;
      out ResponseText, ErrorMsg: string): Boolean;
    function ShowConfigDialog(AOwner: TComponent): Boolean;

    property LLM: TAIUnifiedLLM read FLLM;
    property ConfigFile: string read FConfigFile;
  end;

implementation

type
  TMmpAiConfigForm = class(TForm)
  private
    FProviderCombo: TComboBox;
    FModelEdit: TEdit;
    FEndpointEdit: TEdit;
    FTokenEdit: TEdit;
    FTempEdit: TEdit;
    FMaxTokensEdit: TEdit;
    FSSLStatusLabel: TLabel;
    procedure OnProviderChanged(Sender: TObject);
  public
    constructor CreateForBridge(AOwner: TComponent; Bridge: TMmpAiBridge);
    procedure ApplyToBridge(Bridge: TMmpAiBridge);
  end;

const
  SupportedProviders: array[0..7] of TAILLMProviderKind = (
    llmOpenAI,
    llmGemini,
    llmClaude,
    llmDeepSeek,
    llmOpenRouter,
    llmGroq,
    llmOllama,
    llmOpenAICompatible
  );

  SupportedProviderLabels: array[0..7] of string = (
    'OpenAI',
    'Google Gemini',
    'Anthropic Claude',
    'DeepSeek',
    'OpenRouter',
    'Groq',
    'Ollama (Local)',
    'OpenAI-Compatible'
  );

  DefaultModels: array[0..7] of string = (
    'gpt-4o-mini',
    'gemini-2.5-flash',
    'claude-3-5-sonnet-latest',
    'deepseek-chat',
    'openai/gpt-4o-mini',
    'llama-3.3-70b-versatile',
    'llama3.2',
    'gpt-4o-mini'
  );

function FindProviderComboIndex(Kind: TAILLMProviderKind): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(SupportedProviders) do
    if SupportedProviders[I] = Kind then
      Exit(I);
end;

constructor TMmpAiConfigForm.CreateForBridge(AOwner: TComponent;
  Bridge: TMmpAiBridge);
var
  Head, Body, Footer: TPanel;
  L: TLabel;
  BtnOK, BtnCancel: TButton;
  I: Integer;
  SSLInfo: string;
  SSLOk: Boolean;
begin
  inherited CreateNew(AOwner, 1);
  Caption := 'Configurar Provedor de IA (CHATGPT) - ' + Bridge.FAppDisplayName;
  Width := 560;
  Height := 420;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;

  Head := TPanel.Create(Self);
  Head.Parent := Self;
  Head.Align := alTop;
  Head.Height := 52;
  Head.BevelOuter := bvNone;
  Head.Color := $003A3028;
  Head.ParentBackground := False;

  L := TLabel.Create(Self);
  L.Parent := Head;
  L.Caption := 'Integracao CHATGPT / OpenSSL';
  L.Font.Size := 13;
  L.Font.Style := [fsBold];
  L.Font.Color := clWhite;
  L.SetBounds(16, 14, 420, 24);

  Footer := TPanel.Create(Self);
  Footer.Parent := Self;
  Footer.Align := alBottom;
  Footer.Height := 52;
  Footer.BevelOuter := bvLowered;

  BtnOK := TButton.Create(Self);
  BtnOK.Parent := Footer;
  BtnOK.Caption := 'Salvar';
  BtnOK.ModalResult := mrOK;
  BtnOK.Default := True;
  BtnOK.SetBounds(348, 10, 92, 32);

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Footer;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.Cancel := True;
  BtnCancel.SetBounds(450, 10, 92, 32);

  Body := TPanel.Create(Self);
  Body.Parent := Self;
  Body.Align := alClient;
  Body.BevelOuter := bvNone;

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Provedor LLM:';
  L.SetBounds(18, 16, 140, 18);

  FProviderCombo := TComboBox.Create(Self);
  FProviderCombo.Parent := Body;
  FProviderCombo.Style := csDropDownList;
  for I := 0 to High(SupportedProviderLabels) do
    FProviderCombo.Items.Add(SupportedProviderLabels[I]);
  FProviderCombo.ItemIndex := FindProviderComboIndex(Bridge.FLLM.ProviderKind);
  FProviderCombo.SetBounds(165, 12, 370, 26);
  FProviderCombo.OnChange := @OnProviderChanged;

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Modelo:';
  L.SetBounds(18, 52, 140, 18);

  FModelEdit := TEdit.Create(Self);
  FModelEdit.Parent := Body;
  FModelEdit.SetBounds(165, 48, 370, 26);
  FModelEdit.Text := Bridge.FLLM.Model;

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Endpoint (opcional):';
  L.SetBounds(18, 88, 140, 18);

  FEndpointEdit := TEdit.Create(Self);
  FEndpointEdit.Parent := Body;
  FEndpointEdit.SetBounds(165, 84, 370, 26);
  FEndpointEdit.Text := Bridge.FLLM.Endpoint;

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Token / API Key:';
  L.SetBounds(18, 124, 140, 18);

  FTokenEdit := TEdit.Create(Self);
  FTokenEdit.Parent := Body;
  FTokenEdit.SetBounds(165, 120, 370, 26);
  FTokenEdit.PasswordChar := '*';
  FTokenEdit.Text := Bridge.FLLM.Token;

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Temperatura:';
  L.SetBounds(18, 160, 140, 18);

  FTempEdit := TEdit.Create(Self);
  FTempEdit.Parent := Body;
  FTempEdit.SetBounds(165, 156, 110, 26);
  FTempEdit.Text := FloatToStr(Bridge.FLLM.Temperature);

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Max Tokens:';
  L.SetBounds(295, 160, 100, 18);

  FMaxTokensEdit := TEdit.Create(Self);
  FMaxTokensEdit.Parent := Body;
  FMaxTokensEdit.SetBounds(405, 156, 130, 26);
  FMaxTokensEdit.Text := IntToStr(Bridge.FLLM.MaxTokens);

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Segredos ficam apenas em AppData (' + Bridge.FConfigFile + '), nunca nos arquivos da producao.';
  L.WordWrap := True;
  L.Font.Color := clGrayText;
  L.SetBounds(18, 200, 518, 36);

  SSLOk := Bridge.CheckOpenSSL(SSLInfo);
  FSSLStatusLabel := TLabel.Create(Self);
  FSSLStatusLabel.Parent := Body;
  FSSLStatusLabel.WordWrap := True;
  FSSLStatusLabel.SetBounds(18, 246, 518, 48);
  FSSLStatusLabel.Caption := SSLInfo;
  if SSLOk then
    FSSLStatusLabel.Font.Color := $00007A00
  else
    FSSLStatusLabel.Font.Color := clMaroon;
end;

procedure TMmpAiConfigForm.OnProviderChanged(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FProviderCombo.ItemIndex;
  if (Idx >= 0) and (Idx <= High(DefaultModels)) then
    FModelEdit.Text := DefaultModels[Idx];
end;

procedure TMmpAiConfigForm.ApplyToBridge(Bridge: TMmpAiBridge);
var
  Idx: Integer;
begin
  Idx := FProviderCombo.ItemIndex;
  if (Idx >= 0) and (Idx <= High(SupportedProviders)) then
    Bridge.FLLM.ProviderKind := SupportedProviders[Idx];
  Bridge.FLLM.Model := Trim(FModelEdit.Text);
  Bridge.FLLM.Endpoint := Trim(FEndpointEdit.Text);
  Bridge.FLLM.Token := Trim(FTokenEdit.Text);
  Bridge.FLLM.Temperature := StrToFloatDef(FTempEdit.Text, 0.7);
  Bridge.FLLM.MaxTokens := StrToIntDef(FMaxTokensEdit.Text, 1800);
  Bridge.SaveConfig;
end;

constructor TMmpAiBridge.Create(const AppDisplayName: string);
var
  CfgDir: string;
begin
  inherited Create;
  FAppDisplayName := AppDisplayName;
  FLLM := TAIUnifiedLLM.Create(nil);
  FLLM.ProviderKind := llmOpenAI;
  FLLM.Model := 'gpt-4o-mini';
  FLLM.MaxTokens := 2000;
  FLLM.Temperature := 0.7;

  CfgDir := GetAppConfigDir(False) + 'MaurinMovie' + PathDelim;
  ForceDirectories(CfgDir);
  FConfigFile := CfgDir + 'chatgpt_ai.ini';
  LoadConfig;
end;

destructor TMmpAiBridge.Destroy;
begin
  FLLM.Free;
  inherited Destroy;
end;

procedure TMmpAiBridge.LoadConfig;
begin
  if FileExists(FConfigFile) then
    FLLM.LoadFromIni(FConfigFile);
end;

procedure TMmpAiBridge.SaveConfig;
begin
  FLLM.SaveToIni(FConfigFile);
end;

function TMmpAiBridge.IsConfigured: Boolean;
begin
  Result := (FLLM.ProviderKind = llmOllama) or
            (FLLM.ProviderKind = llmLlamaCpp) or
            (Trim(FLLM.Token) <> '');
end;

function TMmpAiBridge.ProviderDisplayName: string;
begin
  Result := AILLMProviderKindName(FLLM.ProviderKind) + ' (' + FLLM.Model + ')';
end;

function TMmpAiBridge.CheckOpenSSL(out InfoText: string): Boolean;
var
  SSLLib, CryptoLib, ExeDir: string;
begin
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  if FileExists(IncludeTrailingPathDelimiter(ExeDir) + 'libssl-1_1-x64.dll') and
     FileExists(IncludeTrailingPathDelimiter(ExeDir) + 'libcrypto-1_1-x64.dll') then
  begin
    InfoText := 'OpenSSL pronto na pasta do aplicativo: libssl-1_1-x64.dll e libcrypto-1_1-x64.dll.';
    Exit(True);
  end;

  if AIResolveOpenSSLLibraries(ExeDir, SSLLib, CryptoLib) and
     FileExists(SSLLib) and FileExists(CryptoLib) then
  begin
    InfoText := 'OpenSSL localizado via CHATGPT runtime: ' + SSLLib;
    Exit(True);
  end;

  InfoText := 'Aviso OpenSSL: libssl-1_1-x64.dll / libcrypto-1_1-x64.dll nao encontradas ao lado do executavel.';
  Result := False;
end;

function TMmpAiBridge.Ask(const SystemPrompt, UserPrompt: string;
  out ResponseText, ErrorMsg: string): Boolean;
begin
  Result := False;
  ResponseText := '';
  ErrorMsg := '';

  if not IsConfigured then
  begin
    ErrorMsg := 'Token de API nao configurado. Clique em "Configurar IA..." para informar provedor e chave.';
    Exit;
  end;

  FLLM.SystemPrompt := SystemPrompt;
  if FLLM.Ask(UserPrompt) then
  begin
    ResponseText := FLLM.LastResult;
    Result := True;
  end
  else
    ErrorMsg := FLLM.LastError;
end;

function TMmpAiBridge.ShowConfigDialog(AOwner: TComponent): Boolean;
var
  Dlg: TMmpAiConfigForm;
begin
  Result := False;
  Dlg := TMmpAiConfigForm.CreateForBridge(AOwner, Self);
  try
    if Dlg.ShowModal = mrOK then
    begin
      Dlg.ApplyToBridge(Self);
      Result := True;
    end;
  finally
    Dlg.Free;
  end;
end;

end.

