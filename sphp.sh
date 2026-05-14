#!/usr/bin/env bash
# Shell script for switching between Brew-installed PHP versions
#
# Copyright (c) 2026 Andy Miller
# Released under the MIT License
#
# Creator: Phil Cook
# Modified: Andy Miller
#
# More information: https://github.com/rhukster/sphp.sh

set -euo pipefail

script_version=1.2.0


# ----------------------------------------------------------------------------
# Helper functions
#

# Use macOS native grep to avoid GNU grep >=3.8 warnings (see #1).
grep() { /usr/bin/grep "$@"; }

# Use macOS native sed to avoid No such file or directory error with GNU sed (see #19)
sed() { /usr/bin/sed "$@"; }

# Print "<module> <lib_path>" for the given PHP version (X.Y or php@X.Y).
# Covers PHP 5/7/8 and forward-compatible for 9+ (assumed to keep the 8.x layout).
apache_module_and_lib() {
    local version="${1#php@}"
    local major="${version%%.*}"
    case "$major" in
        5)   echo "php5_module /lib/httpd/modules/libphp5.so" ;;
        6|7) echo "php7_module /lib/httpd/modules/libphp7.so" ;;
        *)   echo "php_module /lib/httpd/modules/libphp.so" ;;
    esac
}

# Escape a string for use in a sed BRE/ERE pattern.
sed_escape() {
    local s=$*
    s=${s//\\/\\\\}
    s=${s//\//\\/}
    s=${s//./\\.}
    s=${s//\*/\\*}
    s=${s//\[/\\[}
    s=${s//\]/\\]}
    s=${s//\^/\\^}
    s=${s//\$/\\\$}
    echo "$s"
}

# Test whether the first argument is present in the remaining arguments.
in_array() {
    local needle=$1 item
    shift
    for item in "$@"; do
        [[ $item == "$needle" ]] && return 0
    done
    return 1
}

usage() {
    local installed_versions=("$@")
    cat <<EOF
PHP Switcher - v$script_version

Switch between Brew-installed PHP versions.

usage: $(basename "$0") <version> [-s] [-c=<path>]

    <version>   PHP version (e.g. 8.4) — must be installed via brew
    -s          skip Apache configuration changes
    -c=<path>   path to httpd.conf (default: \$(brew --prefix)/etc/httpd/httpd.conf)
    -h, --help  show this help

EOF
    if (( ${#installed_versions[@]} )); then
        echo "Installed versions: ${installed_versions[*]}"
    else
        echo "No php@X.Y formulae appear to be installed via brew."
        echo "Install one with, for example: brew install php@8.4"
    fi
}

# Discover installed php@X.Y formulae from \$(brew --prefix)/opt/php@*.
# Glob lex-order is sufficient for the X.Y versions Homebrew currently ships.
discover_installed() {
    local d v
    shopt -s nullglob
    for d in "$homebrew_path"/opt/php@*; do
        v=${d##*/php@}
        [[ $v =~ ^[0-9]+\.[0-9]+$ ]] && installed+=("$v")
    done
    shopt -u nullglob
}


# ----------------------------------------------------------------------------
# Main
#

# Preflight: brew is required.
if ! command -v brew >/dev/null 2>&1; then
    echo "Error: 'brew' not found in PATH. Install Homebrew first: https://brew.sh" >&2
    exit 1
fi

homebrew_path=$(brew --prefix)
apache_conf_path="$homebrew_path/etc/httpd/httpd.conf"
php_opt_path="$homebrew_path/opt/"
apache_change=1
target_version=""

installed=()
discover_installed

# Parse arguments.
for arg in "$@"; do
    case "$arg" in
        -s)        apache_change=0 ;;
        -c=*)      apache_conf_path="${arg#-c=}" ;;
        -h|--help) usage "${installed[@]}"; exit 0 ;;
        -*)        echo "Unknown option: $arg" >&2; usage "${installed[@]}"; exit 2 ;;
        *)
            if [[ -n "$target_version" ]]; then
                echo "Unexpected argument: $arg" >&2
                exit 2
            fi
            target_version=$arg
            ;;
    esac
done

if [[ -z $target_version ]]; then
    usage "${installed[@]}"
    exit 0
fi

# Validate version format (X.Y).
if [[ ! $target_version =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version: '$target_version' (expected format: X.Y, e.g. 8.4)" >&2
    exit 2
fi

php_version="php@$target_version"

if ! in_array "$target_version" "${installed[@]}"; then
    echo "Sorry, but $php_version is not installed via brew."
    echo "Install it by running: brew install $php_version"
    exit 1
fi

# Switch shell.
echo "Switching to $php_version"
echo "Switching your shell"
for v in "${installed[@]}"; do
    brew unlink "php@$v" >/dev/null
done
brew link --force "$php_version"

# Switch Apache.
if (( apache_change == 1 )); then
    if [[ ! -f $apache_conf_path ]]; then
        echo "Note: Apache config not found at $apache_conf_path — skipping Apache changes."
    elif [[ ! -w $apache_conf_path ]]; then
        echo "Note: Apache config not writable at $apache_conf_path — skipping Apache changes."
    else
        echo "Switching your apache conf"

        # Single backup of the live config per run.
        cp "$apache_conf_path" "${apache_conf_path}.bak-sphp"

        # Ensure every installed version's LoadModule line is present and commented.
        for v in "${installed[@]}"; do
            read -r mod lib < <(apache_module_and_lib "$v")
            module_string="LoadModule $mod ${php_opt_path}php@${v}${lib}"
            esc=$(sed_escape "$module_string")

            if grep -qE "^#*$esc" "$apache_conf_path"; then
                # Normalize to a single '#' prefix (idempotent).
                sed -i '' -E "s/^#*($esc)/#\1/" "$apache_conf_path"
            elif grep -q '^LoadModule rewrite_module' "$apache_conf_path"; then
                # Insert (commented) after the rewrite_module line.
                sed -i '' "/^LoadModule rewrite_module/a\\
#$module_string
" "$apache_conf_path"
            else
                echo "Warning: 'LoadModule rewrite_module' not found in $apache_conf_path" >&2
                echo "         Skipping insertion of: $module_string" >&2
            fi
        done

        # Uncomment the target version's LoadModule line.
        read -r mod lib < <(apache_module_and_lib "$target_version")
        target_string="LoadModule $mod ${php_opt_path}${php_version}${lib}"
        target_esc=$(sed_escape "$target_string")
        sed -i '' -E "s/^#+($target_esc)/\1/" "$apache_conf_path"

        if brew services list 2>/dev/null | grep -qE '^httpd[[:space:]]'; then
            echo "Restarting apache"
            brew services restart httpd 2>&1 | sed '/(might take a while)/d'
        else
            echo "Note: brew httpd service not loaded — restart Apache manually if needed."
        fi
    fi
fi

echo
php -v
echo
echo "All done!"
