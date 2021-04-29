#!/bin/ksh

## 
## $Id: run_update_app_table.sh,v 1.1 2016/04/13 18:14:11 jozhao Exp $
## Usage:  
## Date       By        Comment
## 2012/03/24 Jozhao    This is a part of LoadMgr 

## load internal shell functions
autoload set_env
set_env

export HOSTTYPE=$(uname)
export LOG_DIR=${LOG_ROOT}/$1
export report_lvl=${LOG_REPORT_LVL:-2}
date_str=`date +"%Y%m%d"`

typeset program_nm=update_app_table

if [[ $SASCONFIG = "" ]]; then
   "$SASROOT"/sas -noterminal -autoexec $SASAUTOEXEC -log $LOG_ROOT/$PACKAGE_NAME/$program_nm.log -print $LOG_ROOT/$PACKAGE_NAME/$program_nm.lst -sysin $SRC_ROOT/$PACKAGE_NAME/${program_nm}.sas
else
   "$SASROOT"/sas -noterminal -autoexec $SASAUTOEXEC -config $SASCONFIG -log $LOG_ROOT/$PACKAGE_NAME/$program_nm.log -print $LOG_ROOT/$PACKAGE_NAME/$program_nm.lst -sysin $SRC_ROOT/$PACKAGE_NAME/${program_nm}.sas
 fi

##tracking errors OS specific!!!!
sas_rc_code=$?

timestamp=`date +"%Y-%m-%d %H:%M:%S"`
if [ ${sas_rc_code} -gt 1 ]; then
  lm_mail "$program_nm.sas failed ${timestamp}"  "${ENV_ID} LOADMGR NOTIFICATION - Task $program_nm for ${PACKAGE_NAME} failed"  "${NOTIFICATION_ADDRESS}" "${CC_NOTIFICATION_ADDRESSES}" "${REPLY_TO}"
  print "${timestamp} --> sas_rc_code = ${sas_rc_code} $program_nm.sas failed with errors!"
  return 1
fi

if [ ${sas_rc_code} -eq 1 ]; then
  lm_mail "$program_nm.sas finished with warning on ${timestamp}" "${ENV_ID} LOADMGR NOTIFICATION - Task $program_nm for  ${PACKAGE_NAME} finished with warning"  "${NOTIFICATION_ADDRESS}" "${CC_NOTIFICATION_ADDRESSES}" "${REPLY_TO}"
  print "${timestamp} --> sas_rc_code = ${sas_rc_code} $program_nm.sas finished with warnings"
else
  print "${timestamp}  --> sas_rc_code = ${sas_rc_code} $program_nm.sas finished successfully!"
fi
