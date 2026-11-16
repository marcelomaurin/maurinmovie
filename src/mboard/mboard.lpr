program mboard;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umboardmain;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMboardMainForm, mboardMainForm);
  Application.Run;
end.
