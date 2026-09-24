#!/bin/bash
# Release unificado: bump de versão, build desktop (Windows ZIP + Linux AppImage) e publicação.
#
# Uso:
#   bash .sh/release.sh              # patch automático ou versão digitada
#   bash .sh/release.sh 1.1.0        # versão manual (build number +1)
#
# Requisitos: Flutter, gh autenticado (gh auth login).

set -e

# shellcheck disable=SC1090
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"

export PATH="$HOME/flutter/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
# shellcheck source=.sh/lib/version.sh
source "$SCRIPT_DIR/.sh/lib/version.sh"

GITHUB_REPO="vandreborba/pdf_enxuto"
GITHUB_BRANCH="main"
APP_NAME="pdf-enxuto"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$SCRIPT_DIR"

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   PDF Enxuto - Release${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}ERRO: 'gh' não instalado. Instale: sudo apt install gh${NC}"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}ERRO: 'gh' não autenticado. Execute: gh auth login${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Versão: patch automático ou manual
# ---------------------------------------------------------------------------
CURRENT_FULL="$(get_pubspec_version_line)"
CURRENT_SEMVER="$(get_app_version "$CURRENT_FULL")"
CURRENT_BUILD="$(get_build_number "$CURRENT_FULL")"
AUTO_SEMVER="$(bump_version_patch "$CURRENT_SEMVER")"
NEW_BUILD="$(bump_build_number "$CURRENT_BUILD")"
NEW_SEMVER="$AUTO_SEMVER"

echo -e "${BLUE}Versão atual:${NC}     $CURRENT_FULL"
echo -e "${BLUE}Sugestão (patch):${NC} ${AUTO_SEMVER}+${NEW_BUILD}"
echo ""

if [[ -n "${1:-}" ]]; then
    if ! is_valid_semver "$1"; then
        echo -e "${RED}ERRO: versão inválida '$1'. Use o formato X.Y.Z (ex: 1.1.0)${NC}"
        exit 1
    fi
    NEW_SEMVER="$1"
    echo -e "${GREEN}Versão manual via argumento: $NEW_SEMVER+${NEW_BUILD}${NC}"
    echo ""
else
    echo "Opções:"
    echo "  [Enter]  usar patch automático (${AUTO_SEMVER})"
    echo "  1.1.0    digitar versão manual (semver)"
    echo "  n        cancelar"
    echo ""
    read -r -p "Nova versão: " VERSION_INPUT

    if [[ "$VERSION_INPUT" =~ ^[nN]$ ]]; then
        echo "Release cancelada."
        exit 0
    fi

    if [[ -n "$VERSION_INPUT" ]]; then
        if ! is_valid_semver "$VERSION_INPUT"; then
            echo -e "${RED}ERRO: versão inválida '$VERSION_INPUT'.${NC}"
            exit 1
        fi
        NEW_SEMVER="$VERSION_INPUT"
    fi
fi

NEW_FULL="${NEW_SEMVER}+${NEW_BUILD}"

echo -e "${BLUE}Versão da release:${NC} $NEW_FULL"
echo ""
read -r -p "Continuar com a release? [S/n] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]?$ ]] && [[ -n "$CONFIRM" ]]; then
    echo "Release cancelada."
    exit 0
fi
echo ""

set_pubspec_version "$SCRIPT_DIR" "$NEW_SEMVER" "$NEW_BUILD"
echo -e "${GREEN}✓ pubspec.yaml atualizado para $NEW_FULL${NC}"
echo ""

# ---------------------------------------------------------------------------
# Testes antes de publicar
# ---------------------------------------------------------------------------
echo -e "${YELLOW}=== Testes ===${NC}"
flutter test
echo ""

# ---------------------------------------------------------------------------
# Commit e push (código + versão, sem binários)
# ---------------------------------------------------------------------------
echo -e "${YELLOW}=== Commit e push ===${NC}"

git reset HEAD -- release/*.deb release/*.AppImage release/windows/*.zip 2>/dev/null || true
git add -A
git reset HEAD -- release/*.deb release/*.AppImage release/windows/*.zip 2>/dev/null || true

if git diff --cached --quiet; then
    echo -e "${YELLOW}Nenhuma alteração de código para commitar (apenas versão).${NC}"
    git add pubspec.yaml
fi

if ! git diff --cached --quiet; then
    git commit -m "Bump versão para $NEW_FULL"
    echo -e "${GREEN}✓ Commit criado${NC}"
else
    echo -e "${YELLOW}Nada novo para commitar.${NC}"
fi

echo -e "${YELLOW}Enviando para origin/$GITHUB_BRANCH...${NC}"
git push origin "$GITHUB_BRANCH"
echo -e "${GREEN}✓ Push concluído${NC}"
echo ""

# ---------------------------------------------------------------------------
# Build desktop (AppImage local + Windows ZIP via GitHub Actions)
# ---------------------------------------------------------------------------
echo -e "${YELLOW}=== Build desktop (Linux AppImage + Windows ZIP) ===${NC}"
bash "$SCRIPT_DIR/.sh/build-desktop.sh" --no-prompt
echo ""

# ---------------------------------------------------------------------------
# Validar artefatos
# ---------------------------------------------------------------------------
APPIMAGE_FILE="$SCRIPT_DIR/release/${APP_NAME}_${NEW_SEMVER}_x86_64.AppImage"
ZIP_FILE="$SCRIPT_DIR/release/windows/${APP_NAME}_windows_${NEW_SEMVER}.zip"
TAG="v${NEW_SEMVER}"

echo -e "${YELLOW}=== Validando artefatos ===${NC}"

MISSING=0
if [[ ! -f "$APPIMAGE_FILE" ]]; then
    echo -e "${RED}✗ AppImage não encontrado: $APPIMAGE_FILE${NC}"
    MISSING=1
else
    echo -e "${GREEN}✓ $(basename "$APPIMAGE_FILE")${NC}"
fi

if [[ ! -f "$ZIP_FILE" ]]; then
    echo -e "${RED}✗ ZIP não encontrado: $ZIP_FILE${NC}"
    MISSING=1
else
    echo -e "${GREEN}✓ $(basename "$ZIP_FILE")${NC}"
fi

if [[ "$MISSING" -eq 1 ]]; then
    echo -e "${RED}ERRO: artefatos faltando. Release não criada.${NC}"
    exit 1
fi
echo ""

# ---------------------------------------------------------------------------
# Criar release no GitHub
# ---------------------------------------------------------------------------
echo -e "${YELLOW}=== Criando release $TAG no GitHub ===${NC}"

NOTES_FILE="$(mktemp)"
NOTAS_MANUAIS="$SCRIPT_DIR/.sh/notas/${TAG}.md"

if [[ -f "$NOTAS_MANUAIS" ]]; then
    # Notas escritas à mão para esta versão (.sh/notas/vX.Y.Z.md).
    cat "$NOTAS_MANUAIS" > "$NOTES_FILE"
else
    cat > "$NOTES_FILE" <<EOF
## PDF Enxuto $TAG

Compressor e divisor de PDF **100% local**: nada sai do seu computador.
Sem conta, sem nuvem, sem anúncios.

### O que faz

- **Comprimir** por perfil de qualidade (Leve, Equilibrado, Forte, Extremo)
  ou por **tamanho alvo** ("até 5 MB", por arquivo ou somando todos).
- **Manter o texto selecionável** ou **virar imagem** (máxima redução).
- **Dividir** por intervalos (\`1-3, 7, 10-12\`), a cada N páginas, por
  tamanho máximo, páginas escolhidas ou pelos marcadores do documento.
- Vários arquivos de uma vez, com progresso por arquivo, cancelar e
  histórico do quanto você já economizou.
- Arraste PDFs para a janela ou use \`Ctrl+O\`.

Funciona **sem instalar nada**: o motor próprio (pdfium + leitor/escritor
de PDF em Dart) já vem junto.

### Linux (AppImage)

Baixe o AppImage, dê permissão de execução e rode — não precisa instalar:

\`\`\`bash
chmod +x ${APP_NAME}_${NEW_SEMVER}_x86_64.AppImage
./${APP_NAME}_${NEW_SEMVER}_x86_64.AppImage
\`\`\`

### Windows

Baixe o ZIP, extraia e execute \`pdf_enxuto.exe\`.

### Motores opcionais (resultados ainda melhores)

Se quiser resultados ainda melhores, instale o Ghostscript e o qpdf:

\`\`\`bash
sudo apt install ghostscript qpdf
\`\`\`

O próprio aplicativo mostra essas instruções em **Configurações → Motores**.
EOF
fi

if gh release view "$TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
    echo -e "${RED}ERRO: release $TAG já existe no GitHub.${NC}"
    rm -f "$NOTES_FILE"
    exit 1
fi

gh release create "$TAG" \
    --repo "$GITHUB_REPO" \
    --title "PDF Enxuto $TAG" \
    --notes-file "$NOTES_FILE" \
    "$APPIMAGE_FILE" \
    "$ZIP_FILE"

rm -f "$NOTES_FILE"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   ✓ Release publicada com sucesso!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}URL:${NC} https://github.com/$GITHUB_REPO/releases/tag/$TAG"
echo ""
