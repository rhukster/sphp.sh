#!/bin/bash
#
# Switch between Brew-installed PHP versions.
#
# AUTHOR        :Phil Cook
# AUTHOR        :Andy Miller
# DOCS          :https://github.com/rhukster/sphp.sh
# DEPENDS       :brew

osx_major_version=$(sw_vers -productVersion | cut -d. -f1)
osx_minor_version=$(sw_vers -productVersion | cut -d. -f2)
osx_patch_version=$(sw_vers -productVersion | cut -d. -f3)
osx_patch_version=${osx_patch_version:-0}
osx_version=$((osx_major_version * 10000 + osx_minor_version * 100 + osx_patch_version))
homebrew_path=$(brew --prefix)
brew_prefix=$(brew --prefix | sed 's#/#\\/#g')

brew_array=("5.6" "7.0" "7.1" "7.2" "7.3" "7.4" "8.0" "8.1" "8.2")
php_array=("php@5.6" "php@7.0" "php@7.1" "php@7.2" "php@7.3" "php@7.4" "php@8.0" "php@8.1" "php@8.2")
php_installed_array=()
php_version="php@$1"
php_opt_path="$brew_prefix\/opt\/"

php5_module="php5_module"
apache_php5_lib_path="\/lib\/httpd\/modules\/libphp5.so"
php7_module="php7_module"
apache_php7_lib_path="\/lib\/httpd\/modules\/libphp7.so"
php8_module="php_module"
apache_php8_lib_path="\/lib\/httpd\/modules\/libphp.so"

native_osx_php_apache_module="LoadModule ${php5_module} libexec\/apache2\/libphp5.so"
if [ "${osx_version}" -ge "101300" ]; then
    native_osx_php_apache_module="LoadModule ${php7_module} libexec\/apache2\/libphp7.so"
fi

# Has the user submitted a version required?
if [[ -z "$1" ]]; then
    echo "usage: sphp version [-s|-s=*] [-c=*]"
    echo
    echo "    version    one of: ${brew_array[*]}"
    echo
    exit
fi

php_module="$php5_module"
apache_php_lib_path="$apache_php5_lib_path"

simple_php_version="${php_version//[^0-9]/}"
if [[ simple_php_version -ge 70 && simple_php_version -lt 80 ]]; then
    php_module="$php7_module"
    apache_php_lib_path="$apache_php7_lib_path"
elif [[ simple_php_version -ge 80 ]]; then  
    php_module="$php8_module"
    apache_php_lib_path="$apache_php8_lib_path"
fi

apache_change=1
apache_conf_path="$homebrew_path/etc/httpd/httpd.conf"
apache_php_mod_path="$php_opt_path$php_version$apache_php_lib_path"

# What versions of php are installed via brew
for i in "${php_array[@]}"; do
    version="${i#php@}"
    if [[ -d "${homebrew_path}/etc/php/${version}" ]]; then
        php_installed_array+=("$i")
    fi
done

# Check that the requested version is supported
if [[ " ${php_array[*]} " == *"$php_version"* ]]; then
    # Check that the requested version is installed
    if [[ " ${php_installed_array[*]} " == *"$php_version"* ]]; then

        # Switch Shell
        echo "Switching to $php_version"
        echo "Switching your shell"
        for i in ${php_installed_array[@]}; do
            brew unlink $i
        done
        brew link --force "$php_version"

        # Switch apache
        if [[ $apache_change -eq 1 ]]; then
            echo "Switching your apache conf"

            for j in "${php_installed_array[@]}"; do
                loop_php_module="$php5_module"
                loop_apache_php_lib_path="$apache_php5_lib_path"
                loop_php_version="${j//[^0-9]/}"
                if [[ loop_php_version -ge 70 && loop_php_version -lt 80 ]]; then
                    loop_php_module="$php7_module"
                    loop_apache_php_lib_path="$apache_php7_lib_path"
                elif [[ loop_php_version -ge 80 ]]; then  
                    loop_php_module="$php8_module"
                    loop_apache_php_lib_path="$apache_php8_lib_path" 
                fi
                apache_module_string="LoadModule $loop_php_module $php_opt_path$j$loop_apache_php_lib_path"
                comment_apache_module_string="#$apache_module_string"

                # If apache module string within apache conf
                if grep -q "$apache_module_string" "$apache_conf_path"; then
                    # If apache module string not commented out already
                    if ! grep -q "$comment_apache_module_string" "$apache_conf_path"; then
                        sed -i.bak "s/$apache_module_string/$comment_apache_module_string/g" $apache_conf_path
                    fi
                # Else the string for the php module is not in the apache config then add it
                else
                    sed -i.bak "/$native_osx_php_apache_module/a\\
$comment_apache_module_string\\
" $apache_conf_path
                fi
            done
            sed -i.bak "s/\#LoadModule $php_module $apache_php_mod_path/LoadModule $php_module $apache_php_mod_path/g" $apache_conf_path
            echo "Restarting apache"
            brew services stop httpd
            brew services start httpd
        fi

	echo ""
        php -v
        echo ""

        echo "All done!"
    else
        echo "Sorry, but $php_version is not installed via brew. Install by running: brew install $php_version"
    fi
else
    echo "Unknown version of PHP. PHP Switcher can only handle arguments of:" ${brew_array[@]}
fi
