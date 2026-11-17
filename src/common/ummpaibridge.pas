unit ummpaibridge;

{ Ponte de IA centralizada (specs 00-comum §9 e §12):
  - Le configuracoes gravadas pelo MMenu (TMMSettings) e segredos de secrets.ini/env.
  - Integra os pacotes da suite CHATGPT:
    * openai_core  (TAIUnifiedLLM)
    * openai_image (TAIUnifiedImage)
    * openai_voice (TAIUnifiedSound / aisoundruntime)
    * openai_video (TAIUnifiedVideo)
  - Suporta servidores abertos locais e runtimes CPU sem GPU. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Process,
  aiunifiedllm, aillmproviders, airuntimepaths,
  aiunifiedimage, aiimageproviders,
  aiunifiedsound, aisoundproviders, aisoundruntime,
  aiunifiedvideo, aivideoproviders,
  mmpcommon, mmpsettings;

type
  TMmpAiBridge = class
  private
    FLLM: TAIUnifiedLLM;
    FImage: TAIUnifiedImage;
    FSound: TAIUnifiedSound;
    FVideo: TAIUnifiedVideo;
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

    // Texto / Roteiro / Planejamento
    function Ask(const SystemPrompt, UserPrompt: string;
      out ResponseText, ErrorMsg: string): Boolean;

    // Imagem / Storyboard / Biblioteca Visual
    function GenerateImage(const Prompt, OutputFile: string;
      out ErrorMsg: string; const NegativePrompt: string = '';
      WidthPx: Integer = 0; HeightPx: Integer = 0): Boolean;

    // Som: Fala (TTS), Clonagem de Voz e Efeitos Sonoros (SFX) / Trilha
    function SynthesizeSpeech(const Text, OutputFile: string;
      out ErrorMsg: string; const VoiceId: string = '';
      const RefAudioFile: string = ''; ConsentConfirmed: Boolean = False;
      const VoiceOwner: string = ''): Boolean;
    function GenerateSFX(const Prompt, OutputFile: string;
      out ErrorMsg: string; DurationSec: Double = 4.0): Boolean;
    procedure DiscoverLocalAudioServers(AList: TStrings);

    // Video / Montagem de Cenas (inclui FFmpeg CPU sem GPU)
    function GenerateVideo(const Prompt, OutputFile: string;
      out ErrorMsg: string; const SourceImage: string = '';
      const AudioFile: string = ''; DurationSec: Integer = 5): Boolean;

    // Teste de conectividade por categoria ('text','image','voice','sfx','video')
    function TestProviderByKind(const Kind: string;
      out InfoMsg, ErrorMsg: string): Boolean;

    // Abre o MMenu na aba deste aplicativo (00-comum §12.2)
    function OpenMMenuSettings(AOwner: TComponent): Boolean;
    function ShowConfigDialog(AOwner: TComponent): Boolean;

    property Settings: TMMSettings read FSettings;
    property LLM: TAIUnifiedLLM read FLLM;
    property ImageAI: TAIUnifiedImage read FImage;
    property SoundAI: TAIUnifiedSound read FSound;
    property VideoAI: TAIUnifiedVideo read FVideo;
  end;

implementation

uses
  ummpappbase;

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

function MapAdapterToImageKind(const Adapter, BaseUrl: string): TAIImageProviderKind;
var
  S: string;
begin
  S := LowerCase(Trim(Adapter) + ' ' + Trim(BaseUrl));
  if Pos('comfy', S) > 0 then Result := imgComfyUI
  else if (Pos('automatic', S) > 0) or (Pos('7860', S) > 0) or (Pos('sdapi', S) > 0) then Result := imgAutomatic1111
  else if Pos('stability', S) > 0 then Result := imgStability
  else if (Pos('bfl', S) > 0) or (Pos('flux', S) > 0) then Result := imgBlackForestLabs
  else if (Pos('gemini', S) > 0) or (Pos('imagen', S) > 0) then Result := imgGemini
  else if Pos('huggingface', S) > 0 then Result := imgHuggingFace
  else if Pos('api.openai.com', S) > 0 then Result := imgOpenAI
  else Result := imgOpenAICompatible;
end;

function MapAdapterToSoundKind(const Adapter, BaseUrl: string): TAISoundProviderKind;
var
  S: string;
begin
  S := LowerCase(Trim(Adapter) + ' ' + Trim(BaseUrl));
  if (Pos('parakeet', S) > 0) or (Pos('8090', S) > 0) then Result := sndParakeet
  else if (Pos('kokoro', S) > 0) or (Pos('8880', S) > 0) then Result := sndKokoroFastAPI
  else if (Pos('piper', S) > 0) or (Pos('5000', S) > 0) then Result := sndPiperHTTP
  else if Pos('openedai', S) > 0 then Result := sndOpenedAISpeech
  else if (Pos('coqui', S) > 0) or (Pos('xtts', S) > 0) or (Pos('8020', S) > 0) then Result := sndCoquiXTTS
  else if (Pos('alltalk', S) > 0) or (Pos('7851', S) > 0) then Result := sndAllTalkTTS
  else if (Pos('openvoice', S) > 0) or (Pos('8030', S) > 0) then Result := sndOpenVoice
  else if Pos('f5', S) > 0 then Result := sndF5TTSServer
  else if (Pos('chatterbox', S) > 0) or (Pos('fish', S) > 0) then Result := sndChatterbox
  else if (Pos('audiocraft', S) > 0) or (Pos('audiogen', S) > 0) or (Pos('musicgen', S) > 0) or (Pos('bark', S) > 0) or (Pos('8040', S) > 0) then Result := sndBarkAudioGen
  else if Pos('eleven', S) > 0 then Result := sndElevenLabs
  else if Pos('gemini', S) > 0 then Result := sndGeminiTTS
  else if (Pos('local-cpu', S) > 0) or (Pos('aisound_cpu_worker', S) > 0) then Result := sndLocalCPURuntime
  else if (Pos('system', S) > 0) or (Pos('sapi', S) > 0) then Result := sndSystemOS
  else if Pos('api.openai.com', S) > 0 then Result := sndOpenAI
  else if Trim(BaseUrl) = '' then Result := sndLocalCPURuntime
  else Result := sndOpenAICompatible;
end;

function MapAdapterToVideoKind(const Adapter, BaseUrl: string): TAIVideoProviderKind;
var
  S: string;
begin
  S := LowerCase(Trim(Adapter) + ' ' + Trim(BaseUrl));
  if (Pos('ffmpeg', S) > 0) or (Pos('local://', S) > 0) or (Trim(BaseUrl) = '') then
    Result := vidLocalFFmpegCPU
  else if (Pos('veo', S) > 0) or (Pos('generativelanguage', S) > 0) then
    Result := vidGoogleVeo
  else if Pos('runway', S) > 0 then Result := vidRunway
  else if Pos('kling', S) > 0 then Result := vidKling
  else if Pos('luma', S) > 0 then Result := vidLuma
  else if Pos('comfy', S) > 0 then Result := vidComfyUIVideo
  else if (Pos('sora', S) > 0) or (Pos('api.openai.com', S) > 0) then Result := vidOpenAISora
  else Result := vidOpenAICompatible;
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

  FImage := TAIUnifiedImage.Create(nil);
  FImage.ProviderKind := imgOpenAICompatible;
  FImage.UseGPU := False;

  FSound := TAIUnifiedSound.Create(nil);
  FSound.ProviderKind := sndLocalCPURuntime;
  FSound.UseGPU := False;

  FVideo := TAIUnifiedVideo.Create(nil);
  FVideo.ProviderKind := vidLocalFFmpegCPU;
  FVideo.UseGPU := False;
end;

destructor TMmpAiBridge.Destroy;
begin
  FVideo.Free;
  FSound.Free;
  FImage.Free;
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
  if FProductionRoot <> '' then
    FSettings.ReloadIfChanged(FAppEnum);
  FSettings.ResolveProvider('text', FAppEnum, Prov);
  Result := Prov.Adapter;
end;

function TMmpAiBridge.IsConfigured: Boolean;
var
  Prov: TMmpAiProviderCfg;
  Secret: string;
  LLMKind: TAILLMProviderKind;
begin
  if FProductionRoot <> '' then
    FSettings.ReloadIfChanged(FAppEnum);
  FSettings.ResolveProvider('text', FAppEnum, Prov);
  if not Prov.Enabled then Exit(False);
  if SameText(Prov.Adapter, 'mock') or SameText(Prov.Adapter, 'local-cli') then
    Exit(True);
  LLMKind := MapAdapterToLLMKind(Prov.BaseUrl, Prov.Model);
  Secret := FSettings.ResolveSecret(Prov.SecretRef);
  Result := (Secret <> '') or (LLMKind in [llmOllama, llmLlamaCpp]);
end;

function TMmpAiBridge.ProviderDisplayName: string;
var
  Prov: TMmpAiProviderCfg;
begin
  if FProductionRoot <> '' then
    FSettings.ReloadIfChanged(FAppEnum);
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

function EscapeJsonStr(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
end;

function TMmpAiBridge.RunMockCompletion(const SystemPrompt, UserPrompt: string): string;
begin
  if Pos('"scenes"', SystemPrompt) > 0 then
    Result :=
      '{"scenes":[' +
      '{"heading":"INT. ESTUDIO - NOITE","location":"Estudio","time_of_day":"NOITE","mood":"Misterioso",' +
      '"estimated_duration":45,"characters":"Protagonista","objects":"Lanterna, Carta","costumes":"Casaco escuro",' +
      '"action":"Baseado no roteiro simulado: ' + EscapeJsonStr(Copy(UserPrompt, 1, 80)) + '",' +
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

function TMmpAiBridge.GenerateImage(const Prompt, OutputFile: string;
  out ErrorMsg: string; const NegativePrompt: string; WidthPx,
  HeightPx: Integer): Boolean;
var
  Prov: TMmpAiProviderCfg;
begin
  Result := False;
  ErrorMsg := '';
  if FProductionRoot <> '' then FSettings.ReloadIfChanged(FAppEnum);
  FSettings.ResolveProvider('image', FAppEnum, Prov);
  if not Prov.Enabled then
  begin
    ErrorMsg := 'Provedor de imagem "' + Prov.Id + '" desabilitado.';
    Exit;
  end;
  if SameText(Prov.Adapter, 'mock') or FSettings.OfflineMode then
  begin
    ErrorMsg := 'Modo simulado/offline ativo para imagem.';
    Exit;
  end;

  FImage.ProviderKind := MapAdapterToImageKind(Prov.Adapter, Prov.BaseUrl);
  FImage.Endpoint := Prov.BaseUrl;
  FImage.Model := Prov.Model;
  FImage.Token := FSettings.ResolveSecret(Prov.SecretRef);
  FImage.NegativePrompt := NegativePrompt;
  if WidthPx > 0 then FImage.Width := WidthPx else if Prov.Width > 0 then FImage.Width := Prov.Width else FImage.Width := 1024;
  if HeightPx > 0 then FImage.Height := HeightPx else if Prov.Height > 0 then FImage.Height := Prov.Height else FImage.Height := 1024;
  FImage.Timeout := Max(60000, Prov.TimeoutSec * 1000);

  Result := FImage.Generate(Prompt, OutputFile);
  if not Result then
    ErrorMsg := FImage.LastError;
end;

function TMmpAiBridge.SynthesizeSpeech(const Text, OutputFile: string;
  out ErrorMsg: string; const VoiceId, RefAudioFile: string;
  ConsentConfirmed: Boolean; const VoiceOwner: string): Boolean;
var
  Prov: TMmpAiProviderCfg;
begin
  Result := False;
  ErrorMsg := '';
  if FProductionRoot <> '' then FSettings.ReloadIfChanged(FAppEnum);
  FSettings.ResolveProvider('voice', FAppEnum, Prov);
  if not Prov.Enabled then
  begin
    ErrorMsg := 'Provedor de voz "' + Prov.Id + '" desabilitado.';
    Exit;
  end;

  if SameText(Prov.Adapter, 'mock') then
  begin
    FSound.ProviderKind := sndParakeet;
    FSound.TaskKind := stkSpeech;
  end
  else
  begin
    FSound.ProviderKind := MapAdapterToSoundKind(Prov.Adapter, Prov.BaseUrl);
    if (RefAudioFile <> '') and FileExists(RefAudioFile) then
      FSound.TaskKind := stkVoiceClone
    else
      FSound.TaskKind := stkSpeech;
  end;

  FSound.Endpoint := Prov.BaseUrl;
  FSound.Model := Prov.Model;
  FSound.Voice := VoiceId;
  FSound.Language := FSettings.ProdLanguage;
  if FSound.Language = '' then FSound.Language := 'pt';
  FSound.Token := FSettings.ResolveSecret(Prov.SecretRef);
  FSound.ReferenceAudio := RefAudioFile;
  FSound.ConsentConfirmed := ConsentConfirmed;
  FSound.VoiceOwner := VoiceOwner;
  FSound.RequireConsent := (FSound.TaskKind = stkVoiceClone);
  FSound.Timeout := Max(60000, Prov.TimeoutSec * 1000);

  Result := FSound.SynthesizeToFile(Text, OutputFile);
  if not Result then
    ErrorMsg := FSound.LastError;
end;

function TMmpAiBridge.GenerateSFX(const Prompt, OutputFile: string;
  out ErrorMsg: string; DurationSec: Double): Boolean;
var
  Prov: TMmpAiProviderCfg;
begin
  Result := False;
  ErrorMsg := '';
  if FProductionRoot <> '' then FSettings.ReloadIfChanged(FAppEnum);
  FSettings.ResolveProvider('sfx', FAppEnum, Prov);
  if not Prov.Enabled then
  begin
    ErrorMsg := 'Provedor de efeitos sonoros "' + Prov.Id + '" desabilitado.';
    Exit;
  end;

  if SameText(Prov.Adapter, 'mock') or FSettings.OfflineMode then
    FSound.ProviderKind := sndLocalCPURuntime
  else
    FSound.ProviderKind := MapAdapterToSoundKind(Prov.Adapter, Prov.BaseUrl);

  FSound.Endpoint := Prov.BaseUrl;
  FSound.Model := Prov.Model;
  FSound.Token := FSettings.ResolveSecret(Prov.SecretRef);
  FSound.Timeout := Max(60000, Prov.TimeoutSec * 1000);

  Result := FSound.GenerateSFX(Prompt, OutputFile, DurationSec);
  if not Result then
    ErrorMsg := FSound.LastError;
end;

procedure TMmpAiBridge.DiscoverLocalAudioServers(AList: TStrings);
begin
  DiscoverLocalSoundServers(AList);
end;

function TMmpAiBridge.GenerateVideo(const Prompt, OutputFile: string;
  out ErrorMsg: string; const SourceImage, AudioFile: string;
  DurationSec: Integer): Boolean;
var
  Prov: TMmpAiProviderCfg;
begin
  Result := False;
  ErrorMsg := '';
  if FProductionRoot <> '' then FSettings.ReloadIfChanged(FAppEnum);
  FSettings.ResolveProvider('video', FAppEnum, Prov);
  if not Prov.Enabled then
  begin
    ErrorMsg := 'Provedor de video "' + Prov.Id + '" desabilitado.';
    Exit;
  end;

  if SameText(Prov.Adapter, 'mock') or FSettings.OfflineMode then
    FVideo.ProviderKind := vidLocalFFmpegCPU
  else
    FVideo.ProviderKind := MapAdapterToVideoKind(Prov.Adapter, Prov.BaseUrl);

  FVideo.Endpoint := Prov.BaseUrl;
  FVideo.Model := Prov.Model;
  FVideo.Token := FSettings.ResolveSecret(Prov.SecretRef);
  FVideo.FfmpegPath := FSettings.ToolFfmpeg;
  FVideo.SourceImageFile := SourceImage;
  FVideo.AudioFile := AudioFile;
  if Prov.Width > 0 then FVideo.Width := Prov.Width else FVideo.Width := 1280;
  if Prov.Height > 0 then FVideo.Height := Prov.Height else FVideo.Height := 720;
  FVideo.DurationSec := DurationSec;
  FVideo.Timeout := Max(120000, Prov.TimeoutSec * 1000);

  Result := FVideo.GenerateTextToVideo(Prompt, OutputFile);
  if not Result then
    ErrorMsg := FVideo.LastError;
end;

function TMmpAiBridge.TestProviderByKind(const Kind: string;
  out InfoMsg, ErrorMsg: string): Boolean;
var
  K: string;
  Prov: TMmpAiProviderCfg;
  Resp, OutTmp, PyOut, PyErr: string;
  T0: QWord;
begin
  Result := False;
  InfoMsg := '';
  ErrorMsg := '';
  K := LowerCase(Trim(Kind));
  FSettings.ResolveProvider(K, FAppEnum, Prov);
  T0 := GetTickCount64;

  if SameText(Prov.Adapter, 'mock') then
  begin
    InfoMsg := 'OK (simulado) - latencia ' + IntToStr(GetTickCount64 - T0) + ' ms';
    Exit(True);
  end;

  if (K = 'text') or (K = 'vision') or (K = 'asr') then
  begin
    if Ask('Responda apenas OK.', 'Teste de conectividade.', Resp, ErrorMsg) then
    begin
      InfoMsg := 'OK - latencia ' + IntToStr(GetTickCount64 - T0) + ' ms';
      Result := True;
    end;
    Exit;
  end;

  if (K = 'voice') or (K = 'sfx') then
  begin
    if SameText(Prov.Adapter, 'local-cpu-runtime') or
       SameText(Prov.Adapter, 'parakeet') or
       (Pos('local://', LowerCase(Prov.BaseUrl)) = 1) then
    begin
      if CheckAISoundCpuRuntimeHealth('', '', PyOut, PyErr) then
      begin
        InfoMsg := 'OK CPU Runtime: ' + Copy(PyOut, 1, 140);
        Exit(True);
      end
      else
      begin
        ErrorMsg := PyErr;
        Exit(False);
      end;
    end;
    if Pos('http', LowerCase(Prov.BaseUrl)) = 1 then
    begin
      if ProbeSoundHttpServer(Prov.BaseUrl, 2000) then
      begin
        InfoMsg := 'Servidor de som acessivel (' + IntToStr(GetTickCount64 - T0) + ' ms)';
        Exit(True);
      end
      else
      begin
        ErrorMsg := 'Servidor nao respondeu em ' + Prov.BaseUrl;
        Exit(False);
      end;
    end;
    OutTmp := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_sound_test.wav';
    if K = 'sfx' then
      Result := GenerateSFX('teste curto', OutTmp, ErrorMsg, 1.0)
    else
      Result := SynthesizeSpeech('Teste de voz MaurinMovie.', OutTmp, ErrorMsg);
    if Result then
      InfoMsg := 'OK audio gerado (' + IntToStr(GetTickCount64 - T0) + ' ms)';
    Exit;
  end;

  if K = 'image' then
  begin
    if Pos('http', LowerCase(Prov.BaseUrl)) = 1 then
    begin
      if ProbeSoundHttpServer(Prov.BaseUrl, 2500) then
      begin
        InfoMsg := 'Endpoint de imagem acessivel (' + IntToStr(GetTickCount64 - T0) + ' ms)';
        Exit(True);
      end;
    end;
    ErrorMsg := 'Configure URL/chave valida para testar imagem (' + Prov.BaseUrl + ').';
    Exit(False);
  end;

  if K = 'video' then
  begin
    if SameText(Prov.Adapter, 'ffmpeg-cpu') or (Pos('local://', LowerCase(Prov.BaseUrl)) = 1) then
    begin
      OutTmp := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_vid_test.mp4';
      if GenerateVideo('Teste CPU', OutTmp, ErrorMsg, '', '', 2) then
      begin
        InfoMsg := 'OK FFmpeg CPU (' + IntToStr(GetTickCount64 - T0) + ' ms)';
        DeleteFile(OutTmp);
        Exit(True);
      end;
      Exit(False);
    end;
    if ProbeSoundHttpServer(Prov.BaseUrl, 2500) then
    begin
      InfoMsg := 'Endpoint de video acessivel (' + IntToStr(GetTickCount64 - T0) + ' ms)';
      Exit(True);
    end;
    ErrorMsg := 'Servidor de video indisponivel em ' + Prov.BaseUrl;
  end;
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

  if IsAppInstanceRunning(maMMenu) then
  begin
    FocusAppInstanceWindow(maMMenu);
    MessageDlg('O MMenu ja esta aberto (permitida apenas 1 instancia).' + LineEnding +
      'Use a engrenagem no MMenu aberto para ajustar a aba "' + FAppDisplayName + '".',
      mtInformation, [mbOK], 0);
    Exit(True);
  end;

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
