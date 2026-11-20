program test_mmp_media;

{ Testa ummpmedia com o ffmpeg do sistema: áudio de segmento, animática,
  costura de cena e gravação do filme com transições. Sem ffmpeg, o teste
  é pulado (código de saída 0). }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, ummpmedia;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  M: TMmpMedia;
  Dir, Err, ImgA, ImgB, Voice1, Voice2, Amb, Wav, SegA, SegB, Scene, Film, Mkv, Thumb: string;
  Total, D: Double;
  Clips: array of TMmpClip;

procedure Check(Cond: Boolean; const Name: string);
begin
  if Cond then begin Inc(PassCount); WriteLn('[PASS] ', Name); end
  else begin Inc(FailCount); WriteLn('[FAIL] ', Name); end;
end;

procedure Near(Got, Expected, Tol: Double; const Name: string);
begin
  Check(Abs(Got - Expected) <= Tol, Format('%s (obtido %.2f, esperado %.2f)', [Name, Got, Expected]));
end;

function MakeClip(const F: string; InS, OutS: Double; const Tr: string; TrSec: Double): TMmpClip;
begin
  Result.FileName := F;
  Result.InSec := InS;
  Result.OutSec := OutS;
  Result.Transition := Tr;
  Result.TransitionSec := TrSec;
end;

begin
  M := TMmpMedia.Create('', '');
  try
    if not M.Available or (M.Ffprobe = '') then
    begin
      WriteLn('[SKIP] ffmpeg/ffprobe não encontrados no PATH');
      Halt(0);
    end;
    M.Width := 320; M.Height := 180; M.Fps := 25;
    Dir := IncludeTrailingPathDelimiter(GetTempDir) + 'mmp_media_test' + PathDelim;
    ForceDirectories(Dir);

    { insumos sintéticos }
    ImgA := Dir + 'a.png'; ImgB := Dir + 'b.png';
    Voice1 := Dir + 'v1.wav'; Voice2 := Dir + 'v2.wav'; Amb := Dir + 'amb.wav';
    Check(M.RunFfmpeg(['-f', 'lavfi', '-i', 'testsrc2=s=640x360', '-frames:v', '1', ImgA]), 'imagem A');
    Check(M.RunFfmpeg(['-f', 'lavfi', '-i', 'color=c=orange:s=640x480', '-frames:v', '1', ImgB]), 'imagem B');
    Check(M.RunFfmpeg(['-f', 'lavfi', '-i', 'sine=f=440:d=1.5', Voice1]), 'fala 1');
    Check(M.RunFfmpeg(['-f', 'lavfi', '-i', 'sine=f=660:d=1.0', Voice2]), 'fala 2');
    Check(M.RunFfmpeg(['-f', 'lavfi', '-i', 'anoisesrc=d=0.7:a=0.1', Amb]), 'ambiência');

    { áudio do segmento: 0,4 + 1,5 + 0,35 + 1,0 + 0,35 + 0,4 = 4,0 s }
    Wav := Dir + 'seg.wav';
    Check(M.MakeSegmentAudio([Voice1, Voice2], Amb, 3, Wav, Total, Err), 'áudio do segmento ' + Err);
    Near(Total, 4.0, 0.15, 'duração calculada do áudio');
    Near(M.Duration(Wav), Total, 0.1, 'duração do WAV');
    Check(M.MakeSegmentAudio([], '', 6, Dir + 'mudo.wav', Total, Err), 'áudio sem falas');
    Near(Total, 6, 0.01, 'segmento mudo respeita a duração mínima');

    { animáticas }
    SegA := Dir + 'segA.mp4'; SegB := Dir + 'segB.mp4';
    Check(M.RenderAnimatic(ImgA, ImgB, Wav, 4, SegA, Err), 'animática com dois quadros ' + Err);
    Near(M.Duration(SegA), 4, 0.15, 'duração da animática A');
    Check(M.HasAudio(SegA), 'animática tem áudio');
    Check(M.RenderAnimatic(ImgB, '', '', 3, SegB, Err), 'animática com um quadro e sem áudio ' + Err);
    Near(M.Duration(SegB), 3, 0.15, 'duração da animática B');
    Check(M.RenderAnimatic('', '', '', 2, Dir + 'segC.mp4', Err), 'animática sem quadros ' + Err);

    { costura da cena }
    Scene := Dir + 'cena.mp4';
    Check(M.Concat([SegA, SegB], Scene, Err), 'costura da cena ' + Err);
    Near(M.Duration(Scene), 7, 0.2, 'duração da cena');

    { filme: cena (corte) + segA com fusão de 1 s + segB com fade final de 0,5 s }
    SetLength(Clips, 3);
    Clips[0] := MakeClip(Scene, 1, 6, 'cut', 0);              // 5 s
    Clips[1] := MakeClip(SegA, 0, 0, 'dissolve', 1);          // 4 s, fusão com o próximo
    Clips[2] := MakeClip(SegB, 0, 0, 'fade_out', 0.5);        // 3 s, fade no fim
    Film := Dir + 'filme.mp4';
    Check(M.RenderTimeline(Clips, Film, Err), 'filme MP4 ' + Err);
    D := M.Duration(Film);
    Near(D, 5 + 4 + 3 - 1, 0.25, 'duração do filme');
    Check(M.HasAudio(Film), 'filme tem áudio');

    M.Width := 160; M.Height := 90;
    Mkv := Dir + 'filme.mkv';
    Check(M.RenderTimeline(Clips, Mkv, Err), 'filme MKV sem perdas ' + Err);
    Check(Pos('ffv1', M.LastLog) > 0, 'MKV usa ffv1');

    Thumb := Dir + 'quadro.png';
    Check(M.ExtractFrame(Film, 2, Thumb), 'quadro de prévia');

    Check(MmpTransitionKind('cut') = '', 'corte');
    Check(MmpTransitionKind('dissolve') = 'fade', 'fusão');
    Check(MmpTransitionKind('fade_out') = 'fadeblack', 'fade para preto');
  finally
    M.Free;
  end;
  WriteLn(Format('%d passaram, %d falharam', [PassCount, FailCount]));
  if FailCount > 0 then Halt(1);
end.
