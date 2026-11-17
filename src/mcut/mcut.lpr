program mcut;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umcutmain;

{$R mcut_icon.res}

var
  Args: TMMLaunchArgs;
begin
  if HandleStandardCliEarlyExit(maMCut) then
    Exit;

  if not RequireMMenuLaunch(maMCut, Args) then
    Halt(EXIT_INVALID_ARGS);

  if not RequireSingleAppInstance(maMCut, Args.Headless) then
    Halt(EXIT_LOCKED);

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMcutMainForm, mcutMainForm);
  Application.Run;
end.
