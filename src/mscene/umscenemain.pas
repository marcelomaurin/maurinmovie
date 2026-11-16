unit umscenemain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type
  TMsceneMainForm = class(TForm)
    HeaderPanel: TPanel;
    WorkspacePanel: TPanel;
    StatusPanel: TPanel;
    TitleLabel: TLabel;
    DescriptionLabel: TLabel;
  end;

var
  msceneMainForm: TMsceneMainForm;

implementation

{$R *.lfm}

end.
