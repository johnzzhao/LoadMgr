#!/bin/ksh

## 
## $Id: runjob.sh,v 1.13 2015/03/08 02:55:20 jozhao Exp $
## Usage:  this shell script is called by LoadMgr.sh internally 
## Date       By        Comment
## 2012/03/23 Jozhao    This is a part of LoadMgr
## 2014/4/25  Jozhao    remove local variable definition for PACKAGE_NAME
## 2015/3/7   Jozhao    backup sas log when there is external rerun
##


## load internal functioins
autoload set_env
set_env

##define variables
typeset time_str=$(date +"%Y_%m_%d_%H%M%S")
typeset task_id=$1
typeset dupliate_id=$3
typeset program_nm=$2
typeset PPID=$4
typeset TASK_PARAM=$6
typeset tmpstatus=${LOADMGR_TMP_DIR}/status_$$_$(date +"%y%m%d")
typeset basename=${program_nm%.*}
typeset saslog_nm=${basename##*/}
typeset -l ext=${program_nm##*.}
typeset rc
typeset timestamp

## create temp. status file for logging
touch $tmpstatus 

##set up traps
trap "rm -f $tmpstatus; write_status_log ${task_id} ${program_nm##*/} TERMINATED $$ $PPID; exit 1"  INT TERM QUIT 
trap "" HUP


##write status log
write_status_log ${task_id} ${program_nm##*/} RUNNING $$  $PPID

## execute the job
if [[ $ext == sas ]]; then
   if [[ $dupliate_id -eq 1 ]]; then 
        saslog_nm=${saslog_nm}_task_${task_id}
   fi
   ## 3/7/2015 where there is external rerun, backup existing log 
   if [[ -e ${LOG_ROOT}/${PACKAGE_NAME}/${saslog_nm}.log ]]; then
         mv ${LOG_ROOT}/${PACKAGE_NAME}/${saslog_nm}.log  ${LOG_ROOT}/${PACKAGE_NAME}/${saslog_nm}_${time_str}.log 2>/dev/null
   fi

   sasjob ${basename} ${saslog_nm}  "${TASK_PARAM}" ${task_id}
else 
   if [[ ${TASK_PARAM} = undefined ]]; then 
      if [[ -e ${program_nm} ]]; then
         ${program_nm}
      else 
         ${SRC_ROOT}/${PACKAGE_NAME}/${program_nm} 
      fi
   else
      if [[ -e ${program_nm} ]]; then
         ${program_nm} "${TASK_PARAM}"
      else 
         ${SRC_ROOT}/${PACKAGE_NAME}/${program_nm} "${TASK_PARAM}"
      fi
   fi
fi

## get return code
rc=$?
## get time
timestamp=`date +"%Y-%m-%d %H:%M:%S"`

##write exit status log
if [[ ${rc} -eq 0 ]]; then 
   if [[ $ext != sas ]]; then
       print "${timestamp}  --> rc_code = ${rc} TaskID ${task_id} ${program_nm} finished successfully!" 
   fi
   write_status_log ${task_id} ${program_nm##*/} DONE $$ $PPID 
else 
   if [[ $ext != sas ]]; then
       print "${timestamp}  --> rc_code = ${rc} TaskID ${task_id} ${program_nm} failed!" 
   fi
   write_status_log ${task_id} ${program_nm##*/} FAILED $$ $PPID 
fi

##remove the status file
rm -f $tmpstatus 
