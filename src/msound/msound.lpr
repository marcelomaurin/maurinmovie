program msound;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umsoundmain;

{$R msound_icon.res}

var
  Args: TMMLaunchArgs;
begin
  if HandleStandardCliEarlyExit(maMSound) then
    Exit;

  if not RequireMMenuLaunch(maMSound, Args) then
    Halt(EXIT_INVALID_ARGS);

  if not RequireSingleAppInstance(maMSound, Args.Headless) then
    Halt(EXIT_LOCKED);

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsoundMainForm, msoundMainForm);
  Application.Run;
end.
