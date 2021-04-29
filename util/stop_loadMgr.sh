#!/bin/ksh
## 
## $Id: stop_loadMgr.sh,v 1.4 2012/09/14 01:06:35 jozhao Exp $
## Usage:   {0} ${PACKAGE_NAME}
## Date       By        Comment
## 2012/03/29 Jozhao    This is a part of LoadMgr
##

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir 
script_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

if [[ ${#} -ne 1 ]] ; then
   print "ussage ${0} [PACKAGE_NAME]" 
   exit 1
fi

typeset PACKAGE_NAME=$1

## check whether the package is already running for current LoadMgr instance 
if [[ -e ${LOG_ROOT}/status/${PACKAGE_NAME}.pid ]]; then
   pid=$(cat ${LOG_ROOT}/status/${PACKAGE_NAME}.pid)
   kill -0 $pid > /dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      print "$PACKAGE_NAME package is not running"
      exit 1
   fi
fi

##define local variables
typeset -L38 task_id
typeset statuscode 
typeset begtime
typeset endtime 
typeset pid
typeset ppid
typeset i=0 
rm -f ${LOCKFILE}
LOGFILE=$LOG_ROOT/status/${PACKAGE_NAME}.log
LOCKFILE={LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${STOP_LOADMGR}_$(date +"%y%m%d")
GETLOCK=${LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${STOP_LOADMGR}_$(date +"%y%m%d")_lock

echo "I am here ..."
## get lock
while ! $(ln -s ${LOCKFILE} ${GETLOCK} 2>/dev/null)
do  
 #echo "waiting lock for check status"
 sleep 1 
done

## get pid for running jobs
while read pid ppid task_id program_nm begtime endtime statuscode 
do 
  echo  $pid $ppid $task_id $program_nm $begtime $endtime $statuscode ...
  if [[ ${statuscode} == RUNNING  && ${program_nm} != LoadMgr.sh ]]; then
     runing_pid[$i]=${pid}
     running_program[$i]=$program_nm
     ((i+=1))
  fi
done < ${LOGFILE} 
rm -f  ${GETLOCK} 
rm -f ${LOCKFILE}

i=0
while [[ $i -lt ${#runing_pid[*]} ]]
do
   print "stop tasks ${running_program[$i]}..."
   kill -s TERM ${runing_pid[$i]}
   sleep 2 
   ((i+=1))
done

