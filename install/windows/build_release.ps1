param(
  [string]$Version = $env:VERSION,
  [ValidatePattern('^\d{3}$')][string]$SetupSeq = '004',
  [switch]$AllowDirty,
  [switch]$SkipBinUpdate
)
$ErrorActionPreference = 'Stop'
if (-not $Version) { $Version = '0.4.0' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Set-Location -LiteralPath $root
$dist = Join-Path $root 'dist'
$app = Join-Path $dist 'app'
$bin = Join-Path $root 'bin'
$installRoot = Join-Path $root 'install'

function FindTool($EnvName, $Name, $Fallbacks) {
  $value = [Environment]::GetEnvironmentVariable($EnvName)
  if ($value -and (Test-Path -LiteralPath $value)) { return $value }
  foreach ($path in $Fallbacks) { if (Test-Path -LiteralPath $path) { return $path } }
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  throw "Ferramenta ausente: $Name. Configure $EnvName."
}

$env:LAZBUILD = FindTool 'LAZBUILD' 'lazbuild' @('C:\lazarus\lazbuild.exe')
$env:FPC = FindTool 'FPC' 'fpc' @('C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe', 'C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe')
$pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
$iscc = FindTool 'ISCC' 'iscc' @("$env:ProgramFiles\Inno Setup 7\ISCC.exe", "$pf86\Inno Setup 6\ISCC.exe")

$chatgpt = if ($env:MAURINMOVIE_CHATGPT_DIR) { $env:MAURINMOVIE_CHATGPT_DIR } else { Join-Path (Split-Path $root) 'CHATGPT' }
if (-not (Test-Path -LiteralPath $chatgpt)) {
  throw "Repositorio CHATGPT nao encontrado em: $chatgpt. Configure MAURINMOVIE_CHATGPT_DIR."
}

if (-not $AllowDirty) {
  $status = & git status --porcelain
  if ($LASTEXITCODE -ne 0 -or $status) {
    Write-Warning 'Arvore Git com alteracoes locais; continuando build local.'
  }
}

if ([IO.Path]::GetFullPath($app) -ne (Join-Path $root 'dist\app')) { throw 'Staging fora da pasta esperada.' }
if (Test-Path -LiteralPath $app) { Remove-Item -LiteralPath $app -Recurse -Force }
New-Item -ItemType Directory -Force -Path $app, $bin, $installRoot, (Join-Path $dist 'build-logs'), (Join-Path $root 'build\tests') | Out-Null

# Compila pacotes CHATGPT utilizados pelos aplicativos
foreach ($pkg in @('openai_core.lpk', 'openai_image.lpk', 'openai_voice.lpk', 'openai_video.lpk')) {
  $pkgPath = Join-Path $chatgpt ("pacote\packages\$pkg")
  Write-Host "Verificando pacote CHATGPT: $pkg..."
  & $env:LAZBUILD '--cpu=x86_64' '--os=win64' '--ws=win32' $pkgPath *> (Join-Path $dist ("build-logs\$pkg.log"))
  if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath (Join-Path $dist ("build-logs\$pkg.log")) -Tail 30
    throw "Falha ao compilar pacote CHATGPT: $pkg"
  }
}

$targets = @(
  @('src\mmenu\mmenu', 'mmenu'),
  @('src\mscript\mscript', 'mscript'),
  @('src\mvisual\mvisual', 'mvisual'),
  @('src\mboard\mboard', 'mboard'),
  @('src\msound\msound', 'msound'),
  @('src\mscene\mscene', 'mscene'),
  @('src\mcut\mcut', 'mcut')
)

foreach ($target in $targets) {
  Write-Host "Compilando $($target[1])..."
  $log = Join-Path $dist ("build-logs\" + $target[1] + '.log')
  & $env:LAZBUILD '--cpu=x86_64' '--os=win64' '--ws=win32' "--compiler=$env:FPC" '--build-mode=Default' ($target[0] + '.lpi') *> $log
  if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $log -Tail 35
    throw "Falha ao compilar $($target[1])"
  }
  $builtExe = Join-Path $bin ($target[1] + '.exe')
  if (-not (Test-Path -LiteralPath $builtExe)) {
    throw "Executavel esperado nao gerado em: $builtExe"
  }
  Copy-Item -LiteralPath $builtExe -Destination (Join-Path $app ($target[1] + '.exe')) -Force
}

# Copia bibliotecas OpenSSL Win64 (1.1.1.10 para TFPHTTPClient/opensslsockets + 3.1.3) e SQLite3 Win64 + template zerado
$sqliteDll = Join-Path $chatgpt 'runtime\database\libs\sqlite\win64\sqlite3.dll'
if (-not (Test-Path -LiteralPath $sqliteDll)) {
  throw "Biblioteca SQLite3 Win64 ausente: $sqliteDll"
}
Copy-Item -LiteralPath $sqliteDll -Destination $app -Force
Copy-Item -LiteralPath $sqliteDll -Destination (Join-Path $root 'build\tests') -Force
if (-not $SkipBinUpdate) {
  Copy-Item -LiteralPath $sqliteDll -Destination $bin -Force
}

$emptyDb = Join-Path $root 'db\maurinmovie_empty.db'
if (-not (Test-Path -LiteralPath $emptyDb)) {
  throw "Banco zerado template ausente: $emptyDb"
}
$appTplDir = Join-Path $app 'templates'
New-Item -ItemType Directory -Force -Path $appTplDir | Out-Null
Copy-Item -LiteralPath $emptyDb -Destination (Join-Path $appTplDir 'maurinmovie_empty.db') -Force
if (-not $SkipBinUpdate) {
  $binTplDir = Join-Path $bin 'templates'
  New-Item -ItemType Directory -Force -Path $binTplDir | Out-Null
  Copy-Item -LiteralPath $emptyDb -Destination (Join-Path $binTplDir 'maurinmovie_empty.db') -Force
}

# Executa testes automatizados do protocolo MMP v1
Write-Host "Compilando e executando testes MMP v1..."
& $env:FPC '-MObjFPC' '-Scghi' '-O1' "-Fu$root\src\common" "-Fu$chatgpt\pacote\packages\lib\x86_64-win64" '-FuC:\lazarus\components\lazutils\lib\x86_64-win64' "-FU$root\build\tests" "-FE$root\build\tests" "$root\tests\test_mmp_protocol.pas"
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar tests\test_mmp_protocol.pas.' }
& "$root\build\tests\test_mmp_protocol.exe"
if ($LASTEXITCODE -ne 0) { throw 'Testes MMP v1 falharam.' }

# Testes de video/audio (ffmpeg). Sem ffmpeg no PATH o teste informa [SKIP] e sai com 0.
Write-Host "Compilando e executando testes de midia (ffmpeg)..."
& $env:FPC '-MObjFPC' '-Scghi' '-O1' "-Fu$root\src\common" "-FU$root\build\tests" "-FE$root\build\tests" "$root\tests\common\test_mmp_media.pas"
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar tests\common\test_mmp_media.pas.' }
& "$root\build\tests\test_mmp_media.exe"
if ($LASTEXITCODE -ne 0) { throw 'Testes de midia falharam.' }

$ssl11Dir = Join-Path $chatgpt 'runtime\OpenSSL\1.1.1.10\x64'
$ssl3Dir = Join-Path $chatgpt 'runtime\OpenSSL\3.1.3\x64'
$sslFiles = @(
  (Join-Path $ssl11Dir 'libssl-1_1-x64.dll'),
  (Join-Path $ssl11Dir 'libcrypto-1_1-x64.dll'),
  (Join-Path $ssl3Dir 'libssl-3-x64.dll'),
  (Join-Path $ssl3Dir 'libcrypto-3-x64.dll'),
  (Join-Path $ssl3Dir 'legacy.dll')
)

foreach ($dll in $sslFiles) {
  if (-not (Test-Path -LiteralPath $dll)) {
    throw "Biblioteca OpenSSL obrigatoria ausente: $dll"
  }
  Copy-Item -LiteralPath $dll -Destination $app -Force
  if (-not $SkipBinUpdate) {
    Copy-Item -LiteralPath $dll -Destination $bin -Force
  }
}

# Copia documentacao
$docsDst = Join-Path $app 'docs'
New-Item -ItemType Directory -Force -Path $docsDst | Out-Null
Copy-Item -Path (Join-Path $root 'docs\*') -Destination $docsDst -Recurse -Force

# Gera version.iss e build-manifest.json
$parts = $Version.Split('.')
$major = if ($parts.Count -ge 1) { [int]$parts[0] } else { 0 }
$minor = if ($parts.Count -ge 2) { [int]$parts[1] } else { 1 }
$patch = if ($parts.Count -ge 3) { [int]$parts[2] } else { 0 }
$binVersion = "$major.$minor.$patch.$SetupSeq"
$versionIss = @(
  "#define MyAppVersion `"$Version`""
  "#define MyBinaryVersion `"$binVersion`""
) -join [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $dist 'version.iss'), $versionIss + [Environment]::NewLine)

$manifestFiles = @()
foreach ($f in Get-ChildItem -LiteralPath $app -File) {
  $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
  $manifestFiles += @{
    name = $f.Name
    bytes = $f.Length
    sha256 = $h
  }
}
$manifest = @{
  product = 'MaurinMovie'
  version = $Version
  setup_seq = $SetupSeq
  arch = 'x64'
  built_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  files = $manifestFiles
} | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $app 'build-manifest.json'), $manifest)

# Gera imagens e compila instalador Inno Setup
& (Join-Path $PSScriptRoot 'prepare_images.ps1') -Version $Version

$name = "setup_maurinmovie_$SetupSeq"
& $iscc "-dSetupSeq=$SetupSeq" "-dOutputExeName=$name" (Join-Path $PSScriptRoot 'maurinmovie.iss')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar instalador no Inno Setup.' }

$generatedSetup = Join-Path $dist "$name.exe"
$versionedName = "setup_maurinmovie_$Version.exe"
Copy-Item -LiteralPath $generatedSetup -Destination (Join-Path $installRoot "$name.exe") -Force
Copy-Item -LiteralPath $generatedSetup -Destination (Join-Path $installRoot $versionedName) -Force
Copy-Item -LiteralPath $generatedSetup -Destination (Join-Path $bin $versionedName) -Force

$hash = (Get-FileHash -LiteralPath $generatedSetup -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS'), "$hash  $name.exe" + [Environment]::NewLine)
[IO.File]::WriteAllText((Join-Path $installRoot 'SHA256SUMS'), "$hash  $name.exe`r`n$hash  $versionedName`r`n")

Write-Host "Instalador gerado com sucesso:"
Write-Host "  install\$name.exe"
Write-Host "  install\$versionedName"
Write-Host "  SHA256: $hash"

