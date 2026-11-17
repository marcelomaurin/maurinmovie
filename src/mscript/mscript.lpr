program mscript;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, SysUtils, mmpcommon, ummpappbase, umscriptmain;

{$R mscript_icon.res}

var
  Args: TMMLaunchArgs;
  ExitCode: Integer;
begin
  if HandleStandardCliEarlyExit(maMScript) then
    Exit;

  if not RequireMMenuLaunch(maMScript, Args) then
    Halt(EXIT_INVALID_ARGS);

  if not RequireSingleAppInstance(maMScript, Args.Headless) then
    Halt(EXIT_LOCKED);

  if Args.Headless then
  begin
    ExitCode := RunMScriptHeadlessEvent(Args);
    Halt(ExitCode);
  end;

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMscriptMainForm, mscriptMainForm);
  Application.Run;
end.
