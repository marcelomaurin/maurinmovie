unit umsoundmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type
  TMsoundMainForm = class(TForm)
    HeaderPanel: TPanel;
    WorkspacePanel: TPanel;
    StatusPanel: TPanel;
    TitleLabel: TLabel;
    DescriptionLabel: TLabel;
  end;

var
  msoundMainForm: TMsoundMainForm;

implementation

{$R *.lfm}

end.
