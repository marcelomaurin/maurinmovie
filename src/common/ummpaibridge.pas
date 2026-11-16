unit ummpaibridge;

{ Ponte de IA centralizada (specs 00-comum §9 e §12):
  - Le configuracoes gravadas pelo MMenu (TMMSettings) e segredos de secrets.ini/env.
  - Suporta adaptador 'mock' (simulado deterministico) e 'chatgpt-lib' / 'openai-compatible'
    via pacote openai_core (TAIUnifiedLLM).
  - Apps 1..6 nunca gravam configuracoes; 'Alterar no MMenu...' abre o MMenu na aba certa. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Process, aiunifiedllm, aillmproviders, airuntimepaths,
  mmpcommon, mmpsettings;

type
  TMmpAiBridge = class
  private
    FLLM: TAIUnifiedLLM;
    FSettings: TMMSettings;
    FAppEnum: TMMApp;
    FAppDisplayName: string;
    FProductionRoot: string;
    function FindMMenuExecutable: string;
    function RunMockCompletion(const SystemPrompt, UserPrompt: string): string;
  public
    constructor Create(const AppDisplayName: string);
    destructor Destroy; override;

    procedure LoadForProduction(const ProdRoot: string);
    function ReloadIfChanged: Boolean;
    function IsConfigured: Boolean;
    function ActiveAdapter: string;
    function ProviderDisplayName: string;
    function SettingsSha256: string;
    function CheckOpenSSL(out InfoText: string): Boolean;
    function Ask(const SystemPrompt, UserPrompt: string;
      out ResponseText, ErrorMsg: string): Boolean;

    // Abre o MMenu na aba deste aplicativo (00-comum §12.2)
    function OpenMMenuSettings(AOwner: TComponent): Boolean;
    function ShowConfigDialog(AOwner: TComponent): Boolean;

    property Settings: TMMSettings read FSettings;
    property LLM: TAIUnifiedLLM read FLLM;
  end;

implementation

function MapAdapterToLLMKind(const BaseUrl, ModelName: string): TAILLMProviderKind;
var
  U, M: string;
begin
  U := LowerCase(BaseUrl);
  M := LowerCase(ModelName);
  if (Pos('generativelanguage', U) > 0) or (Pos('gemini', M) > 0) then
    Result := llmGemini
  else if (Pos('anthropic', U) > 0) or (Pos('claude', M) > 0) then
    Result := llmClaude
  else if (Pos('deepseek', U) > 0) or (Pos('deepseek', M) > 0) then
    Result := llmDeepSeek
  else if Pos('openrouter', U) > 0 then
    Result := llmOpenRouter
  else if Pos('groq', U) > 0 then
    Result := llmGroq
  else if (Pos('11434', U) > 0) or (Pos('ollama', U) > 0) then
    Result := llmOllama
  else if (U <> '') and (Pos('api.openai.com', U) = 0) then
    Result := llmOpenAICompatible
  else
    Result := llmOpenAI;
end;

constructor TMmpAiBridge.Create(const AppDisplayName: string);
var
  A: TMMApp;
begin
  inherited Create;
  FAppDisplayName := AppDisplayName;
  FAppEnum := maMMenu;
  for A := Low(TMMApp) to High(TMMApp) do
    if SameText(MMAppNames[A], AppDisplayName) then
    begin
      FAppEnum := A;
      Break;
    end;

  FSettings := TMMSettings.Create;
  FLLM := TAIUnifiedLLM.Create(nil);
  FLLM.ProviderKind := llmOpenAI;
  FLLM.Model := 'mock-script-v1';
  FLLM.MaxTokens := 2000;
  FLLM.Temperature := 0.7;
end;

destructor TMmpAiBridge.Destroy;
begin
  FLLM.Free;
  FSettings.Free;
  inherited Destroy;
end;

procedure TMmpAiBridge.LoadForProduction(const ProdRoot: string);
begin
  FProductionRoot := ExcludeTrailingPathDelimiter(ProdRoot);
  FSettings.Load(FProductionRoot, FAppEnum);
end;

function TMmpAiBridge.ReloadIfChanged: Boolean;
begin
  Result := FSettings.ReloadIfChanged(FAppEnum);
end;

function TMmpAiBridge.ActiveAdapter: string;
var
  Prov: TMmpAiProviderCfg;
begin
  FSettings.ResolveProvider('text', FAppEnum, Prov);
  Result := Prov.Adapter;
end;

function TMmpAiBridge.IsConfigured: Boolean;
var
  Prov: TMmpAiProviderCfg;
  Secret: string;
begin
  FSettings.ResolveProvider('text', FAppEnum, Prov);
  if not Prov.Enabled then Exit(False);
  if SameText(Prov.Adapter, 'mock') or SameText(Prov.Adapter, 'local-cli') then
    Exit(True);
  Secret := FSettings.ResolveSecret(Prov.SecretRef);
  Result := (Secret <> '') or (FLLM.ProviderKind = llmOllama);
end;

function TMmpAiBridge.ProviderDisplayName: string;
var
  Prov: TMmpAiProviderCfg;
begin
  FSettings.ResolveProvider('text', FAppEnum, Prov);
  Result := Prov.Adapter + ' / ' + Prov.Model + ' [via MMenu]';
end;

function TMmpAiBridge.SettingsSha256: string;
begin
  Result := FSettings.SettingsSha256;
end;

function TMmpAiBridge.CheckOpenSSL(out InfoText: string): Boolean;
var
  SSLLib, CryptoLib, ExeDir: string;
begin
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  if FileExists(IncludeTrailingPathDelimiter(ExeDir) + 'libssl-1_1-x64.dll') and
     FileExists(IncludeTrailingPathDelimiter(ExeDir) + 'libcrypto-1_1-x64.dll') then
  begin
    InfoText := 'OpenSSL Win64 pronta: libssl-1_1-x64.dll e libcrypto-1_1-x64.dll.';
    Exit(True);
  end;

  if AIResolveOpenSSLLibraries(ExeDir, SSLLib, CryptoLib) and
     FileExists(SSLLib) and FileExists(CryptoLib) then
  begin
    InfoText := 'OpenSSL localizada via CHATGPT runtime: ' + SSLLib;
    Exit(True);
  end;

  InfoText := 'Aviso OpenSSL: libssl-1_1-x64.dll / libcrypto-1_1-x64.dll nao encontradas ao lado do executavel.';
  Result := False;
end;

function TMmpAiBridge.RunMockCompletion(const SystemPrompt, UserPrompt: string): string;
begin
  if Pos('"scenes"', SystemPrompt) > 0 then
    Result :=
      '{"scenes":[' +
      '{"heading":"INT. ESTUDIO - NOITE","location":"Estudio","time_of_day":"NOITE","mood":"Misterioso",' +
      '"estimated_duration":45,"characters":"Protagonista","objects":"Lanterna, Carta","costumes":"Casaco escuro",' +
      '"action":"Baseado no roteiro simulado: ' + StringReplace(Copy(UserPrompt, 1, 80), '"', '''', [rfReplaceAll]) + '",' +
      '"dialogue":"Protagonista: Precisamos validar cada revisao antes de seguir."},' +
      '{"heading":"EXT. PRACA CENTRAL - DIA","location":"Praca Central","time_of_day":"DIA","mood":"Tenso",' +
      '"estimated_duration":60,"characters":"Protagonista, Aliado","objects":"Pasta de documentos","costumes":"Casaco escuro, Jaqueta",' +
      '"action":"Encontro rapido sob observacao discreta.",' +
      '"dialogue":"Aliado: Os manifestos confirmam o caminho exato."},' +
      '{"heading":"INT. SALA DE MONTAGEM - ENTARDECER","location":"Sala de Montagem","time_of_day":"ENTARDECER","mood":"Resolucao",' +
      '"estimated_duration":50,"characters":"Protagonista, Aliado","objects":"Projetor","costumes":"Casaco escuro, Jaqueta",' +
      '"action":"Projecao final confirma continuidade de todas as cenas.",' +
      '"dialogue":"Protagonista: Agora esta pronto para validacao."}' +
      ']}'
  else
    Result := '[Simulado - ' + FAppDisplayName + '] Resposta deterministica gerada localmente para: ' +
      Copy(Trim(UserPrompt), 1, 140);
end;

function TMmpAiBridge.Ask(const SystemPrompt, UserPrompt: string;
  out ResponseText, ErrorMsg: string): Boolean;
var
  Prov: TMmpAiProviderCfg;
  Secret: string;
begin
  Result := False;
  ResponseText := '';
  ErrorMsg := '';

  if FProductionRoot <> '' then
    FSettings.ReloadIfChanged(FAppEnum);

  FSettings.ResolveProvider('text', FAppEnum, Prov);
  if not Prov.Enabled then
  begin
    ErrorMsg := 'Provedor "' + Prov.Id + '" esta desabilitado. Abra Configuracoes no MMenu.';
    Exit;
  end;

  if SameText(Prov.Adapter, 'mock') or FSettings.OfflineMode then
  begin
    ResponseText := RunMockCompletion(SystemPrompt, UserPrompt);
    Exit(True);
  end;

  Secret := FSettings.ResolveSecret(Prov.SecretRef);
  FLLM.ProviderKind := MapAdapterToLLMKind(Prov.BaseUrl, Prov.Model);
  FLLM.Endpoint := Prov.BaseUrl;
  FLLM.Model := Prov.Model;
  FLLM.Token := Secret;
  FLLM.Temperature := Prov.Temperature;
  FLLM.MaxTokens := Prov.MaxTokens;
  FLLM.Timeout := Prov.TimeoutSec * 1000;
  FLLM.SystemPrompt := SystemPrompt;

  if (Trim(FLLM.Token) = '') and (FLLM.ProviderKind <> llmOllama) and
     (FLLM.ProviderKind <> llmLlamaCpp) then
  begin
    ErrorMsg := 'Provedor "' + Prov.Id + '" sem chave no cofre (secret_ref=' +
      Prov.SecretRef + '). Abra Configuracoes no MMenu.';
    Exit;
  end;

  if FLLM.Ask(UserPrompt) then
  begin
    ResponseText := FLLM.LastResult;
    Result := True;
  end
  else
    ErrorMsg := FLLM.LastError;
end;

function TMmpAiBridge.FindMMenuExecutable: string;
var
  ExeDir, Suffix, Candidate: string;
begin
  {$IFDEF WINDOWS}
  Suffix := '.exe';
  {$ELSE}
  Suffix := '';
  {$ENDIF}
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  Candidate := IncludeTrailingPathDelimiter(ExeDir) + 'mmenu' + Suffix;
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := ExpandFileName(ExeDir + PathDelim + '..' + PathDelim + 'bin' +
    PathDelim + 'mmenu' + Suffix);
  if FileExists(Candidate) then Exit(Candidate);
  Result := '';
end;

function TMmpAiBridge.OpenMMenuSettings(AOwner: TComponent): Boolean;
var
  MMenuExe, TabArg: string;
  P: TProcess;
  Prov: TMmpAiProviderCfg;
  DlgRes: Integer;
begin
  Result := False;
  FSettings.ResolveProvider('text', FAppEnum, Prov);
  DlgRes := MessageDlg(
    'Configuracao centralizada no MMenu (00-comum §12):' + LineEnding + LineEnding +
    'Aplicativo: ' + FAppDisplayName + LineEnding +
    'Provedor ativo: ' + Prov.Id + ' (' + Prov.Adapter + ' / ' + Prov.Model + ')' + LineEnding +
    'Endpoint: ' + Prov.BaseUrl + LineEnding +
    'Settings SHA-256: ' + Copy(FSettings.SettingsSha256, 1, 16) + LineEnding + LineEnding +
    'Deseja abrir a tela de Configuracoes no MMenu na aba ' + FAppDisplayName + '?',
    mtInformation, [mbYes, mbNo], 0);
  if DlgRes <> mrYes then Exit;

  MMenuExe := FindMMenuExecutable;
  if MMenuExe = '' then
  begin
    MessageDlg('Executavel do MMenu nao encontrado ao lado de ' + FAppDisplayName + '.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  TabArg := LowerCase(FAppDisplayName);
  P := TProcess.Create(nil);
  try
    P.Executable := MMenuExe;
    if FProductionRoot <> '' then
    begin
      P.Parameters.Add('--production');
      P.Parameters.Add(FProductionRoot);
    end;
    P.Parameters.Add('--settings');
    P.Parameters.Add('--tab');
    P.Parameters.Add(TabArg);
    P.Options := [];
    P.Execute;
    Result := True;
  finally
    P.Free;
  end;
  if AOwner <> nil then;
end;

function TMmpAiBridge.ShowConfigDialog(AOwner: TComponent): Boolean;
begin
  Result := OpenMMenuSettings(AOwner);
end;

end.
