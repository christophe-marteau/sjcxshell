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

# SJCX mkdir 
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
  ${ECHO_BINARY} "This script adds one or more buckets"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "usage : ${0} [-v] <bucket name> [<bucket name>] ..."
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "  -h (--help)    : Display this help."
  ${ECHO_BINARY} "  -v (--verbose) : Print some information when adding buckets"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} ""
  printMsg "usage" "END usage" "debug" "9"
  exit 1
}

declare -a SJCX_BUCKET_LIST
SELECTED_USER="${SJCX_HOME}/.${SJCX_USER}"

# Menu
while [ $# -gt 0 ]
do
  case "${1}" in
    "--help" | "-h" )
      usage
      ;;
    "--verbose" | "-v" )
      DEBUG=1
      ;;
    *)
      printMsg "sjcxmkdir" "Parsing bucket option '${1}'" "debug" "2"
      SJCX_BUCKET_LIST[${#SJCX_BUCKET_LIST[*]}]="${1}"
      ;;
    esac
    shift
done

if [ -z "${SJCX_BUCKET_LIST[*]}" ]
then
  printMsg "sjcxmkdir" "No bucket name provided" "error"
  usage
fi

printMsg "sjcxmkdir" "BEGIN main" "debug" "9"
for (( i=0; i<${#SJCX_BUCKET_LIST[*]}; i++))
do
  printMsg "sjcxmkdir" "Atempting to create bucket '${SJCX_BUCKET_LIST[${i}]}' ..." "debug" "2"
  BUCKETS_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets" "")"
  printMsg "sjcxmkdir" "Bucket list : '${BUCKETS_LIST}'" "debug" "5"

  BUCKET_ID="$(getBucketID "${SJCX_BUCKET_LIST[${i}]}" "${BUCKETS_LIST}")"
  if [ -n "${BUCKET_ID}" ]
  then
    printMsg "sjcxmkdir" "Bucket '${SJCX_BUCKET_LIST[${i}]}' with ID '${BUCKET_ID}' already exists for user '${SJCX_USER}'" "error"
  else
    BUCKET_MKDIR_RESPONSE="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "POST" "'Content-Type: application/json' 'Accept: application/json'" '{"name":"'"${SJCX_BUCKET_LIST[${i}]}"'"}' "" "${METADISK_API_URL}" "buckets" "")"
    printMsg "sjcxmkdir" "Response : ${BUCKET_MKDIR_RESPONSE}" "debug" "5"
   
    # {"user":"rickenny-test2@votez-cthulhu.net","created":"2016-03-27T11:18:22.629Z","name":"ploc","pubkeys":[],"status":"Active","transfer":30,"storage":10,"id":"56f7c17e868b539304131e1f"}
    if [[ "${BUCKET_MKDIR_RESPONSE}" =~ '^\{"user":"([^"]+)","created":"([^"]+)","name":"([^"]+)","pubkeys":[^,]+,"status":"([^"]+)","transfer":[^,]+,"storage":[^,]+,"id":"([^"]+)"\}$' ]]
    then
      USER_NAME="${BASH_REMATCH[1]}"
      CREATE_TIMESTAMP="${BASH_REMATCH[2]}"
      CREATE_NAME="${BASH_REMATCH[3]}"
      CREATE_STATUS="${BASH_REMATCH[4]}"
      CREATE_ID="${BASH_REMATCH[5]}"
      if [ "${SJCX_BUCKET_LIST[${i}]}" == "${CREATE_NAME}" ]
      then
        printMsg "sjcxmkdir" "Bucket '${SJCX_BUCKET_LIST[${i}]}' with ID '${CREATE_ID}' succesfully created for user '${USER_NAME}'" "debug" "1"
      else
        printMsg "sjcxmkdir" "Created bucket name (${CREATE_NAME}) mismatch with asked bucket name (${SJCX_BUCKET_LIST[${i}]})" "error"
      fi
    else
      printMsg "sjcxmkdir" "Unable to create bucket (${BUCKET_MKDIR_RESPONSE})" "error"
    fi
  fi
done
printMsg "sjcxmkdir" "END main" "debug" "9"
