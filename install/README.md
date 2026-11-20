# Instalador Windows — MaurinMovie

Baseado na estrutura do instalador do **MultiCNC / MultiSuite** (`multicnc/installer/windows/`), adaptado para os sete aplicativos do **MaurinMovie**, pacotes **CHATGPT** e bibliotecas **OpenSSL Win64**.

## Pré-requisitos
- Windows 64 bits
- Lazarus / Free Pascal 64 bits (`C:\lazarus\lazbuild.exe`)
- Inno Setup 6 ou 7 (`C:\Program Files\Inno Setup 7\ISCC.exe`)
- Repositório `CHATGPT` ao lado do `maurinmovie` (ou definido em `MAURINMOVIE_CHATGPT_DIR`)

## Como gerar o instalador
```powershell
install\windows\build_release.bat -Version 0.4.0 -SetupSeq 004 -AllowDirty
```

O script:
1. Verifica/compila os pacotes `CHATGPT` (`openai_core.lpk`, `openai_image.lpk`, `openai_voice.lpk`, `openai_video.lpk`).
2. Compila os 7 aplicativos em `bin\`: `mmenu.exe`, `mscript.exe`, `mvisual.exe`, `mboard.exe`, `msound.exe`, `mscene.exe`, `mcut.exe`.
3. Copia `sqlite3.dll` Win64 e `templates\maurinmovie_empty.db` para `bin\` e `dist\app\`.
4. Executa as suítes de testes `tests\test_mmp_protocol.pas` e `tests\common\test_mmp_media.pas` (esta usa o ffmpeg do PATH; sem ele, é pulada).
5. Copia as DLLs OpenSSL Win64 (`libssl-1_1-x64.dll`, `libcrypto-1_1-x64.dll`, `libssl-3-x64.dll`, `libcrypto-3-x64.dll`, `legacy.dll`) para `bin\` e para o staging `dist\app\`.
6. Gera as imagens do wizard (`prepare_images.ps1`), o manifesto (`build-manifest.json`) e compila `install\windows\maurinmovie.iss` com o `ISCC.exe`.
7. Salva os instaladores e `SHA256SUMS` em `install\`.

## ffmpeg (vídeo e áudio)
O MScene (vídeo dos segmentos e costura das cenas) e o MCut (gravação do filme) usam o **ffmpeg** e o **ffprobe** externos; o reprodutor é o **mpv**, se configurado, ou o programa padrão do sistema. O instalador **não** inclui o ffmpeg (a licença da distribuição escolhida ainda está em aberto, docs/specs/99-lacunas L-14). Instale-o à parte e indique os caminhos em MMenu → Configurações → Ferramentas, ou deixe-o no PATH. Sem libx264, o vídeo sai em MPEG-4 Parte 2.

## Compilação no Linux (desenvolvimento)
Não há instalador Linux; os executáveis podem ser gerados com `lazbuild`:

1. Pacotes do sistema (Debian/Ubuntu): `fpc lazarus-ide lcl-gtk2 lcl-utils libsqlite3-0`.
2. Pacotes Lazarus exigidos pelo CHATGPT: ZeosLib **7.2** (`zcomponent.lpk`; o ramo 8.x não compila com FPC 3.2.2) e os pacotes `openai_core`, `openai_image`, `openai_voice`, `openai_video` do repositório CHATGPT, registrados com `lazbuild --add-package-link <arquivo.lpk>`.
3. `lazbuild -B src/<app>/<app>.lpi` para cada um dos sete aplicativos (saída em `bin/`).

Os aplicativos LCL/GTK2 precisam de um display (use `xvfb-run -a` em servidor), inclusive no modo `--headless`.
