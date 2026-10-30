#!/bin/bash
# Prepara o Tesseract (OCR) para ir dentro do pacote do app, em build/ocr:
#
#   build/ocr/tesseract        o programa
#   build/ocr/lib/             as bibliotecas de que ele depende
#   build/ocr/tessdata/        os idiomas (tessdata_fast, os menores) e configs
#
# O app procura essa pasta ao lado do executável (veja motor_tesseract.dart).
# Os scripts de AppImage e .deb chamam este automaticamente.
#
# Uso:
#   bash .sh/preparar-ocr.sh
#   OCR_IDIOMAS="por eng spa" bash .sh/preparar-ocr.sh
#
# Requisitos: tesseract instalado na máquina de build (sudo apt install
# tesseract-ocr) e internet na primeira vez (baixa os idiomas; ficam em cache
# em build/tools/tessdata_fast).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
OUT="$SCRIPT_DIR/build/ocr"
CACHE="$SCRIPT_DIR/build/tools/tessdata_fast"
IDIOMAS="${OCR_IDIOMAS:-por eng spa fra deu ita}"
URL_BASE="https://github.com/tesseract-ocr/tessdata_fast/raw/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESSERACT="$(command -v tesseract || true)"
if [ -z "$TESSERACT" ]; then
    echo -e "${RED}❌ tesseract não encontrado. Instale: sudo apt install tesseract-ocr${NC}"
    exit 1
fi

echo -e "${YELLOW}🔤 Preparando o Tesseract para o pacote...${NC}"
rm -rf "$OUT"
mkdir -p "$OUT/lib" "$OUT/tessdata" "$CACHE"

cp -L "$TESSERACT" "$OUT/tesseract"

# Bibliotecas: tudo o que o ldd lista, menos o núcleo da glibc (que precisa
# ser a do sistema onde o app roda).
ldd "$TESSERACT" | awk '/=> \//{print $3}' | while read -r lib; do
    case "$(basename "$lib")" in
        libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|libresolv.so*|libutil.so*|ld-linux*) ;;
        *) cp -L "$lib" "$OUT/lib/" ;;
    esac
done

# O formato "tsv" que o app usa é um arquivo de configuração do Tesseract.
SISTEMA_DADOS=""
for pasta in /usr/share/tesseract-ocr/*/tessdata /usr/share/tessdata /usr/local/share/tessdata; do
    if [ -d "$pasta/configs" ]; then SISTEMA_DADOS="$pasta"; break; fi
done
if [ -z "$SISTEMA_DADOS" ]; then
    echo -e "${RED}❌ Não achei a pasta tessdata/configs do sistema.${NC}"
    exit 1
fi
cp -r "$SISTEMA_DADOS/configs" "$OUT/tessdata/"
[ -d "$SISTEMA_DADOS/tessconfigs" ] && cp -r "$SISTEMA_DADOS/tessconfigs" "$OUT/tessdata/"

for idioma in $IDIOMAS; do
    arquivo="$CACHE/$idioma.traineddata"
    if [ ! -s "$arquivo" ]; then
        echo "  → Baixando idioma: $idioma"
        if ! curl -fsSL -o "$arquivo.parcial" "$URL_BASE/$idioma.traineddata"; then
            rm -f "$arquivo.parcial"
            if [ -s "$SISTEMA_DADOS/$idioma.traineddata" ]; then
                echo "    (sem internet: usando o idioma instalado no sistema)"
                cp "$SISTEMA_DADOS/$idioma.traineddata" "$arquivo.parcial"
            else
                echo -e "${RED}❌ Não consegui obter o idioma $idioma${NC}"
                exit 1
            fi
        fi
        mv "$arquivo.parcial" "$arquivo"
    fi
    cp "$arquivo" "$OUT/tessdata/"
done

# Conferência: roda do jeito que o app vai rodar, sem o ambiente do sistema.
if ! LD_LIBRARY_PATH="$OUT/lib" "$OUT/tesseract" --tessdata-dir "$OUT/tessdata" --list-langs >/dev/null 2>&1; then
    echo -e "${RED}❌ O Tesseract preparado não executa. Veja: LD_LIBRARY_PATH=$OUT/lib $OUT/tesseract --version${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Tesseract pronto em build/ocr ($(du -sh "$OUT" | cut -f1))${NC}"
