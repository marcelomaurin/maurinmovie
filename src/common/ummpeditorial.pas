unit ummpeditorial;

{$mode objfpc}{$H+}

interface

uses
  fpjson;

function ApplyEditorialOperations(const Script: TJSONObject; const Operations: TJSONArray;
  out ErrorMsg: string): Boolean;
function EditorialScriptMarkdown(const Script: TJSONObject): string;

implementation

uses
  Classes, SysUtils, mmpcommon;

function ApplyEditorialOperations(const Script: TJSONObject; const Operations: TJSONArray;
  out ErrorMsg: string): Boolean;
var
  Scenes: TJSONArray;
  Op, Scene: TJSONObject;
  I, J, Match: Integer;
  SceneId, FieldName, Original, Replaced, NewValue: string;
  Targets: array of TJSONObject;
  Fields, Values: array of string;
begin
  Result := False;
  ErrorMsg := 'O evento não contém operações de roteiro.';
  if (Operations = nil) or (Operations.Count = 0) or not (Script.Find('scenes') is TJSONArray) then Exit;
  Scenes := TJSONArray(Script.Find('scenes'));
  SetLength(Targets, Operations.Count);
  SetLength(Fields, Operations.Count);
  SetLength(Values, Operations.Count);
  for I := 0 to Operations.Count - 1 do
  begin
    if not (Operations.Items[I] is TJSONObject) then Exit;
    Op := Operations.Objects[I];
    SceneId := Op.Get('scene_id', '');
    FieldName := Op.Get('field', 'action');
    ErrorMsg := 'Operação editorial inválida: ' + SceneId + ' / ' + FieldName;
    if (SceneId = '') or ((FieldName <> 'action') and (FieldName <> 'dialogue_text') and
      (FieldName <> 'objects_csv') and (FieldName <> 'characters_csv') and
      (FieldName <> 'location_ref') and (FieldName <> 'costumes_csv')) or
      (Op.Find('from') = nil) or (Op.Find('to') = nil) then Exit;
    Match := -1;
    for J := 0 to Scenes.Count - 1 do
      if Scenes.Objects[J].Get('scene_id', '') = SceneId then
      begin
        if Match >= 0 then Exit;
        Match := J;
      end;
    if Match < 0 then Exit;
    Scene := Scenes.Objects[Match];
    Original := Scene.Get(FieldName, '');
    // Duas operações para o mesmo campo do mesmo item devem ser enviadas juntas como um único ajuste.
    for J := 0 to I - 1 do
      if (Targets[J] = Scene) and (Fields[J] = FieldName) then Exit;
    Replaced := Op.Get('from', '');
    NewValue := Op.Get('to', '');
    ErrorMsg := 'O valor original mudou ou o ajuste é ambíguo na cena ' + SceneId + '.';
    if Op.Get('operation', 'replace') = 'set' then
    begin
      if Original <> Replaced then Exit;
    end
    else if Op.Get('operation', 'replace') = 'replace' then
    begin
      if (Replaced = '') or (Pos(Replaced, Original) = 0) then Exit;
      NewValue := StringReplace(Original, Replaced, NewValue, [rfReplaceAll]);
    end
    else Exit;
    if Original = NewValue then Exit;
    Targets[I] := Scene;
    Fields[I] := FieldName;
    Values[I] := NewValue;
  end;
  for I := 0 to High(Targets) do
    Targets[I].Strings[Fields[I]] := Values[I];
  ErrorMsg := '';
  Result := True;
end;

function EditorialScriptMarkdown(const Script: TJSONObject): string;
var
  Lines: TStringList;
  Scenes: TJSONArray;
  Scene: TJSONObject;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('# ' + Script.Get('title', 'Roteiro'));
    Lines.Add('Genero: ' + Script.Get('genre', '') + ' | Duracao-alvo: ' +
      MmpFormatDurationHms(Script.Get('target_duration_sec', 600)));
    Lines.Add('');
    Lines.Add('## Sinopse');
    Lines.Add(Script.Get('synopsis', ''));
    Lines.Add('');
    if Script.Find('scenes') is TJSONArray then
    begin
      Scenes := TJSONArray(Script.Find('scenes'));
      for I := 0 to Scenes.Count - 1 do
      begin
        Scene := Scenes.Objects[I];
        Lines.Add(Format('## Cena %d (%s) - %s',
          [Scene.Get('sequence', I + 1), Scene.Get('scene_id', ''), Scene.Get('heading', '')]));
        Lines.Add('Local: ' + Scene.Get('location_ref', '') + ' | Periodo: ' +
          Scene.Get('time_of_day', '') + ' | Clima: ' + Scene.Get('mood', '') +
          ' | Duracao: ' + IntToStr(Scene.Get('estimated_duration', 0)) + 's');
        Lines.Add('Personagens: ' + Scene.Get('characters_csv', ''));
        Lines.Add('');
        Lines.Add(Scene.Get('action', ''));
        Lines.Add('');
        Lines.Add(Scene.Get('dialogue_text', ''));
        Lines.Add('');
      end;
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
