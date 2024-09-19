ddev-test-typo3
===============

@todo template: https://github.com/ddev/test-drupal11
@todo template: https://github.com/ddev/test-cakephp

Description
-----------

This repository provides the required structure to create [TYPO3](https://github.com/typo) v12 LTS setups in composer
and legacy mode and package them as [ddev apptype test package](https://ddev.readthedocs.io/en/stable/developers/project-types/#adding-new-project-types).

That means, that two test packages are created out of this repository:

* TYPO3 v12 composer mode
* TYPO3 v12 legacy mode

The composer mode is used for version update detection and the legacy setup uses the exact same version.

Following tarballs are created:

* .tarballs/composer-db.tgz
* .tarballs/composer-files.tgz
* .tarballs/composer-source.tgz
* .tarballs/legacy-db.tgz
* .tarballs/legacy-files.tgz
* .tarballs/legacy-source.tgz

TYPO3 installation modes
------------------------

[TYPO3](https://github.com/typo) provides two basic ways to be installed and used:

*   [composer mode](https://docs.typo3.org/m/typo3/tutorial-getting-started/12.4/en-us/Installation/Install.html):
    Installing TYPO3 as dependency using the PHP dependency manager [composer](https://getcomposer.org/). This
    mode uses a configurable subfolder, usually `./public/`, as entrypoint (`docroot`) for the webserver and holding
    sensible information like configuration files out of the public accessible folder as long as the webserver is
    configured properly.
 
*   [legacy mode](https://docs.typo3.org/m/typo3/tutorial-getting-started/12.4/en-us/Installation/LegacyInstallation.html):
    Deflated from an archive and using symlinks to make source folder exchangeable. The webserver document root (`docroot`)
    matches in this case the project folder.

In both modes TYPO3 provides with everything needed to create a general setup in both modes which this repository make
a benefit out of it to combine it with the game changing local development toolchain [ddev](https://ddev.readthedocs.io/en/stable/).

> Note that this repository provides an composer based setup

**Further readings**

*   [Latest release information TYPO3 v12 LTS](https://get.typo3.org/version/12)
*   [TYPO3 Documentation: Installation with composer](https://docs.typo3.org/m/typo3/tutorial-getting-started/12.4/en-us/Installation/Install.html)
