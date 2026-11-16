program mboard;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umboardmain;

begin
  if HandleStandardCliEarlyExit(maMBoard) then
    Exit;

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMboardMainForm, mboardMainForm);
  Application.Run;
end.
