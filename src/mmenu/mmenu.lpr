program mmenu;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, ummenumain;

begin
  RequireDerivedFormResource := False;
  Application.Initialize;
  Application.CreateForm(TMmenuMainForm, mmenuMainForm);
  Application.Run;
end.
