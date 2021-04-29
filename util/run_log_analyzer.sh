#!/bin/ksh

## 
## $Id: run_log_analyzer.sh,v 1.8 2014/03/13 17:54:31 ranliu Exp $
## Usage:  
## Date       By        Comment
## 2012/03/24 Jozhao    This is a part of LoadMgr 
## 2013/11/04 Ranliu    Add CC_LOG_ADDRESS

## load internal shell functions
autoload set_env
set_env

export HOSTTYPE=$(uname)
export LOG_DIR=${LOG_ROOT}/$1
export report_lvl=${LOG_REPORT_LVL:-2}
date_str=`date +"%Y%m%d"`
current_dir=$PWD
include_msg=${LOG_DIR}/$1_included.msg
excluse_msg=${LOG_DIR}/$1_excluded.msg
message_file=${LOADMGR_TMP_DIR}/message_$date_str_$$

## if not defined in package, use the global incldue/exclude list
test ! -a  ${include_msg} && include_msg=${LOADMGR_HOME}/etc/global_include.msg
test ! -a  ${excluse_msg} && excluse_msg=${LOADMGR_HOME}/etc/global_exclude.msg

##trap to remove message file
trap "rm -f $message_file" INT TERM QUIT
trap "" HUP 
## remove last message log
if [[ -f ${LOG_DIR}/$1_current.msg ]]; then  
   rm -f ${LOG_DIR}/$1_current.msg
fi

cd ${LOG_DIR}

ls -l | egrep ".\.log.*" | awk '{print $9}' |  while read log_file_name 
do
  if [[ -f $log_file_name ]]; then
     egrep -f ${include_msg} $log_file_name | egrep -v -f ${excluse_msg}  | while read str
     do
        message_type="${str%%:*}"
        message="${str}"
        print  "$1|${log_file_name}|${message_type}|REVIEW|{Add_notes_here}|${date_str}|${message}" >> $message_file
     done
  fi
done

if [[ -f $message_file ]] ; then
   sort -u -t"|" -d -k2,2 -k3,3 -k5,5 -k7,7 $message_file  > ${LOADMGR_TMP_DIR}/message$$_
   mv ${LOADMGR_TMP_DIR}/message$$_ ${LOG_DIR}/$1_current.msg 
fi


if [[ ! -f ${LOG_DIR}/$1.msg ]]; then  
   touch ${LOG_DIR}/$1.msg 
fi

cd $current_dir

typeset program_nm=log_analyzer

if [[ $SASCONFIG = "" ]]; then
   "$SASROOT"/sas -noterminal -autoexec $SASAUTOEXEC -log $LOG_ROOT/$PACKAGE_NAME/$program_nm.log -print $LOG_ROOT/$PACKAGE_NAME/$program_nm.lst -sysin $LOADMGR_HOME/util/${program_nm}.sas
else
   "$SASROOT"/sas -noterminal -autoexec $SASAUTOEXEC -config $SASCONFIG -log $LOG_ROOT/$PACKAGE_NAME/$program_nm.log -print $LOG_ROOT/$PACKAGE_NAME/$program_nm.lst -sysin $LOADMGR_HOME/util/${program_nm}.sas
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

if [[ $sas_rc_code -lt 2 && $MAIL_REPORT -eq 1 && -f ${LOG_ROOT}/${PACKAGE_NAME}/log_analysis_report.lst ]]; then
  send_report ${LOG_ROOT}/${PACKAGE_NAME}/log_analysis_report.lst "$ENV_ID LOADMGR NOTIFICATION - ${PACKAGE_NAME} log analysis report"  "$LOG_MAIL_ADDRESS" "$CC_LOG_MAIL_ADDRESS" "$REPLY_TO"
fi

rm -f $message_file
