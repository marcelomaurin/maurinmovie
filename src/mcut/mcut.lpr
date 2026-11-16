program mcut;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umcutmain;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMcutMainForm, mcutMainForm);
  Application.Run;
end.
