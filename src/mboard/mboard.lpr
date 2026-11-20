program mboard;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umboardmain;

{$R mboard_icon.res}

var
  Args: TMMLaunchArgs;
begin
  if HandleStandardCliEarlyExit(maMBoard) then
    Exit;

  if not RequireMMenuLaunch(maMBoard, Args) then
    Halt(EXIT_INVALID_ARGS);

  if not RequireSingleAppInstance(maMBoard, Args.Headless) then
    Halt(EXIT_LOCKED);

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  { retomada de cascata sem mostrar a janela }
  if Args.Headless then
  begin
    ExitCode := RunMBoardHeadlessResume(Args);
    Halt(ExitCode);
  end;
  Application.CreateForm(TMboardMainForm, mboardMainForm);
  Application.Run;
end.
