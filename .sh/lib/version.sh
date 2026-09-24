#!/bin/bash
# Funções compartilhadas para leitura e bump de versão no pubspec.yaml.

# Retorna o diretório raiz do projeto (parent de .sh).
get_project_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
    if [[ "$script_dir" == */.sh/lib ]]; then
        cd "$script_dir/../../" && pwd
    elif [[ "$script_dir" == */.sh ]]; then
        cd "$script_dir/../" && pwd
    else
        echo "$script_dir"
    fi
}

# Lê a linha version: do pubspec.yaml (ex: 1.0.0+6).
get_pubspec_version_line() {
    local root="${1:-$(get_project_root)}"
    grep -oP '^version:\s*\K\S+' "$root/pubspec.yaml" | head -1
}

# Parte semver (ex: 1.0.0).
get_app_version() {
    local full="${1:-$(get_pubspec_version_line)}"
    echo "${full%%+*}"
}

# Número de build (ex: 6). Retorna 0 se não houver +.
get_build_number() {
    local full="${1:-$(get_pubspec_version_line)}"
    if [[ "$full" == *"+"* ]]; then
        echo "${full#*+}"
    else
        echo "0"
    fi
}

# Incrementa patch na semver (1.2.1 -> 1.2.2).
bump_version_patch() {
    local version="$1"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    patch=$((patch + 1))
    echo "${major}.${minor}.${patch}"
}

# Incrementa build number.
bump_build_number() {
    local build="${1:-0}"
    echo $((build + 1))
}

# Escreve version: X.Y.Z+N no pubspec.yaml.
set_pubspec_version() {
    local root semver build full
    root="${1:-$(get_project_root)}"
    semver="$2"
    build="$3"
    full="${semver}+${build}"

    if [[ ! -f "$root/pubspec.yaml" ]]; then
        echo "ERRO: pubspec.yaml não encontrado em $root" >&2
        return 1
    fi

    sed -i "s/^version: .*/version: $full/" "$root/pubspec.yaml"
}

# Calcula nova versão após bump patch + build.
compute_bumped_version() {
    local full current_semver current_build new_semver new_build
    full="$(get_pubspec_version_line)"
    current_semver="$(get_app_version "$full")"
    current_build="$(get_build_number "$full")"
    new_semver="$(bump_version_patch "$current_semver")"
    new_build="$(bump_build_number "$current_build")"
    echo "${new_semver}+${new_build}"
}

# Valida formato semver X.Y.Z
is_valid_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
