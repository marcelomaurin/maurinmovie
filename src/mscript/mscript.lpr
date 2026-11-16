program mscript;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umscriptmain;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMscriptMainForm, mscriptMainForm);
  Application.Run;
end.
