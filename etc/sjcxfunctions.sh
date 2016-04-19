#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# SJCX core functions 
#
# Author : Christophe Marteau
# Version : 1.0
#
# Realease notes :
# 23/11/2009 : - Initial version

source "${SJCXSHELL_PATH}/etc/sjcx.conf" || exit ${?}

# Logging and debugging function.
# [in] $PRINT_FUNCTION_NAME : Function name in which we make the call
# [in] $PRINT_MESSAGE : Message to display ("No msg" by default)
# [in] $PRINT_PRIORITY : Message pritority ('info' by default)
#                        Possible values : alert, crit, debug, emerg, err, error, info, notice, warning, warn
# [in] $PRINT_DEBUG_LEVEL : Debug level
function printMsg() {
  local PRINT_FUNCTION_NAME="${1}"
  local PRINT_MESSAGE="${2:-No msg}"
  local PRINT_PRIORITY="${3:-info}"
  local PRINT_DEBUG_LEVEL="${4:-1}"

  local PRINT_LINE_CPT=0
  local PRINT_INDENT_PRIORITY=""

  if [ -n "${PRINT_INDENT_STRING}" ]
  then
    PRINT_INDENT_PRIORITY="-9"
  fi

  if [[ ${PRINT_PRIORITY} =~ '^(alert|crit|debug|emerg|err|error|info|notice|warning|warn)$' ]]
  then
    IFS="
"   
    if [[ "${PRINT_MESSAGE}" =~ "^(DEBUT|BEGIN) " ]]
    then
      PRINT_INDENT="${PRINT_INDENT_STRING}${PRINT_INDENT}"
    fi

    if [ "${DEBUG}" -eq 1 ] && [ "${PRINT_PRIORITY}" = "debug" ] && [ "${PRINT_DEBUG_LEVEL}" -eq 1 ]
    then
      PRINT_PRIORITY="info"
    fi

    for print_message_line in ${PRINT_MESSAGE}
    do
      if [ ${PRINT_LINE_CPT} -eq 0 ]
      then
        print_message_line="$(${PRINTF_BINARY} "%${PRINT_INDENT_PRIORITY}s ${PRINT_INDENT:2}%s %s" "[${PRINT_PRIORITY}]" "(${PRINT_FUNCTION_NAME})" "${print_message_line}")"
      else
        print_message_line="$(${PRINTF_BINARY} "%${PRINT_INDENT_PRIORITY}s ${PRINT_INDENT:2}%s %s" "[${PRINT_PRIORITY}]" "(${PRINT_FUNCTION_NAME}) ..." "${print_message_line}")"
      fi
      if [ "${PRINT_PRIORITY}" != "debug" ] || [ ${DEBUG} -ge ${PRINT_DEBUG_LEVEL} ]
      then 
        ${ECHO_BINARY} "${print_message_line}" >&2
      fi
      ((PRINT_LINE_CPT ++))
    done
    IFS="${IFS_INI}"

    if [[ "${PRINT_MESSAGE}" =~ "^(FIN|END) " ]]
    then
      PRINT_INDENT="${PRINT_INDENT:2}"
    fi
  else
    ${PRINTF_BINARY} "%${PRINT_INDENT_PRIORITY}s ${PRINT_INDENT:2}%s %s" "[err]" "(printMsg)" "Invalid message priority '${PRINT_PRIORITY}'."
  fi
}

# Fonction check availability for all binary listed in BINARY_LIST
# [in] $BINARY_LIST : Binary list to check
function isLaunchable() {
    local BINARY_LIST="${1}"

    printMsg "isLaunchable" "BEGIN isLaunchable" "debug" "9"
    local IS_LAUNCHABLE_ERROR=0
    for binary in ${BINARY_LIST}
    do
        if [ -f ${binary} ] ; then
            printMsg "isLaunchable" "'${binary}' : [FOUND]" "debug" "8"
        else
            printMsg "isLaunchable" "'${binary}' : [NOT FOUND]" "err"
            IS_LAUNCHABLE_ERROR=1
        fi
    done
       if [ ${IS_LAUNCHABLE_ERROR} -eq 1 ] ; then
        printMsg "isLaunchable" "Unable to execute this script." "err"
        printMsg "isLaunchable" "END isLaunchable" "debug" "9"
        exit 1
    fi
    printMsg "isLaunchable" "END isLaunchable"  "debug" "9"
}

# This function query the API and sanitize output. It raise error when curl request failed or when response has an "error" item
# [in] $AUTH : Username to autenticate to the API
# [in] $METHOD : Method to query API
# [in] $HEADERS : List of headers to add to the request if exists
# [in] $DATA : Data to post in the request if exists
# [in] $FILE : FILE to upload in the request if exists
# [in] $API_URL : API url
# [in] $API_URI : API uri
# [in] $FILTER : A grep filter to select items in reponse
# Return a list of item (one per line) 
function queryAPI() {
  local AUTH="${1}"
  local METHOD="${2}"
  local HEADERS="${3}"
  local DATA="${4}"
  local FILE="${5}"
  local API_URL="${6}"
  local API_URI="${7}"
  local FILTER="${8}"

  printMsg "queryAPI" "BEGIN queryAPI" "debug" "9"

  printMsg "queryAPI" "queryAPI( ${AUTH}, ${METHOD}, [${HEADERS}], ${DATA}, ${FILE}, ${API_URL}, ${API_URI}, ${FILTER} )" "debug" "8"
  local CURL_OPT='-s -S'

  local HEADER_OPT=""
  if [ "${HEADERS}" != "" ]
  then
    HEADER_OPT="--header $(${ECHO_BINARY} "${HEADERS}" | ${AWK_BINARY} '{ gsub(/'"'"' '"'"'/,"'"'"' --header '"'"'",$0); print $0 }')"
  fi

  local CURL_COMMAND="${CURL_BINARY} ${CURL_OPT} --basic --user '${AUTH}' -X ${METHOD} ${HEADER_OPT}"
  local DATA_OPT=""
  if [ "${DATA}" != "" ]
  then
    CURL_COMMAND="${CURL_COMMAND} --data '${DATA}'"  
  fi

  local FILE_OPT=""
  if [ "${FILE}" != "" ]
  then
    CURL_COMMAND=" ${CURL_COMMAND} --form \"file=@${FILE}\""  
  fi

  printMsg "queryAPI" "Request : ${CURL_COMMAND} ${API_URL}/${API_URI} 2>&1" "debug" "5"
  CURL_RESPONSE="$(eval ${CURL_COMMAND} "${API_URL}/${API_URI}" 2>&1)"
  CURL_RESPONSE_CODE=${?}
  printMsg "queryAPI" "Response : [${CURL_RESPONSE_CODE}] ${CURL_RESPONSE}" "debug" "5"

  RESPONSE_MSG="$( ${ECHO_BINARY} "${CURL_RESPONSE}" | ${TAIL_BINARY} -n 1)"
  printMsg "queryAPI" "Response (short) : [${CURL_RESPONSE_CODE}] ${RESPONSE_MSG}" "debug" "5"

  if [ ${CURL_RESPONSE_CODE} -eq 0 ] && [[ "${RESPONSE_MSG}" =~ '^(\{[^}]*\}|\[(\{?[^}]+\}?,?)*\]|)$' ]]
  then
    if [[ "${RESPONSE_MSG}" =~ '^\{"error":"([^"]+)"\}$' ]]
    then
      API_ERROR="${BASH_REMATCH[1]}"
      printMsg "queryAPI" "Unable to query API (${API_ERROR})" "error"
      printMsg "queryAPI" "END queryAPI" "debug" "9"
      exit 1
    else
      if [ "${FILTER}" == '' ]
      then
        RETURN_OUTPUT="$(${ECHO_BINARY} "${RESPONSE_MSG}" | ${AWK_BINARY} '{ gsub(/^\[{?|}?\]$/,"",$0); gsub(/},{/,"\n",$0); print $0 }')"
      else
        printMsg "queryAPI" "FILTER : ${GREP_BINARY} -E ${FILTER}" "debug" "8"
        RETURN_OUTPUT="$(${ECHO_BINARY} "${RESPONSE_MSG}" | ${AWK_BINARY} '{ gsub(/^\[{?|}?\]$/,"",$0); gsub(/},{/,"\n",$0); print $0 }' | eval ${GREP_BINARY} -E ${FILTER} )"
      fi
      printMsg "queryAPI" "Return '${RETURN_OUTPUT}'" "debug" "5"
      ${ECHO_BINARY} "${RETURN_OUTPUT}"
    fi
  else
    printMsg "queryAPI" "Unable to query API (${RESPONSE_MSG})" "error"
    printMsg "queryAPI" "END queryAPI" "debug" "9"
    exit 1
  fi

  printMsg "queryAPI" "END queryAPI" "debug" "9"
}

function getBucketID() {
  local BUCKET_NAME="${1}"
  local BUCKET_LIST="${2}"

  printMsg "getBucketID" "BEGIN getBucketID" "debug" "9"
  if [[ "${BUCKET_LIST}" =~ '"user":"[^"]+","created":"[^"]+","name":"'${BUCKET_NAME}'","pubkeys":[^,]+,"status":"[^"]+","transfer":[^,]+,"storage":[^,]+,"id":"([^"]+)"' ]]
  then
    BUCKET_ID="${BASH_REMATCH[1]}"
    printMsg "getBucketID" "Found bucket '${BUCKET_NAME}' with ID '${BUCKET_ID}'" "debug" "5"
    ${ECHO_BINARY} "${BUCKET_ID}"
    printMsg "getBucketID" "END getBucketID" "debug" "9"
  fi
}

# For bash (>3.1)
if [ -n "$(shopt | grep "compat31")" ] ; then
    shopt -s compat31
fi
LC_ALL=POSIX
export LC_ALL
IFS_INI="${IFS}"

# Generales
PRINT_INDENT=""					# Indent start string
PRINT_INDENT_STRING="${PRINT_INDENT_STRING:-}"	# Indent string (disabled by default)

isLaunchable "${BINARY_LIST}"
