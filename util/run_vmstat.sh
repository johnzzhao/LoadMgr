#!/bin/ksh
## 
## $Id: run_vmstat.sh,v 1.1 2014/06/11 18:11:34 jozhao Exp $
## Usage:   {0} {LOG_FILE_NAME} 
## Date       By        Comment
## 2014/03/29 Jozhao    This is a part of LoadMgr
##

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir 
script_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

if [[ ${#} -ne 1 ]] ; then
   print "ussage ${0} {LOG_FILE_NAME} " 
   exit 1
fi

typeset LOG_DIR=${LOG_ROOT}/${PACKAGE_NAME}
typeset i=0

while [[ $i -lt ${NMON_OPTION_C} ]]
do
   vmstat -t -S M -n 1 5 >>  ${LOG_DIR}/vmstat_${1}.log
   sleep ${NMON_OPTION_S}
   ((i=i+1))
done
