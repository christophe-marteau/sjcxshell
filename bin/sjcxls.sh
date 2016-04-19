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

# SJCX list buckets and files
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
  ${ECHO_BINARY} "This script lists buckets and files"
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "usage : ${0} [-aldR] [<bucket>] ... [<bucket]" 
  ${ECHO_BINARY} ""
  ${ECHO_BINARY} "  -h       : Display this help."
  ${ECHO_BINARY} "  -a       : List all attributes for files or buckets."
  ${ECHO_BINARY} "  -l       : List attributes for files or buckets but not IDs."
  ${ECHO_BINARY} "  -R -r    : List buckets and files"
  ${ECHO_BINARY} "  -d       : List buckets only"
  ${ECHO_BINARY} ""
  printMsg "usage" "END usage" "debug" "9"
  exit 1
}

ACTIVE_FOLDER_OUTPUT_COLOR="$(${TPUT_BINARY} setaf ${ACTIVE_FOLDER_COLOR})"
INACTIVE_FOLDER_OUTPUT_COLOR="$(${TPUT_BINARY} setaf ${INACTIVE_FOLDER_COLOR})"
FILE_OUTPUT_COLOR="$(${TPUT_BINARY} setaf ${FILE_COLOR})"
RESET_COLOR="$(${TPUT_BINARY} sgr0)"

SELECTED_USER="${SJCX_HOME}/.${SJCX_USER}"
LIST_ATTRIBUTE_ID=0
LIST_ATTRIBUTES=0
LIST_FOLDER=0
LIST_ALL=0

SJCXLS_OPT='halrRd'
while getopts "${SJCXLS_OPT}" opt
do
  case "${opt}" in
    'h' )
      usage
      ;;
    'a' )
      LIST_ATTRIBUTE_ID=1
      ;;
    'l' )
      LIST_ATTRIBUTES=1
      ;;
    'r' | 'R' )
      LIST_ALL=1
      ;;
    'd' )
      LIST_FOLDER=1
      ;;
    *)
      printMsg "sjcxls" "Incorrect option '${1}'." "error"
      usage
      ;;
  esac
done
shift $((OPTIND-1))
LS_LIST=("$@")

printMsg "sjcxls" "BEGIN main" "debug" "9"
if [ ${LIST_FOLDER} -eq 1 ]
then
  LIST_ALL=0
fi

SEARCH_FILTER=''
if [ -n "${LS_LIST}" ]
then
  for (( i=0; i<${#LS_LIST[*]}; i++ ))
  do
    SEARCH_FILTER="${SEARCH_FILTER}|\"name\":\"${LS_LIST[${i}]}\""
  done
  SEARCH_FILTER="'${SEARCH_FILTER##|}'"
fi

printMsg "sjcxls" "Filter : '${SEARCH_FILTER}'" "debug" "8"
BUCKETS_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets" "${SEARCH_FILTER}")"
printMsg "sjcxls" "Bucket list : '${BUCKETS_LIST}'" "debug" "5"
if [ ${LIST_ATTRIBUTES} -eq 1 ] && [ ${LIST_FOLDER} -eq 0 ]
then
  if [ -n "${BUCKETS_LIST}" ]
  then
    ${ECHO_BINARY} "total $(${ECHO_BINARY} "${BUCKETS_LIST}" | ${WC_BINARY} -l)"
  else
    ${ECHO_BINARY} "total 0"
  fi
fi


IFS="
"
for bucketName in ${BUCKETS_LIST}
do
  printMsg "sjcxls" "Bucket : '${bucketName}'" "debug" "1"
  if [[ "${bucketName}" =~ '"user":"([^"]+)","created":"([^"]+)","name":"([^"]+)","pubkeys":([^,]+),"status":"([^"]+)","transfer":([^,]+),"storage":([^,]+),"id":"([^"]+)"' ]]
  then
    SJCX_BUCKET_DISPLAY=""
    BUCKET_OWNER="${BASH_REMATCH[1]}"
    BUCKET_TIMESTAMP="${BASH_REMATCH[2]}"
    BUCKET_NAME="${BASH_REMATCH[3]}"
    BUCKET_PUBKEYS="${BASH_REMATCH[4]}"
    BUCKET_STATUS="${BASH_REMATCH[5]}"
    BUCKET_TRANSFERT="${BASH_REMATCH[6]}"
    BUCKET_STORAGE="${BASH_REMATCH[7]}"
    BUCKET_ID="${BASH_REMATCH[8]}"
    BRIEF_BUCKET_STATUS="${BUCKET_STATUS:0:1}"
    BUCKET_DATE="$(${DATE_BINARY} -d"${BUCKET_TIMESTAMP}" "+%b %d %Y %H:%M")"
    if [ ${LIST_ATTRIBUTE_ID} -eq 1 ] 
    then
      SJCX_BUCKET_DISPLAY="[${BUCKET_ID}] "
    fi
    if [ ${LIST_ATTRIBUTES} -eq 1 ] && [ ${LIST_ALL} -eq 0 ]
    then
      SJCX_BUCKET_DISPLAY="b ${BRIEF_BUCKET_STATUS,,} ${BUCKET_OWNER} ${BUCKET_TRANSFERT},${BUCKET_STORAGE} ${BUCKET_DATE} ${SJCX_BUCKET_DISPLAY}"
    fi
    if [ "${BUCKET_STATUS}" == "Active" ]
    then
      SJCX_BUCKET_DISPLAY="${SJCX_BUCKET_DISPLAY}${ACTIVE_FOLDER_OUTPUT_COLOR}${BUCKET_NAME}${RESET_COLOR}"
    else
      SJCX_BUCKET_DISPLAY="${SJCX_BUCKET_DISPLAY}${INACTIVE_FOLDER_OUTPUT_COLOR}${BUCKET_NAME}${RESET_COLOR}"
    fi
    if [ ${LIST_ALL} -eq 1 ] && [ ${LIST_FOLDER} -eq 0 ]
    then
      SJCX_BUCKET_DISPLAY="${SJCX_BUCKET_DISPLAY}:"
    fi

    ${ECHO_BINARY} "${SJCX_BUCKET_DISPLAY}"    

    if [ ${LIST_ALL} -eq 1 ] && [ ${LIST_FOLDER} -eq 0 ]
    then
        FILES_LIST="$(queryAPI "$( ${CAT_BINARY} "${SELECTED_USER}" )" "GET" "'Accept: application/json'" "" "" "${METADISK_API_URL}" "buckets/${BUCKET_ID}/files" "")" 
      printMsg "sjcxls" "File list : '${FILES_LIST}'" "debug" "5" 
      if [ ${LIST_ATTRIBUTES} -eq 1 ] 
      then 
        if [ -n "${FILES_LIST}" ] 
        then 
          ${ECHO_BINARY} "total $(${ECHO_BINARY} "${FILES_LIST}" | ${WC_BINARY} -l)" 
        else 
          ${ECHO_BINARY} "total 0" 
        fi 
      fi 
     
     
      IFS="
" 
      for fileName in ${FILES_LIST} 
      do 
        printMsg "sjcxls" "File : '${fileName}'" "debug" "2" 
        # '"bucket":"56e559c0dfd1d65c1d93fde8","filename":"plic.txt","size":8,"mimetype":"text/plain","hash":"4544082e1cc2db05a376d3391245d9dd0074d7e7","id":"4544082e1cc2db05a376d3391245d9dd0074d7e7"' 
        if [[ "${fileName}" =~ '"bucket":"([^"]+)","mimetype":"([^"]+)","filename":"([^"]+)","size":([^,]+),"hash":"([^"]+)"' ]] 
        then 
          SJCX_FILE_DISPLAY="" 
          FILE_BUCKET_ID="${BASH_REMATCH[1]}" 
          FILE_MIME_TYPE="${BASH_REMATCH[2]}" 
          FILE_NAME="${BASH_REMATCH[3]}" 
          FILE_SIZE="${BASH_REMATCH[4]}" 
          FILE_HASH="${BASH_REMATCH[5]}" 
          if [ ${LIST_ATTRIBUTE_ID} -eq 1 ] 
          then 
            SJCX_FILE_DISPLAY="[${FILE_HASH}] " 
          fi 
          if [ ${LIST_ATTRIBUTES} -eq 1 ] 
          then 
            SJCX_FILE_DISPLAY="f $(${NUMFMT_BINARY} --padding=${NUMFMT_PADDING} --to=iec ${FILE_SIZE}) $(${PRINTF_BINARY} "%-24s" ${FILE_MIME_TYPE}) ${SJCX_FILE_DISPLAY}" 
          fi 
          ${ECHO_BINARY} "${SJCX_FILE_DISPLAY}${FILE_NAME}" 
        else 
          printMsg "sjcxls" "Unable to parse file : '${fileName}'" "error" 
        fi 
      done 
     
      if [ ${LIST_ALL} -eq 1 ] 
      then 
        ${ECHO_BINARY} "" 
      fi 
    fi
  else
    printMsg "sjcxls" "Unable to parse bucket : '${bucketName}'" "error"
  fi
done 

if [ -n "${LS_LIST}" ] && [ ${#LS_LIST[*]} -ne ${#BUCKET_LIST[*]} ]
then
  for (( i=0; i<${#LS_LIST[*]}; i++ ))
  do
    printMsg "sjcxls" "Parsing for not found bucket '${LS_LIST[${i}]}' in '${BUCKETS_LIST}' ... " "debug" "8"
    if ! [[ "${BUCKETS_LIST}" =~ '"name":"'"${LS_LIST[${i}]}"'"' ]]
    then
      printMsg "sjcxls" "sjcxls: failed to list '${LS_LIST[${i}]}': No such bucket" "error"
    fi
  done 
fi
printMsg "sjcxls" "END main" "debug" "9"

