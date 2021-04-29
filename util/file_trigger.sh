#!/bin/ksh
## 
## $Id: file_trigger.sh,v 1.5 2012/09/14 01:06:35 jozhao Exp $
## Usage:   {0} [Trigger_file_name] [LoadMgr_template_package]" 
##          This script can be scheduled to trigger a LoadMgr process by a defined file.  
##          If the same process is allowed to be triggered to run in parallel more than one instance, 
##          the process will be renamed with timestamps.  Unlike typical LoadMgr
##          if the process is failed, the LoadMgr status log file will be archived, so no restart is allowed.
## Date       By        Comment
## 2012/03/29 Jozhao    This is a part of LoadMgr
##


## set up running mode
LOCAL_EVENT_PROCESS_MODE=1     # 1 = run parallel, more than one of defined LoadMgr package can run in parallel, 
                               # 0 = run one package at a time

## don't change the code below
if [[ ${#} -ne 2 ]] ; then
   print "ussage ${0} [Trigger_file_name] [LoadMgr_template_package]" 
   exit 1
fi

typeset file_name=$1
typeset base_name=${file_name##*/}
typeset rc
typeset loadmgr_package_template_nm=$2
typeset timestamp_str=$(date +"%Y_%m_%d_%H%M%S")

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir 
script_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

if [[ ! -e $LOADMGR_HOME/etc/$loadmgr_package_template_nm.conf ]]; then
   print "LoadMgr package $loadmgr_package_template_nm doesn't exit"
   exit 1
fi

## define final process mode
EVENT_PROCESS_MODE=${LOCAL_EVENT_PROCESS_MODE:-${EVENT_PROCESS_MODE}}

if [[ -e ${file_name} ]]; then 
   print `date +"%Y-%m-%d %H:%M:%S"` "--- event trigger file is found:" >> $EVENT_LOG
   ls -l ${file_name} >> $EVENT_LOG

   ## move the event trigger file to event log directory
   mv ${file_name} $LOG_BACKUP_ROOT/${base_name}_${timestamp_str}

   if  [[ ! $? -eq 0 ]]; then
      print `date +"%Y-%m-%d %H:%M:%S"`  "failed to move event trigger file" >> $EVENT_LOG
      exit 1
   fi
   
   print `date +"%Y-%m-%d %H:%M:%S"` " -- start process $loadmgr_package_template_nm..." >> $EVENT_LOG

   if [[ $EVENT_PROCESS_MODE -eq 1 ]]; then
      ## instantiate loadmgr pacakge 
      ln -s $LOADMGR_HOME/etc/$loadmgr_package_template_nm.conf \
         $LOADMGR_HOME/etc/${loadmgr_package_template_nm}_${timestamp_str}.conf
      ln -s $LOADMGR_HOME/src/${loadmgr_package_template_nm} $LOADMGR_HOME/src/${loadmgr_package_template_nm}_${timestamp_str}

      ## run LoadMgr process 
      $LOADMGR_HOME/bin/controller.sh ${loadmgr_package_template_nm}_${timestamp_str} 

      ## move status log if failed
      test $? -ne 0 && mv ${LOG_ROOT}/status/${loadmgr_package_template_nm}_${timestamp_str}.log \
         ${LOG_ROOT}/${loadmgr_package_template_nm}/${loadmgr_package_template_nm}_${timestamp_str}.log

      rm -f $LOADMGR_HOME/etc/${loadmgr_package_template_nm}_${timestamp_str}.conf
      rm -f $LOADMGR_HOME/src/${loadmgr_package_template_nm}_${timestamp_str}


      ## archive the logs
      mv  $LOG_ROOT/${loadmgr_package_template_nm}_${timestamp_str} $LOG_BACKUP_ROOT
   else 
      $LOADMGR_HOME/bin/controller.sh ${loadmgr_package_template_nm}

      ## move status log if failed
      test $? -ne 0 && mv ${LOG_ROOT}/status/${loadmgr_package_template_nm}.log \
         ${LOG_ROOT}/${loadmgr_package_template_nm}/${loadmgr_package_template_nm}_${timestamp_str}.log
   fi
else 
   print `date +"%Y-%m-%d %H:%M:%S` " --- event trigger files $file_name doesn't exit"
fi
