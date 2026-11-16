unit ummenumain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type
  TMmenuMainForm = class(TForm)
    HeaderPanel: TPanel;
    WorkspacePanel: TPanel;
    StatusPanel: TPanel;
    TitleLabel: TLabel;
    DescriptionLabel: TLabel;
  end;

var
  mmenuMainForm: TMmenuMainForm;

implementation

{$R *.lfm}

end.
