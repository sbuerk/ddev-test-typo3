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
SCRIPT_DEBUG=${SCRIPT_DEBUG:-0}
#-----------------------------------------------------------------------------------------------------------------------
cd ${SCRIPT_PATH}
#-----------------------------------------------------------------------------------------------------------------------

SCRIPT_DEBUG=${SCRIPT_DEBUG:-0}

\
  SCRIPT_DEBUG="${SCRIPT_DEBUG}" \
  ONLY_IF_UPDATE_AVAILABLE=1 \
  ${SCRIPT_PATH}/scripts/create-packages.sh