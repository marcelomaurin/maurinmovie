unit ummenumain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Process, IniFiles;

type
  TMmenuMainForm = class(TForm)
  private
    FRoot: string;
    FConfig: string;
    FProjectEdit: TEdit;
    FStatus: TLabel;
    FApps: array[1..6] of TButton;
    FAppPaths: array[1..6] of string;
    procedure ChooseProduction(Sender: TObject);
    procedure OpenApp(Sender: TObject);
    procedure OpenSettings(Sender: TObject);
    procedure SaveConfig;
    procedure LoadConfig;
    function FindExecutable(const AppName: string): string;
    procedure UpdateButtons;
    procedure SetStatus(const S: string);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  mmenuMainForm: TMmenuMainForm;

implementation

const
  AppNames: array[1..6] of string =
    ('MScript', 'MVisual', 'MBoard', 'MSound', 'MScene', 'MCut');
  AppDescriptions: array[1..6] of string =
    ('Roteiro e personagens', 'Biblioteca visual',
     'Storyboard', 'Vozes e efeitos', 'Geracao de cenas',
     'Montagem e filme final');

constructor TMmenuMainForm.Create(TheOwner: TComponent);
var
  Head, Sidebar, Content, Bottom: TPanel;
  L: TLabel;
  B: TButton;
  I: Integer;
begin
  inherited CreateNew(TheOwner, 1);
  Caption := 'MMenu - MaurinMovie';
  Width := 1100;
  Height := 720;
  Position := poScreenCenter;
  Constraints.MinWidth := 780;
  Constraints.MinHeight := 550;

  Head := TPanel.Create(Self);
  Head.Parent := Self;
  Head.Align := alTop;
  Head.Height := 76;
  Head.Caption := '';
  Head.BevelOuter := bvNone;
  Head.Color := $003A3028;
  Head.ParentBackground := False;

  L := TLabel.Create(Self);
  L.Parent := Head;
  L.Caption := 'MaurinMovie  |  MMenu';
  L.Font.Size := 20;
  L.Font.Style := [fsBold];
  L.Font.Color := clWhite;
  L.Left := 20;
  L.Top := 17;

  Sidebar := TPanel.Create(Self);
  Sidebar.Parent := Self;
  Sidebar.Align := alLeft;
  Sidebar.Width := 270;
  Sidebar.Caption := '';
  Sidebar.BevelOuter := bvNone;
  Sidebar.Color := $00ECECEC;
  Sidebar.ParentBackground := False;

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'PRODUCAO ATIVA';
  L.Font.Style := [fsBold];
  L.Left := 14;
  L.Top := 24;

  FProjectEdit := TEdit.Create(Self);
  FProjectEdit.Parent := Sidebar;
  FProjectEdit.Left := 14;
  FProjectEdit.Top := 52;
  FProjectEdit.Width := 240;
  FProjectEdit.ReadOnly := True;
  FProjectEdit.Anchors := [akLeft, akTop, akRight];
  FProjectEdit.Text := '(nenhuma selecionada)';

  B := TButton.Create(Self);
  B.Parent := Sidebar;
  B.Caption := 'Abrir producao...';
  B.SetBounds(14, 90, 240, 36);
  B.OnClick := @ChooseProduction;

  B := TButton.Create(Self);
  B.Parent := Sidebar;
  B.Caption := 'Configurar executaveis...';
  B.SetBounds(14, 138, 240, 36);
  B.OnClick := @OpenSettings;

  L := TLabel.Create(Self);
  L.Parent := Sidebar;
  L.Caption := 'Cada aplicativo possui projeto proprio.';
  L.SetBounds(14, 200, 250, 30);
  L.WordWrap := True;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 40;
  Bottom.Caption := '';
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Bottom;
  FStatus.Left := 12;
  FStatus.Top := 12;
  FStatus.Caption := 'Pronto';

  Content := TPanel.Create(Self);
  Content.Parent := Self;
  Content.Align := alClient;
  Content.Caption := '';
  Content.BevelOuter := bvNone;

  L := TLabel.Create(Self);
  L.Parent := Content;
  L.Caption := 'Aplicativos da suite';
  L.Font.Size := 16;
  L.Font.Style := [fsBold];
  L.SetBounds(24, 20, 400, 30);

  for I := 1 to 6 do
  begin
    FApps[I] := TButton.Create(Self);
    FApps[I].Parent := Content;
    FApps[I].Tag := I;
    FApps[I].Caption := AppNames[I] + '  -  ' + AppDescriptions[I];
    FApps[I].SetBounds(24 + ((I - 1) mod 2) * 285,
      72 + ((I - 1) div 2) * 100, 265, 72);
    FApps[I].OnClick := @OpenApp;
  end;

  FConfig := GetAppConfigDir(False) + 'MaurinMovie' + PathDelim +
    'mmenu.ini';
  LoadConfig;
  UpdateButtons;
end;

destructor TMmenuMainForm.Destroy;
begin
  SaveConfig;
  inherited Destroy;
end;

procedure TMmenuMainForm.SetStatus(const S: string);
begin
  FStatus.Caption := S;
end;

procedure TMmenuMainForm.LoadConfig;
var
  Ini: TIniFile;
  I: Integer;
begin
  if not FileExists(FConfig) then Exit;
  Ini := TIniFile.Create(FConfig);
  try
    FRoot := Ini.ReadString('Production', 'Root', '');
    for I := 1 to 6 do
      FAppPaths[I] := Ini.ReadString('Applications', AppNames[I], '');
  finally
    Ini.Free;
  end;
  if FRoot <> '' then FProjectEdit.Text := FRoot;
end;

procedure TMmenuMainForm.SaveConfig;
var
  Ini: TIniFile;
  I: Integer;
begin
  ForceDirectories(ExtractFileDir(FConfig));
  Ini := TIniFile.Create(FConfig);
  try
    Ini.WriteString('Production', 'Root', FRoot);
    for I := 1 to 6 do
      Ini.WriteString('Applications', AppNames[I], FAppPaths[I]);
  finally
    Ini.Free;
  end;
end;

procedure TMmenuMainForm.ChooseProduction(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Selecione production.json da producao';
    D.Filter := 'Projeto MaurinMovie (production.json)|production.json|JSON|*.json';
    D.Options := [ofFileMustExist, ofPathMustExist];
    if D.Execute then
    begin
      if ExtractFileName(D.FileName) <> 'production.json' then
      begin
        MessageDlg('Selecione o arquivo production.json.', mtWarning,
          [mbOK], 0);
        Exit;
      end;
      FRoot := ExtractFileDir(D.FileName);
      FProjectEdit.Text := FRoot;
      SaveConfig;
      SetStatus('Producao selecionada: ' + FRoot);
    end;
  finally
    D.Free;
  end;
end;

function TMmenuMainForm.FindExecutable(const AppName: string): string;
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

procedure TMmenuMainForm.UpdateButtons;
var
  I: Integer;
begin
  for I := 1 to 6 do
    FApps[I].Hint := 'Abrir ' + AppNames[I];
end;

procedure TMmenuMainForm.OpenSettings(Sender: TObject);
var
  I: Integer;
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    for I := 1 to 6 do
    begin
      D.Title := 'Executavel de ' + AppNames[I] +
        ' (Cancelar para manter atual)';
      D.FileName := FAppPaths[I];
      {$IFDEF WINDOWS}
      D.Filter := 'Executaveis|*.exe|Todos|*.*';
      {$ELSE}
      D.Filter := 'Todos|*';
      {$ENDIF}
      if D.Execute then FAppPaths[I] := D.FileName;
    end;
    SaveConfig;
    SetStatus('Caminhos de executaveis atualizados.');
  finally
    D.Free;
  end;
end;

procedure TMmenuMainForm.OpenApp(Sender: TObject);
var
  I: Integer;
  Executable: string;
  P: TProcess;
begin
  I := (Sender as TButton).Tag;
  Executable := FAppPaths[I];
  if (Executable = '') or (not FileExists(Executable)) then
    Executable := FindExecutable(AppNames[I]);
  if Executable = '' then
  begin
    MessageDlg('Executavel de ' + AppNames[I] +
      ' nao encontrado. Configure o caminho no menu.', mtWarning,
      [mbOK], 0);
    Exit;
  end;
  P := TProcess.Create(nil);
  try
    P.Executable := Executable;
    if FRoot <> '' then
    begin
      P.Parameters.Add('--production');
      P.Parameters.Add(FRoot);
    end;
    P.Options := [];
    try
      P.Execute;
      SetStatus(AppNames[I] + ' iniciado.');
    except
      on E: Exception do
        MessageDlg('Erro ao iniciar ' + AppNames[I] + ': ' + E.Message,
          mtError, [mbOK], 0);
    end;
  finally
    P.Free;
  end;
end;

end.
