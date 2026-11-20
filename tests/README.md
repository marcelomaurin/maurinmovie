# Testes

Uma pasta por programa (`mmenu/`, `mscript/`, `mvisual/`, `mboard/`, `msound/`, `mscene/`, `mcut/`) e `common/` para o código compartilhado.

## Teste de montagem de vídeo

`test_mmp_video.pas` testa a montagem com FFmpeg e FFprobe, incluindo um clipe sem áudio, corte, dissolve, MP4, MKV, preservação de exportação anterior e rejeição de cortes inválidos. Exemplo em Linux, a partir da raiz do repositório:

```bash
tmp="$(mktemp -d)"
fpc -Fusrc/common -FU"$tmp" -FE"$tmp" tests/test_mmp_video.pas
ffmpeg -v error -f lavfi -i color=red:s=160x90:r=25 -f lavfi -i sine=f=440 -t 2 -c:v libx264 -c:a aac "$tmp/com audio.mp4"
ffmpeg -v error -f lavfi -i color=blue:s=120x90:r=30 -t 2 -c:v libx264 "$tmp/sem audio.mp4"
"$tmp/test_mmp_video" "$(command -v ffmpeg)" "$(command -v ffprobe)" "$tmp/com audio.mp4" "$tmp/sem audio.mp4" "$tmp/resultados"
```


## Testes de áudio e cascata

Compile `tests/test_mmp_audio.pas` com `fpc -Fusrc/common`. Gere dois WAV de teste com FFmpeg, um tom de 440 Hz e outro de 660 Hz, ambos de dois segundos. Rode `test_mmp_audio <ffmpeg> <fala.wav> <efeito.wav> <pasta-de-saída>` e depois `python3 tests/check_mmp_audio.py <pasta-de-saída>`. A leitura do PCM confere atrasos, sobreposição, volume, duração e o recorte do segmento.

`test_mmp_cascade.pas` usa as unidades comuns e o LCL de Lazarus. Execute com o widgetset sem interface gráfica e passe o executável compilado do MScript e uma pasta vazia. O teste cria uma produção, aplica de fato um evento editorial no MScript, retoma a transação e verifica as revisões vinculadas.
