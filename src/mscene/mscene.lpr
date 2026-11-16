program mscene;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umscenemain;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsceneMainForm, msceneMainForm);
  Application.Run;
end.
