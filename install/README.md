# Instalador Windows — MaurinMovie

Baseado na estrutura do instalador do **MultiCNC / MultiSuite** (`multicnc/installer/windows/`), adaptado para os sete aplicativos do **MaurinMovie**, pacotes **CHATGPT** e bibliotecas **OpenSSL Win64**.

## Pré-requisitos
- Windows 64 bits
- Lazarus / Free Pascal 64 bits (`C:\lazarus\lazbuild.exe`)
- Inno Setup 6 ou 7 (`C:\Program Files\Inno Setup 7\ISCC.exe`)
- Repositório `CHATGPT` ao lado do `maurinmovie` (ou definido em `MAURINMOVIE_CHATGPT_DIR`)

## Como gerar o instalador
```powershell
install\windows\build_release.bat -Version 0.3.0 -SetupSeq 003 -AllowDirty
```

O script:
1. Verifica/compila os pacotes `CHATGPT` (`openai_core.lpk`, `openai_image.lpk`, `openai_voice.lpk`, `openai_video.lpk`).
2. Compila os 7 aplicativos em `bin\`: `mmenu.exe`, `mscript.exe`, `mvisual.exe`, `mboard.exe`, `msound.exe`, `mscene.exe`, `mcut.exe`.
3. Executa a suíte de testes `tests\test_mmp_protocol.pas`.
4. Copia as DLLs OpenSSL Win64 (`libssl-1_1-x64.dll`, `libcrypto-1_1-x64.dll`, `libssl-3-x64.dll`, `libcrypto-3-x64.dll`, `legacy.dll`) para `bin\` e para o staging `dist\app\`.
5. Gera as imagens do wizard (`prepare_images.ps1`), o manifesto (`build-manifest.json`) e compila `install\windows\maurinmovie.iss` com o `ISCC.exe`.
6. Salva os instaladores e `SHA256SUMS` em `install\`.

