#!/bin/bash
# Dispara o build desktop no GitHub Actions (Windows ZIP + Linux AppImage)
# e baixa os dois pacotes.
#
# Uso:
#   bash .sh/build-desktop.sh
#   bash .sh/build-desktop.sh --no-prompt   # sem avisos de git (usado pelo release.sh)
#
# Requisitos: gh autenticado (gh auth login) e o workflow já enviado ao GitHub.
# O build Windows/AppImage não roda localmente — usa os runners do GitHub.

set -e

# shellcheck disable=SC1090
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"

export PATH="$HOME/flutter/bin:$PATH"

NO_PROMPT=0
for arg in "$@"; do
    if [[ "$arg" == "--no-prompt" ]]; then
        NO_PROMPT=1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
# shellcheck source=.sh/lib/version.sh
source "$SCRIPT_DIR/.sh/lib/version.sh"

GITHUB_REPO="vandreborba/pdf_enxuto"
GITHUB_BRANCH="main"
WORKFLOW_NAME="Build Desktop"
WINDOWS_DIR="$SCRIPT_DIR/release/windows"
APPIMAGE_DIR="$SCRIPT_DIR/release"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   PDF Enxuto - Build Desktop${NC}"
echo -e "${BLUE}   (Windows ZIP + Linux AppImage)${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [[ "$NO_PROMPT" -eq 0 ]]; then
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  AVISO: faça commit e push antes de compilar!                    ║${NC}"
    echo -e "${YELLOW}║                                                                  ║${NC}"
    echo -e "${YELLOW}║  O build roda no GitHub com o código do último push.             ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
fi

cd "$SCRIPT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}ERRO: não é um repositório git.${NC}"
    exit 1
fi

if [[ "$NO_PROMPT" -eq 0 ]]; then
    PENDING_CHANGES=$(git status --porcelain)
    if [ -n "$PENDING_CHANGES" ]; then
        echo -e "${YELLOW}Alterações pendentes detectadas:${NC}"
        echo "$PENDING_CHANGES"
        echo ""
        echo "Sugestão:"
        echo "  git add -A"
        echo "  git commit -m \"Sua mensagem\""
        echo "  git push origin $GITHUB_BRANCH"
        echo ""
        read -r -p "Continuar mesmo assim? [s/N] " ANSWER
        if [[ ! "$ANSWER" =~ ^[sS]$ ]]; then
            echo "Compilação cancelada."
            exit 1
        fi
        echo ""
    else
        echo -e "${GREEN}✓ Working tree limpo — pronto para compilar.${NC}"
        echo ""
    fi
fi

VERSION="$(get_app_version)"
if [ -z "$VERSION" ]; then
    VERSION="dev"
    echo -e "${YELLOW}AVISO: versão não encontrada no pubspec. Usando sufixo 'dev'.${NC}"
fi

ZIP_NAME="pdf-enxuto_windows_${VERSION}.zip"
APPIMAGE_NAME="pdf-enxuto_${VERSION}_x86_64.AppImage"
mkdir -p "$WINDOWS_DIR"
rm -f "$WINDOWS_DIR"/*.zip 2>/dev/null || true
rm -f "$APPIMAGE_DIR"/*.AppImage 2>/dev/null || true

echo -e "${BLUE}Versão:${NC} $VERSION"
echo -e "${BLUE}Saída:${NC}  $WINDOWS_DIR"
echo -e "${BLUE}        ${NC} $APPIMAGE_DIR"
echo ""

echo -e "${YELLOW}=== Disparando build desktop no GitHub Actions ===${NC}"

if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}ERRO: 'gh' não instalado. Instale: sudo apt install gh${NC}"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}ERRO: 'gh' não autenticado. Execute: gh auth login${NC}"
    exit 1
fi

gh workflow run "$WORKFLOW_NAME" --repo "$GITHUB_REPO" --ref "$GITHUB_BRANCH"

echo "Aguardando o run aparecer no GitHub..."
sleep 5

RUN_ID=$(gh run list --repo "$GITHUB_REPO" --workflow "$WORKFLOW_NAME" \
    --limit 1 --json databaseId --jq '.[0].databaseId')
RUN_URL=$(gh run list --repo "$GITHUB_REPO" --workflow "$WORKFLOW_NAME" \
    --limit 1 --json url --jq '.[0].url')

echo -e "${GREEN}✓ Build enfileirado.${NC}"
echo "  Run ID: $RUN_ID"
echo "  URL:    $RUN_URL"
echo ""

DEST_ZIP="$WINDOWS_DIR/$ZIP_NAME"
DEST_APPIMAGE="$APPIMAGE_DIR/$APPIMAGE_NAME"
TEMP_DOWNLOAD="$APPIMAGE_DIR/.download-tmp"

echo -e "${YELLOW}=== Aguardando build desktop no GitHub (~10-20 min) ===${NC}"
echo "  Acompanhe: $RUN_URL"
echo ""

if gh run watch "$RUN_ID" --repo "$GITHUB_REPO" --exit-status; then
    echo ""
    echo -e "${YELLOW}=== Baixando pacotes (Windows ZIP + Linux AppImage) ===${NC}"
    rm -rf "$TEMP_DOWNLOAD"
    mkdir -p "$TEMP_DOWNLOAD"

    if gh run download "$RUN_ID" --repo "$GITHUB_REPO" -D "$TEMP_DOWNLOAD"; then
        DOWNLOADED_ZIP=$(find "$TEMP_DOWNLOAD" -name "*.zip" -type f | head -1)
        DOWNLOADED_APPIMAGE=$(find "$TEMP_DOWNLOAD" -name "*.AppImage" -type f | head -1)

        if [ -z "$DOWNLOADED_ZIP" ] || [ -z "$DOWNLOADED_APPIMAGE" ]; then
            rm -rf "$TEMP_DOWNLOAD"
            echo -e "${RED}ERRO: download concluído, mas algum artefato não foi encontrado.${NC}"
            echo "  ZIP:      ${DOWNLOADED_ZIP:-não encontrado}"
            echo "  AppImage: ${DOWNLOADED_APPIMAGE:-não encontrado}"
            exit 1
        fi

        mv "$DOWNLOADED_ZIP" "$DEST_ZIP"
        mv "$DOWNLOADED_APPIMAGE" "$DEST_APPIMAGE"
        rm -rf "$TEMP_DOWNLOAD"

        echo ""
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}   ✓ Build Desktop concluído!${NC}"
        echo -e "${GREEN}=========================================${NC}"
        echo ""
        echo -e "${BLUE}Windows:${NC}  $DEST_ZIP ($(du -h "$DEST_ZIP" | cut -f1))"
        echo -e "${BLUE}AppImage:${NC} $DEST_APPIMAGE ($(du -h "$DEST_APPIMAGE" | cut -f1))"
        echo ""
        echo -e "${YELLOW}Para usar no Windows:${NC}"
        echo "  1. Extraia o ZIP"
        echo "  2. Execute pdf_enxuto.exe"
        echo ""
        echo -e "${YELLOW}Para usar no Linux (AppImage):${NC}"
        echo "  chmod +x $(basename "$DEST_APPIMAGE")"
        echo "  ./$(basename "$DEST_APPIMAGE")"
        echo ""

        if [[ "$NO_PROMPT" -eq 0 ]] && command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$WINDOWS_DIR" >/dev/null 2>&1 || true
        fi
    else
        rm -rf "$TEMP_DOWNLOAD"
        echo -e "${RED}ERRO: falha ao baixar os artefatos.${NC}"
        exit 1
    fi
else
    echo -e "${RED}ERRO: build falhou no GitHub.${NC}"
    echo "  Veja os logs: $RUN_URL"
    exit 1
fi
