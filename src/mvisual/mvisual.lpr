program mvisual;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umvisualmain;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMvisualMainForm, mvisualMainForm);
  Application.Run;
end.
