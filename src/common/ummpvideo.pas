unit ummpvideo;

{$mode objfpc}{$H+}

interface

type
  TMmpVideoClip = record
    FileName: string;
    InSec, OutSec: Double; // OutSec = 0 usa a duração do arquivo.
    Transition: string;    // Transição de saída do clipe.
    TransitionSec: Double;
  end;

type
  TMmpAudioClip = record
    FileName: string;
    SourceStartMs, StartMs, EndMs, VolumePercent: Integer;
  end;

function RenderMmpAudio(const Ffmpeg, OutputFile: string;
  const Clips: array of TMmpAudioClip; DurationMs, SampleRate, Channels: Integer;
  out ErrorMsg: string): Boolean;

function ProbeMmpVideo(const Ffprobe, FileName: string; out Duration: Double;
  out HasAudio: Boolean; out ErrorMsg: string): Boolean;
function RenderMmpVideo(const Ffmpeg, Ffprobe, OutputFile: string;
  const Clips: array of TMmpVideoClip; Width, Height, Fps: Integer;
  out Duration: Double; out ErrorMsg: string): Boolean;

implementation

uses
  Classes, SysUtils, Process, fpjson, jsonparser;

function RunMediaTool(const Exe: string; const Args: array of string;
  out Output, ErrorMsg: string): Boolean;
begin
  Output := '';
  ErrorMsg := '';
  if Exe = '' then
  begin
    ErrorMsg := 'Configure FFmpeg e FFprobe no MMenu.';
    Exit(False);
  end;
  try
    Result := RunCommand(Exe, Args, Output, [poStderrToOutput, poNoConsole]);
    if not Result then ErrorMsg := ExtractFileName(Exe) + ': ' + Trim(Output);
  except
    on E: Exception do
    begin
      ErrorMsg := E.Message;
      Result := False;
    end;
  end;
end;

function MediaFormat: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function MediaNumber(Value: Double): string;
begin
  Result := FloatToStr(Value, MediaFormat);
end;

function RenderMmpAudio(const Ffmpeg, OutputFile: string;
  const Clips: array of TMmpAudioClip; DurationMs, SampleRate, Channels: Integer;
  out ErrorMsg: string): Boolean;
var
  Args: TStringList;
  Params: array of string;
  Layout, Graph, Links, N, TempFile, Output: string;
  I: Integer;
begin
  Result := False;
  ErrorMsg := '';
  if (DurationMs <= 0) or (SampleRate < 8000) or (SampleRate > 192000) or
    not (Channels in [1, 2]) or FileExists(OutputFile) then
  begin
    ErrorMsg := 'Configuração ou destino do WAV inválido.';
    Exit;
  end;
  if not ForceDirectories(ExtractFileDir(ExpandFileName(OutputFile))) then
  begin
    ErrorMsg := 'Não foi possível criar a pasta do WAV.';
    Exit;
  end;
  if Channels = 2 then Layout := 'stereo' else Layout := 'mono';
  TempFile := ChangeFileExt(OutputFile, '.partial.wav');
  Args := TStringList.Create;
  try
    Args.AddStrings(['-hide_banner', '-nostdin', '-v', 'error', '-y', '-f', 'lavfi',
      '-i', 'anullsrc=r=' + IntToStr(SampleRate) + ':cl=' + Layout]);
    Graph := '[0:a]atrim=end_sample=' + IntToStr(Int64(DurationMs) * SampleRate div 1000) + '[bed];';
    Links := '[bed]';
    for I := 0 to High(Clips) do
      with Clips[I] do
      begin
        if not FileExists(FileName) or (SourceStartMs < 0) or (StartMs < 0) or
          (EndMs <= StartMs) or (EndMs > DurationMs) or
          (VolumePercent < 0) or (VolumePercent > 200) then
        begin
          ErrorMsg := Format('Evento de áudio inválido (%d).', [I + 1]);
          Exit;
        end;
        N := IntToStr(I + 1);
        Args.AddStrings(['-ss', MediaNumber(SourceStartMs / 1000), '-i', FileName]);
        Graph := Graph + '[' + N + ':a:0]aresample=' + IntToStr(SampleRate) +
          ',aformat=sample_fmts=fltp:channel_layouts=' + Layout +
          ',atrim=duration=' + MediaNumber((EndMs - StartMs) / 1000) +
          ',asetpts=PTS-STARTPTS,volume=' + MediaNumber(VolumePercent / 100) +
          ',adelay=' + IntToStr(StartMs) + ':all=1[e' + N + '];';
        Links := Links + '[e' + N + ']';
      end;
    Graph := Graph + Links + 'amix=inputs=' + IntToStr(Length(Clips) + 1) +
      ':duration=first:normalize=0[out]';
    Args.AddStrings(['-filter_complex', Graph, '-map', '[out]', '-c:a', 'pcm_s16le', TempFile]);
    SetLength(Params, Args.Count);
    for I := 0 to Args.Count - 1 do Params[I] := Args[I];
    if not RunMediaTool(Ffmpeg, Params, Output, ErrorMsg) then Exit;
    Result := RenameFile(TempFile, OutputFile);
    if not Result then ErrorMsg := 'Não foi possível gravar ' + OutputFile;
  finally
    Args.Free;
    if FileExists(TempFile) then DeleteFile(TempFile);
  end;
end;

function ProbeMmpVideo(const Ffprobe, FileName: string; out Duration: Double;
  out HasAudio: Boolean; out ErrorMsg: string): Boolean;
var
  Output, Kind: string;
  Data: TJSONData;
  Streams: TJSONArray;
  I: Integer;
  HasVideo: Boolean;
begin
  Result := False;
  Duration := 0;
  HasAudio := False;
  if not FileExists(FileName) then
  begin
    ErrorMsg := 'Vídeo ausente: ' + FileName;
    Exit;
  end;
  if not RunMediaTool(Ffprobe, ['-v', 'error', '-show_entries',
    'format=duration:stream=codec_type', '-of', 'json', FileName], Output, ErrorMsg) then Exit;
  Data := nil;
  try
    try
      Data := GetJSON(Output);
      HasVideo := False;
      Streams := TJSONArray(Data.FindPath('streams'));
      if Streams <> nil then
        for I := 0 to Streams.Count - 1 do
        begin
          Kind := Streams.Objects[I].Get('codec_type', '');
          HasAudio := HasAudio or (Kind = 'audio');
          HasVideo := HasVideo or (Kind = 'video');
        end;
      if Data.FindPath('format.duration') <> nil then
        TryStrToFloat(Data.FindPath('format.duration').AsString, Duration,
          MediaFormat);
      Result := HasVideo and (Duration > 0);
    except
      on E: Exception do ErrorMsg := E.Message;
    end;
  finally
    Data.Free;
  end;
  if not Result then
    ErrorMsg := 'Vídeo inválido ou sem duração: ' + FileName + ' ' + ErrorMsg;
end;

function RenderMmpVideo(const Ffmpeg, Ffprobe, OutputFile: string;
  const Clips: array of TMmpVideoClip; Width, Height, Fps: Integer;
  out Duration: Double; out ErrorMsg: string): Boolean;
var
  Args: TStringList;
  Params: array of string;
  Lengths: array of Double;
  I: Integer;
  EndSec, SourceDuration, Total, Fade: Double;
  HasAudio: Boolean;
  Graph, N, Previous, ClipDuration, Output, TempFile, Ext: string;
begin
  Result := False;
  Duration := 0;
  ErrorMsg := '';
  if (Length(Clips) = 0) or (Width < 2) or (Height < 2) or
    Odd(Width) or Odd(Height) or (Fps < 1) then
  begin
    ErrorMsg := 'A montagem precisa de vídeos, dimensões pares e FPS válido.';
    Exit;
  end;
  Ext := LowerCase(ExtractFileExt(OutputFile));
  if (Ext <> '.mp4') and (Ext <> '.mkv') then
  begin
    ErrorMsg := 'Formato de exportação inválido: ' + Ext;
    Exit;
  end;
  if FileExists(OutputFile) then
  begin
    ErrorMsg := 'O vídeo de destino já existe: ' + OutputFile;
    Exit;
  end;
  if not ForceDirectories(ExtractFileDir(ExpandFileName(OutputFile))) then
  begin
    ErrorMsg := 'Não foi possível criar a pasta de destino do vídeo.';
    Exit;
  end;
  TempFile := ChangeFileExt(OutputFile, '.partial' + Ext);
  Args := TStringList.Create;
  try
    Args.AddStrings(['-nostdin', '-hide_banner', '-loglevel', 'error',
      '-filter_complex_threads', '1', '-y']);
    SetLength(Lengths, Length(Clips));
    Graph := '';
    for I := 0 to High(Clips) do
    begin
      if not ProbeMmpVideo(Ffprobe, Clips[I].FileName, SourceDuration,
        HasAudio, ErrorMsg) then Exit;
      EndSec := Clips[I].OutSec;
      if EndSec = 0 then EndSec := SourceDuration;
      if (Clips[I].InSec < 0) or (EndSec > SourceDuration + 0.05) or
        (EndSec <= Clips[I].InSec) then
      begin
        ErrorMsg := Format('Corte fora da duração do clipe %d.', [I + 1]);
        Exit;
      end;
      if EndSec > SourceDuration then EndSec := SourceDuration;
      Lengths[I] := EndSec - Clips[I].InSec;
      N := IntToStr(I);
      ClipDuration := MediaNumber(Lengths[I]);
      Args.AddStrings(['-ss', MediaNumber(Clips[I].InSec), '-i', Clips[I].FileName]);
      Graph := Graph + '[' + N + ':v:0]trim=duration=' + ClipDuration +
        ',setpts=PTS-STARTPTS,fps=' + IntToStr(Fps) + ',scale=' + IntToStr(Width) +
        ':' + IntToStr(Height) + ':force_original_aspect_ratio=decrease:force_divisible_by=2,pad=' +
        IntToStr(Width) + ':' + IntToStr(Height) +
        ':(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p,settb=AVTB';
      if (I < High(Clips)) and (Clips[I].Transition = 'fade_out') then
      begin
        Fade := Clips[I].TransitionSec;
        if (Fade <= 0) or (Fade > Lengths[I]) then
        begin
          ErrorMsg := Format('Fade inválido no clipe %d.', [I + 1]);
          Exit;
        end;
        Graph := Graph + ',fade=t=out:st=' + MediaNumber(Lengths[I] - Fade) +
          ':d=' + MediaNumber(Fade);
      end;
      Graph := Graph + '[v' + N + '];';
      if HasAudio then
        Graph := Graph + '[' + N + ':a:0]aresample=48000,' +
          'aformat=sample_fmts=fltp:channel_layouts=stereo,apad'
      else
        Graph := Graph + 'anullsrc=r=48000:cl=stereo';
      Graph := Graph + ',atrim=duration=' + ClipDuration +
        ',asetpts=PTS-STARTPTS[a' + N + '];';
    end;

    Total := Lengths[0];
    Previous := '0';
    for I := 1 to High(Clips) do
    begin
      N := IntToStr(I);
      if Clips[I - 1].Transition = 'dissolve' then
      begin
        Fade := Clips[I - 1].TransitionSec;
        if (Fade <= 0) or (Fade >= Lengths[I - 1]) or (Fade >= Lengths[I]) then
        begin
          ErrorMsg := Format('Dissolve inválido entre os clipes %d e %d.', [I, I + 1]);
          Exit;
        end;
        Graph := Graph + '[v' + Previous + '][v' + N +
          ']xfade=transition=fade:duration=' + MediaNumber(Fade) +
          ':offset=' + MediaNumber(Total - Fade) + ',format=yuv420p,settb=AVTB[vx' + N + '];' +
          '[a' + Previous + '][a' + N + ']acrossfade=d=' + MediaNumber(Fade) + '[ax' + N + '];';
        Total := Total + Lengths[I] - Fade;
      end
      else
      begin
        if (Clips[I - 1].Transition <> '') and (Clips[I - 1].Transition <> 'cut') and
          (Clips[I - 1].Transition <> 'fade_out') then
        begin
          ErrorMsg := 'Transição não reconhecida: ' + Clips[I - 1].Transition;
          Exit;
        end;
        Graph := Graph + '[v' + Previous + '][a' + Previous + '][v' + N + '][a' + N +
          ']concat=n=2:v=1:a=1[cv' + N + '][ax' + N + '];' +
          '[cv' + N + ']fps=' + IntToStr(Fps) + ',settb=AVTB[vx' + N + '];';
        Total := Total + Lengths[I];
      end;
      Previous := 'x' + N;
    end;
    Delete(Graph, Length(Graph), 1);
    Args.AddStrings(['-filter_complex', Graph, '-map', '[v' + Previous + ']',
      '-map', '[a' + Previous + ']', '-t', MediaNumber(Total)]);
    if Ext = '.mkv' then
      Args.AddStrings(['-c:v', 'ffv1', '-c:a', 'flac'])
    else
      Args.AddStrings(['-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-movflags', '+faststart']);
    Args.Add(TempFile);
    SetLength(Params, Args.Count);
    for I := 0 to Args.Count - 1 do Params[I] := Args[I];

    if not RunMediaTool(Ffmpeg, Params, Output, ErrorMsg) then Exit;
    if not ProbeMmpVideo(Ffprobe, TempFile, Duration, HasAudio, ErrorMsg) then Exit;
    if not RenameFile(TempFile, OutputFile) then
    begin
      ErrorMsg := 'Não foi possível concluir a gravação de ' + OutputFile;
      Exit;
    end;
    Result := True;
  finally
    Args.Free;
    if FileExists(TempFile) then DeleteFile(TempFile);
  end;
end;

end.
