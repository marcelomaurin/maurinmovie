# Testes — common

Testes da biblioteca compartilhada `src/common/`.

| Teste | O que cobre |
|---|---|
| [../test_mmp_protocol.pas](../test_mmp_protocol.pas) | IDs, revisões, manifestos MMP, auditoria, prevenção de ciclos |
| [test_mmp_media.pas](test_mmp_media.pas) | `ummpmedia`: áudio do segmento (duração com falas e mínima), animática com dois quadros, um quadro e nenhum, costura de cena, filme MP4 com corte, fusão e fade final (duração esperada), filme MKV sem perdas e quadro de prévia. Gera os insumos com o próprio ffmpeg; sem ffmpeg/ffprobe no PATH, informa `[SKIP]` e sai com 0 |

```bash
fpc -MObjFPC -Scghi -O1 -Fusrc/common -FUbuild/tests -obuild/tests/test_mmp_media tests/common/test_mmp_media.pas
./build/tests/test_mmp_media
```
