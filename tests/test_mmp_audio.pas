program test_mmp_audio;

{$mode objfpc}{$H+}

uses
  SysUtils, ummpdialogue, ummpvideo;

procedure Check(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, Msg);
    Halt(1);
  end;
end;

var
  Lines: TMmpDialogueLines;
  Clips: array[0..1] of TMmpAudioClip;
  Slice: array[0..0] of TMmpAudioClip;
  Err, Dir, Mixed: string;
begin
  Check(ParamCount = 4, 'Uso: test_mmp_audio ffmpeg fala.wav efeito.wav pasta-vazia');
  Lines := ParseMmpDialogue('Ana: Ideia: partir.' + LineEnding +
    'Agora mesmo.' + LineEnding + 'Bruno: Vamos.');
  Check(Length(Lines) = 2, 'Número incorreto de falas.');
  Check((Lines[0].Speaker = 'Ana') and (Lines[0].Text = 'Ideia: partir. Agora mesmo.'),
    'Perdeu a atribuição, o segundo dois-pontos ou a continuação.');
  Check(MmpDialoguePortion(Lines, 1, 2) = 'Bruno: Vamos.', 'Divisão trocou a fala de segmento.');

  Dir := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(4)));
  Mixed := Dir + 'cena.wav';
  Clips[0].FileName := ExpandFileName(ParamStr(2));
  Clips[0].StartMs := 500;
  Clips[0].EndMs := 1300;
  Clips[0].VolumePercent := 100;
  Clips[1].FileName := ExpandFileName(ParamStr(3));
  Clips[1].StartMs := 800;
  Clips[1].EndMs := 1500;
  Clips[1].VolumePercent := 50;
  Check(RenderMmpAudio(ParamStr(1), Mixed, Clips, 2000, 16000, 2, Err), Err);
  Slice[0].FileName := Mixed;
  Slice[0].SourceStartMs := 1000;
  Slice[0].EndMs := 1000;
  Slice[0].VolumePercent := 100;
  Check(RenderMmpAudio(ParamStr(1), Dir + 'segmento.wav', Slice, 1000, 16000, 2, Err), Err);
  Check(RenderMmpAudio(ParamStr(1), Dir + 'silencio.wav', [], 2000, 16000, 1, Err), Err);
  Clips[1].EndMs := 2500;
  Check(not RenderMmpAudio(ParamStr(1), Dir + 'invalido.wav', Clips, 2000, 16000, 2, Err),
    'A mistura aceitou um evento fora da cena.');
  Check(not FileExists(Dir + 'invalido.wav'), 'A mistura deixou um WAV inválido.');
end.
