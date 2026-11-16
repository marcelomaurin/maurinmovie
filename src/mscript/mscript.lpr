program mscript;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umscriptmain;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMscriptMainForm, mscriptMainForm);
  Application.Run;
end.
