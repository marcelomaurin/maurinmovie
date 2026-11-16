program mscene;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, umscenemain;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMsceneMainForm, msceneMainForm);
  Application.Run;
end.
