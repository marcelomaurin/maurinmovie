unit ummenusettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ummpprotocol;

type
  TMmenuSettingsForm = class(TForm)
  private
    FDefaultRootEdit: TEdit;
    FPathEdits: array[1..6] of TEdit;
    FStatusLabels: array[1..6] of TLabel;
    procedure BrowseDefaultRoot(Sender: TObject);
    procedure BrowseAppExe(Sender: TObject);
    procedure AutoDetectAll(Sender: TObject);
    procedure PathChanged(Sender: TObject);
    procedure UpdateStatusBadges;
    function DetectExeForApp(const AppName: string): string;
  public
    constructor CreateWithPaths(TheOwner: TComponent;
      const CurrentDefaultRoot: string;
      const CurrentPaths: array of string);
    function GetDefaultRoot: string;
    function GetAppPath(Index: Integer): string;
  end;

implementation

constructor TMmenuSettingsForm.CreateWithPaths(TheOwner: TComponent;
  const CurrentDefaultRoot: string;
  const CurrentPaths: array of string);
var
  Header, Body, Footer: TPanel;
  L, SubL: TLabel;
  B, BtnDetect, BtnCancel, BtnOK: TButton;
  I, Y: Integer;
begin
  inherited CreateNew(TheOwner, 1);
  Caption := 'Configuracoes - MMenu';
  Width := 760;
  Height := 510;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;

  Header := TPanel.Create(Self);
  Header.Parent := Self;
  Header.Align := alTop;
  Header.Height := 56;
  Header.Caption := '';
  Header.BevelOuter := bvNone;
  Header.Color := $003A3028;
  Header.ParentBackground := False;

  L := TLabel.Create(Self);
  L.Parent := Header;
  L.Caption := 'Configuracao de Executaveis e Diretorios';
  L.Font.Size := 13;
  L.Font.Style := [fsBold];
  L.Font.Color := clWhite;
  L.SetBounds(18, 16, 500, 24);

  Footer := TPanel.Create(Self);
  Footer.Parent := Self;
  Footer.Align := alBottom;
  Footer.Height := 54;
  Footer.Caption := '';
  Footer.BevelOuter := bvLowered;

  BtnDetect := TButton.Create(Self);
  BtnDetect.Parent := Footer;
  BtnDetect.Caption := 'Autodetectar em bin/';
  BtnDetect.SetBounds(16, 11, 170, 32);
  BtnDetect.OnClick := @AutoDetectAll;

  BtnOK := TButton.Create(Self);
  BtnOK.Parent := Footer;
  BtnOK.Caption := 'Salvar';
  BtnOK.ModalResult := mrOK;
  BtnOK.Default := True;
  BtnOK.SetBounds(546, 11, 95, 32);

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Footer;
  BtnCancel.Caption := 'Cancelar';
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.Cancel := True;
  BtnCancel.SetBounds(649, 11, 95, 32);

  Body := TPanel.Create(Self);
  Body.Parent := Self;
  Body.Align := alClient;
  Body.Caption := '';
  Body.BevelOuter := bvNone;

  L := TLabel.Create(Self);
  L.Parent := Body;
  L.Caption := 'Pasta padrao para novas producoes:';
  L.Font.Style := [fsBold];
  L.SetBounds(18, 16, 300, 20);

  FDefaultRootEdit := TEdit.Create(Self);
  FDefaultRootEdit.Parent := Body;
  FDefaultRootEdit.SetBounds(18, 38, 608, 26);
  FDefaultRootEdit.Text := CurrentDefaultRoot;

  B := TButton.Create(Self);
  B.Parent := Body;
  B.Caption := 'Pasta...';
  B.SetBounds(634, 37, 108, 28);
  B.OnClick := @BrowseDefaultRoot;

  SubL := TLabel.Create(Self);
  SubL.Parent := Body;
  SubL.Caption := 'Executaveis dos seis aplicativos da suite (MMenu v' +
    MMP_EXECUTABLE_VERSION + '):';
  SubL.Font.Style := [fsBold];
  SubL.SetBounds(18, 78, 520, 20);

  Y := 108;
  for I := 1 to 6 do
  begin
    L := TLabel.Create(Self);
    L.Parent := Body;
    L.Caption := IntToStr(I) + ' - ' + MmpAppNames[I];
    L.Font.Style := [fsBold];
    L.SetBounds(18, Y + 4, 110, 20);

    FPathEdits[I] := TEdit.Create(Self);
    FPathEdits[I].Parent := Body;
    FPathEdits[I].SetBounds(132, Y, 412, 26);
    if (I - 1) <= High(CurrentPaths) then
      FPathEdits[I].Text := CurrentPaths[I - 1];
    FPathEdits[I].OnChange := @PathChanged;

    B := TButton.Create(Self);
    B.Parent := Body;
    B.Caption := 'Procurar...';
    B.Tag := I;
    B.SetBounds(552, Y - 1, 92, 28);
    B.OnClick := @BrowseAppExe;

    FStatusLabels[I] := TLabel.Create(Self);
    FStatusLabels[I].Parent := Body;
    FStatusLabels[I].SetBounds(652, Y + 5, 92, 20);

    Inc(Y, 44);
  end;

  UpdateStatusBadges;
end;

procedure TMmenuSettingsForm.BrowseDefaultRoot(Sender: TObject);
var
  D: TSelectDirectoryDialog;
begin
  D := TSelectDirectoryDialog.Create(Self);
  try
    D.Title := 'Selecione a pasta padrao para producoes MaurinMovie';
    if DirectoryExists(FDefaultRootEdit.Text) then
      D.InitialDir := FDefaultRootEdit.Text;
    if D.Execute then
      FDefaultRootEdit.Text := D.FileName;
  finally
    D.Free;
  end;
end;

procedure TMmenuSettingsForm.BrowseAppExe(Sender: TObject);
var
  Idx: Integer;
  D: TOpenDialog;
begin
  Idx := (Sender as TButton).Tag;
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Selecionar executavel de ' + MmpAppNames[Idx];
    D.FileName := FPathEdits[Idx].Text;
    {$IFDEF WINDOWS}
    D.Filter := 'Executaveis (*.exe)|*.exe|Todos (*.*)|*.*';
    {$ELSE}
    D.Filter := 'Todos|*';
    {$ENDIF}
    D.Options := [ofFileMustExist, ofPathMustExist];
    if D.Execute then
    begin
      FPathEdits[Idx].Text := D.FileName;
      UpdateStatusBadges;
    end;
  finally
    D.Free;
  end;
end;

function TMmenuSettingsForm.DetectExeForApp(const AppName: string): string;
var
  Base, Candidate, Suffix: string;
begin
  Result := '';
  {$IFDEF WINDOWS}
  Suffix := '.exe';
  {$ELSE}
  Suffix := '';
  {$ENDIF}
  Base := ExtractFileDir(ExpandFileName(ParamStr(0)));
  Candidate := IncludeTrailingPathDelimiter(Base) + LowerCase(AppName) + Suffix;
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := ExpandFileName(Base + PathDelim + '..' + PathDelim +
    'bin' + PathDelim + LowerCase(AppName) + Suffix);
  if FileExists(Candidate) then Exit(Candidate);
end;

procedure TMmenuSettingsForm.AutoDetectAll(Sender: TObject);
var
  I: Integer;
  Found: string;
begin
  for I := 1 to 6 do
  begin
    Found := DetectExeForApp(MmpAppNames[I]);
    if Found <> '' then
      FPathEdits[I].Text := Found;
  end;
  UpdateStatusBadges;
end;

procedure TMmenuSettingsForm.PathChanged(Sender: TObject);
begin
  UpdateStatusBadges;
end;

procedure TMmenuSettingsForm.UpdateStatusBadges;
var
  I: Integer;
  P, Detected: string;
begin
  for I := 1 to 6 do
  begin
    P := Trim(FPathEdits[I].Text);
    if (P <> '') and FileExists(P) then
    begin
      FStatusLabels[I].Caption := 'OK (config.)';
      FStatusLabels[I].Font.Color := $00007A00;
    end
    else if P <> '' then
    begin
      FStatusLabels[I].Caption := 'Ausente';
      FStatusLabels[I].Font.Color := clMaroon;
    end
    else
    begin
      Detected := DetectExeForApp(MmpAppNames[I]);
      if Detected <> '' then
      begin
        FStatusLabels[I].Caption := 'Auto (bin/)';
        FStatusLabels[I].Font.Color := $00805000;
      end
      else
      begin
        FStatusLabels[I].Caption := 'Nao config.';
        FStatusLabels[I].Font.Color := clGray;
      end;
    end;
  end;
end;

function TMmenuSettingsForm.GetDefaultRoot: string;
begin
  Result := Trim(FDefaultRootEdit.Text);
end;

function TMmenuSettingsForm.GetAppPath(Index: Integer): string;
begin
  if (Index >= 1) and (Index <= 6) then
    Result := Trim(FPathEdits[Index].Text)
  else
    Result := '';
end;

end.

