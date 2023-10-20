# sphp.sh

Shell script for switching between Brew-installed PHP versions, as featured in the popular
[macOS Apache + PHP series](https://getgrav.org/blog/macos-ventura-apache-multiple-php-versions)
on https://getgrav.org.

The code has been moved from the
[original gist](https://gist.github.com/rhukster/f4c04f1bf59e0b74e335ee5d186a98e2)
to a proper repository, to better allow for pull requests and issues.


## Installation

#### Intel Macs:

Install various versions of PHP per [macOS Apache + PHP series](https://getgrav.org/blog/macos-ventura-apache-multiple-php-versions) using Homebrew.

```
curl -L https://raw.githubusercontent.com/rhukster/sphp.sh/main/sphp.sh > /usr/local/bin/sphp
chmod +x /usr/local/bin/sphp
```

#### Apple Silicon Macs:

```
curl -L https://raw.githubusercontent.com/rhukster/sphp.sh/main/sphp.sh > /opt/homebrew/bin/sphp
chmod +x /opt/homebrew/bin/sphp
```

## Usage

To switch your current PHP installation to PHP 8.2, simply enter this command in the terminal:

```
➜ sphp 8.2
```

Result:

```
Switching to php@8.2
Switching your shell
Unlinking /opt/homebrew/Cellar/php@7.3/7.3.33_4... 0 symlinks removed.
Unlinking /opt/homebrew/Cellar/php@7.4/7.4.33_1... 25 symlinks removed.
Unlinking /opt/homebrew/Cellar/php@8.0/8.0.27_1... 0 symlinks removed.
Unlinking /opt/homebrew/Cellar/php@8.1/8.1.15... 0 symlinks removed.
Unlinking /opt/homebrew/Cellar/php/8.2.3... 0 symlinks removed.
Linking /opt/homebrew/Cellar/php/8.2.3... 24 symlinks created.
Switching your apache conf
Restarting apache
Stopping `httpd`... (might take a while)
==> Successfully stopped `httpd` (label: homebrew.mxcl.httpd)
==> Successfully started `httpd` (label: homebrew.mxcl.httpd)

PHP 8.2.3 (cli) (built: Feb 15 2023 00:18:01) (NTS)
Copyright (c) The PHP Group
Zend Engine v4.2.3, Copyright (c) Zend Technologies
    with Zend OPcache v8.2.3, Copyright (c), by Zend Technologies
    with Xdebug v3.2.0, Copyright (c) 2002-2022, by Derick Rethans

All done!
```


## Support

Submit a [new bug report](https://github.com/rhukster/sphp.sh/issues/new/choose)
on the [Github repository](https://github.com/rhukster/sphp.sh).

All code contributions (bug fixes, new features and enhancements) are welcome.
Please submit a [Pull Request](https://github.com/rhukster/sphp.sh/compare).


## License and Copyright

Copyright (c) 2023 Andy Miller

Released under the [MIT License](LICENSE)
