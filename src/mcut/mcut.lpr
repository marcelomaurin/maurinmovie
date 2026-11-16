program mcut;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umcutmain;

begin
  if HandleStandardCliEarlyExit(maMCut) then
    Exit;

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMcutMainForm, mcutMainForm);
  Application.Run;
end.
