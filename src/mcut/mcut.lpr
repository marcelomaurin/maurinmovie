program mcut;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umcutmain;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMcutMainForm, mcutMainForm);
  Application.Run;
end.
