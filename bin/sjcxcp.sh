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

# SJCX copy buckets and files
#
# Author : Christophe Marteau
# Version : 1.0
#
# Realease notes :
# 19/03/2016 : - Initial version

source "${SJCXSHELL_PATH}/etc/sjcxfunctions.sh" || exit ${?}

function usage() {
  printMsg "usage" "BEGIN usage" "debug" "9"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "Storj cp files"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "usage : ${0} [-v] <local file path> [<local file path>] ... sjcx://<bucket>"
  ${ECHO_BINARY} "              or: <bucket name>/<remote file> [<bucket name>/<remote file>] ... <local folder>"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "  -h (--help)    : Display this help."
  ${ECHO_BINARY} "  -v (--verbose) : Print some informations when copy file"
  ${ECHO_BINARY} ""
  printMsg "usage" "END usage" "debug" "9"
  exit 1
}

SELECTED_USER="${SJCX_HOME}/.${SJCX_USER}"
SJCXLS_OPT='hv'
while getopts "${SJCXLS_OPT}" opt
do
  case "${opt}" in
    'h' )
      usage
      ;;
    'v' )
      DEBUG=1
      ;;
    *)
      printMsg "sjcxcp" "Incorrect option '${1}'." "error"
      usage
      ;;
  esac
done
shift $((OPTIND-1))
CP_LIST=("$@")


printMsg "sjcxcp" "BEGIN main" "debug" "9"
if [ -z "${CP_LIST}" ]
then
  printMsg "sjcxcp" "No option provided"
  usage
  exit 1
fi

for (( i=0; i<${#CP_LIST[*]}; i++))
do 
  SRC_LIST[${i}]=${CP_LIST[${i}]}
done
unset -v "SRC_LIST[-1]"
DST=${CP_LIST[-1]}
printMsg "sjcxcp" "Trying to copy '${SRC_LIST[*]}' into '${DST}' ..." "debug" "4"

if [ -z "${SRC_LIST}" ] || [ -z "${DST}" ]
then
  printMsg "sjcxcp" "No src nor dst"
  usage
  exit 1
fi

if [[ "${DST}" =~ '^sjcx://(.*)$' ]]
then
  SJCX_BUCKET_NAME="${BASH_REMATCH[1]}"
  printMsg "sjcxcp" "Uploading file ..." "debug" "8"
  BUCKETS_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets")"
  printMsg "sjcxcp" "Bucket list : '${BUCKETS_LIST}'" "debug" "5"

  BUCKET_ID="$(getBucketID "${SJCX_BUCKET_NAME}" "${BUCKETS_LIST}")"
  if [ -z "${BUCKET_ID}" ]
  then
    printMsg "sjcxcp" "sjcxcp: '${SJCX_BUCKET_NAME}': No such bucket" "error"
  else
    for (( i=0; i<${#SRC_LIST[*]}; i++ ))
    do
      if [ -f "${SRC_LIST[${i}]}" ]
      then
        SJCX_TOKEN="$(queryAPI "$(${CAT_BINARY} "${SELECTED_USER}")" "POST" "'Content-Type: application/json' 'Accept: application/json'" '{"operation":"PUSH"}' "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/tokens")"
        printMsg "sjcxcp" "Response : ${SJCX_TOKEN}" "debug" "5"
        
        if [[ "${SJCX_TOKEN}" =~ '^\{"bucket":"([^"]+)","operation":"([^"]+)","expires":"([^"]+)","token":"([^"]+)","id":"([^"]+)"\}$' ]]
        then
          TOKEN_BUCKET_ID="${BASH_REMATCH[1]}"
          TOKEN_OPERATION="${BASH_REMATCH[2]}"
          TOKEN_EXPIRES="${BASH_REMATCH[3]}"
          TOKEN="${BASH_REMATCH[4]}"
          TOKEN_ID="${BASH_REMATCH[5]}"
          if [ "${TOKEN_BUCKET_ID}" == "${BUCKET_ID}" ]
          then
            FILE_SIZE="$(${WC_BINARY} -c "${SRC_LIST[${i}]}" 2>&1 | ${AWK_BINARY} '{print $1}')"
            printMsg "sjcxcp" "Uploading file '${SRC_LIST[${i}]}' with size '${FILE_SIZE}'" "debug" "2"

            printMsg "sjcxcp" "\"${SRC_LIST[${i}]}\" -> \"${DST}/$(${BASENAME_BINARY} "${SRC_LIST[${i}]}")\"" "debug" "1" 
            printMsg "sjcxcp" "[${TOKEN_OPERATION}] Token '${TOKEN}' for bucket : '${SJCX_BUCKET_NAME}' [${BUCKET_ID}] (expires : '${TOKEN_EXPIRES}')" "debug" "2"
            COPY_REQUEST="$(queryAPI "$(${CAT_BINARY} "${SELECTED_USER}")" "PUT" "'Content-Type: multipart/form-data' 'Accept: application/json' 'x-token: ${TOKEN}' 'x-filesize: ${FILE_SIZE}'" "" "${SRC_LIST[${i}]}" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files" "")"
            printMsg "sjcxcp" "Response : ${COPY_REQUEST}" "debug" "5"
            if [[ "${COPY_REQUEST}" =~ '^\{"bucket":"([^"]+)","mimetype":"([^"]+)","filename":"([^"]+)","size":([^,]+),"hash":"([^"]+)"\}$' ]]
            then
              COPY_BUCKET_ID="${BASH_REMATCH[1]}"
              COPY_MIME_TYPE="${BASH_REMATCH[2]}"
              COPY_FILE_NAME="${BASH_REMATCH[3]}"
              COPY_SIZE="${BASH_REMATCH[4]}"
              COPY_FILE_ID="${BASH_REMATCH[5]}"
              if [ "${COPY_BUCKET_ID}" == "${BUCKET_ID}" ]
              then
                if [ "${FILE_SIZE}" == "${COPY_SIZE}" ]
                then
                  printMsg "sjcxcp" "Local file '${SRC_LIST[${i}]}' succesfully copied on '${DST}/${COPY_FILE_NAME}' with ID [${COPY_FILE_ID}]" "debug" "1"
                else
                  printMsg "sjcxcp" "Internal error: Input filename size '${FILE_SIZE}' and copy size '${COPY_SIZE}' mistmatch" "error"
                fi
              else
                printMsg "sjcxcp" "Internal error: Selected bucket '${BUCKET_ID}' and copy bucket '${COPY_BUCKET_ID}' mistmatch" "error"
              fi
            else
              printMsg "sjcxcp" "Unable copy file '${SRC_LIST[${i}]}' on '${DST}' (${COPY_REQUEST})" "error"
            fi
          else
            printMsg "sjcxcp" "Internal error: Selected bucket '${BUCKET_ID}' and token bucket '${TOKEN_BUCKET_ID}' mistmatch" "error"
          fi
        else
          printMsg "sjcxcp" "Unable to retrieve token (${SJCX_TOKEN}) for file '${SRC_LIST[${i}]}'" "error"
        fi
      else
        printMsg "sjcxcp" "Unable to find local file '${SRC_LIST[${i}]}'" "error"
      fi
    done
  fi
else
  printMsg "sjcxcp" "Downloading file ..." "debug" "8"
  if [ -d "${DST}" ]
  then 
    BUCKETS_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets")"
    printMsg "sjcxcp" "Bucket list : '${BUCKETS_LIST}'" "debug" "5"
    for (( i=0; i<${#SRC_LIST[*]}; i++ ))
    do
      SJCX_BUCKET_NAME="$(${DIRNAME_BINARY} "${SRC_LIST[${i}]}")"
      SJCX_FILE_NAME="$(${BASENAME_BINARY} "${SRC_LIST[${i}]}")"
      BUCKET_ID="$(getBucketID "${SJCX_BUCKET_NAME}" "${BUCKETS_LIST}")"
      if [ -z "${BUCKET_ID}" ]
      then
        printMsg "sjcxcp" "sjcxcp: '${SJCX_BUCKET_NAME}': No such bucket" "error"
      else
        SEARCH_FILTER="'\"filename\":\"${SJCX_FILE_NAME}\"'"
        SJCX_FILE="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files" "${SEARCH_FILTER}")"
        printMsg "sjcxcp" "Files list : '${SJCX_FILE}'" "debug" "2"
        if [[ "${SJCX_FILE}" =~ '"bucket":"([^"]+)","mimetype":"([^"]+)","filename":"([^"]+)","size":([^,]+),"hash":"([^"]+)"' ]]  
        then
          FILE_BUCKET_ID="${BASH_REMATCH[1]}"
          FILE_MIME_TYPE="${BASH_REMATCH[2]}"
          FILE_NAME="${BASH_REMATCH[3]}"
          FILE_SIZE="${BASH_REMATCH[4]}"
          FILE_HASH="${BASH_REMATCH[5]}"
          if [ "${FILE_BUCKET_ID}" == "${BUCKET_ID}" ]
          then
            SJCX_TOKEN="$(queryAPI "$(${CAT_BINARY} "${SELECTED_USER}")" "POST" "'Content-Type: application/json' 'Accept: application/json'" '{"operation":"PULL"}' "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/tokens")"
            printMsg "sjcxcp" "Response : ${SJCX_TOKEN}" "debug" "5"
            if [[ "${SJCX_TOKEN}" =~ '^\{"bucket":"([^"]+)","operation":"([^"]+)","expires":"([^"]+)","token":"([^"]+)","id":"([^"]+)"\}$' ]]
            then
              TOKEN_BUCKET_ID="${BASH_REMATCH[1]}"
              TOKEN_OPERATION="${BASH_REMATCH[2]}"
              TOKEN_EXPIRES="${BASH_REMATCH[3]}"
              TOKEN="${BASH_REMATCH[4]}"
              TOKEN_ID="${BASH_REMATCH[5]}"
              if [ "${TOKEN_BUCKET_ID}" == "${BUCKET_ID}" ]
              then
                printMsg "sjcxcp" "Uploading file '${SRC_LIST[${i}]}' with size '${FILE_SIZE}'" "debug" "2"
                printMsg "sjcxcp" "[${TOKEN_OPERATION}] Token '${TOKEN}' for bucket : '${SJCX_BUCKET_NAME}' [${BUCKET_ID}] (expires : '${TOKEN_EXPIRES}')" "debug" "2"
                printMsg "sjcxcp" "\"sjcx://${SRC_LIST[${i}]}\" -> \"${DST}\"" "debug" "1" 
                COPY_REQUEST="$(queryAPI "$(${CAT_BINARY} "${SELECTED_USER}")" "GET" "'Accept: application/json' 'x-token: ${TOKEN}'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files/${FILE_HASH}" "")"
                printMsg "sjcxcp" "Response : ${COPY_REQUEST}" "debug" "5"
                if [[ "${COPY_REQUEST}" =~ '^"hash":"([^"]+)","token":"([^"]+)","operation":"([^"]+)","channel":"([^"]+)"$' ]]
                then
                  COPY_FILE_ID="${BASH_REMATCH[1]}"
                  COPY_TOKEN="${BASH_REMATCH[2]}"
                  COPY_OPERATION="${BASH_REMATCH[3]}"
                  COPY_CHANNEL="${BASH_REMATCH[4]}"
                  printMsg "sjcxcp" "Get token '${COPY_TOKEN}' for operation '${COPY_OPERATION}' for file ID '${COPY_FILE_ID}' on channel '${COPY_CHANNEL}'" "debug" "2"
                  WRITE_DATA="$(${PYTHON3_BINARY} $(${DIRNAME_BINARY} "$0")/${DIRTYWEBSOCKETCLI_SCRIPT} "${COPY_CHANNEL}" '{"hash":"'"${COPY_FILE_ID}"'","token":"'"${COPY_TOKEN}"'","operation":"'"${COPY_OPERATION}"'"}' "${DST}/${FILE_NAME}")"
                  if [ "${WRITE_DATA}" == "" ]
                  then
                    WRITE_FILE_SIZE="$(${WC_BINARY} -c "${DST}/${SJCX_FILE_NAME}" 2>&1 | ${AWK_BINARY} '{print $1}')"
                    if [ "${FILE_SIZE}" == "${WRITE_FILE_SIZE}" ]
                    then
                      printMsg "sjcxcp" "Remote file 'sjcx://${SJCX_BUCKET_NAME}/${SJCX_FILE_NAME}' succesfully copied on '${DST}/${SJCX_FILE_NAME}' with ID [${COPY_FILE_ID}]" "debug" "1"
                    else
                      printMsg "sjcxcp" "Internal error: Input filename size '${FILE_SIZE}' and copy size '${WRITE_FILE_SIZE}' mistmatch" "error"
                    fi
                  else
                    printMsg "sjcxcp" "Unable copy file 'sjcx://${SJCX_BUCKET_NAME}/${SJCX_FILE_NAME}' on '${DST}' (${WRITE_DATA})" "error"
                  fi
                else
                  printMsg "sjcxcp" "Unable copy file 'sjcx://${SJCX_BUCKET_NAME}/${SJCX_FILE_NAME}' on '${DST}' (${COPY_REQUEST})" "error"
                fi
              else
                printMsg "sjcxcp" "Internal error: Selected bucket '${BUCKET_ID}' and token bucket '${TOKEN_BUCKET_ID}' mistmatch" "error"
              fi
            else
              printMsg "sjcxcp" "Unable to retrieve token (${SJCX_TOKEN}) for file 'sjcx://${SJCX_BUCKET_NAME}/${SJCX_FILE_NAME}'" "error"
            fi
          else
            printMsg "sjcxcp" "Internal error: Selected bucket '${BUCKET_ID}' and file bucket '${FILE_BUCKET_ID}' mistmatch" "error"
          fi
        else
          printMsg "sjcxcp" "sjcxcp: '${SJCX_FILE_NAME}': No such file in bucket '${SJCX_BUCKET_NAME}'" "error"
        fi
      fi
    done
  else
    printMsg "sjcxcp" "Unable to find local folder '${DST}'" "error"
  fi
fi
printMsg "sjcxcp" "END main" "debug" "9"

