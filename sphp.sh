#!/bin/bash
# Shell script for switching between Brew-installed PHP versions
#
# Copyright (c) 2023 Andy Miller
# Released under the MIT License
#
# Creator: Phil Cook
# Modified: Andy Miller
#
# More information: https://github.com/rhukster/sphp.sh


script_version=1.1.0

# Supported PHP versions
brew_array=("5.6" "7.0" "7.1" "7.2" "7.3" "7.4" "8.0" "8.1" "8.2")

# Apache configuration switch: 1=enabled, 0=disabled
apache_change=1

# Reference arrays defining PHP module and Apache library path per PHP version
php_modules[5]="php5_module"
php_modules[7]="php7_module"
php_modules[8]="php_module"
apache_lib_paths[5]="\/lib\/httpd\/modules\/libphp5.so"
apache_lib_paths[7]="\/lib\/httpd\/modules\/libphp7.so"
apache_lib_paths[8]="\/lib\/httpd\/modules\/libphp.so"


# ----------------------------------------------------------------------------
# Helper functions
#

# Returns the following values based on PHP version
# - PHP module
# - Apache PHP Library path
#
# Parameters:
# $1 = PHP version ('X.Y' or 'php@X.Y')
#
# Example usage (to assign 'module' and 'libpath' variables):
# read -r module libpath < <(apache_module_and_lib "<PHP version>")
apache_module_and_lib() {
    # Remove 'php@' prefix if present
    version="${1#php@}"
    # Keep only major version number (remove first '.' and everything after)
    major="${version%%.*}"

    # Lookup values in reference arrays for major PHP version number
    echo ${php_modules[$major]} ${apache_lib_paths[$major]}
}


# Make sure we call macOS native grep.
# This avoids warnings when GNU grep >=3.8+ is installed (see #1)
grep() {
    /usr/bin/grep "$@"
}


# ----------------------------------------------------------------------------
# Main script
#

target_version=$1
php_version="php@$target_version"

# Display help and exit if the user did not specify a version
if [[ -z "$target_version" ]]; then
    echo "PHP Switcher - v$script_version"
    echo
    echo "Switch between Brew-installed PHP versions."
    echo
    echo "usage: $(basename "$0") version [-s|-s=*] [-c=*]"
    echo
    echo "    version    one of:" "${brew_array[@]}"
    echo
    exit
fi

homebrew_path=$(brew --prefix)
apache_conf_path="$homebrew_path/etc/httpd/httpd.conf"
brew_prefix=$(brew --prefix | sed 's#/#\\\/#g')
php_opt_path="$brew_prefix\/opt\/"

# From the list of supported PHP versions, build array of PHP versions actually
# installed on the system via brew
for version in ${brew_array[*]}; do
    if [[ -d "$homebrew_path/etc/php/$version" ]]; then
        php_installed_array+=("$version")
    fi
done

# Check that the requested version is supported
if [[ " ${brew_array[*]} " == *"$target_version"* ]]; then
    # Check that the requested version is installed
    if [[ " ${php_installed_array[*]} " == *"$target_version"* ]]; then

        # Switch Shell
        echo "Switching to $php_version"
        echo "Switching your shell"
        for i in "${php_installed_array[@]}"; do
            brew unlink "php@$i"
        done
        brew link --force "$php_version"

        # Switch apache
        if [[ $apache_change -eq 1 ]]; then
            echo "Switching your apache conf"

            # Backup apache config file
            cp "$apache_conf_path" "$apache_conf_path".bak-sphp

            # Disable module for any PHP version other than target
            for version in "${php_installed_array[@]}"; do
                # Get PHP Module and Apache lib path for PHP version
                read -r loop_php_module loop_apache_php_lib_path < <(apache_module_and_lib "$version")

                loop_php_version="php@$version"
                apache_module_string="LoadModule $loop_php_module $php_opt_path$loop_php_version$loop_apache_php_lib_path"

                # If apache module string within apache conf
                if grep -q "$apache_module_string" "$apache_conf_path"; then
                    # Comment out the Apache module string if not done already
                    sed -i.bak "/^$apache_module_string/s/^.*\$/#&/" "$apache_conf_path"
                else
                    # The string for the php module is not in the Apache config
                    # Add it after rewrite_module, which is expected to be the last
                    # module in the list according to
                    # https://getgrav.org/blog/macos-ventura-apache-multiple-php-versions
                    sed -i.bak "/LoadModule rewrite_module/a\\
#$apache_module_string\\
" "$apache_conf_path"
                fi
            done

            # Enable target PHP version
            read -r php_module apache_php_lib_path < <(apache_module_and_lib "$target_version")
            apache_php_mod_path="$php_opt_path$php_version$apache_php_lib_path"
            sed -i.bak -E "s/^#(LoadModule $php_module $apache_php_mod_path)/\1/" "$apache_conf_path"

            # Cleanup sed backup file
            [[ -e "${apache_conf_path}.bak" ]] && rm "${apache_conf_path}.bak"

            echo "Restarting apache"
            brew services restart httpd
        fi

        echo
        php -v
        echo

        echo "All done!"
    else
        echo "Sorry, but $php_version is not installed via brew. Install by running: brew install $php_version"
    fi
else
    echo "Unknown version of PHP. PHP Switcher can only handle arguments of:" "${brew_array[@]}"
fi
