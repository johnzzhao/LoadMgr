#!/bin/ksh

## $Id: run_fullstimer_parser.sh,v 1.3 2016/04/13 13:07:27 jozhao Exp $
## Usage:
## Date       By        Comment
## 2014/05/22 Jozhao    This is a part of LoadMgr
## load internal shell functions
autoload set_env
set_env

typeset program_nm=fullstimer_log_parser
typeset timestamp
export LOG_DIR=${LOG_ROOT}/$1
export PACKAGE_NAME=$1

##  this scrit will run logparse against all SAS logs in LoadMgr package log directionry
for fname in `ls -l $LOG_DIR/*.log | grep -v LoadMgr_${PACKAGE_NAME} | awk '{print $9}'`
do
   timestamp=`date +"%Y-%m-%d %H:%M:%S"`
   print "$timestamp --> process ${fname} for pacakge $PACKAGE_NAME..." 

   if [[ $SASCONFIG = "" ]]; then
         "$SASROOT"/sas -noterminal -autoexec $SASAUTOEXEC -log $LOG_ROOT/$PACKAGE_NAME/$program_nm.log -print $LOG_ROOT/$PACKAGE_NAME/$program_nm.lst -sysparm "${fname}"  -sysin $LOADMGR_HOME/util/${program_nm}.sas
      else
         "$SASROOT"/sas -noterminal -autoexec $SASAUTOEXEC -config $SASCONFIG -log $LOG_ROOT/$PACKAGE_NAME/$program_nm.log -print $LOG_ROOT/$PACKAGE_NAME/$program_nm.lst  -sysparm "${fname}"  -sysin $LOADMGR_HOME/util/${program_nm}.sas
   fi

   ##tracking errors OS specific!!!!
   sas_rc_code=$?

   if [ ${sas_rc_code} -gt 1 ]; then
     print "${timestamp} --> sas_rc_code = ${sas_rc_code} $program_nm.sas failed with errors!"
     return 1
   fi

   if [ ${sas_rc_code} -eq 1 ]; then
     print "${timestamp} --> sas_rc_code = ${sas_rc_code} $program_nm.sas finished with warnings"
   fi
done
