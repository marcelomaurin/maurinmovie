program mvisual;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umvisualmain;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMvisualMainForm, mvisualMainForm);
  Application.Run;
end.
