program mscene;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umscenemain;

begin
  if HandleStandardCliEarlyExit(maMScene) then
    Exit;

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsceneMainForm, msceneMainForm);
  Application.Run;
end.
