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

# SJCX rm
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
  ${ECHO_BINARY} "This script removes buckets and files"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "usage : ${0} [-vrf] <bucket name>[/<file name>|/*] [<bucket name>[/<file name>|/*]] ..."
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "  -h    : Display this help."
  ${ECHO_BINARY} "  -v    : Print some informations when removing buckets"
  ${ECHO_BINARY} "  -r -R : Remove also bucket if empty when removing file"
  ${ECHO_BINARY} "  -f    : Remove also bucket even if there is files in it"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} ""
  printMsg "usage" "END usage" "debug" "9"
  exit 1
}

RECURSIVE=0
RM_FORCE=0
declare -a SJCX_BUCKET_LIST
SELECTED_USER="${SJCX_HOME}/.${SJCX_USER}"

# Menu
SJCXLS_OPT='hvrRf'
while getopts "${SJCXLS_OPT}" opt
do
  case "${opt}" in
    'h' )
      usage
      ;;
    'v' )
      DEBUG=1
      ;;
    'r' | 'R' )
      RECURSIVE=1
      ;;
    'f' )
      RM_FORCE=1
      ;;
    *)
      printMsg "sjcxrm" "Incorrect option '${1}'." "error"
      usage
      ;;
    esac
done
shift $((OPTIND-1))
SJCX_BUCKET_LIST=("$@")

if [ -z "${SJCX_BUCKET_LIST[*]}" ]
then
  printMsg "sjcxrm" "No bucket or file name provided" "error"
  usage
fi

printMsg "sjcxrm" "BEGIN main" "debug" "9"

BUCKETS_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets" "")"
printMsg "sjcxrm" "Bucket list : '${BUCKETS_LIST}'" "debug" "5"

declare -a RM_BUCKET_LIST=()
for (( i=0; i<${#SJCX_BUCKET_LIST[*]}; i++))
do
  SJCX_BUCKET_NAME="$(${DIRNAME_BINARY} "${SJCX_BUCKET_LIST[${i}]}")"
  SJCX_FILE_NAME="$(${BASENAME_BINARY} "${SJCX_BUCKET_LIST[${i}]}")"
  printMsg "sjcxrm" "Parsed bucket '${SJCX_BUCKET_NAME}' and file '${FILE_NAME}'" "debug" "5" 
  if [ "${SJCX_BUCKET_NAME}" == '.' ]
  then
    SJCX_BUCKET_NAME="${SJCX_FILE_NAME}"
    if [ ${RM_FORCE} -eq 1 ] && [ ${RECURSIVE} -eq 1 ]
    then
      SJCX_FILE_NAME="*"
    else
      SJCX_FILE_NAME=""
    fi
  fi
  BUCKET_ID="$(getBucketID "${SJCX_BUCKET_NAME}" "${BUCKETS_LIST}")"
  if [ -z "${BUCKET_ID}" ]
  then
    printMsg "sjcxrm" "sjcxrm: failed to remove '${SJCX_BUCKET_NAME}': No such bucket" "error"
  else
    if [ "${SJCX_FILE_NAME}" == "" ]
    then
      printMsg "sjcxrm" "File list : '${FILES_LIST}'" "debug" "5"
    else
      FILES_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files" "")"
      printMsg "sjcxrm" "No selected file to be removed in bucket '${SJCX_BUCKET_NAME}'" "debug" "4"
      RM_FILE_OK=0
      IFS="
"
      for fileName in ${FILES_LIST} 
      do 
        if [[ "${fileName}" =~ '"bucket":"([^"]+)","mimetype":"([^"]+)","filename":"([^"]+)","size":([^,]+),"hash":"([^"]+)"' ]]
        then
          FILE_BUCKET_ID="${BASH_REMATCH[1]}"
          FILE_MIME_TYPE="${BASH_REMATCH[2]}"
          FILE_NAME="${BASH_REMATCH[3]}"
          FILE_SIZE="${BASH_REMATCH[4]}"
          FILE_HASH="${BASH_REMATCH[5]}"
          printMsg "sjcxrm" "Removing file '${FILE_NAME}' for bucket '${SJCX_BUCKET_NAME}'" "debug" "2"
   
          if [ "${FILE_NAME}" == "${SJCX_FILE_NAME}" ] || [ "${SJCX_FILE_NAME}" == '*' ]
          then
            RMFILE_RESPONSE="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "DELETE" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files/${FILE_HASH}")"
            
            if [ "${RMFILE_RESPONSE}" == "" ]
            then
              printMsg "sjcxrm" "File '${FILE_NAME}' in bucket '${SJCX_BUCKET_NAME}' succesfully removed" "debug" "1"
              RM_FILE_OK=1
            else
              printMsg "sjcxrm" "sjcxrm: failed to remove '${FILE_NAME}' in bucket '${SJCX_BUCKET_NAME}'  (${RMFILE_RESPONSE})" "error"
            fi
          fi
        else
          printMsg "sjcxrm" "Unable to parse file : '${fileName}'" "error"
        fi
      done
      if [ ${RM_FILE_OK} -eq 0 ]
      then
        printMsg "sjcxrm" "sjcxrm: failed to remove '${SJCX_FILE_NAME}' in bucket '${SJCX_BUCKET_NAME}: No such file'" "error"
      fi
    fi
    printMsg "sjcxrm" "Searching bucket '${SJCX_BUCKET_NAME}' in bucket list '${RM_BUCKET_LIST[*]}'" "debug" "4"
    if [[ "${RM_BUCKET_LIST[*]}" =~ "${SJCX_BUCKET_NAME}" ]]
    then 
      printMsg "sjcxrm" "Bucket '${SJCX_BUCKET_NAME}' already added to remove list" "debug" "4"
    else
      RM_BUCKET_LIST[${#RM_BUCKET_LIST[*]}]="${SJCX_BUCKET_NAME}"
    fi
  fi
done

for (( i=0; i<${#RM_BUCKET_LIST[*]}; i++))
do
  SJCX_BUCKET_NAME="${RM_BUCKET_LIST[${i}]}"
  BUCKET_ID="$(getBucketID "${SJCX_BUCKET_NAME}" "${BUCKETS_LIST}")"
  if [ -z "${BUCKET_ID}" ]
  then
    printMsg "sjcxrm" "sjcxrm: failed to remove '${SJCX_BUCKET_NAME}': No such bucket" "error"
  else
    END_FILES_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files" "")"
    printMsg "sjcxls" "File list : '${FILES_LIST}'" "debug" "5"

    if [ ${RECURSIVE} -eq 1 ]
    then
      printMsg "sjcxrm" "Removing bucket '${SJCX_BUCKET_NAME}'" "debug" "1"
      if [ "${END_FILES_LIST}" == "" ]
      then 
        RMDIR_RESPONSE="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "DELETE" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}")"
        printMsg "sjcxrm" "Response : '${RMDIR_RESPONSE}'" "debug" "5"
        if [ "${RMDIR_RESPONSE}" == "" ]
        then
          printMsg "sjcxrm" "Bucket '${SJCX_BUCKET_NAME}' removed" "debug" "1"
        else
          printMsg "sjcxrm" "sjcxrm: failed to remove '${SJCX_BUCKET_NAME}' (${RMDIR_RESPONSE})" "error"
        fi
      else
        printMsg "sjcxrm" "sjcxrm: failed to remove '${SJCX_BUCKET_NAME}': Bucket not empty" "error"
      fi
    fi
  fi 
done
printMsg "sjcxrm" "END main" "debug" "9"

