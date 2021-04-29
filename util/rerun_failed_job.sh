#!/bin/ksh
## 
## $Id: rerun_failed_job.sh,v 1.2 2018/01/11 20:23:04 ranliu Exp $
## Usage:   {0} [PACKAGE_NAME]  [FAILED JOB ID]
## Date       By        Comment
## 2015/03/04 Jozhao    This is a part of LoadMgr
##

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir 
script_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

if [[ ${#} -ne 2 ]] ; then
   print "usage ${0} [PACKAGE_NAME] [FAILED JOB ID]" 
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
typeset task_id
typeset statuscode 
typeset begtime
typeset endtime 
typeset pid
typeset ppid
typeset i=0 
typeset duplicated_id
typeset TASKID=${2}

export HOSTTYPE=$(uname)
export PACKAGE_NAME=${1}
## locate lock file
export LOCKFILE=$(find ${LOADMGR_TMP_DIR} -name "${PACKAGE_NAME}_${pid}*" -type f -size 0 2>/dev/null)
export GETLOCK=${LOCKFILE}_lock
export LOGFILE=$LOG_ROOT/status/${PACKAGE_NAME}.log


## parse package job configuration file
config_dir=${LOCAL_META_DIR:-${LOADMGR_HOME}/etc}
parse_config ${config_dir}/${PACKAGE_NAME}.conf


## get task information
while (( i < ${#tasks[*]} ))
do
   if [[ ${tasks[$i]} = ${TASKID} ]]; then
      eval duplicated_id=\${duplicate_ind[$i]}
      ##get parameter, if not found, set to undefined
      get_task_param ${tasks[$i]}
      ##get program name, including path
      program_nm=${programs[$i]}
      echo $program_nm
   fi
   ((i+=1))
done

## get lock
while ! $(ln -s ${LOCKFILE} ${GETLOCK} 2>/dev/null)
do  
 #echo "waiting lock for check status"
 sleep 1 
done

## get pid for running jobs
FOUND=0
while read pid ppid task_id program_name begtime endtime statuscode 
do 
  echo  $pid $ppid $task_id $program_nm $begtime $endtime $statuscode ...
  if [[ ${statuscode} == FAILED && ${task_id} = ${TASKID} ]]; then
      FOUND=1
      timestamp=`date +"%Y-%m-%d %H:%M:%S"`
      print "${timestamp}--> ${LOADMGR_HOME}/bin/runjob.sh ${task_id} ${program_nm} ${duplicated_id} ${ppid} ${PACKAGE_NAME} ${CURRENT_JOB_PARM}" >> ${LOG_ROOT}/${PACKAGE_NAME}/external_rerun.log

      ${LOADMGR_HOME}/bin/runjob.sh ${task_id} ${program_nm} ${duplicated_id} ${ppid} ${PACKAGE_NAME} "${CURRENT_JOB_PARM}" >> ${LOG_ROOT}/${PACKAGE_NAME}/external_rerun.log  &  

      ## log runjob PID 
      RERUN_PROCESS_PID=$!
      print "${timestamp}--> runjob.sh pid = ${RERUN_PROCESS_PID}" >> ${LOG_ROOT}/${PACKAGE_NAME}/external_rerun.log
      break
  fi
done < ${LOGFILE} 


if [[ ${FOUND} = 0 ]]; then
   timestamp=`date +"%Y-%m-%d %H:%M:%S"`
   print "${timestamp}--> no failed ${TASKID} found!" >> ${LOG_ROOT}/${PACKAGE_NAME}/external_rerun.log
fi

## get out the lock
rm -f  ${GETLOCK} 
