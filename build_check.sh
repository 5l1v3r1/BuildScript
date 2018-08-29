#!/bin/bash

################################################################################
# CORE FUNCTIONS - Do not edit
################################################################################
#
# VARIABLES
#
_bold=$(tput bold)
_underline=$(tput sgr 0 1)
_reset=$(tput sgr0)

_purple=$(tput setaf 171)
_red=$(tput setaf 1)
_green=$(tput setaf 76)
_tan=$(tput setaf 3)
_blue=$(tput setaf 38)

#
# HEADERS & LOGGING
#
function _debug() {
    [ "$DEBUG" == "1" ] && $@
}

function _header() {
    printf "\n${_bold}${_purple}==========  %s  ==========${_reset}\n" "$@"
}

function _arrow() {
    printf "➜ $@\n"
}

function _success() {
    printf "${_green}✔ %s${_reset}\n" "$@"
}

function _error() {
    printf "${_red}✖ %s${_reset}\n" "$@"
}

function _warning() {
    printf "${_tan}➜ %s${_reset}\n" "$@"
}

function _underline() {
    printf "${_underline}${_bold}%s${_reset}\n" "$@"
}

function _bold() {
    printf "${_bold}%s${_reset}\n" "$@"
}

function _note() {
    printf "${_underline}${_bold}${_blue}Note:${_reset}  ${_blue}%s${_reset}\n" "$@"
}

function _table_separator() {
    printf "$1%s${_reset}${_blue}%s${_reset}$1%s${_reset}${_blue}%s$1%s${_reset}${_blue}%s$1%s\n" "|" "----------------------------------" "|" "----------------------------------" "|" "--------------------------------------------------" "|"
}

function _die() {
    _error "$@"
    exit 1
}

function _safeExit() {
    exit 0
}

function _showHeader() {
    cat <<"EOF"



EOF
}

function _printUsage() {
    
    _showHeader
        
    echo -n "
    
    Required Arguments
    ===================================================================
            
            -d,--dependency              : The dependency name
            --url
            
    
    Optional Arguments
    ===================================================================
        
        
        
    General
    ===================================================================
    
        -h, --help        Display this help and exit
        -v, --version     Output version information and exit

        
    Examples
    ===================================================================
        $(basename $0) --help
        

"
    exit 1
}

function processArgs() {
    # Parse Arguments
    for arg in "$@"
    do
        case $arg in
            -d=*)
                DEPENDENCY_ARG="${arg#*=}"
                shift # past argument=value
            ;;
            
            --dependency=*)
                DEPENDENCY_ARG="${arg#*=}"
                shift # past argument=value
            ;;
            
            --url=*)
                URL_ARG="${arg#*=}"
                shift # past argument=value
            ;;
            
            --debug)
                DEBUG=1
                shift # past argument=value
            ;;
            -h|--help)
                _printUsage
            ;;
            
        esac
    done
    

}

################################################################################
# General
################################################################################

function checkroot() {
    if [[ $EUID -ne 0 ]]
    then
        _error "This script must be run as root ." 1>&2
        exit 1
    fi
}

function getChar() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

function getVariable() {
    local VARIABLE=""
    
    while [[ -z "$VARIABLE" ]]
    do
        read -p "$1" VARIABLE
    done
    
    echo $VARIABLE
}

function getFileVariable() {
    local VARIABLE=""
    
    while [[ -z "$VARIABLE" && ! -f "$VARIABLE" ]]
    do
        read -p "$1" VARIABLE
    done
    
    echo $VARIABLE
}

function killProgram() {
    if [ ! -z "$1" ]
    then
        local PROGRAM="$1"
        local PID=$(pidof ${PROGRAM})
        
        if ! [ -z "$PID" ]
        then
            kill -HUP ${PID}
        fi
        
        pkill -9 ${PROGRAM}
    fi
}

function split() {
    if [ ! -z "$1" ] && [ ! -z "$2" ]
    then
        local STRING="$1"
        local DELIMETER="$2"
        local items=$(echo "${STRING}" | tr "${DELIMETER}" "\n")
        
        for item in $items
        do
            echo "${item}"
        done
    fi
}

################################################################################
# Parsers
################################################################################

function checkDependency() {
    if [ ! -z "$1" ]
    then
        local DEPENDENCY=$(echo "$1" | perl -pe 's/(.*)\.(.+)\.(.+)\.(.+)$/\1/g')
        local BUILD_NAME=$(echo "$1" | perl -pe 's/(.*)\.(.+)\.(.+)\.(.+)$/\2/g')
        local ARCH=$(echo "$1" | perl -pe 's/(.*)\.(.+)\.(.+)\.(.+)$/\3/g')
        local EXTENSION=$(echo "$1" | perl -pe 's/(.*)\.(.+)\.(.+)\.(.+)$/\4/g')
        local DEPENDENCY_URL=$(getDependencyUrl "${DEPENDENCY}" "${BUILD_NAME}" "${ARCH}" "${EXTENSION}")
        
        _note "${DEPENDENCY_URL}"
        
        ZIP_FILE="/tmp/${DEPENDENCY}.${EXTENSION}"
        ZIP_REMOTE_FILE="${DEPENDENCY_URL}"
        ZIP_REMOTE_CHECKSUM_FILE="${ZIP_REMOTE_FILE}.md5"
        
        ZIP_REMOTE_FILE_EXISTS=$(urlExists "${ZIP_REMOTE_FILE}")
        ZIP_REMOTE_CHECKSUM_FILE_EXISTS=$(urlExists "${ZIP_REMOTE_CHECKSUM_FILE}")
        
        if [ "${ZIP_REMOTE_FILE_EXISTS}" == "1" ]
        then
            wget "${ZIP_REMOTE_FILE}" -O "${ZIP_FILE}" 1>>$LOGFILE 2>>$LOGFILE
            ZIP_FILE_CHECKSUM=$(getFileChecksum "${ZIP_FILE}")
            
            getArchiveInformations "${ZIP_FILE}" "${EXTENSION}"
            ARCHIVE="${DEPENDENCY}"
            DEVEL_ARCHIVE=$(echo "${ARCHIVE}" | sed -n "s/\([^0-9]*\)\([0-9]\)/\1devel-\2/Ip")
        else
            ZIP_REMOTE_FILE="N/A"
            ZIP_FILE_CHECKSUM="N/A"
            ZIP_FILE="N/A"
        fi
        
        if [ "${ZIP_REMOTE_CHECKSUM_FILE_EXISTS}" == "1" ]
        then
            ZIP_REMOTE_CHECKSUM=$(curl -S "${ZIP_REMOTE_CHECKSUM_FILE}" 2>>$LOGFILE | awk '/ / {print $1}')
            
            if [ "${ZIP_FILE_CHECKSUM}" != "N/A" ]
            then
                compareChecksums ${ZIP_FILE_CHECKSUM} ${ZIP_REMOTE_CHECKSUM}
            fi
        else
            ZIP_REMOTE_CHECKSUM_FILE="N/A"
            ZIP_REMOTE_CHECKSUM="N/A"
        fi
        
        DEVEL_ZIP_FILE="/tmp/${DEVEL_ARCHIVE}"
        DEVEL_ZIP_REMOTE_FILE="${URL_ARG}${DEVEL_ARCHIVE}"
        DEVEL_ZIP_REMOTE_CHECKSUM_FILE="${DEVEL_ZIP_REMOTE_FILE}.md5"
        
        DEVEL_ZIP_REMOTE_FILE_EXISTS=$(urlExists ${DEVEL_ZIP_REMOTE_FILE})
        DEVEL_ZIP_REMOTE_CHECKSUM_FILE_EXISTS=$(urlExists ${DEVEL_ZIP_REMOTE_CHECKSUM_FILE})
        
        if [ "${DEVEL_ZIP_REMOTE_FILE_EXISTS}" == "1" ]
        then
            wget ${DEVEL_ZIP_REMOTE_FILE} -O ${DEVEL_ZIP_FILE} 1>>$LOGFILE 2>>$LOGFILE
            DEVEL_ZIP_FILE_CHECKSUM=$(getFileChecksum ${DEVEL_ZIP_FILE})
        else
            DEVEL_ARCHIVE="N/A"
            DEVEL_ZIP_REMOTE_FILE="N/A"
            DEVEL_ZIP_FILE_CHECKSUM="N/A"
            DEVEL_ZIP_FILE="N/A"
        fi
        
        if [ "${DEVEL_ZIP_REMOTE_CHECKSUM_FILE_EXISTS}" == "1" ]
        then
            DEVEL_ZIP_REMOTE_CHECKSUM=$(curl -S "${DEVEL_ZIP_REMOTE_CHECKSUM_FILE}" 2>>$LOGFILE | awk '/ / {print $1}')
            
            if [ "${DEVEL_ZIP_FILE_CHECKSUM}" != "N/A" ]
            then
                compareChecksums ${DEVEL_ZIP_FILE_CHECKSUM} ${DEVEL_ZIP_REMOTE_CHECKSUM}
            fi
        else
            DEVEL_ZIP_REMOTE_CHECKSUM_FILE="N/A"
            DEVEL_ZIP_REMOTE_CHECKSUM="N/A"
        fi
        
        displayInformations
    fi
}

function getArchiveInformations() {
    if [ ! -z "$1" ] && [ ! -z "$2" ]
    then
        local ZIP_PATH="$1"
        local EXTENSION="$2"
        local INFOS_FILE="/tmp/infos.txt"
        local DEPENDENCIES_INFOS_FILE="/tmp/dependencies.txt"
        
        if [ -f "$ZIP_PATH" ]
        then
            if [ "${EXTENSION}" == "zip" ]
            then
                INFORMATIONS_TEXT=$(/usr/bin/zipinfo -z "$ZIP_PATH" | grep -zPo "NAME: (?s)(.*)Zip file size:")
                /usr/bin/zipinfo -z "$ZIP_PATH" | grep -zPo "DEPENDENCIES: (?s)(.*)DESCRIPTION:" | grep -zPo "(?s)(?:DEPENDENCIES:|,)? (.*?)(?:DESCRIPTION:)" | sed  "s/[^:]*:.//gi" | tr -d " " | tr -d "\n" | tr "," "\n" | sort -u > ${DEPENDENCIES_INFOS_FILE}
            else
                if [ "${EXTENSION}" == "rpm" ]
                then
                    INFORMATIONS_TEXT=$(rpm -q  "$ZIP_PATH" --info)
                    rpm -q "$ZIP_PATH" --info | grep -zPo "DEPENDENCIES: (?s)(.*)DESCRIPTION:" | grep -zPo "(?s)(?:DEPENDENCIES:|,)? (.*?)(?:DESCRIPTION:)" | sed  "s/[^:]*:.//gi" | tr -d " " | tr -d "\n" | tr "," "\n" | sort -u > ${DEPENDENCIES_INFOS_FILE}
                fi
            fi

            echo ${INFORMATIONS_TEXT} | sed "s/SOURCE RPM:/RPM:/g" | sed "s/: /:/g" | sed "s/\([^:]*\):\([^:]*\) \([A-Z ]*\):/\1:\2\n\3:/g" | sed "s/\([^:]*\):\([^:]*\) \([A-Z ]*\):/\1:\2\n\3:/g" > ${INFOS_FILE}
            
            while read line
            do
              export "$(echo "${line}" | sed -n "s#^\([^:]*\):\(.*\)#\1=\2#pI")"
            done < ${INFOS_FILE}
            
            while read dependency
            do
                DEPENDENCIES_LIST[${DEPENDENCIES_COUNT}]="${dependency}"
                DEPENDENCIES_COUNT=$((${DEPENDENCIES_COUNT} + 1))
            done < ${DEPENDENCIES_INFOS_FILE}
        fi
    fi
}

function getUrlInformations() {
    if [ ! -z "$1" ]
    then
        local URL="$1"
        local URL_EXISTS=$(urlExists "${URL}")
        local INFOS_FILE="/tmp/infos.txt"
        
        if [ "$URL_EXISTS" -eq "1" ]
        then
            _arrow "Getting source code from url: ${URL}"
            local Archive=""
        
            SOURCE_CODE=$(getUrlSource ${URL})
            INFORMATIONS_TEXT=$(echo ${SOURCE_CODE} | sed -n "s/.*<pre>\(.*\)<\/pre>.*/\1\n/Ip")
            
            echo ${INFORMATIONS_TEXT} | sed "s/SOURCE RPM:/RPM:/g" | sed "s/: /:/g" | sed "s/\([^:]*\):\([^:]*\) \([A-Z ]*\):/\1:\2\n\3:/g" | sed "s/\([^:]*\):\([^:]*\) \([A-Z ]*\):/\1:\2\n\3:/g" > ${INFOS_FILE}
            
            while read line; do
              export "$(echo "${line}" | sed -n "s#^\([^:]*\):\(.*\)#\1=\2#pI")"
            done < ${INFOS_FILE}
        fi
    fi
}

function getUrlResponseCode() {
    if [ ! -z "$1" ]
    then
        local URL="$1"
        local RESPONSE_CODE=$(curl -L -s --head --insecure "${URL}" | head -n 1 | sed -n "s/HTTP\/[0-9]\.[0-9] \([0-9]*\).*/\1/Ip")
        
        
        if [ ! -z "${RESPONSE_CODE}" ] && [ "${RESPONSE_CODE}" != "" ]
        then
            echo "${RESPONSE_CODE}"
        fi
    fi
}

function getUrlSource() {
    if [ ! -z "$1" ]
    then
        local URL="$1"
        local SOURCE=$(curl "${URL}" -L --insecure 2>>$LOGFILE)
        echo ${SOURCE}
    fi
}

function urlExists() {
    if [ ! -z "$1" ]
    then
        local URL="$1"
        local EXISTS="0"
        local RESPONSE_CODE=$(getUrlResponseCode "${URL}")
        
        
        if [ "${RESPONSE_CODE}" == "200" ]
        then
            EXISTS="1"
        fi
        echo ${EXISTS}
    fi
}

function getFileChecksum() {
    if [ ! -z "$1" ]
    then
        local FILE="$1"
        local CHECKSUM=$(md5sum ${FILE} | awk '/ / {print $1}')
        echo -E ${CHECKSUM}
    fi
}

function compareChecksums() {
    if [ ! -z "$1" ] && [ ! -z $2 ]
    then
        local CHECKSUM="$1"
        local REMOTE_CHECKSUM="$2"

        if [ "${CHECKSUM}" != "${REMOTE_CHECKSUM}" ]
        then
            
            ERRORS_LIST[${ERRORS_COUNT}]="|${SPACE}${CHECKSUM}${SPACE}|${SPACE}${REMOTE_CHECKSUM}${SPACE}|${SPACE}The${SPACE}checksum${SPACE}files${SPACE}doesn't${SPACE}have${SPACE}the${SPACE}same${SPACE}value${SPACE}.${SPACE}|\n"
            ERRORS_COUNT=$((${ERRORS_COUNT} + 1))
        else
            _success "the checksums are matching ."
        fi
    fi
}

function dependencyNameToPath() {
    if [ ! -z "$1" ]
    then
        local DEPENDENCY_NAME="$1"
        local DEPENDENCY_PATH=""
        
        for part in $(IFS='-'; echo $DEPENDENCY_NAME)
        do
            DEPENDENCY_PATH="${DEPENDENCY_PATH}/${part}"
        done
        
        echo "${DEPENDENCY_PATH}/"
    fi
}

function getDependencyUrl() {
    if [ ! -z "$1" ] && [ ! -z "$2" ] && [ ! -z "$3" ] && [ ! -z "$4" ]
    then
        local BUILD_NAME="$2"
        local ARCH="$3"
        local EXTENSION="$4"
        
        local DEPENDENCY_NAME=$(echo "$1" | sed -n "s/^\([^\.]*\)-[0-9].*/\1/Ip")
        local DEPENDENCY_NAME_SUFFIX=$(echo "$1" | sed -n "s/^\([^\.]*\)-\([0-9].*\)/\2/Ip")
        local DEPENDENCY_PATH_NAME=$(echo "${DEPENDENCY_NAME_SUFFIX}.${BUILD_NAME}-${ARCH}")
        local DEPENDENCY_PATH=$(dependencyNameToPath "${DEPENDENCY_PATH_NAME}")
        DEPENDENCY_PATH="${DEPENDENCY_NAME}${DEPENDENCY_PATH}"
        
        for url in ${REPOSITORIES_URLS_LIST[@]}
        do
            local URL_FIRST_PATH_ITEM=$(echo ${url} | sed -n "s/.*:\/\/\([^\/]*\)\/\([^\/]*\)\/.*/\2/pI")
            local DEPENDENCY_URL="${url}/${DEPENDENCY_PATH}"
            local DEPENDENCY_URL_EXISTS=$(urlExists "${DEPENDENCY_URL}")
            local PACKAGE_NAME=$(echo "${DEPENDENCY_PATH_NAME}" | sed "s/-${ARCH}/.${ARCH}/gi")

            if [ "${DEPENDENCY_URL_EXISTS}" == "1" ]
            then
                echo "${DEPENDENCY_URL}/${DEPENDENCY_NAME}-${PACKAGE_NAME}.${EXTENSION}"
            else
                if [ "${URL_FIRST_PATH_ITEM}" == "brewroot" ]
                then
                    DEPENDENCY_URL=$(echo "${DEPENDENCY_URL}" | sed -n "s/\/\([0-9]\+.\)\([^0-9\/]*\)\([0-9]\+\)\/\([^\/]*\)\/$/\/\1\2\3\/\2\//pI")
                    DEPENDENCY_URL_EXISTS=$(urlExists "${DEPENDENCY_URL}")
                    
                    if [ "${DEPENDENCY_URL_EXISTS}" == "1" ]
                    then
                        echo "${DEPENDENCY_URL}/${DEPENDENCY_NAME}-${PACKAGE_NAME}.${EXTENSION}"
                    fi
                fi
            fi
        done
    fi

}

function displayInformations() {
    printf "\n\n${_bold}${_underline}${_purple} %60s%60s${_reset}\n" "Build Informations" ""
    echo ""
    for attribute in ${INFORMATIONS_ATTRIBUTES[@]}
    do
        printf " ${_bold}${_purple}>>${_reset} ${_bold}${_red}%30s${_reset}: ${_blue}%-50s${_reset}\n" ${attribute} "${!attribute}"
    done
    
    printf "\n\n\n${_bold}${_underline}${_red} %60s%60s${_reset}\n" "Dependencies" ""
    echo ""
    for dependency in ${DEPENDENCIES_LIST[@]}
    do
        local dependency_url=$(getDependencyUrl "${dependency}" "${BUILD_NAME}" "${ARCH}" "zip")
        
        if [ "${dependency_url}" != "" ]
        then
            printf "| ${_bold}${_blue}%b${_reset} => ${_green}%b${_reset}\n" "$dependency" "$dependency_url"
        else
            printf "| ${_bold}${_blue}%b${_reset} => ${_red}NOT FOUND${_reset}\n" "$dependency"
        fi
    done
    
    printf "\n\n\n${_bold}${_underline}${_red} %60s%60s${_reset}\n" "Errors Found" ""
    echo ""
    for error in ${ERRORS_LIST[@]}
    do
        _table_separator ${_red}
        printf "${_red}%b${_reset}" "$error"
        _table_separator ${_red}
    done
    
    echo ""
    echo ""
}

################################################################################
# Main
################################################################################

# Notes
# http://www.qa.jboss.com/xbuildroot/packages/jws3.1/
# http://www.qa.jboss.com/xbuildroot/packages/ep6.4/
# /usr/bin/zipinfo -z /tmp/jws-application-servers-3.1.0-14.sun10.sparc64.zip |  grep -zPo "DEPENDENCIES: (?s)(.*)DESCRIPTION:" | grep -zPo "(?s)(?:DEPENDENCIES:|,) (.*?)(?:DESCRIPTION:)" | sed  "s/[^:]*:.//gi" | tr -d " " | tr -d "\n" | tr "," "\n"


export LC_CTYPE=C
export LANG=C

DEBUG=0 # 1|0
_debug set -x
VERSION="0.1.0"
SPACE='\x20'

# General
LOGFILE="build_check.log"
ERRORS_COUNT=0
DEPENDENCIES_COUNT=0

ERRORS_LIST=()
DEPENDENCIES_LIST=()

# Arguments/global variables
URL_ARG=""
DEPENDENCY_ARG=""
SOURCE_CODE=""

# Build informations variables
ARCHIVE=""
NAME=""
VERSION=""
RELEASE=""
SUMMARY=""
DISTRIBUTION=""
VENDOR=""
LICENSE=""
PACKAGER=""
GROUP=""
OS=""
ARCH=""
BUILD_NAME=""
RPM=""
URL=""
TIMESTAMP=""
COMPILER=""
DESCRIPTION=""

ZIP_FILE=""
ZIP_FILE_CHECKSUM=""
ZIP_REMOTE_FILE=""
ZIP_REMOTE_CHECKSUM=""
ZIP_REMOTE_CHECKSUM_FILE=""

DEVEL_ZIP_FILE=""
DEVEL_ZIP_FILE_CHECKSUM=""
DEVEL_ZIP_REMOTE_FILE=""
DEVEL_ZIP_REMOTE_CHECKSUM=""
DEVEL_ZIP_REMOTE_CHECKSUM_FILE=""

INFORMATIONS_ATTRIBUTES=("ARCHIVE" "DEVEL_ARCHIVE" "BUILD_NAME" "NAME" "VERSION" "RELEASE" "SUMMARY" "DISTRIBUTION" "VENDOR" "LICENSE" "PACKAGER" "GROUP" "OS" "ARCH" "RPM" "URL" "TIMESTAMP" "COMPILER" "DESCRIPTION" "ZIP_FILE" "ZIP_REMOTE_FILE" "ZIP_REMOTE_CHECKSUM_FILE" "ZIP_FILE_CHECKSUM" "ZIP_REMOTE_CHECKSUM" "DEVEL_ZIP_FILE" "DEVEL_ZIP_REMOTE_FILE" "DEVEL_ZIP_REMOTE_CHECKSUM_FILE" "DEVEL_ZIP_FILE_CHECKSUM" "DEVEL_ZIP_REMOTE_CHECKSUM")

REPOSITORIES_URLS_LIST=("http://www.qa.jboss.com/xbuildroot/packages/ep6.4" "http://www.qa.jboss.com/xbuildroot/packages/jws3.1" "http://www.qa.jboss.com/xbuildroot/packages/jbcs2.4.27" "http://download.eng.bos.redhat.com/brewroot/packages")

function main() {
    [[ $# -lt 1 ]] && _printUsage
    
    _arrow "Processing arguments..."
    processArgs "$@"
    _success "Done ."
    
    if [ -f $LOGFILE ]
    then
        rm -rf ${LOGFILE}
    fi
    
    if [ ! -z ${DEPENDENCY_ARG} ]
    then
        checkDependency "${DEPENDENCY_ARG}"
    else
        _error "Argument: --dependency is required ."
    fi
    
    exit 0
}

main "$@"

_debug set +x
