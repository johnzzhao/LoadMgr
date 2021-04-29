#!/bin/ksh

## 
## $Id: controller.sh,v 1.30 2018/01/16 16:41:33 ranliu Exp $
## Usage:  The option -f forces a total rerun, instead of resume, after a failed run.
##         controller.sh [-f]  <package_conffile name>  
## Date       By        Comment
## 2012/03/04 Jozhao    This is a part of LoadMgr 
##                      

LOADMGR_VERSION=5.6
print Starting LoadMgr $LOADMGR_VERSION ...

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir 
LoadMgr_bin_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

## load internal shell functions
autoload set_env
set_env

## validate call signature 
while getopts :fd:p: opt
do
   case $opt in
      f) export RUN_MODE=rerun ;;
      d) export LOCAL_META_DIR=$OPTARG;;
      p) export lm_prama=$OPTARG;;
      \?) usage 
          ;;
   esac
done
shift OPTIND-1
if [[ ${#} -ne 1 ]] ; then
   usage 
fi


## get package name
export PACKAGE_NAME="$1"
export LM_PRAMA=$lm_prama

## check the existence of conf file
if  ! [[  -e ${LOCAL_META_DIR}/${PACKAGE_NAME}.conf  || -e $LOADMGR_HOME/etc/${PACKAGE_NAME}.conf ]]; then
   usage
fi

## get controller.sh pid
export CONTROLLER_PID=$$

## define additional environment variables
export TIMESTAMP_STR=$(date +"%Y_%m_%d_%H%M%S")
export DATE_STR=$(date +"%Y_%m_%d")
export START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
export LOGFILE=$LOG_ROOT/status/${PACKAGE_NAME}.log
#export LOCKFILE=${LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${CONTROLLER_PID}_$(date +"%y%m%d")
#export GETLOCK=${LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${CONTROLLER_PID}_$(date +"%y%m%d")_lock


## check whether the package is already running for current LoadMgr instance 
if [[ -e ${LOG_ROOT}/status/${PACKAGE_NAME}.pid ]]; then
   pid=$(cat ${LOG_ROOT}/status/${PACKAGE_NAME}.pid)
   kill -0 $pid > /dev/null 2>&1
   if [[ $? -eq 0 ]]; then
      print "one instance of $PACKAGE_NAME package is already running (pid $pid)"
      exit 0
   fi
   rm -f $LOG_ROOT/status/{$PACKAGE_NAME}.pid
fi

## backup previous logs
backup_log

## kick off LoadMgr process
print "The stdout and stderr of this ${PACKAGE_NAME} run  is redirected to: ${LOG_ROOT}/${PACKAGE_NAME}/LoadMgr_${PACKAGE_NAME}.log\n"
$LOADMGR_HOME/bin/LoadMgr.sh ${PACKAGE_NAME} > ${LOG_ROOT}/${PACKAGE_NAME}/LoadMgr_${PACKAGE_NAME}.log 2>&1 &
#$LOADMGR_HOME/bin/LoadMgr.sh ${PACKAGE_NAME} 

#rm -f $LOG_ROOT/status/{$PACKAGE_NAME}.pid

#exit 0

export LOADMGR_PID=$!
export LOCKFILE=${LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${LOADMGR_PID}_$(date +"%y%m%d")
export GETLOCK=${LOADMGR_TMP_DIR}/${PACKAGE_NAME}_${LOADMGR_PID}_$(date +"%y%m%d")_lock

## create status directory if it doesn't exist yet
test ! -d ${LOG_ROOT}/status && mkdir ${LOG_ROOT}/status

# Trap signals 2, 3 and 15 and pass on to child LoadMgr process
trap "kill -s TERM ${LOADMGR_PID} " INT QUIT TERM 

## create pid file
print "${LOADMGR_PID}" > ${LOG_ROOT}/status/${PACKAGE_NAME}.pid

print "${PACKAGE_NAME} package has been launched by LoadMgr, its process id is ${LOADMGR_PID}..."

print "waiting on the LoadMgr process ${LOADMGR_PID} ..."
wait ${LOADMGR_PID} 
rc=$?

if [[ -e ${LOG_ROOT}/status/${PACKAGE_NAME}.pid ]]; then
   rm -f $LOG_ROOT/status/${PACKAGE_NAME}.pid
fi 

#check whether LoadMgr is terminated
if [[ -e ${LOGFILE} ]]; then
   if [[ $rc -eq 1 ]]; then
      print "Terminate LoadMgr ..."
      exit 1 
   else 
      print "Stop LoadMgr ..."
      exit 0 
   fi
fi 
