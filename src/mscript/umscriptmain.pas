unit umscriptmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type
  TMscriptMainForm = class(TForm)
    HeaderPanel: TPanel;
    WorkspacePanel: TPanel;
    StatusPanel: TPanel;
    TitleLabel: TLabel;
    DescriptionLabel: TLabel;
  end;

var
  mscriptMainForm: TMscriptMainForm;

implementation

{$R *.lfm}

end.
