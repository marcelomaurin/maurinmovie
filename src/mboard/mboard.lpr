program mboard;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umboardmain;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMboardMainForm, mboardMainForm);
  Application.Run;
end.
