unit ummpdialogue;

{$mode objfpc}{$H+}

interface

type
  TMmpDialogueLine = record
    Speaker, Text: string;
  end;
  TMmpDialogueLines = array of TMmpDialogueLine;

function ParseMmpDialogue(const Dialogue: string): TMmpDialogueLines;
function MmpDialoguePortion(const Lines: TMmpDialogueLines; Index, Count: Integer): string;

implementation

uses
  Classes, SysUtils;

function ParseMmpDialogue(const Dialogue: string): TMmpDialogueLines;
var
  Items: TStringList;
  I, P, N: Integer;
  LineText, Speaker, Speech: string;
begin
  Result := nil;
  Items := TStringList.Create;
  try
    Items.Text := Dialogue;
    for I := 0 to Items.Count - 1 do
    begin
      LineText := Trim(Items[I]);
      if LineText = '' then Continue;
      P := Pos(':', LineText);
      Speaker := '';
      Speech := LineText;
      if P > 1 then
      begin
        Speaker := Trim(Copy(LineText, 1, P - 1));
        Speech := Trim(Copy(LineText, P + 1, MaxInt));
        if Speech = '' then Continue;
      end;
      N := Length(Result);
      if (Speaker = '') and (N > 0) then
        Result[N - 1].Text := Result[N - 1].Text + ' ' + Speech
      else
      begin
        SetLength(Result, N + 1);
        Result[N].Speaker := Speaker;
        Result[N].Text := Speech;
      end;
    end;
  finally
    Items.Free;
  end;
end;

function MmpDialoguePortion(const Lines: TMmpDialogueLines; Index, Count: Integer): string;
var
  I, First, Last: Integer;
begin
  Result := '';
  if (Count <= 0) or (Index < 0) or (Index >= Count) then Exit;
  // Distribui falas inteiras, preservando a ordem e o personagem.
  First := (Length(Lines) * Index + Count - 1) div Count;
  Last := (Length(Lines) * (Index + 1) + Count - 1) div Count;
  for I := First to Last - 1 do
  begin
    if Result <> '' then Result := Result + LineEnding;
    if Lines[I].Speaker <> '' then Result := Result + Lines[I].Speaker + ': ';
    Result := Result + Lines[I].Text;
  end;
end;

end.
