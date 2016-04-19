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

# SJCX rmdir
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
  ${ECHO_BINARY} "This script removes one or more buckets"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "usage : ${0} [-v] <bucket name> [<bucket name>] ..."
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "  -h (--help)    : Display this help."
  ${ECHO_BINARY} "  -v (--verbose) : Print some information when removing buckets"
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
      printMsg "sjcxrmdir" "Parsing bucket option '${1}'" "debug" "2"
      SJCX_BUCKET_LIST[${#SJCX_BUCKET_LIST[*]}]="${1}"
      ;;
    esac
    shift
done

if [ -z "${SJCX_BUCKET_LIST[*]}" ]
then
  printMsg "sjcxrmdir" "No bucket name provided" "error"
  usage
fi

printMsg "sjcxrmdir" "BEGIN main" "debug" "9"

BUCKETS_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets" "")"
printMsg "sjcxrmdir" "Bucket list : '${BUCKETS_LIST}'" "debug" "5"

for (( i=0; i<${#SJCX_BUCKET_LIST[*]}; i++))
do
  
  BUCKET_ID="$(getBucketID "${SJCX_BUCKET_LIST[${i}]}" "${BUCKETS_LIST}")"
  if [ -z "${BUCKET_ID}" ]
  then
    printMsg "sjcxrmdir" "sjcxrmdir: failed to remove '${SJCX_BUCKET_LIST[${i}]}': No such bucket" "error"
  else
    FILES_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files" "")"
    printMsg "sjcxls" "File list : '${FILES_LIST}'" "debug" "5"
    if [ "${FILES_LIST}" == "" ]
    then 
      RMDIR_RESPONSE="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "DELETE" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}")"
      printMsg "sjcxrmdir" "Response : '${RMDIR_RESPONSE}'" "debug" "5"
      if [ "${RMDIR_RESPONSE}" == "" ]
      then
        printMsg "sjcxrmdir" "Bucket '${SJCX_BUCKET_LIST[${i}]}' removed" "debug" "1"
      else
        printMsg "sjcxrmdir" "sjcxrmdir: failed to remove '${SJCX_BUCKET_LIST[${i}]}' (${RMDIR_RESPONSE})" "error"
      fi
    else
      printMsg "sjcxrmdir" "sjcxrmdir: failed to remove '${SJCX_BUCKET_LIST[${i}]}': Bucket not empty" "error"
    fi
  fi
done
printMsg "sjcxrmdir" "END main" "debug" "9"

