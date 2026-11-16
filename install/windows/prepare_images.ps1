param(
  [string]$OutputDirectory,
  [string]$Version = '0.1.0'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist\installer-images' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function MakeBanner($Destination, $Width, $Height, $Heading, $Subheading, $Badge, $AccentColor) {
  $bitmap = [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [Drawing.Graphics]::FromImage($bitmap)
  $titleFont = [Drawing.Font]::new('Segoe UI', 16, [Drawing.FontStyle]::Bold)
  $subFont = [Drawing.Font]::new('Segoe UI', 10)
  $badgeFont = [Drawing.Font]::new('Segoe UI', 9, [Drawing.FontStyle]::Bold)
  $white = [Drawing.SolidBrush]::new([Drawing.Color]::White)
  $muted = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(205, 222, 238))
  $accentBrush = [Drawing.SolidBrush]::new($AccentColor)
  $cardBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(46, 56, 72))
  $borderPen = [Drawing.Pen]::new($AccentColor, 2)
  try {
    $g.Clear([Drawing.Color]::FromArgb(30, 38, 50))
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $g.FillRectangle($accentBrush, 0, 0, $Width, 8)
    $g.FillRectangle($cardBrush, 20, 26, $Width - 40, $Height - 46)
    $g.DrawRectangle($borderPen, 20, 26, $Width - 40, $Height - 46)

    if ($Badge) {
      $g.FillRectangle($accentBrush, 42, 48, 175, 28)
      $g.DrawString($Badge, $badgeFont, $white, 52, 54)
    }

    $g.DrawString($Heading, $titleFont, $white, [Drawing.RectangleF]::new(40, 92, $Width - 80, 64))
    $g.DrawString($Subheading, $subFont, $muted, [Drawing.RectangleF]::new(40, 152, $Width - 80, $Height - 180))

    $bitmap.Save((Join-Path $OutputDirectory $Destination), [Drawing.Imaging.ImageFormat]::Bmp)
  } finally {
    $g.Dispose(); $bitmap.Dispose()
    $titleFont.Dispose(); $subFont.Dispose(); $badgeFont.Dispose()
    $white.Dispose(); $muted.Dispose(); $accentBrush.Dispose()
    $cardBrush.Dispose(); $borderPen.Dispose()
  }
}

MakeBanner 'welcome.bmp' 246 471 "MaurinMovie $Version" `
  "Suite modular de producao audiovisual com IA.`n`nMMenu | MScript | MVisual | MBoard | MSound | MScene | MCut`n`nProtocolo MMP v1 + CHATGPT + OpenSSL" `
  'MAURINSOFT' ([Drawing.Color]::FromArgb(58, 128, 196))

$slides = @(
  @('0 - MMenu', 'Portal central da suite, abertura por revisao exata, integridade SHA-256 e sincronizacoes.', 'MODULO 0', [Drawing.Color]::FromArgb(58, 128, 196)),
  @('1 - MScript', 'Sinopse, geracao de roteiro com IA (CHATGPT), edicao por cena e mapa de personagens.', 'MODULO 1', [Drawing.Color]::FromArgb(72, 148, 112)),
  @('2 - MVisual', 'Indexacao bidirecional de entidades, vistas padronizadas e filtros visuais (openai_image).', 'MODULO 2', [Drawing.Color]::FromArgb(168, 112, 56)),
  @('3 - MBoard', 'Storyboard inicial/final, subdivisao com continuidade por asset_id e cascata.', 'MODULO 3', [Drawing.Color]::FromArgb(142, 86, 166)),
  @('4 - MSound', 'Perfis vocais, efeitos sonoros e ensaio sincronizado (TAIVoiceSynthesizer).', 'MODULO 4', [Drawing.Color]::FromArgb(182, 84, 84)),
  @('5 - MScene', 'Geracao sequencial de sub-blocos, montagem de cena unica e validacao de ligacoes.', 'MODULO 5', [Drawing.Color]::FromArgb(62, 142, 162)),
  @('6 - MCut', 'Timeline narrativa, transicoes, sessoes de publico, analise e exportacao final.', 'MODULO 6', [Drawing.Color]::FromArgb(92, 116, 184))
)

for ($i = 0; $i -lt $slides.Count; $i++) {
  $s = $slides[$i]
  MakeBanner ("slide$i.bmp") 900 350 $s[0] $s[1] $s[2] $s[3]
}

