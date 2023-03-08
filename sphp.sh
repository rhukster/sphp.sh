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

# Returns macOS version in numeric format
# e.g. 11.7 = 110700, 12.6.3 = 120603
# Note: will cause syntax error if version number returned by sw_vers has
# more than 3 elements.
osx_version() {
    IFS='.' read -r major minor patch < <(sw_vers -productVersion)
    echo $((major * 10000 + minor * 100 + ${patch:-0}))
}


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


# ----------------------------------------------------------------------------
# Main script
#

# Display help and exit if the user did not specify a version
if [[ -z "$1" ]]; then
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
brew_prefix=$(brew --prefix | sed 's#/#\\\/#g')

php_version="php@$1"
php_opt_path="$brew_prefix\/opt\/"

if [[ $(osx_version) -ge 101300 ]]; then
    native_osx_php_apache_module="LoadModule ${php_modules[7]} libexec\/apache2\/libphp7.so"
else
    native_osx_php_apache_module="LoadModule ${php_modules[5]} libexec\/apache2\/libphp5.so"
fi

# Get PHP Module and Apache lib path for PHP version
read -r php_module apache_php_lib_path < <(apache_module_and_lib "$1")

apache_change=1
apache_conf_path="$homebrew_path/etc/httpd/httpd.conf"
apache_php_mod_path="$php_opt_path$php_version$apache_php_lib_path"

# Build 2 arrays from the list of supported PHP versions:
# - php_array: PHP version numbers prefixed by 'php@'
# - php_installed_array: PHP versions actually installed on the system via brew
for version in ${brew_array[*]}; do
    php_array+=("php@${version}")
    if [[ -d "$homebrew_path/etc/php/$version" ]]; then
        php_installed_array+=("$version")
    fi
done

# Check that the requested version is supported
if [[ " ${php_array[*]} " == *"$php_version"* ]]; then
    # Check that the requested version is installed
    if [[ " ${php_installed_array[*]} " == *"$1"* ]]; then

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

            for j in "${php_installed_array[@]}"; do
                # Get PHP Module and Apache lib path for PHP version
                read -r loop_php_module loop_apache_php_lib_path < <(apache_module_and_lib "$j")

                apache_module_string="LoadModule $loop_php_module $php_opt_path$j$loop_apache_php_lib_path"
                comment_apache_module_string="#$apache_module_string"

                # If apache module string within apache conf
                if grep -q "$apache_module_string" "$apache_conf_path"; then
                    # If apache module string not commented out already
                    if ! grep -q "$comment_apache_module_string" "$apache_conf_path"; then
                        sed -i.bak "s/$apache_module_string/$comment_apache_module_string/g" "$apache_conf_path"
                    fi
                # Else the string for the php module is not in the apache config then add it
                else
                    sed -i.bak "/$native_osx_php_apache_module/a\\
$comment_apache_module_string\\
" "$apache_conf_path"
                fi
            done
            sed -i.bak "s/\#LoadModule $php_module $apache_php_mod_path/LoadModule $php_module $apache_php_mod_path/g" "$apache_conf_path"
            echo "Restarting apache"
            brew services stop httpd
            brew services start httpd
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
