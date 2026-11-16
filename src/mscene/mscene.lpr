program mscene;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umscenemain;

{$R mscene_icon.res}

var
  Args: TMMLaunchArgs;
begin
  if HandleStandardCliEarlyExit(maMScene) then
    Exit;

  if not RequireMMenuLaunch(maMScene, Args) then
    Halt(EXIT_INVALID_ARGS);

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsceneMainForm, msceneMainForm);
  Application.Run;
end.
