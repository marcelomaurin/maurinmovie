program mscript;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, SysUtils, mmpcommon, ummpappbase, umscriptmain;

var
  Args: TMMLaunchArgs;
  ExitCode: Integer;
begin
  if HandleStandardCliEarlyExit(maMScript) then
    Exit;

  Args := ParseLaunchArgs;
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
