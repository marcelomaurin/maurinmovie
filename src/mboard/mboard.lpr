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

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMboardMainForm, mboardMainForm);
  Application.Run;
end.
