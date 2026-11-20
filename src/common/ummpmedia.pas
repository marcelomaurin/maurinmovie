unit ummpmedia;

{ Processamento de vídeo e áudio do MaurinMovie com ffmpeg/ffprobe externos
  (docs/specs/99-lacunas L-14).

  - Áudio de segmento: falas em sequência (com pausas) sobre a ambiência do
    local, em WAV com a duração do segmento.
  - Animática de segmento: quadro de abertura e de fechamento do storyboard
    com movimento de câmera lento e fusão entre eles, mais o áudio. É o
    vídeo usado quando não há IA de vídeo configurada e o vídeo de reserva
    quando a IA falha.
  - Costura de cena: concatena os segmentos aprovados num MP4 da cena.
  - Filme: aplica entrada/saída de cada cena, transições (corte, fusão,
    fade para preto) e grava o filme no formato escolhido.

  Os caminhos dos programas vêm da configuração do MMenu (seção Tools) ou
  são procurados no PATH. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Process;

type
  TMmpClip = record
    FileName: string;
    InSec, OutSec: Double;     // OutSec <= 0: até o fim
    Transition: string;        // transição para o clipe seguinte
    TransitionSec: Double;
  end;

  TMmpMedia = class
  private
    FFfmpeg, FFfprobe: string;
    FLastLog: string;
    FHasX264: Integer; // -1 desconhecido, 0 não, 1 sim
    function VideoArgs(Lossless: Boolean): string;
    function AudioArgs(Lossless: Boolean): string;
    function Normalize(const InLabel, OutLabel: string): string;
    function AudioNormalize(const InLabel, OutLabel: string): string;
  public
    Width, Height, Fps: Integer;
    { Chamado a cada ~0,2 s enquanto o ffmpeg roda (por exemplo, para
      Application.ProcessMessages e atualizar o status). }
    OnProgress: TNotifyEvent;
    constructor Create(const AFfmpeg, AFfprobe: string);
    function Available: Boolean;
    function HasX264: Boolean;
    { Executa o ffmpeg com uma lista de argumentos; o log fica em LastLog. }
    function RunFfmpeg(const Args: array of string): Boolean;
    function Duration(const FileName: string): Double;
    function HasAudio(const FileName: string): Boolean;
    function MakeSegmentAudio(const Lines: array of string; const Ambience: string;
      MinSec: Double; const OutWav: string; out TotalSec: Double; out Err: string): Boolean;
    function RenderAnimatic(const ImgA, ImgB, AudioWav: string; Sec: Double;
      const OutMp4: string; out Err: string): Boolean;
    { Junta um vídeo (por exemplo, da IA) a uma trilha de áudio, na duração dada. }
    function MuxAudio(const Video, AudioWav: string; Sec: Double; const OutMp4: string;
      out Err: string): Boolean;
    function Concat(const Files: array of string; const OutFile: string; out Err: string): Boolean;
    function RenderTimeline(const Clips: array of TMmpClip; const OutFile: string;
      out Err: string): Boolean;
    function ExtractFrame(const Video: string; AtSec: Double; const OutImage: string): Boolean;
    property Ffmpeg: string read FFfmpeg;
    property Ffprobe: string read FFfprobe;
    property LastLog: string read FLastLog;
  end;

{ Procura um executável no PATH (com .exe no Windows). }
function MmpFindExecutable(const Name: string): string;
{ Resolução de saída pelo nome do formato do MCut ("... 720p", "... 1080p"...). }
procedure MmpFormatSize(const FormatName: string; out W, H: Integer; out Lossless: Boolean);
{ Tipo de transição do ffmpeg (xfade) para os nomes usados no MCut. '' = corte. }
function MmpTransitionKind(const Name: string): string;
function FloatArg(V: Double): string;

implementation

function FloatArg(V: Double): string;
var F: TFormatSettings;
begin
  F := DefaultFormatSettings;
  F.DecimalSeparator := '.';
  Result := FormatFloat('0.###', V, F);
end;

function MmpFindExecutable(const Name: string): string;
var
  Paths: TStringList;
  P, Cand: string;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    Paths.Delimiter := PathSeparator;
    Paths.StrictDelimiter := True;
    Paths.DelimitedText := GetEnvironmentVariable('PATH');
    for P in Paths do
    begin
      if P = '' then Continue;
      Cand := IncludeTrailingPathDelimiter(P) + Name;
      {$IFDEF WINDOWS}
      if LowerCase(ExtractFileExt(Cand)) <> '.exe' then Cand := Cand + '.exe';
      {$ENDIF}
      if FileExists(Cand) then Exit(Cand);
    end;
  finally
    Paths.Free;
  end;
end;

procedure MmpFormatSize(const FormatName: string; out W, H: Integer; out Lossless: Boolean);
var S: string;
begin
  S := LowerCase(FormatName);
  Lossless := (Pos('mkv', S) > 0) or (Pos('lossless', S) > 0);
  W := 1920; H := 1080;
  if Pos('480p', S) > 0 then begin W := 854; H := 480; end
  else if Pos('720p', S) > 0 then begin W := 1280; H := 720; end
  else if Pos('1080p', S) > 0 then begin W := 1920; H := 1080; end
  else if Pos('1440p', S) > 0 then begin W := 2560; H := 1440; end
  else if Pos('2160p', S) > 0 then begin W := 3840; H := 2160; end
  else if Pos('4320p', S) > 0 then begin W := 7680; H := 4320; end;
end;

function MmpTransitionKind(const Name: string): string;
var S: string;
begin
  S := LowerCase(Trim(Name));
  if (S = '') or (S = 'cut') or (Pos('corte', S) > 0) then Exit('');
  if (Pos('preto', S) > 0) or (S = 'fade_out') or (S = 'fade out') or (Pos('black', S) > 0) then
    Exit('fadeblack');
  if Pos('branco', S) > 0 then Exit('fadewhite');
  Result := 'fade'; // dissolve, fade cruzado, fusão
end;

{ ---- TMmpMedia ---- }

constructor TMmpMedia.Create(const AFfmpeg, AFfprobe: string);
begin
  inherited Create;
  FFfmpeg := AFfmpeg;
  if (FFfmpeg = '') or not FileExists(FFfmpeg) then FFfmpeg := MmpFindExecutable('ffmpeg');
  FFfprobe := AFfprobe;
  if (FFfprobe = '') or not FileExists(FFfprobe) then FFfprobe := MmpFindExecutable('ffprobe');
  if (FFfprobe = '') and (FFfmpeg <> '') then
  begin
    FFfprobe := ExtractFilePath(FFfmpeg) + 'ffprobe' + ExtractFileExt(FFfmpeg);
    if not FileExists(FFfprobe) then FFfprobe := '';
  end;
  FHasX264 := -1;
  Width := 1280; Height := 720; Fps := 25;
end;

function TMmpMedia.Available: Boolean;
begin
  Result := (FFfmpeg <> '') and FileExists(FFfmpeg);
end;

function RunTool(const Exe: string; const Args: array of string; out Output: string;
  Progress: TNotifyEvent = nil; Sender: TObject = nil): Integer;
var
  LastTick: QWord;
  P: TProcess;
  Buf: array[0..65535] of Byte;
  N: LongInt;
  Mem: TMemoryStream;
  A: string;
begin
  Output := '';
  Result := -1;
  if (Exe = '') or not FileExists(Exe) then
  begin
    Output := 'Programa não encontrado: ' + Exe;
    Exit;
  end;
  P := TProcess.Create(nil);
  Mem := TMemoryStream.Create;
  try
    P.Executable := Exe;
    for A in Args do P.Parameters.Add(A);
    P.Options := [poUsePipes, poStderrToOutPut];
    P.ShowWindow := swoHIDE;
    try
      P.Execute;
    except
      on E: Exception do
      begin
        Output := E.Message;
        Exit;
      end;
    end;
    { lê a saída enquanto roda, para o processo não travar com o cano cheio }
    LastTick := GetTickCount64;
    while P.Running or (P.Output.NumBytesAvailable > 0) do
    begin
      if P.Output.NumBytesAvailable > 0 then
      begin
        N := P.Output.Read(Buf, SizeOf(Buf));
        if N > 0 then Mem.WriteBuffer(Buf, N);
      end
      else
        Sleep(10);
      if Assigned(Progress) and (GetTickCount64 - LastTick >= 200) then
      begin
        LastTick := GetTickCount64;
        Progress(Sender);
      end;
    end;
    repeat
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then Mem.WriteBuffer(Buf, N);
    until N <= 0;
    Result := P.ExitStatus;
    SetLength(Output, Mem.Size);
    if Mem.Size > 0 then Move(Mem.Memory^, Output[1], Mem.Size);
  finally
    Mem.Free;
    P.Free;
  end;
end;

function TMmpMedia.RunFfmpeg(const Args: array of string): Boolean;
var Full: array of string; I: Integer; Output: string;
begin
  SetLength(Full, Length(Args) + 3);
  Full[0] := '-hide_banner'; Full[1] := '-nostdin'; Full[2] := '-y';
  for I := 0 to High(Args) do Full[I + 3] := Args[I];
  Result := RunTool(FFfmpeg, Full, Output, OnProgress, Self) = 0;
  if Length(Output) > 6000 then Output := '...' + Copy(Output, Length(Output) - 6000, 6001);
  FLastLog := Output;
end;

function TMmpMedia.HasX264: Boolean;
var Output: string;
begin
  if FHasX264 < 0 then
  begin
    if RunTool(FFfmpeg, ['-hide_banner', '-encoders'], Output) = 0 then
      FHasX264 := Ord(Pos('libx264', Output) > 0)
    else
      FHasX264 := 0;
  end;
  Result := FHasX264 = 1;
end;

function ErrTail(const Log: string): string;
begin
  Result := Trim(Log);
  if Length(Result) > 900 then Result := '...' + Copy(Result, Length(Result) - 900, 901);
end;

function TMmpMedia.Duration(const FileName: string): Double;
var Output: string; F: TFormatSettings;
begin
  Result := 0;
  if FFfprobe = '' then Exit;
  if RunTool(FFfprobe, ['-v', 'error', '-show_entries', 'format=duration', '-of',
    'default=noprint_wrappers=1:nokey=1', FileName], Output) <> 0 then Exit;
  F := DefaultFormatSettings;
  F.DecimalSeparator := '.';
  Result := StrToFloatDef(Trim(Output), 0, F);
end;

function TMmpMedia.HasAudio(const FileName: string): Boolean;
var Output: string;
begin
  Result := False;
  if FFfprobe = '' then Exit;
  if RunTool(FFfprobe, ['-v', 'error', '-select_streams', 'a', '-show_entries',
    'stream=index', '-of', 'csv=p=0', FileName], Output) = 0 then
    Result := Trim(Output) <> '';
end;

function TMmpMedia.VideoArgs(Lossless: Boolean): string;
begin
  if Lossless then Result := '-c:v|ffv1|-level|3'
  else if HasX264 then Result := '-c:v|libx264|-preset|veryfast|-crf|20|-pix_fmt|yuv420p'
  else Result := '-c:v|mpeg4|-q:v|3|-pix_fmt|yuv420p';
end;

function TMmpMedia.AudioArgs(Lossless: Boolean): string;
begin
  if Lossless then Result := '-c:a|flac|-ar|48000|-ac|2'
  else Result := '-c:a|aac|-b:a|160k|-ar|48000|-ac|2';
end;

function TMmpMedia.Normalize(const InLabel, OutLabel: string): string;
begin
  Result := Format('[%s]scale=%d:%d:force_original_aspect_ratio=decrease,' +
    'pad=%d:%d:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=%d,format=yuv420p,settb=1/%d[%s]',
    [InLabel, Width, Height, Width, Height, Fps, Fps, OutLabel]);
end;

function TMmpMedia.AudioNormalize(const InLabel, OutLabel: string): string;
begin
  Result := Format('[%s]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[%s]',
    [InLabel, OutLabel]);
end;

procedure AddSplit(var Args: TStringArray; const Spec: string);
var Parts: TStringArray; S: string; N: Integer;
begin
  Parts := Spec.Split('|');
  for S in Parts do
  begin
    N := Length(Args);
    SetLength(Args, N + 1);
    Args[N] := S;
  end;
end;

procedure Add(var Args: TStringArray; const Items: array of string);
var S: string; N: Integer;
begin
  for S in Items do
  begin
    N := Length(Args);
    SetLength(Args, N + 1);
    Args[N] := S;
  end;
end;

function TMmpMedia.MakeSegmentAudio(const Lines: array of string; const Ambience: string;
  MinSec: Double; const OutWav: string; out TotalSec: Double; out Err: string): Boolean;
const Gap = 0.35; Lead = 0.4;
var
  Args: TStringArray;
  Filter, Mix: string;
  I, Idx, Inputs: Integer;
  T, D: Double;
  Valid: array of string;
begin
  Err := '';
  Args := nil;
  Valid := nil;
  for I := 0 to High(Lines) do
    if FileExists(Lines[I]) then
    begin
      SetLength(Valid, Length(Valid) + 1);
      Valid[High(Valid)] := Lines[I];
    end;
  T := Lead;
  for I := 0 to High(Valid) do T := T + Duration(Valid[I]) + Gap;
  TotalSec := Max(MinSec, T + 0.4);
  Add(Args, ['-f', 'lavfi', '-t', FloatArg(TotalSec), '-i', 'anullsrc=r=48000:cl=stereo']);
  for I := 0 to High(Valid) do Add(Args, ['-i', Valid[I]]);
  if (Ambience <> '') and FileExists(Ambience) then
    Add(Args, ['-stream_loop', '-1', '-i', Ambience]);
  Filter := ''; Mix := '[0:a]'; Inputs := 1;
  T := Lead;
  for I := 0 to High(Valid) do
  begin
    Idx := I + 1;
    D := Duration(Valid[I]);
    Filter := Filter + Format('[%d:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,' +
      'adelay=%d|%d[v%d];', [Idx, Round(T * 1000), Round(T * 1000), Idx]);
    Mix := Mix + Format('[v%d]', [Idx]);
    Inc(Inputs);
    T := T + D + Gap;
  end;
  if (Ambience <> '') and FileExists(Ambience) then
  begin
    Idx := Length(Valid) + 1;
    Filter := Filter + Format('[%d:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,' +
      'volume=0.22[amb];', [Idx]);
    Mix := Mix + '[amb]';
    Inc(Inputs);
  end;
  Filter := Filter + Mix + Format('amix=inputs=%d:duration=first:dropout_transition=0:normalize=0[a]', [Inputs]);
  Add(Args, ['-filter_complex', Filter, '-map', '[a]', '-t', FloatArg(TotalSec),
    '-c:a', 'pcm_s16le', OutWav]);
  ForceDirectories(ExtractFileDir(OutWav));
  Result := RunFfmpeg(Args);
  if not Result then Err := 'ffmpeg (áudio do segmento): ' + ErrTail(FLastLog);
end;

function TMmpMedia.RenderAnimatic(const ImgA, ImgB, AudioWav: string; Sec: Double;
  const OutMp4: string; out Err: string): Boolean;
var
  Args: TStringArray;
  Frames, AudioIdx: Integer;
  Fade, Half: Double;
  Filter, B: string;

  function Zoom(const InLabel, OutLabel: string; ZoomIn: Boolean): string;
  var Z: string;
  begin
    if ZoomIn then Z := Format('min(1+%s*on,1.12)', [FloatArg(0.12 / Max(1, Frames))])
    else Z := Format('max(1.12-%s*on,1)', [FloatArg(0.12 / Max(1, Frames))]);
    Result := Format('[%s]scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d,' +
      'zoompan=z=''%s'':x=''iw/2-(iw/zoom/2)'':y=''ih/2-(ih/zoom/2)'':d=%d:s=%dx%d:fps=%d,' +
      'setsar=1,format=yuv420p[%s]',
      [InLabel, Width * 2, Height * 2, Width * 2, Height * 2, Z, Frames, Width, Height, Fps, OutLabel]);
  end;

begin
  Err := '';
  Args := nil;
  Sec := Max(1, Sec);
  Frames := Max(1, Round(Sec * Fps));
  if (ImgA <> '') and FileExists(ImgA) then
  begin
    Add(Args, ['-i', ImgA]);
    B := ImgB;
    if (B = '') or not FileExists(B) or SameText(B, ImgA) then B := '';
    if B <> '' then
    begin
      Add(Args, ['-i', B]);
      AudioIdx := 2;
      Fade := Min(1.5, Sec / 4);
      Half := Sec / 2;
      Filter := Zoom('0:v', 'a', True) + ';' + Zoom('1:v', 'b', False) + ';' +
        Format('[a][b]xfade=transition=fade:duration=%s:offset=%s[v]',
          [FloatArg(Fade), FloatArg(Max(0.1, Half - Fade / 2))]);
    end
    else
    begin
      AudioIdx := 1;
      Filter := Zoom('0:v', 'v', True);
    end;
  end
  else
  begin
    Add(Args, ['-f', 'lavfi', '-t', FloatArg(Sec), '-i',
      Format('color=c=0x283848:s=%dx%d:r=%d', [Width, Height, Fps])]);
    AudioIdx := 1;
    Filter := '[0:v]format=yuv420p[v]';
  end;
  if (AudioWav <> '') and FileExists(AudioWav) then
    Add(Args, ['-i', AudioWav])
  else
    Add(Args, ['-f', 'lavfi', '-t', FloatArg(Sec), '-i', 'anullsrc=r=48000:cl=stereo']);
  Add(Args, ['-filter_complex', Filter, '-map', '[v]', '-map', IntToStr(AudioIdx) + ':a',
    '-t', FloatArg(Sec), '-r', IntToStr(Fps)]);
  AddSplit(Args, VideoArgs(False));
  AddSplit(Args, AudioArgs(False));
  Add(Args, ['-movflags', '+faststart', OutMp4]);
  ForceDirectories(ExtractFileDir(OutMp4));
  Result := RunFfmpeg(Args);
  if not Result then Err := 'ffmpeg (animática): ' + ErrTail(FLastLog);
end;

function TMmpMedia.MuxAudio(const Video, AudioWav: string; Sec: Double; const OutMp4: string;
  out Err: string): Boolean;
var Args: TStringArray;
begin
  Err := '';
  Args := nil;
  Add(Args, ['-stream_loop', '-1', '-i', Video]);
  if (AudioWav <> '') and FileExists(AudioWav) then Add(Args, ['-i', AudioWav])
  else Add(Args, ['-f', 'lavfi', '-t', FloatArg(Sec), '-i', 'anullsrc=r=48000:cl=stereo']);
  Add(Args, ['-filter_complex', Normalize('0:v', 'v'), '-map', '[v]', '-map', '1:a',
    '-t', FloatArg(Sec)]);
  AddSplit(Args, VideoArgs(False));
  AddSplit(Args, AudioArgs(False));
  Add(Args, ['-movflags', '+faststart', OutMp4]);
  Result := RunFfmpeg(Args);
  if not Result then Err := 'ffmpeg (vídeo + áudio): ' + ErrTail(FLastLog);
end;

function TMmpMedia.Concat(const Files: array of string; const OutFile: string; out Err: string): Boolean;
var
  Args: TStringArray;
  Filter, Pairs: string;
  I: Integer;
begin
  Err := '';
  Args := nil;
  if Length(Files) = 0 then begin Err := 'Nenhum vídeo para juntar.'; Exit(False); end;
  for I := 0 to High(Files) do Add(Args, ['-i', Files[I]]);
  Filter := ''; Pairs := '';
  for I := 0 to High(Files) do
  begin
    Filter := Filter + Normalize(Format('%d:v', [I]), Format('v%d', [I])) + ';';
    if HasAudio(Files[I]) then
      Filter := Filter + AudioNormalize(Format('%d:a', [I]), Format('a%d', [I])) + ';'
    else
      Filter := Filter + Format('anullsrc=r=48000:cl=stereo,atrim=duration=%s[a%d];',
        [FloatArg(Duration(Files[I])), I]);
    Pairs := Pairs + Format('[v%d][a%d]', [I, I]);
  end;
  Filter := Filter + Pairs + Format('concat=n=%d:v=1:a=1[v][a]', [Length(Files)]);
  Add(Args, ['-filter_complex', Filter, '-map', '[v]', '-map', '[a]']);
  AddSplit(Args, VideoArgs(False));
  AddSplit(Args, AudioArgs(False));
  Add(Args, ['-movflags', '+faststart', OutFile]);
  ForceDirectories(ExtractFileDir(OutFile));
  Result := RunFfmpeg(Args);
  if not Result then Err := 'ffmpeg (costura): ' + ErrTail(FLastLog);
end;

function TMmpMedia.RenderTimeline(const Clips: array of TMmpClip; const OutFile: string;
  out Err: string): Boolean;
var
  Args: TStringArray;
  Filter, Cur, CurA, Kind, NextV, NextA: string;
  I: Integer;
  Lens: array of Double;
  InS, OutS, Full, CurDur, T, LastT: Double;
  Lossless: Boolean;
begin
  Err := '';
  Args := nil;
  if Length(Clips) = 0 then begin Err := 'A linha do tempo está vazia.'; Exit(False); end;
  Lossless := SameText(ExtractFileExt(OutFile), '.mkv');
  SetLength(Lens, Length(Clips));
  Filter := '';
  for I := 0 to High(Clips) do
  begin
    if not FileExists(Clips[I].FileName) then
    begin
      Err := 'Vídeo da cena não encontrado: ' + Clips[I].FileName;
      Exit(False);
    end;
    Add(Args, ['-i', Clips[I].FileName]);
    Full := Duration(Clips[I].FileName);
    InS := EnsureRange(Clips[I].InSec, 0, Max(0, Full - 0.1));
    OutS := Clips[I].OutSec;
    if (OutS <= InS) or (OutS > Full) then OutS := Full;
    Lens[I] := Max(0.1, OutS - InS);
    Filter := Filter + Format('[%d:v]trim=start=%s:end=%s,setpts=PTS-STARTPTS[t%d];',
      [I, FloatArg(InS), FloatArg(OutS), I]) + Normalize(Format('t%d', [I]), Format('v%d', [I])) + ';';
    if HasAudio(Clips[I].FileName) then
      Filter := Filter + Format('[%d:a]atrim=start=%s:end=%s,asetpts=PTS-STARTPTS[s%d];',
        [I, FloatArg(InS), FloatArg(OutS), I]) + AudioNormalize(Format('s%d', [I]), Format('a%d', [I])) + ';'
    else
      Filter := Filter + Format('anullsrc=r=48000:cl=stereo,atrim=duration=%s[a%d];',
        [FloatArg(Lens[I]), I]);
  end;
  Cur := 'v0'; CurA := 'a0'; CurDur := Lens[0];
  for I := 1 to High(Clips) do
  begin
    Kind := MmpTransitionKind(Clips[I - 1].Transition);
    T := Min(Clips[I - 1].TransitionSec, Min(Lens[I - 1], Lens[I]) / 2);
    NextV := Format('x%d', [I]); NextA := Format('y%d', [I]);
    if (Kind = '') or (T < 0.05) then
    begin
      Filter := Filter + Format('[%s][%s][v%d][a%d]concat=n=2:v=1:a=1[c%d][%s];[c%d]settb=1/%d[%s];',
        [Cur, CurA, I, I, I, NextA, I, Fps, NextV]);
      CurDur := CurDur + Lens[I];
    end
    else
    begin
      Filter := Filter + Format('[%s][v%d]xfade=transition=%s:duration=%s:offset=%s[%s];',
        [Cur, I, Kind, FloatArg(T), FloatArg(CurDur - T), NextV]) +
        Format('[%s][a%d]acrossfade=d=%s[%s];', [CurA, I, FloatArg(T), NextA]);
      CurDur := CurDur + Lens[I] - T;
    end;
    Cur := NextV; CurA := NextA;
  end;
  { transição de saída do último clipe: fade no fim do filme }
  Kind := MmpTransitionKind(Clips[High(Clips)].Transition);
  LastT := Min(Clips[High(Clips)].TransitionSec, CurDur / 2);
  if (Kind <> '') and (LastT >= 0.05) then
    Filter := Filter + Format('[%s]fade=t=out:st=%s:d=%s[vf];[%s]afade=t=out:st=%s:d=%s[af]',
      [Cur, FloatArg(CurDur - LastT), FloatArg(LastT), CurA, FloatArg(CurDur - LastT), FloatArg(LastT)])
  else
    Filter := Filter + Format('[%s]null[vf];[%s]anull[af]', [Cur, CurA]);
  Add(Args, ['-filter_complex', Filter, '-map', '[vf]', '-map', '[af]']);
  AddSplit(Args, VideoArgs(Lossless));
  AddSplit(Args, AudioArgs(Lossless));
  if not Lossless then Add(Args, ['-movflags', '+faststart']);
  Add(Args, [OutFile]);
  ForceDirectories(ExtractFileDir(OutFile));
  Result := RunFfmpeg(Args);
  if not Result then Err := 'ffmpeg (filme): ' + ErrTail(FLastLog);
end;

function TMmpMedia.ExtractFrame(const Video: string; AtSec: Double; const OutImage: string): Boolean;
begin
  Result := RunFfmpeg(['-ss', FloatArg(Max(0, AtSec)), '-i', Video, '-frames:v', '1', OutImage]) and
    FileExists(OutImage);
end;

end.
