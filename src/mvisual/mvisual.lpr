program mvisual;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umvisualmain;

{$R mvisual_icon.res}

var
  Args: TMMLaunchArgs;
begin
  if HandleStandardCliEarlyExit(maMVisual) then
    Exit;

  if not RequireMMenuLaunch(maMVisual, Args) then
    Halt(EXIT_INVALID_ARGS);

  if not RequireSingleAppInstance(maMVisual, Args.Headless) then
    Halt(EXIT_LOCKED);

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  { cascata: aplica o evento sem mostrar a janela e encerra }
  if Args.Headless then
  begin
    ExitCode := RunMVisualHeadlessEvent(Args);
    Halt(ExitCode);
  end;
  Application.CreateForm(TMvisualMainForm, mvisualMainForm);
  Application.Run;
end.
