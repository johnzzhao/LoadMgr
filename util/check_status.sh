#!/bin/ksh
## 
## $Id: check_status.sh,v 1.2 2012/09/14 01:06:35 jozhao Exp $
## Usage:   {0} ${PACKAGE_NAME}
## Date       By        Comment
## 2012/05/29 Jozhao    This is a part of LoadMgr
##

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir 
script_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

if [[ ${#} -ne 1 ]] ; then
   print "ussage ${0} [PACKAGE_NAME]" 
   exit 1
fi

PACKAGE_NAME=$1

## check whether the package is already running for current LoadMgr instance 
if [[ -e ${LOG_ROOT}/status/${PACKAGE_NAME}.pid ]]; then
   pid=$(cat ${LOG_ROOT}/status/${PACKAGE_NAME}.pid)
   kill -0 $pid > /dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      print "$PACKAGE_NAME package is not running"
      exit 1
   fi 
else 
   print "$PACKAGE_NAME package is not running"
   exit 1
fi

LOGFILE=$LOG_ROOT/status/${PACKAGE_NAME}.log
cat $LOGFILE
