#!/bin/ksh

## 
## $Id: checkconf.sh,v 1.4 2016/07/28 22:36:17 ranliu Exp $
## Usage:   {0} [-d configration_dir ]  ${PACKAGE_NAME} 
## Date       By        Comment
## 2012/03/10 Jozhao    This is a part of LoadMgr
##

typeset config_dir
typeset valid_cfg=1 
typeset i=0

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir 
LoadMgr_bin_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

## load internal shell functions
autoload set_env
set_env

## validate call signature 
while getopts :fd: opt
do
   case $opt in
      d ) export LOCAL_META_DIR=$OPTARG;;
      ? ) usage 
          ;
   esac
done
shift OPTIND-1

if [[ ${#} -ne 1 ]] ; then
   print "You must provide package name" 
   exit 1
fi


## get package location and  name 
config_dir=${LOCAL_META_DIR:-"${LOADMGR_HOME}/etc"}
export PACKAGE_NAME="$1"

## check the existence of conf file
if !  [[  -e ${config_dir}/${PACKAGE_NAME}.conf ]]; then
   print "${config_dir}/${PACKAGE_NAME}.conf doesn't exist!" 
   print "Usage:  ${0} [-d confi_dir] package_name " 
   exit 1
fi

## parse package job configuration file 
parse_config ${config_dir}/${PACKAGE_NAME}.conf

## run validation and  set invalid configuration flag
validate_tasks
valid_cfg=$?

if [[ ${valid_cfg} -ne 0 ]]; then 
    print "The configuration is invalid, please fix the issues displayed."
    exit 1
fi

## List configuration detail
print "\n### Print out parser result based on the configuration file ###\n"
## print jobs and their predecessors
print "<--- List of jobs and their predecessors --->"
while [[ $i -lt ${#tasks[*]} ]]
do
   eval print \${tasks[$i]}  \${programs[$i]} " has precessors: " \${predecessor_array$i[*]}
   ((i+=1))
done
print "<--- The end of job list ---->\n"

print  "<--- List job parameters --->" 
i=0
for i in ${!parms[@]}
do
    print "Task $i has parameter value ${parms[$i]}" 
done
print "<--- End of the list of parameters --->" 
