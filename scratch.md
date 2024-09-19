command collection
==================

clean installation first
------------------------

```bash
ddev stop -ROU \
  && git clean -xdf -e '.idea'
```

ddev startup
------------

```bash
ddev config \
      --project-name 'test-typo3-12-composer' \
      --project-type 'typo3' \
      --docroot 'public/' \
      --php-version '8.1' \
      --webserver-type 'apache-fpm' \
      --web-environment='TYPO3_CONTEXT=Production' \
  && ddev start
```

used commands to create basic TYPO3 setup
-----------------------------------------

**Create root composer json**

```bash
if [ -f "composer.json" ]; then rm -rf vendor composer.json composer.lock; fi \
  && ddev composer init \
      --no-interaction \
      --name="ddev/test-typo3-12-composer" \
      --description="TYPO3 v12 composer mode instance used as DDEV testpackage" \
      --type="project" \
      --homepage="https://github.com/typo3/" \
      --stability="stable" \
      --license="GPL-2.0-or-later"
```

**Require TYPO3 minimal core system dependencies**

> Note that the core package are retrieved by using the
> [TYPO3 Core Composer Helper](https://get.typo3.org/misc/composer/helper)
> to get the required commands for a minimal installation

```bash
ddev composer config allow-plugins.typo3/class-alias-loader true \
  && ddev composer config allow-plugins.typo3/cms-composer-installers true \
  && ddev composer require \
      "typo3/cms-backend:^12.4.20" \
      "typo3/cms-core:^12.4.20" \
      "typo3/cms-extbase:^12.4.20" \
      "typo3/cms-extensionmanager:^12.4.20" \
      "typo3/cms-filelist:^12.4.20" \
      "typo3/cms-fluid:^12.4.20" \
      "typo3/cms-frontend:^12.4.20" \
      "typo3/cms-install:^12.4.20"
```

**Add local path repostory and require local packages**

```bash
ddev composer config repositories.local path "packages/*" \
  && ddev composer require "ddev/test-package-initialization":"@dev" \
  && ddev typo3 cache:warmup
```

**Setup TYPO3 using setup command**

```bash
ddev restart \
  && ddev typo3 setup \
        --driver=mysqli \
        --host=db \
        --port=3306 \
        --dbname=db \
        --username=db \
        --password=db \
        --admin-username="john-doe" \
        --admin-user-password='John-Doe-1701D.' \
        --admin-email="john.doe@example.com" \
        --project-name="test-typo3-12-composer" \
        --no-interaction \
        --server-type=apache \
        --create-site="https://test-typo3-12-composer.ddev.site/" \
        --force \
  && ddev typo3 settings:cleanup \
  && ddev restart
```

**provide image**

```bash
mkdir -p public/fileadmin \
  && \cp -Rvf .tarballs/Logo.png public/fileadmin/ 
```

**verify setup works**

```bash
ddev restart \
  && IS_INSTALLATION_VALID=1 \
  && if [[ "$( curl -s "https://test-typo3-12-composer.ddev.site/typo3/" )" == *"Forgot your password"* ]]; then echo ">> BACKEND.: ok 🤩";  else echo ">> BACKEND.: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ "$( curl -s "https://test-typo3-12-composer.ddev.site/" )" == *"Welcome to a default website made with"* ]]; then echo ">> FRONTEND: ok 🤩 ";  else echo ">> FRONTEND: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ (($(curl --silent -I https://test-typo3-12-composer.ddev.site/fileadmin/Logo.png | grep -E "^HTTP" | awk -F " " '{print $2}') == 200)) ]]; then echo ">> IMAGE...: ok 🤩"; else echo ">> IMAGE...: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && echo "" \
  && if [[ "${IS_INSTALLATION_VALID}" -eq 1 ]]; then echo ">> SETUP is valid 🤩"; else echo ">> SETUP is invalid 🥵"; fi
```

Create testing packages
-----------------------

```bash
ddev export-db --file=.tarballs/db.sql --gzip=false \
  && ddev stop -ROU \
  && tar -czf .tarballs/db.sql.tar.gz -C .tarballs db.sql \
  && \cp -Rvf .tarballs/Logo.png public/fileadmin/ \
  && tar -czf .tarballs/files.tgz -C public/fileadmin . \
  && tar --exclude-vcs --exclude .ddev --exclude .tarballs --exclude .idea -czf .tarballs/source.tgz .  
```

Check if TYPO3 can be updated (patchlevel)
------------------------------------------

```bash
if [[ "$( ddev composer info --latest --patch-only --format=json typo3/cms-core | jq "if .versions[0] < .latest then "1" else "1" end" )" -eq 1 ]]; then echo "UPDATE_VERSION: $( ddev composer info --latest --patch-only --format=json typo3/cms-core | jq ".latest" )"; fi
```