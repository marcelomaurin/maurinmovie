program mmenu;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, SysUtils, mmpcommon, ummpprotocol, ummpappbase, ummenumain;

var
  Args: TMMLaunchArgs;
  Prod: TMmpProduction;
begin
  if HandleStandardCliEarlyExit(maMMenu) then
    Exit;

  Args := ParseLaunchArgs;
  if Args.CheckIntegrity then
  begin
    if (Args.Production = '') or not LoadProduction(Args.Production, True, Prod) then
    begin
      WriteCliLine('Falha ao abrir producao: ' + Prod.ErrorMessage);
      Halt(EXIT_NOT_FOUND);
    end;
    WriteCliLine('Producao: ' + Prod.Title + ' | ' + Prod.OverallStatusText);
    if Prod.HasFailures then
      Halt(EXIT_INTEGRITY_ERROR);
    Halt(EXIT_OK);
  end;

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMmenuMainForm, mmenuMainForm);
  Application.Run;
end.
