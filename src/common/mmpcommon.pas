unit mmpcommon;

{ Definicoes compartilhadas do protocolo MMP v1 (docs/11 e docs/12).
  Esqueleto inicial: nao compilado nem testado. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TMMApp = (maMMenu, maMScript, maMVisual, maMBoard, maMSound, maMScene, maMCut);

  { Argumentos padronizados enviados pelo MMenu:
    --production <pasta-raiz> --project-id <id> --revision <rNNNN> }
  TMMLaunchArgs = record
    Production: string;
    ProjectId: string;
    Revision: string;
  end;

const
  MMP_SCHEMA_PRODUCTION = 'mmp.production/1';
  MMP_SCHEMA_PROJECT    = 'mmp.project/1';
  MMP_SCHEMA_MANIFEST   = 'mmp.manifest/1';

  MMP_PRODUCTION_FILE = 'production.json';
  MMP_PROJECT_FILE    = 'project.json';
  MMP_MANIFEST_FILE   = 'manifest.json';

  MMAppNames: array[TMMApp] of string =
    ('MMenu', 'MScript', 'MVisual', 'MBoard', 'MSound', 'MScene', 'MCut');

  { Subpasta de cada aplicativo dentro de projects/ da producao }
  MMAppProjectDirs: array[TMMApp] of string =
    ('00-mmenu', '01-mscript', '02-mvisual', '03-mboard',
     '04-msound', '05-mscene', '06-mcut');

{ Le os argumentos de linha de comando do protocolo MMP. }
function ParseLaunchArgs: TMMLaunchArgs;

{ Nome do diretorio de revisao: 1 -> 'r0001'. }
function RevisionDirName(ANumber: Integer): string;

{ Caminho do project.json de um aplicativo dentro de uma producao. }
function ProjectFilePath(const AProductionRoot: string; AApp: TMMApp): string;

implementation

function ParseLaunchArgs: TMMLaunchArgs;
var
  I: Integer;
begin
  Result.Production := '';
  Result.ProjectId := '';
  Result.Revision := '';
  I := 1;
  while I < ParamCount do
  begin
    if ParamStr(I) = '--production' then
      Result.Production := ParamStr(I + 1)
    else if ParamStr(I) = '--project-id' then
      Result.ProjectId := ParamStr(I + 1)
    else if ParamStr(I) = '--revision' then
      Result.Revision := ParamStr(I + 1)
    else
    begin
      Inc(I);
      Continue;
    end;
    Inc(I, 2);
  end;
end;

function RevisionDirName(ANumber: Integer): string;
begin
  Result := 'r' + Format('%.4d', [ANumber]);
end;

function ProjectFilePath(const AProductionRoot: string; AApp: TMMApp): string;
begin
  Result := IncludeTrailingPathDelimiter(AProductionRoot) + 'projects' +
    PathDelim + MMAppProjectDirs[AApp] + PathDelim + MMP_PROJECT_FILE;
end;

end.
