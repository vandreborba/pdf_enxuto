#!/bin/bash

# Compila o PDF Enxuto e cria o pacote .deb para Linux.
# Uso: bash .sh/build-deb.sh

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
APP_DESCRIPTION="Compressor e divisor de PDF 100% local"
APP_MAINTAINER="Vandre Borba <vandreapps@gmail.com>"
APP_HOMEPAGE="https://github.com/vandreborba/pdf_enxuto"

BUILD_DIR="$SCRIPT_DIR/build"
DEB_DIR="$BUILD_DIR/deb"
DEB_PKG_DIR="$DEB_DIR/${APP_NAME}_${APP_VERSION}_amd64"

# Garante .dart_tool e dependências antes do build (evita falha após clean).
ensure_flutter_ready() {
    if [[ ! -f "$SCRIPT_DIR/.dart_tool/package_graph.json" ]]; then
        flutter pub get
    fi
    if [[ ! -f "$SCRIPT_DIR/.dart_tool/package_graph.json" ]]; then
        echo -e "${RED}❌ Erro: package_graph.json não encontrado após pub get${NC}"
        exit 1
    fi
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   PDF Enxuto - Build .deb${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${YELLOW}🧹 Limpando builds anteriores...${NC}"
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR/linux" "$DEB_DIR"

echo -e "${YELLOW}📦 Obtendo dependências...${NC}"
ensure_flutter_ready

echo -e "${YELLOW}🔨 Compilando aplicativo Flutter...${NC}"
flutter build linux --release

if [ ! -f "$BUILD_DIR/linux/x64/release/bundle/$APP_NAME" ]; then
    echo -e "${RED}❌ Erro: Executável não encontrado!${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Criando estrutura do pacote .deb...${NC}"

mkdir -p "$DEB_PKG_DIR/DEBIAN"
mkdir -p "$DEB_PKG_DIR/opt/$APP_NAME"
mkdir -p "$DEB_PKG_DIR/usr/share/applications"
mkdir -p "$DEB_PKG_DIR/usr/share/pixmaps"
mkdir -p "$DEB_PKG_DIR/usr/local/bin"

echo -e "${YELLOW}  → Copiando arquivos do aplicativo...${NC}"
cp -r "$BUILD_DIR/linux/x64/release/bundle"/* "$DEB_PKG_DIR/opt/$APP_NAME/"

echo -e "${YELLOW}  → Criando arquivo de controle...${NC}"
cat > "$DEB_PKG_DIR/DEBIAN/control" <<EOF
Package: $APP_NAME
Version: $APP_VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libglib2.0-0, libc6
Recommends: ghostscript, qpdf
Maintainer: $APP_MAINTAINER
Description: $APP_DESCRIPTION
 Comprime e divide arquivos PDF sem enviar nada para a internet.
 Tem motor proprio embutido e aproveita o Ghostscript/qpdf quando
 estao instalados.
Homepage: $APP_HOMEPAGE
EOF

if [ ! -f "$DEB_PKG_DIR/DEBIAN/control" ]; then
    echo -e "${RED}❌ Erro ao criar arquivo de controle!${NC}"
    exit 1
fi

echo -e "${YELLOW}  → Criando scripts de instalação...${NC}"
cat > "$DEB_PKG_DIR/DEBIAN/postinst" <<EOF
#!/bin/bash
set -e

if [ ! -L /usr/local/bin/$APP_NAME ]; then
    ln -sf /opt/$APP_NAME/$APP_NAME /usr/local/bin/$APP_NAME
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi

if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database /usr/share/mime || true
fi

echo ""
echo "✓ PDF Enxuto instalado com sucesso!"
echo "  Abra pelo menu de aplicativos ou execute: $APP_NAME"
echo ""
echo "Opcional (resultados ainda melhores):"
echo "  sudo apt install ghostscript qpdf"
echo ""

exit 0
EOF

chmod +x "$DEB_PKG_DIR/DEBIAN/postinst"

cat > "$DEB_PKG_DIR/DEBIAN/prerm" <<EOF
#!/bin/bash
set -e

if [ -L /usr/local/bin/$APP_NAME ]; then
    rm -f /usr/local/bin/$APP_NAME
fi

exit 0
EOF

chmod +x "$DEB_PKG_DIR/DEBIAN/prerm"

echo -e "${YELLOW}  → Criando arquivo .desktop...${NC}"
cat > "$DEB_PKG_DIR/usr/share/applications/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_DISPLAY_NAME
Comment=$APP_DESCRIPTION
Exec=/opt/$APP_NAME/$APP_NAME %f
Icon=$APP_NAME
Terminal=false
Categories=Utility;Office;Compression;
MimeType=application/pdf;
StartupNotify=true
StartupWMClass=$APP_NAME
Keywords=pdf;comprimir;compactar;reduzir;dividir;separar;split;compress;
EOF

echo -e "${YELLOW}  → Copiando ícone...${NC}"
if [ -f "$SCRIPT_DIR/assets/icons/icon.png" ]; then
    cp "$SCRIPT_DIR/assets/icons/icon.png" "$DEB_PKG_DIR/usr/share/pixmaps/$APP_NAME.png"
    echo -e "${GREEN}    ✓ Ícone copiado${NC}"
else
    echo -e "${RED}    ✗ Ícone não encontrado em assets/icons/icon.png${NC}"
    exit 1
fi

echo -e "${YELLOW}  → Configurando permissões...${NC}"
find "$DEB_PKG_DIR" -type d -exec chmod 755 {} \;
find "$DEB_PKG_DIR/opt" -type f -exec chmod 644 {} \;
find "$DEB_PKG_DIR/usr" -type f -exec chmod 644 {} \;
chmod +x "$DEB_PKG_DIR/opt/$APP_NAME/$APP_NAME"
chmod 755 "$DEB_PKG_DIR/DEBIAN"
chmod 644 "$DEB_PKG_DIR/DEBIAN/control"
chmod 755 "$DEB_PKG_DIR/DEBIAN/postinst"
chmod 755 "$DEB_PKG_DIR/DEBIAN/prerm"

echo -e "${YELLOW}🔧 Construindo pacote .deb...${NC}"

if [ ! -f "$DEB_PKG_DIR/DEBIAN/control" ]; then
    echo -e "${RED}❌ Erro: Arquivo control não encontrado!${NC}"
    exit 1
fi

cd "$DEB_DIR"
dpkg-deb --build --root-owner-group "${APP_NAME}_${APP_VERSION}_amd64"

DEB_FILE="$DEB_DIR/${APP_NAME}_${APP_VERSION}_amd64.deb"
if [ -f "$DEB_FILE" ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}   ✓ Pacote .deb criado com sucesso!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${BLUE}Localização:${NC} $DEB_FILE"
    echo -e "${BLUE}Tamanho:${NC} $(du -h "$DEB_FILE" | cut -f1)"
    echo ""
    echo -e "${YELLOW}Para instalar:${NC}"
    echo -e "  sudo dpkg -i $DEB_FILE"
    echo -e "  sudo apt-get install -f  ${NC}# Se houver dependências faltando"
    echo ""
    echo -e "${YELLOW}Para desinstalar:${NC}"
    echo -e "  sudo apt-get remove $APP_NAME"
    echo ""

    echo -e "${BLUE}Informações do pacote:${NC}"
    dpkg-deb --info "$DEB_FILE"

    echo ""
    echo -e "${YELLOW}📦 Copiando para pasta release...${NC}"
    RELEASE_DIR="$SCRIPT_DIR/release"
    mkdir -p "$RELEASE_DIR"
    cp "$DEB_FILE" "$RELEASE_DIR/"
    echo -e "${GREEN}✓ Arquivo copiado para release/${NC}"

    if [[ "${SKIP_OPEN_FOLDER:-}" != "1" ]]; then
        echo ""
        echo -e "${YELLOW}Abrindo pasta do pacote...${NC}"
        xdg-open "$DEB_DIR" 2>/dev/null || true
    fi
else
    echo -e "${RED}❌ Erro ao criar pacote .deb${NC}"
    exit 1
fi
