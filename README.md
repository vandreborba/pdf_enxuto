# PDF Enxuto

Compressor, divisor e **conversor de PDF em planilha** — tudo **100% local**, para Linux e
Windows. Sem conta, sem nuvem, sem anúncios — seus arquivos nunca saem do seu computador.

[![Flutter](https://img.shields.io/badge/Flutter-Linux%20%7C%20Windows-blue)](https://github.com/vandreborba/pdf_enxuto)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-pdf__enxuto-181717?logo=github)](https://github.com/vandreborba/pdf_enxuto)

![Tela de compressão](assets/screenshot/tela-comprimir.png)

![Tela de conversão em planilha](assets/screenshot/tela-planilha.png)

## O que faz

- **Comprimir** de dois jeitos, em abas: por **perfil de qualidade** (Leve, Equilibrado,
  Forte, Extremo) ou por **tamanho alvo** ("até 5 MB", por arquivo ou somando todos).
- **Manter o texto selecionável** ou **virar imagem** (máxima redução), com aviso do que
  cada modo custa.
- **Dividir** por intervalos (`1-3, 7, 10-12`), a cada N páginas, por tamanho máximo,
  extraindo páginas escolhidas ou pelos **marcadores** do documento.
- **Converter em planilha**: transforma as tabelas do PDF em **planilha (XLSX, que abre no
  Excel e no LibreOffice Calc) ou CSV** — extratos, notas fiscais, relatórios e listagens
  viram linhas e colunas de verdade, com números e datas somáveis. Tem **prévia** das
  tabelas encontradas, controle de separação das colunas e opção de ignorar cabeçalho e
  rodapé repetidos. PDFs que são só imagem (digitalização) são avisados com clareza: para
  esses seria preciso OCR, que o app não faz.
- Vários arquivos de uma vez, com progresso por arquivo, cancelar e histórico do quanto
  você já economizou.
- Ajuda **"?"** em cada opção, em português claro.
- Arraste PDFs para a janela, cole do gerenciador de arquivos ou use `Ctrl+O`.

## Motores

Funciona **sem instalar nada**: o motor próprio (pdfium + leitor/escritor de PDF em Dart)
já vem junto. Se o **Ghostscript** ou o **qpdf** estiverem instalados, o app usa o melhor
disponível — e mostra na interface como instalá-los:

```bash
sudo apt install ghostscript qpdf
```

## Instalação

- **Linux:** baixe o AppImage em [Releases](https://github.com/vandreborba/pdf_enxuto/releases/latest),
  dê permissão de execução e rode — não precisa instalar:

  ```bash
  chmod +x pdf-enxuto_*.AppImage
  ./pdf-enxuto_*.AppImage
  ```

- **Windows:** baixe o ZIP, extraia e execute `pdf_enxuto.exe`.

## Desenvolvimento

```bash
flutter pub get
flutter run -d linux      # ou -d windows
flutter test              # 80 testes
bash .sh/build-desktop.sh   # AppImage local + Windows ZIP (GitHub Actions)
bash .sh/release.sh         # bump + testes + AppImage + Windows + release
```

Cores de destaque (troca em Configurações → Aparência):

![Cores](assets/branding/cores-sobrias.png)

## Licença

GPL-3.0. Veja [LICENSE](LICENSE).

Problemas e sugestões: [vandreapps@gmail.com](mailto:vandreapps@gmail.com)
