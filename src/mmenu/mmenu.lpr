program mmenu;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, SysUtils, mmpcommon, mmpsettings, ummpprotocol, ummpappbase,
  ummenumain, ummenusettings;

{$R mmenu_icon.res}

var
  Args: TMMLaunchArgs;
  Prod: TMmpProduction;
  AuthSettings: TMMSettings;
  LoggedUser: TMmpAccessUser;
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

  if not RequireSingleAppInstance(maMMenu, False) then
    Halt(EXIT_LOCKED);

  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;

  AuthSettings := TMMSettings.Create;
  try
    if AuthSettings.AccessMode = amRestricted then
    begin
      if not PromptMMenuLogin(AuthSettings, LoggedUser) then
        Halt(0);
      GMMenuHasLoggedUser := True;
      GMMenuLoggedUser := LoggedUser;
    end;
  finally
    AuthSettings.Free;
  end;

  Application.CreateForm(TMmenuMainForm, mmenuMainForm);
  Application.Run;
end.
