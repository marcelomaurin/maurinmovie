program mvisual;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, mmpcommon, ummpappbase, umvisualmain;

begin
  if HandleStandardCliEarlyExit(maMVisual) then
    Exit;

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMvisualMainForm, mvisualMainForm);
  Application.Run;
end.
