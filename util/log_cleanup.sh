#!/bin/ksh

## 
## $Id: log_cleanup.sh,v 1.1 2012/04/01 14:48:52 jozhao Exp $
## Usage:  
## Date       By        Comment
## 2012/01/01 Jozhao    This is a part of LoadMgr 

## find out LoadMgr installation directory, and source LoadMgr profile
whence ${0}|read exe_dir 
LoadMgr_bin_dir=${exe_dir%/*}
. $LoadMgr_bin_dir/../etc/.LoadMgr_profile


##load internal functions
autoload set_env
set_env

## check calling parameters 
if ! [[ -e $LOADMGR_HOME/etc/log_cleanup.meta ]]; then
   print "Usage: ${0} "
   exit 1
fi

## parse log cleanup metadata
i=0
grep  "^[^#| #|   #]" "$LOADMGR_HOME"/etc/log_cleanup.meta | {
  while read package_name days extra; do 
    packages[$i]=$package_name
    keep_days[$i]=$days
    ((i= $i + 1 ))
  done 
} 

#go to log root
cd $LOG_BACKUP_ROOT

#loop through all package logs
i=0
while [[ $i -lt ${#packages[*]} ]]
do
   find ./ -type d  -ctime +${keep_days[$i]}  | grep "${packages[$i]}_" |xargs rm -rf
   ((i+=1))
done 
