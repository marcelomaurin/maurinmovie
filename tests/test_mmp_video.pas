program test_mmp_video;

{$mode objfpc}{$H+}

uses
  SysUtils, ummpvideo;

procedure Check(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, Msg);
    Halt(1);
  end;
end;

var
  Ffmpeg, Ffprobe, SourceOne, SourceTwo, OutDir, CutFile, MasterFile: string;
  Clips: array[0..1] of TMmpVideoClip;
  Duration: Double;
  HasAudio: Boolean;
  Err: string;
begin
  Check(ParamCount = 5, 'Uso: test_mmp_video ffmpeg ffprobe entrada-com-audio entrada-sem-audio pasta-vazia');
  Ffmpeg := ParamStr(1);
  Ffprobe := ParamStr(2);
  SourceOne := ExpandFileName(ParamStr(3));
  SourceTwo := ExpandFileName(ParamStr(4));
  OutDir := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(5)));
  CutFile := OutDir + 'filme com corte.mp4';
  MasterFile := OutDir + 'master com dissolve.mkv';
  Clips[0].FileName := SourceOne;
  Clips[0].InSec := 0.5;
  Clips[0].OutSec := 1.5;
  Clips[1].FileName := SourceTwo;
  Clips[1].OutSec := 1.5;

  Check(RenderMmpVideo(Ffmpeg, Ffprobe, CutFile, Clips, 160, 90, 25, Duration, Err), Err);
  Check(Abs(Duration - 2.5) < 0.12, 'Duração incorreta após corte e montagem.');
  Check(ProbeMmpVideo(Ffprobe, CutFile, Duration, HasAudio, Err), Err);
  Check(HasAudio, 'A exportação perdeu a faixa de áudio.');

  Clips[0].Transition := 'dissolve';
  Clips[0].TransitionSec := 0.4;
  Check(RenderMmpVideo(Ffmpeg, Ffprobe, MasterFile, Clips, 160, 90, 25, Duration, Err), Err);
  Check(Abs(Duration - 2.1) < 0.12, 'Duração incorreta após dissolve.');
  Check(not RenderMmpVideo(Ffmpeg, Ffprobe, MasterFile, Clips, 160, 90, 25, Duration, Err),
    'A montagem permitiu sobrescrever um vídeo existente.');
  Check(FileExists(MasterFile), 'A tentativa de sobrescrita removeu o vídeo original.');

  Clips[1].OutSec := 10;
  Check(not RenderMmpVideo(Ffmpeg, Ffprobe, OutDir + 'invalido.mp4',
    Clips, 160, 90, 25, Duration, Err), 'A montagem aceitou um corte fora da duração.');
  Check(not FileExists(OutDir + 'invalido.mp4'), 'Foi criado um vídeo com corte inválido.');
  WriteLn('OK: cortes, áudio, dissolve, MP4, MKV e falhas de montagem.');
end.
