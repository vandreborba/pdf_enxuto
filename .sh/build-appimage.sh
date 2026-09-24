#!/bin/bash
# Compila o PDF Enxuto para Linux e cria um AppImage portátil (não precisa instalar).
#
# Uso:
#   bash .sh/build-appimage.sh
#   SKIP_OPEN_FOLDER=1 bash .sh/build-appimage.sh   # não abre a pasta no fim
#
# Requisitos: Flutter e acesso à internet na primeira execução (baixa o
# appimagetool, que fica em cache em build/tools/).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
# shellcheck source=.sh/lib/version.sh
source "$SCRIPT_DIR/.sh/lib/version.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_NAME="pdf-enxuto"
APP_DISPLAY_NAME="PDF Enxuto"
APP_VERSION="$(get_app_version)"
APP_COMMENT="Compressor e divisor de PDF 100% local"

BUILD_DIR="$SCRIPT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/linux/x64/release/bundle"
APPIMAGE_BUILD_DIR="$BUILD_DIR/appimage"
APPDIR="$APPIMAGE_BUILD_DIR/AppDir"
TOOLS_DIR="$BUILD_DIR/tools"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
RELEASE_DIR="$SCRIPT_DIR/release"
OUTPUT="$RELEASE_DIR/${APP_NAME}_${APP_VERSION}_x86_64.AppImage"

ensure_flutter_ready() {
    if [[ ! -f "$SCRIPT_DIR/.dart_tool/package_graph.json" ]]; then
        flutter pub get
    fi
    if [[ ! -f "$SCRIPT_DIR/.dart_tool/package_graph.json" ]]; then
        echo -e "${RED}❌ Erro: package_graph.json não encontrado após pub get${NC}"
        exit 1
    fi
}

ensure_appimagetool() {
    if [[ -x "$APPIMAGETOOL" ]]; then
        return
    fi
    mkdir -p "$TOOLS_DIR"
    echo -e "${YELLOW}  → Baixando appimagetool (primeira vez)...${NC}"
    local url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$APPIMAGETOOL" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$APPIMAGETOOL" "$url"
    else
        echo -e "${RED}❌ Erro: instale 'curl' ou 'wget' para baixar o appimagetool.${NC}"
        exit 1
    fi
    chmod +x "$APPIMAGETOOL"
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   PDF Enxuto - Build AppImage${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${YELLOW}🧹 Limpando builds anteriores...${NC}"
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR/linux" "$APPIMAGE_BUILD_DIR"

echo -e "${YELLOW}📦 Obtendo dependências...${NC}"
ensure_flutter_ready

echo -e "${YELLOW}🔨 Compilando aplicativo Flutter...${NC}"
flutter build linux --release

if [ ! -x "$BUNDLE_DIR/$APP_NAME" ]; then
    echo -e "${RED}❌ Erro: Executável não encontrado em $BUNDLE_DIR/$APP_NAME${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Montando AppDir...${NC}"
mkdir -p "$APPDIR/usr/bin"
cp -r "$BUNDLE_DIR"/* "$APPDIR/usr/bin/"

echo -e "${YELLOW}  → Criando AppRun...${NC}"
cat > "$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\${0}")")"
export PATH="\$HERE/usr/bin:\$PATH"
exec "\$HERE/usr/bin/$APP_NAME" "\$@"
EOF
chmod +x "$APPDIR/AppRun"

echo -e "${YELLOW}  → Criando atalho .desktop e ícone...${NC}"
if [ ! -f "$SCRIPT_DIR/assets/icons/icon_256.png" ]; then
    echo -e "${RED}❌ Erro: ícone não encontrado em assets/icons/icon_256.png${NC}"
    exit 1
fi
cp "$SCRIPT_DIR/assets/icons/icon_256.png" "$APPDIR/$APP_NAME.png"

cat > "$APPDIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_DISPLAY_NAME
Comment=$APP_COMMENT
Exec=$APP_NAME
Icon=$APP_NAME
Terminal=false
Categories=Utility;Office;Compression;
MimeType=application/pdf;
Keywords=pdf;comprimir;compactar;reduzir;dividir;separar;split;compress;
EOF

ensure_appimagetool

echo -e "${YELLOW}🔧 Construindo AppImage...${NC}"
mkdir -p "$RELEASE_DIR"
rm -f "$OUTPUT"
ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT"

if [ ! -f "$OUTPUT" ]; then
    echo -e "${RED}❌ Erro ao criar o AppImage${NC}"
    exit 1
fi

chmod +x "$OUTPUT"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   ✓ AppImage criado com sucesso!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Arquivo:${NC} $OUTPUT"
echo -e "${BLUE}Tamanho:${NC} $(du -h "$OUTPUT" | cut -f1)"
echo ""
echo -e "${YELLOW}Para usar:${NC}"
echo "  chmod +x $(basename "$OUTPUT")"
echo "  ./$(basename "$OUTPUT")"
echo ""

if [[ "${SKIP_OPEN_FOLDER:-}" != "1" ]] && command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$RELEASE_DIR" >/dev/null 2>&1 || true
fi
