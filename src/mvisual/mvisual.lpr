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

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMvisualMainForm, mvisualMainForm);
  Application.Run;
end.
