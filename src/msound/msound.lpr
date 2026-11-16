program msound;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umsoundmain;

begin
  if HandleStandardCliEarlyExit(maMSound) then
    Exit;

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsoundMainForm, msoundMainForm);
  Application.Run;
end.
