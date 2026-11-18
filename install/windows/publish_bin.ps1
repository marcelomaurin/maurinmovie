param(
  [string]$Branch = 'fila',
  [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Set-Location -LiteralPath $root

if ((git branch --show-current).Trim() -ne $Branch) {
  throw "A branch local deve ser $Branch antes de publicar os binarios."
}
$before = @(git status --porcelain)
if ($before.Count -gt 0) {
  throw "Ha alteracoes locais pendentes. Faça commit ou stash antes de publicar para evitar enviar arquivos nao relacionados."
}
git pull --ff-only origin $Branch
if ($LASTEXITCODE -ne 0) { throw 'git pull falhou.' }

if (-not $SkipBuild) {
  & (Join-Path $PSScriptRoot 'build_release.bat')
  if ($LASTEXITCODE -ne 0) { throw 'Compilacao falhou; nenhum binario sera publicado.' }
}
$names = @('mmenu','mscript','mvisual','mboard','msound','mscene','mcut')
foreach ($name in $names) {
  $exe = Join-Path $root ("bin\$name.exe")
  if (-not (Test-Path -LiteralPath $exe)) { throw "Executavel nao encontrado: $exe" }
  if ((Get-Item -LiteralPath $exe).Length -le 0) { throw "Executavel vazio: $exe" }
}
git add -- bin/mmenu.exe bin/mscript.exe bin/mvisual.exe bin/mboard.exe bin/msound.exe bin/mscene.exe bin/mcut.exe
if ($LASTEXITCODE -ne 0) { throw 'git add falhou.' }
$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) {
  Write-Host 'Nenhuma mudanca nos binarios; nada para publicar.'
  exit 0
}
git commit -m 'build: atualizar executaveis Windows na pasta bin'
if ($LASTEXITCODE -ne 0) { throw 'git commit falhou.' }
git push origin $Branch
if ($LASTEXITCODE -ne 0) { throw 'git push falhou; commit permanece local.' }
Write-Host 'Binarios compilados e publicados na branch' $Branch
