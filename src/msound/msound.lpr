program msound;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umsoundmain;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsoundMainForm, msoundMainForm);
  Application.Run;
end.
