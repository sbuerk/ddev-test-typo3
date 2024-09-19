#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------
# SCRIPT STARTUP AND BASIC SYSTEM DETECTION
#-----------------------------------------------------------------------------------------------------------------------
SECONDS=0
SCRIPT_START=$(date +%s)
SCRIPT_FILE="${BASH_SOURCE[0]}"
while [ -h "${SCRIPT_FILE}" ]; do # resolve ${SCRIPT_FILE} until the file is no longer a symlink
  TMPDIR="$( cd -P "$( dirname "${SCRIPT_FILE}" )" && pwd )"
  SCRIPT_FILE="$(readlink "${SCRIPT_FILE}")"
  [[ ${SCRIPT_FILE} != /* ]] && SOURCE="${TMPDIR}/${SCRIPT_FILE}"
done
SCRIPT_PATH_REAL="$( cd -P "$( dirname "${SCRIPT_FILE}" )/.." && pwd )"
SCRIPT_FILE_REAL="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
SCRIPT_FILE_SYML="$(basename "$0")"
SCRIPT_PATH=${SCRIPT_PATH_REAL}
SCRIPT_FILE=${SCRIPT_FILE_REAL}
SCRIPT_STARTUP_WORKING_PATH=$( pwd )
#-----------------------------------------------------------------------------------------------------------------------
# VARIABLES - detected and filled later by functions
BIN_DDEV=""
BIN_GPG=""
BIN_WGET=""
LATEST_TYPO3_CMS_CORE_VERSION=""
CURRENT_TYPO3_CMS_CORE_VERSION=""
SCRIPT_DEBUG=${SCRIPT_DEBUG:-0}
ONLY_IF_UPDATE_AVAILABLE=${ONLY_IF_UPDATE_AVAILABLE:0}
CREATE_GIT_COMMIT=${CREATE_GIT_COMMIT:-0}
#-----------------------------------------------------------------------------------------------------------------------
cd ${SCRIPT_PATH}
#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------
SCRIPT_PATH_COMPOSER="${SCRIPT_PATH}"
SCRIPT_PATH_LEGACY="${SCRIPT_PATH}/legacy"
#-----------------------------------------------------------------------------------------------------------------------

echo "SCRIPT_DEBUG: ${SCRIPT_DEBUG}"
if [[ "${SCRIPT_DEBUG}" -eq 1 ]]; then
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! SCRIPT DEBUG MODE ENABLED !!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  sleep 5
fi


function detectBinaries() {
  BIN_DDEV="$( which ddev 2>/dev/null )"
  if [[ -z "{BIN_DDEV}" ]]; then
    echo "ERR: ddev binary not found 🥵"
    return 1
  fi

  BIN_WGET="$( which wget 2>/dev/null )"
  if [[ -z "{BIN_WGET}" ]]; then
    echo "ERR: wget binary not found 🥵"
    return 1
  fi

  # gpg verification is optional
  BIN_GPG="$( which gpg 2>/dev/null)"
  [[ -z "${BIN_GPG}" ]] && echo "INF: 'gpg' binary not found, optional 🥵"

  return 0
}

# Note that this function is used in silent
# mode for conditional work in other places.
function isDdevProjectAvailable() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: isDdevProjectAvailable"
  # safe check to avoid ddev finding wrong project
  if [[ ! -f ".ddev/config.yaml" ]]; then
    [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: isDdevProjectAvailable - return 0 (missing .ddev/config.yaml"
    return 1
  fi

  TMP="$( ddev describe 2>/dev/null )"
  if [[ "$?" -eq 0 ]]; then
    [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: isDdevProjectAvailable (EXITCODE: 0) - RETURN 1"
    return 1
  else
    [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: isDdevProjectAvailable (EXITCODE: !0) - RETURN 0"
    return 0
  fi
}

function ensureBothDdevAreNotAvailable() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: ensureBothDdevAreNotAvailable"

  cd ${SCRIPT_PATH_COMPOSER}
  [[ -f ".ddev/config.yaml" ]] && ddev stop -ROU || true
  if isDdevProjectAvailable; then
    echo ">> Removing ddev instance (composer)"
    [[ -f ".ddev/config.yaml" ]] && ddev stop -ROU || true
    if [[ "$?" -ne 0 ]]; then
      echo "ERR: failed to shutdown existing ddev setup 🥵"
      errorOccurred=1
    fi
    rm -rf .ddev
  else
    echo ">> Not removing ddev instance, does not exist"
    rm -rf .ddev
  fi

  errorOccurred=0
  cd ${SCRIPT_PATH_LEGACY}
  [[ -f ".ddev/config.yaml" ]] && ddev stop -ROU || true
  if isDdevProjectAvailable; then
    echo ">> Removing ddev instance (legacy)"
    [[ -f ".ddev/config.yaml" ]] && ddev stop -ROU || true 
    if [[ "$?" -ne 0 ]]; then
      echo "ERR: failed to shutdown existing ddev setup 🥵"
      errorOccurred=1
    fi
    rm -rf .ddev
  else
    echo ">> Not removing ddev instance, does not exist"
    rm -rf .ddev
  fi

  if [[ "${errorOccurred}" -ne 0 ]]; then
    return 1
  fi

  return 0
}

function cleanRepository() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: cleanRepository"

  local fullCleanUp="${1:-1}"
  local errorOccurred=0

  [[ ".ddev/config.yaml" ]] && ddev stop -ROU || true
  if isDdevProjectAvailable; then
    echo ">> Removing ddev instance "
    [[ ".ddev/config.yaml" ]] && ddev stop -ROU || true
    if [[ "$?" -ne 0 ]]; then
      echo "ERR: failed to shutdown existing ddev setup 🥵"
      errorOccurred=1
    fi
    rm -rf .ddev
  else
    echo ">> Not removing ddev instance, does not exist"
    rm -rf .ddev
  fi

  ### ddev describe && ddev stop -ROU && ddev stop --unlist  test-typo3-12-composer
  cd ${SCRIPT_PATH_COMPOSER}

  if [[ "${fullCleanUp}" -eq 1 ]]; then
    echo ">> Resetting git repository (git reset --hard)"
    git reset --hard
    if [[ "$?" -ne 0 ]]; then
      echo "ERR: failed to reset git repository 🥵"
      errorOccurred=1
    fi

    echo ">> Clean untracked filed (git clean -xdf -e '.idea')"
    git clean -xdf -e '.idea'
    if [[ "$?" -ne 0 ]]; then
      echo "ERR: failed to clean up all files not included in repository (except '.idea/') 🥵"
      errorOccurred=1
    fi
  else
    echo ">> Clean untracked filed (git clean -xdf -e '.idea' -e '.tarballs')"
    git clean -xdf -e '.idea' -e '.tarballs'
    if [[ "$?" -ne 0 ]]; then
      echo "ERR: failed to clean up all files not included in repository (except '.idea/' and '.tarballs') 🥵"
      errorOccurred=1
    fi
  fi

  if [[ "${errorOccurred}" -ne 0 ]]; then
    return 1
  fi

  echo ">> Cleanup succeeded"
  return 0
}

function configureComposerDdevInstance() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: configureComposerDdevInstance"

  if isDdevProjectAvailable; then
    echo ">> DDEV instance already available, abort 🥵"
    echo ">> Please ensure to remove instance manually before executing 'scripts/auto-update.sh'"
    return 1
  fi
  ddev config \
        --project-name 'test-typo3-12-composer' \
        --project-type 'typo3' \
        --docroot 'public/' \
        --php-version '8.1' \
        --webserver-type 'apache-fpm' \
        --web-environment='TYPO3_CONTEXT=Production' \
    && ddev start \
    && return 0

    # failed
    echo ">> Configure ddev instance failed, abort after cleanup 🥵"
    cleanRepository
    return 1
}

function configureLegacyDdevInstance() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: configureLegacyDdevInstance"

  # ensure we are in the correct folder
  cd ${SCRIPT_PATH_LEGACY} || return 1

  if isDdevProjectAvailable; then
    echo ">> DDEV instance already available, abort 🥵"
    echo ">> Please ensure to remove instance manually before executing 'scripts/auto-update.sh'"
    echo ">> PATH: $( pwd )"
    return 1
  fi
  ddev config \
        --project-name 'test-typo3-12-legacy' \
        --project-type 'typo3' \
        --docroot './' \
        --php-version '8.1' \
        --webserver-type 'apache-fpm' \
        --web-environment='TYPO3_CONTEXT=Production' \
    && ddev start \
    && if [[ -f "typo3conf/system/AdditionalConfiguration.php" ]]; then rm rf "typo3conf/system/additional.php"; mv "typo3conf/system/AdditionalConfiguration.php" "typo3conf/system/additional.php"; fi \
    && return 0

    # failed
    echo ">> Configure ddev instance failed, abort after cleanup 🥵"
    cleanRepository
    return 1
}

function setupComposerTypo3() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: setupComposerTypo3"

  ddev typo3 setup \
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
    && ddev restart \
    && mkdir -p public/fileadmin \
    && \cp -Rvf .tarballs/Logo.png public/fileadmin/ \
    && echo ">> Setup TYPO3 succeeded 🤩" \
    && return 0

  # something went wrong - cleanup
  echo ">> Failed to setup, abort after cleanup 🥵"
  cleanRepository
  return 1
}

# To avoid the maintenance of the same helper extension in two places,
# we copy the extension to the legacy subfolder. Symlink that into the
# legacy folder is not an option, because it would later point outside
# of the legacy and ddev context folder and would be missing in legacy
# test package files. That is the best option to have a complete and
# valid legacy package in the end.
function copyTestPackageInitializationExtensionToLegacyExtensionFolder() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: copyTestPackageInitializationExtensionToLegacyExtensionFolder"

  # ensure we are in the correct folder
  cd ${SCRIPT_PATH_LEGACY} || return 1

  mkdir -p typo3conf/ext
  if [[ "$?" -ne 0 ]]; then
    echo "ERR: Could not create 'typo3conf/ext folder' - abort 🥵"
    return 1
  fi

  \cp -Rvf ../packages/test_package_initialization typo3conf/ext/
  if [[ "$?" -ne 0 ]]; then
    echo "ERR: Failed to copy '../packages/test_package_initialization' to  'typo3conf/ext folder' - abort 🥵"
    return 1
  fi
}

function setupLegacyTypo3() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: setupLegacyTypo3"

  # ensure we are in the correct folder
  cd ${SCRIPT_PATH_LEGACY} || return 1

  ddev exec typo3/sysext/core/bin/typo3 setup \
        --driver=mysqli \
        --host=db \
        --port=3306 \
        --dbname=db \
        --username=db \
        --password=db \
        --admin-username="john-doe" \
        --admin-user-password='John-Doe-1701D.' \
        --admin-email="john.doe@example.com" \
        --project-name="test-typo3-12-legacy" \
        --no-interaction \
        --server-type=apache \
        --create-site="https://test-typo3-12-legacy.ddev.site/" \
        --force \
    && ddev restart \
    && ddev exec typo3/sysext/core/bin/typo3 extension:install test_package_initialization \
    && ddev exec typo3/sysext/core/bin/typo3 extension:setup \
    && ddev restart \
    && ddev exec typo3/sysext/core/bin/typo3 settings:cleanup \
    && ddev restart \
    && mkdir -p ./fileadmin \
    && \cp -Rvf ../.tarballs/Logo.png ./fileadmin/ \
    && echo ">> Setup TYPO3 succeeded 🤩" \
    && return 0

  # something went wrong - cleanup
  echo ">> Failed to setup, abort after cleanup 🥵"
  cleanRepository
  return 1
}

function verifyComposerInstallation() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: verifyComposerInstallation"
  
  IS_INSTALLATION_VALID=1 \
  && if [[ "$( curl -s "https://test-typo3-12-composer.ddev.site/typo3/" )" == *"Forgot your password"* ]]; then echo ">> BACKEND.: ok 🤩";  else echo ">> BACKEND.: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ "$( curl -s "https://test-typo3-12-composer.ddev.site/" )" == *"Welcome to a default website made with"* ]]; then echo ">> FRONTEND: ok 🤩 ";  else echo ">> FRONTEND: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ (($(curl --silent -I https://test-typo3-12-composer.ddev.site/fileadmin/Logo.png | grep -E "^HTTP" | awk -F " " '{print $2}') == 200)) ]]; then echo ">> IMAGE...: ok 🤩"; else echo ">> IMAGE...: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ "${IS_INSTALLATION_VALID}" -eq 1 ]]; then echo ">> SETUP is valid 🤩"; else echo ">> SETUP is invalid 🥵"; fi

  [[ "${IS_INSTALLATION_VALID}" -eq 1 ]] && return 0

  # something went wrong - cleanup
  echo ">> Composer setup invalid, abort after cleanup 🥵"
  cleanRepository
  return 1
}

function verifyLegacyInstallation() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: verifyLegacyInstallation"

  IS_INSTALLATION_VALID=1 \
  && if [[ "$( curl -s "https://test-typo3-12-legacy.ddev.site/typo3/" )" == *"Forgot your password"* ]]; then echo ">> BACKEND.: ok 🤩";  else echo ">> BACKEND.: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ "$( curl -s "https://test-typo3-12-legacy.ddev.site/" )" == *"Welcome to a default website made with"* ]]; then echo ">> FRONTEND: ok 🤩 ";  else echo ">> FRONTEND: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ (($(curl --silent -I https://test-typo3-12-legacy.ddev.site/fileadmin/Logo.png | grep -E "^HTTP" | awk -F " " '{print $2}') == 200)) ]]; then echo ">> IMAGE...: ok 🤩"; else echo ">> IMAGE...: failed 🥵" ; IS_INSTALLATION_VALID=0 ; fi \
  && if [[ "${IS_INSTALLATION_VALID}" -eq 1 ]]; then echo ">> SETUP is valid 🤩"; else echo ">> SETUP is invalid 🥵"; fi

  [[ "${IS_INSTALLATION_VALID}" -eq 1 ]] && return 0

  # something went wrong - cleanup
  echo ">> Composer setup invalid, abort after cleanup 🥵"
  cleanRepository
  return 1
}

function isTypo3UpdateAvailable() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: isTypo3UpdateAvailable"

  TYPO3_CMS_CORE_NEW_PATCHLEVEL_AVAILABLE="$( ddev composer info --latest --patch-only --format=json typo3/cms-core | jq "if .versions[0] < .latest then "1" else "0" end" )"

  TYPO3_CMS_CORE_NEW_PATCHLEVEL_AVAILABLE="${TYPO3_CMS_CORE_NEW_PATCHLEVEL_AVAILABLE//\"}"
  [[ "${TYPO3_CMS_CORE_NEW_PATCHLEVEL_AVAILABLE}" -eq 1 ]] && echo ">> Update available 🤩" && return 0
  [[ "${ONLY_IF_UPDATE_AVAILABLE}" -eq 0 ]] && echo ">> No update available but package creation enforced 🤩" && return 0

  # no update available, abort after cleanup
  echo ">> No update available - abort auto-update 🤩"
  cleanRepository
  return 1
}

function determineUpdateTypo3Version() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: determineUpdateTypo3Version"

  CURRENT_TYPO3_CMS_CORE_VERSION="$( ddev composer info --latest --patch-only --format=json typo3/cms-core | jq ".versions[0]" )"
  [[ "$?" -ne 0 ]] \
    && echo ">> ERR: Failed to fetch next TYPO3 version 🥵"\
    && cleanRepository \
    && return 1

  LATEST_TYPO3_CMS_CORE_VERSION="$( ddev composer info --latest --patch-only --format=json typo3/cms-core | jq ".latest" )"
  [[ "$?" -ne 0 ]] \
    && echo ">> ERR: Failed to fetch next TYPO3 version 🥵"\
    && cleanRepository \
    && return 1

  [[ -z "${CURRENT_TYPO3_CMS_CORE_VERSION}" ]] \
    && echo ">> ERR: Failed to fetch next TYPO3 version 🥵"\
    && cleanRepository \
    && return 1

  [[ -z "${LATEST_TYPO3_CMS_CORE_VERSION}" ]] \
    && echo ">> ERR: Failed to fetch next TYPO3 version 🥵"\
    && cleanRepository \
    && return 1

  # remove `v` and quotes `"` from version strings
  CURRENT_TYPO3_CMS_CORE_VERSION="${CURRENT_TYPO3_CMS_CORE_VERSION//v}"
  CURRENT_TYPO3_CMS_CORE_VERSION="${CURRENT_TYPO3_CMS_CORE_VERSION//\"}"
  LATEST_TYPO3_CMS_CORE_VERSION="${LATEST_TYPO3_CMS_CORE_VERSION//v}"
  LATEST_TYPO3_CMS_CORE_VERSION="${LATEST_TYPO3_CMS_CORE_VERSION//\"}"
  echo "CURRENT: ${CURRENT_TYPO3_CMS_CORE_VERSION}"
  echo "LATEST.: ${LATEST_TYPO3_CMS_CORE_VERSION}"
  echo "${CURRENT_TYPO3_CMS_CORE_VERSION}" > .tarballs/VERSION_CURRENT
  echo "${LATEST_TYPO3_CMS_CORE_VERSION}" > .tarballs/VERSION_CREATED
  return 0
}

function updateTypo3() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: updateTypo3"
  
  echo ">> Start upgrade to TYPO3 v${LATEST_TYPO3_CMS_CORE_VERSION}"
  ddev composer require -W \
      "typo3/cms-backend:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
      "typo3/cms-core:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
      "typo3/cms-extbase:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
      "typo3/cms-extensionmanager:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
      "typo3/cms-filelist:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
      "typo3/cms-fluid:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
      "typo3/cms-frontend:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
      "typo3/cms-install:^${LATEST_TYPO3_CMS_CORE_VERSION}" \
    && ddev typo3 cache:warmup \
    && ddev typo3 extension:setup \
    && ddev typo3 upgrade:run

  if [[ "$?" -ne 0 ]]; then
    echo ">> Update failed, abort after cleanup 🥵"
    cleanRepository
    return 1
  fi

  if [[ verifyComposerInstallation -ne 0 ]]; then
    echo ">> Update verification failed, abort after cleanup 🥵"
    cleanRepository
    return 1
  fi

  echo ">> Update succeeded 🤩"
}

function createComposerPackageFiles() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: createComposerPackageFiles"
  
  ddev export-db --file=.tarballs/composer-db.sql --gzip=false \
    && ddev stop -ROU \
    && rm -rf .ddev \
    && tar -czf .tarballs/composer-db.sql.tgz -C .tarballs composer-db.sql \
    && \cp -Rvf .tarballs/Logo.png public/fileadmin/ \
    && tar -czf .tarballs/composer-files.tgz -C public/fileadmin . \
    && \tar --exclude-vcs --exclude .ddev --exclude .tarballs --exclude .idea -czf .tarballs/composer-source.tgz . \
    && echo ">> Creating composer packages succeeded 🤩" \
    && ls -l .tarballs/composer-* \
    && return 0

    # something went wrong
    echo ">> Creating composer packages failed, abort after cleanup 🥵"
    cleanRepository
    return 1
}

function createLegacyPackageFiles() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: createLegacyPackageFiles"

  ddev export-db --file=../.tarballs/legacy-db.sql --gzip=false \
    && ddev stop -ROU \
    && rm -rf .ddev \
    && tar -czf ../.tarballs/legacy-db.sql.tgz -C ../.tarballs legacy-db.sql \
    && \cp -Rvf ../.tarballs/Logo.png fileadmin/ \
    && tar -czf ../.tarballs/legacy-files.tgz -C fileadmin . \
    && \tar --exclude-vcs --exclude .ddev -czf ../.tarballs/legacy-source.tgz . \
    && echo ">> Creating legacy packages succeeded 🤩" \
    && ls -l ../.tarballs/legacy-* \
    && return 0

    # something went wrong
    echo ">> Creating legacy packages failed, abort after cleanup 🥵"
    cleanRepository
    return 1
}

function createComposerPackage() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: createComposerPackage"
  
  # setup composer instance
  configureComposerDdevInstance || return 1
  setupComposerTypo3 || return 1
  verifyComposerInstallation || return 1

  # check for update
  isTypo3UpdateAvailable || return 1
  determineUpdateTypo3Version || return 1

  # update
  updateTypo3 || return 1

  # create composer package files
  createComposerPackageFiles || return 1

  return 0
}

# @todo Find a way for automatic checksum verification for package and signature file
function downloadAndVerifyLegacySource() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: downloadAndVerifyLegacySource"

  # ensure we are in the correct folder
  cd ${SCRIPT_PATH_LEGACY} || return 1

  echo -n ">> Download TYPO3 v${LATEST_TYPO3_CMS_CORE_VERSION} legacy source ... "
  TMP="$( ${BIN_WGET} --content-disposition https://get.typo3.org/${LATEST_TYPO3_CMS_CORE_VERSION} >/dev/null 2>&1 )"
  if [[ "$?" -ne 0 ]]; then
    echo "failed, abort after cleanup 🥵"
    cleanRepository
    return 1
  fi
  echo "succeeded 🤩"

  if [[ ! -f "typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz" ]]; then
    echo "ERR: Downloaded legacy does not exist. abort"
    cleanRepository
    return 1
  fi

  local doSignatureValidation=0
  if [[ -n "${BIN_GPG}" ]]; then
      # https://get.typo3.org/13.3.0/tar.gz.sig
      echo -n ">> Download TYPO3 v${LATEST_TYPO3_CMS_CORE_VERSION} legacy source signature ... "
      TMP="$( ${BIN_WGET} --content-disposition https://get.typo3.org/${LATEST_TYPO3_CMS_CORE_VERSION}/tar.gz.sig >/dev/null 2>&1 )"
      if [[ "$?" -ne 0 ]]; then
        echo "failed - skip signature verification"
      else
        echo "done"
        if [[ ! -f "typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz.sig" ]]; then
          echo ">> Legacy Signature file does not exist. Skip verification"
        else
          doSignatureValidation=1
        fi
      fi
      if [[ "${doSignatureValidation}" -eq 1 ]]; then
        echo -n ">> Ensure TYPO3 key is available ..."
        TMP="$( ${BIN_WGET} -qO- https://get.typo3.org/KEYS | ${BIN_GPG} --import >/dev/null 2>&1 )"
        if [[ "$?" -ne 0 ]]; then
          echo "failed. skip 🥵"
        else
          echo "done 🤩"
          ${BIN_GPG} --verify typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz.sig typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz
          if [[ "$?" -ne 0 ]]; then
            echo "ERR: Signature verification failed. abort"
            cleanRepository
            return 1
          fi
        fi
      fi
  fi

  return 0
}

function deflateLegacySourceAndRemoveDownloadedFiles() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: deflateLegacySourceAndRemoveDownloadedFiles"

  # ensure we are in the correct folder
  cd ${SCRIPT_PATH_LEGACY} || return 1

  echo -n ">> Deflate source typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz ... "
  TMP="$( tar xzf typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz >/dev/null 2>&1 )"
  if [[ "$?" -ne 0 ]]; then
    echo "failed, abort 🥵"
    cleanRepository
    return 1
  fi
  echo "done 🤩"

  echo -n ">> Remove downloaded files ... "
  TMP="$( rm -rf typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION}.tar.gz.sig )"
  if [[ "$?" -ne 0 ]]; then
    echo "failed, abort 🥵"
    cleanRepository
    return 1
  fi
  echo "done 🤩"

  echo -n ">> Create symlink (typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION} typo3_src) ... "
  TMP="$( ln -s typo3_src-${LATEST_TYPO3_CMS_CORE_VERSION} typo3_src )"
  if [[ "$?" -ne 0 ]]; then
    echo "failed, abort 🥵"
    cleanRepository
    return 1
  fi
  echo "done 🤩"

  echo -n ">> Create symlink (typo3_src/index.php index.php) ... "
  TMP="$( ln -s typo3_src/index.php index.php )"
  if [[ "$?" -ne 0 ]]; then
    echo "failed, abort 🥵"
    cleanRepository
    return 1
  fi
  echo "done 🤩"

  echo -n ">> Create symlink (typo3_src/typo3 typo3) ... "
  TMP="$( ln -s typo3_src/typo3 typo3 )"
  if [[ "$?" -ne 0 ]]; then
    echo "failed, abort 🥵"
    cleanRepository
    return 1
  fi
  echo "done 🤩"
}

function createLegacyPackage() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: createLegacyPackage"

  echo ">> change to legacy subfolder"
  cd ${SCRIPT_PATH_LEGACY}

  downloadAndVerifyLegacySource || return 1
  deflateLegacySourceAndRemoveDownloadedFiles || return 1
  configureLegacyDdevInstance || return 1
  copyTestPackageInitializationExtensionToLegacyExtensionFolder || return 1
  setupLegacyTypo3 || return 1
  verifyLegacyInstallation || return 1

  # create composer package files
  createLegacyPackageFiles || return 1

  return 0
}

function createCommitIfChangesAvailableAndRequested() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: isCommitable"

  cd "${SCRIPT_PATH_COMPOSER}"

  IS_COMMITABLE=0
  [[ -n "$( git status -s -uall )" ]] && IS_COMMITABLE=1
  echo "------------------------------------------------------------------------------------"
  echo " IS_COMMITABLE.....: ${IS_COMMITABLE}"
  echo " CREATE_GIT_COMMIT.: ${CREATE_GIT_COMMIT}"
  echo "------------------------------------------------------------------------------------"
  if [[ "${SCRIPT_DEBUG}" -eq 1 ]]; then
    git status -s -uall
    echo "------------------------------------------------------------------------------------"
  fi

  if [[ "${IS_COMMITABLE}" -eq 1 ]]; then
    if [[ "${CREATE_GIT_COMMIT:-0}" -eq 1 ]]; then
      COMMIT_MSG="[RELEASE] ${USE_TAG}"
      if [[ "${CURRENT_TYPO3_CMS_CORE_VERSION}" == "${LATEST_TYPO3_CMS_CORE_VERSION}" ]]; then
        if [[ ${ONLY_IF_UPDATE_AVAILABLE} -eq 1 ]]; then
          echo ">> Current and build version are the same but 'only if update available mode' active. Abort."
          return 1
        fi
        COMMIT_MSG="[RELEASE] ${USE_TAG}: Recreate TYPO3 v${CURRENT_TYPO3_CMS_CORE_VERSION}"
      else
        COMMIT_MSG="[RELEASE] ${USE_TAG}: Updating to TYPO3 v${LATEST_TYPO3_CMS_CORE_VERSION}"
      fi

      git add . \
        && git commit --author="[PACKAGE-SCRIPT] <stefan@buerk.tech>" -m "${COMMIT_MSG}" \
        && echo ">> Git commit created" \
        && return 0

      echo ">> Creating git commit failed"
      return 1
    fi
    return 0;
  fi

  return 1
}

function finalBanner() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && echo ">> DEBUG: finalBanner"
  
  # SCRIPT END BANNER
  SCRIPT_END=$(date +%s)
  SCRIPT_START_READABLE=$( date -d @${SCRIPT_START} )
  SCRIPT_END_READABLE=$( date -d @${SCRIPT_END} )
  ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
  echo ""
  echo "---------------------------------------------------------------------------------"
  echo " SCRIPT_START: ${SCRIPT_START_READABLE}"
  echo " SCRIPT_END..: ${SCRIPT_END_READABLE}"
  echo " ELAPSED.....: ${ELAPSED}"
  echo "---------------------------------------------------------------------------------"
  echo ""
  echo ">> FINISHED"
  echo ""
}

# function chain
detectBinaries || exit 1
ensureBothDdevAreNotAvailable || exit 1
cleanRepository || exit 1

# create packages
createComposerPackage || exit 1
createLegacyPackage || exit 1

cd "${SCRIPT_PATH_COMPOSER}"
echo "${LATEST_TYPO3_CMS_CORE_VERSION}" > .tarballs/VERSION_CREATED

# finish
echo ">> Packages successfully created but no release created."
echo ">> Create commit and release manually using following packages (ls -l .tarballs/*.tgz):"
echo ""
ls -l .tarballs/*.tgz
echo ""
git status

cd "${SCRIPT_PATH_COMPOSER}"
createCommitIfChangesAvailableAndRequested
COMMITABLE_EXIT_CODE="$?"
if [[ "${COMMITABLE_EXIT_CODE}" -ne 0 ]]; then
  cleanRepository
  finalBanner
  exit 1
fi

cleanRepository 0
finalBanner
exit 0