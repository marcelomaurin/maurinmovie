program msound;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umsoundmain;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsoundMainForm, msoundMainForm);
  Application.Run;
end.
