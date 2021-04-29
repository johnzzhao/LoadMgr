#!/bin/ksh

## 
## $Id: LoadMgr.sh,v 1.38 2016/06/29 22:01:05 ranliu Exp $
## Usage:   {0} ${PACKAGE_NAME} 
## Date       By        Comment
## 2012/03/04 Jozhao    This is a part of LoadMgr
## 2013/11/04 Ranliu    Add local env var for CC_LOG_MAIL_ADDRESS 
## 2014/05/01 Jozhao    Enhance job sequence
## 2014/10/01 Jozhao    Check Status enhancement
## 2014/10/17 Jozhao    Replace check_status with refresh_status
##

## load internal shell functions
autoload set_env
set_env

##define variables  
typeset i
typeset done_ind 
typeset resume_task
typeset submit_ind 
typeset current_num_of_job=0
typeset beg_time=$(date +%s)
typeset cur_time
typeset total_secs=0

loadmgr_nm=${0##*/}

##define environment variables 
export LOADMGR_PID=$$
export HOSTTYPE=$(uname)
export LOCKFILE=${LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${LOADMGR_PID}_$(date +"%y%m%d")
export GETLOCK=${LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${LOADMGR_PID}_$(date +"%y%m%d")_lock
tmpstatus=${LOADMGR_TMP_DIR}/status_$$_$(date +"%y%m%d")

## set up traps
trap "terminate_loadmgr" INT TERM QUIT 
trap "" HUP

## parse package job configuration file 
config_dir=${LOCAL_META_DIR:-${LOADMGR_HOME}/etc}
parse_config ${config_dir}/${PACKAGE_NAME}.conf

## define local overwritten env vars
export MONITOR_RESOURCE=${LOCAL_RESOURCE_MONITOR:-${MONITOR_RESOURCE}}
export SRC_ROOT=${LOCAL_SRC_ROOT:-${SRC_ROOT}}
export LOG_ROOT=${LOCAL_LOG_ROOT:-${LOG_ROOT}}
export SAS_LOG_ANALYZER=${LOCAL_SAS_LOG_ANALYZER:-${SAS_LOG_ANALYZER}}
export REPORT_LVL=${LOCAL_REPORT_LVL:-${REPORT_LVL}}
export CONCURRENCY_LVL=${LOCAL_CONCURRENCY_LVL:-${CONCURRENCY_LVL}}
export CONCURRENCY_SCOPE=${LOCAL_CONCURRENCY_SCOPE:-${CONCURRENCY_SCOPE}}
export SASROOT=${LOCAL_SASROOT:-${SASROOT}}
export SASCONFIG=${LOCAL_SASCONFIG:-${SASCONFIG}}
export MEMSIZE=${LOCAL_MEMSIZE:-${MEMSIZE}}
export SORTSIZE=${LOCAL_SORTSIZE:-${SORTSIZE}}
export REALMEMSIZE=${LOCAL_REALMEMSIZE:-${REALMEMSIZE}}
export SAS_LOG_ANALYZER=${LOCAL_SAS_LOG_ANALYZER:-${SAS_LOG_ANALYZER}}
export LOG_REPORT_LVL=${LOCAL_LOG_REPORT_LVL:-${LOG_REPORT_LVL}}
export MAIL_REPORT=${LOCAL_MAIL_REPORT:-${MAIL_REPORT}}
export LOG_MAIL_ADDRESS=${LOCAL_LOG_MAIL_ADDRESS:-${LOG_MAIL_ADDRESS}}
export CC_LOG_MAIL_ADDRESS=${LOCAL_CC_LOG_MAIL_ADDRESS:-${CC_LOG_MAIL_ADDRESS}}
export NOTIFICATION_ADDRESS=${LOCAL_NOTIFICATION_ADDRESS:-${NOTIFICATION_ADDRESS}}
export CC_NOTIFICATION_ADDRESSES=${LOCAL_CC_NOTIFICATION_ADDRESS:-${CC_NOTIFICATION_ADDRESSES}}
export REPLY_TO=${LOCAL_REPLY_TO:-${REPLY_TO}}
export SASAUTOEXEC=${LOCAL_SASAUTOEXEC:-${SASAUTOEXEC}}
export RESOURCE_MONITOR=${LOCAL_RESOURCE_MONITOR:-${RESOURCE_MONITOR}}
export MAX_RUN_TIME=${LOCAL_MAX_RUN_TIME:-${MAX_RUN_TIME}}

## initialize pid array for the tasks
init_pid_array ${#tasks[*]} # initialize job pid array

## run validation and  set invalid configuration flag
validate_tasks
valid_cfg=$?

if [[ ${valid_cfg} -ne 0 ]] ; then
   print "invalid configuration file, please fix the issues displayed."

   # leave a log file and tell controller.sh that the run is failed
   if [[ ! -e ${LOGFILE} ]]; then
      touch ${LOGFILE} # create log file 
   fi
   exit 1
fi

## remove left out lock files
if [[ -e ${GETLOCK} ]]; then
   rm -f ${GETLOCK}
fi

## check whether a previous run failed 
if [[ ! -e ${LOGFILE} ]]; then
   touch ${LOGFILE} # create log file 
else 
    ## force a rerun 
    if  [[ $RUN_MODE ==  "rerun" ]]; then
       print "Notes: a previous run failed, start a forced re-run ..."
       rm -f  ${LOGFILE}
       touch ${LOGFILE} # create log file 
    else 
       print "Notes: a previous run failed, resume from the failure point ..."
       export RUN_MODE=resume
       parse_status_log    #parse job status file

       ## deal with invalid status code 
       if [[ $? -eq 255 ]]; then
          print "Terminating Loadmgr ... "
          terminate_loadmgr 
       fi
            
    fi
fi


## create lock and status file
touch ${LOCKFILE}
touch $tmpstatus 

#set package running status
jobstatus=STARTED

##start resource monitoring
if [[ ${MONITOR_RESOURCE} -eq 1 ]]; then
   monitor_resource 
fi


## write status log record
write_status_log "-"  ${loadmgr_nm} RUNNING "$$" ${CONTROLLER_PID} 

## start the job management block
while [[ $jobstatus != ENDED ]]
do
      ## check whether it runs over the max time allowed
      cur_time=$(date +%s) 
      total_secs=$(( $cur_time - $beg_time ))

      if [[ $MAX_RUN_TIME != max && $total_secs -gt $MAX_RUN_TIME ]]; then
         timestamp=`date +"%Y-%m-%d %H:%M:%S"`
         print "${timestamp} --> Run over max allowed time, stop  process ${PACKAGE_NAME}..."
         stop_overtime_jobs
         sleep 2
         if [[ $? -eq 0 ]]; then
            stop_loadmgr
         else 
            print "${timestamp} -> Failed to stop over max allowed time, terminate  process ${PACKAGE_NAME}..."
            terminate_loadmgr
         fi
      fi
      
      ## check concurrency level when CONCURRENCY_SCOPE = 1
      if [[ ${CONCURRENCY_SCOPE} -eq 1 ]]; then
         check_concurrency
         current_num_of_job=$? 
      fi 

      ## will not exam jobs until there is concurrent slot, hard-coded wait time
      while (( $current_num_of_job >= ${CONCURRENCY_LVL} ))
      do
         sleep ${CONCURRENCY_CHECK_TIME}
         
         ## check concurrency level again
         check_concurrency
         current_num_of_job=$? 
      done 
      
      ## may want to get open slots for new jobs ...

      ## loop through all defined jobs
      i=0

      ## Assume no more job to run
      HAS_MORE_JOB=0

      ## Update status for all previous run jobs
      refresh_status

      while (( i < ${#tasks[*]} )) 
      do
         #echo " at the top of ${i}th tasks ${tasks[$i]}..." 

         ## reset to indicate new job has submitted for current interation
         submit_ind=0 
         ## default resume_task to 0, it is used to decide whether to inject sleep time to allow status update
         resume_task=0

         ## if the process is already running set flag
         if [[ ${status_array[$i]} -eq 1 ]]; then
            HAS_MORE_JOB=1
            (( i=i+1 ))
            continue 
         fi

         ## if the process has been run in current session
         if [[ ${run_ind_array[$i]} -eq 1 ]]; then
            (( i=i+1 ))
            continue 
         fi

         ## if the process is blocked by failed process then skip -- necessary to avoid dead loop   
         if [[ ${blocked_array[$i]} -eq 1 ]]; then
           (( i=i+1 ))
           continue 
         fi

         ## check status for the current task i   -  9/25/2014 move down this block to avoid unneccessary check of status 
         #check_status ${tasks[$i]}   
         #echo " ${i}th tasks ${tasks[$i]} ${programs[$i]} with status of ${status_array[$i]} and block indicate of ${blocked_array[$i]} ... -> $HAS_MORE_JOB"

         ## if never run or failed in previous run
         if [[ ${status_array[$i]} -eq 0 || ( ${status_array[$i]} -eq 2 && ${run_ind_array[$i]} -eq 0 ) ]]; then
             #echo "${i}th tasks ${tasks[$i]} ${programs[$i]}  with status code of ${status_array[$i]} and block indicate of ${blocked_array[$i]} ... -> $HAS_MORE_JOB"
            ## check predecessors
            wait_predecessors $i
            wait_code=$?

            ## deal with invalid predecessor
            if [[ ${wait_code} -eq 255 ]]; then
               print "Invalid state of predecessor, Terminating Loadmgr ... "
               terminate_loadmgr 
            fi
            
            ## 
            if [[ ${wait_code} -eq 0 ]]; then
               ## Set more job to run
               HAS_MORE_JOB=1
               #echo "${i}th tasks ${tasks[$i]} ${programs[$i]}  with status of ${status_array[$i]} and block indicate of ${blocked_array[$i]} ... -> $HAS_MORE_JOB"
               
               if [[ ${status_array[$i]} -eq 0 ]]; then
                  print `date +"%Y-%m-%d %H:%M:%S`  " --> Kick off the number $((${i}+1)) job: ${programs[$i]} TaskID = ${tasks[$i]}"
               else 
                  resume_task=1
                  print `date +"%Y-%m-%d %H:%M:%S` " ---> Resume Task $((${i}+1)): ${programs[$i]} TaskID = ${tasks[$i]}"
               fi

               ##get parameter, if not found, set to undefined
               get_task_param ${tasks[$i]}

               ## unblock previous failed job - setting array value -need to work on it ...
               ${LOADMGR_HOME}/bin/runjob.sh ${tasks[$i]} ${programs[$i]} ${duplicate_ind[$i]} $$ ${PACKAGE_NAME} "${CURRENT_JOB_PARM}" &
               ## indicate a job submitted for current iteration
               submit_ind=1

               ## 9/25/2014 increase concurrency level
               if [[ ${CONCURRENCY_SCOPE} -eq 0 ]]; then
                  (( current_num_of_job=current_num_of_job+1))
               fi

               ##get child process pid
               pid_array[i]=$!

               ##set run and status flag
               status_array[i]=1
               run_ind_array[i]=1
            fi
         fi 

         ## sleep and wait for the previous job updates the status, condition code is for performance. 
         if [[ ${resume_task} -eq 1 ]]; then
            sleep ${REST_TIME}
         fi 
         
         ## move back to the top of job to ensure proirity based on the order the jobs listed
         if [[ ${submit_ind} -eq 1 ]]; then
            i=${#tasks[*]}
         else  
            (( i=i+1 ))
         fi 
      done

   ## check whether entire package is done.
   is_done
   done_ind=$?
   if [[ ${done_ind} -eq 1 ]]; then
      jobstatus=ENDED
      break
   fi

   ## check whether there is no more tasks
   if [[ ${HAS_MORE_JOB} -eq 0 ]]; then
      terminate_loadmgr
   fi
done

##cleanup and exit
loadmgr_exit 
