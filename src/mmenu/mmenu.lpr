program mmenu;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, ummenumain;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMmenuMainForm, mmenuMainForm);
  Application.Run;
end.
