unit umvisualmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type
  TMvisualMainForm = class(TForm)
    HeaderPanel: TPanel;
    WorkspacePanel: TPanel;
    StatusPanel: TPanel;
    TitleLabel: TLabel;
    DescriptionLabel: TLabel;
  end;

var
  mvisualMainForm: TMvisualMainForm;

implementation

{$R *.lfm}

end.
