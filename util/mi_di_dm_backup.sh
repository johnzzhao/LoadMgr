#!/bin/ksh

##Id: mi_di_dm_backup.sh,v 1.1 2014/05/23 18:00:22 jozhao Exp $
## Date       By        Comment
## 08/02/11   jozhao    This shell script will backup di_dm to local backup directory 
##                      It use rsync, please work with Sysadm if it is not installed
##                      This script is integrated into LoadMgr package, and runs within the framework.
## Notes:  This script is developed based on rsync 2.6.2, which is available on IBM support site for AIX 5.3
##         The script comes from Mike Rubel's original idea  with enhancement on the configrable incremental running windows
##
## Usage:  mi_di_dm_backup.sh 
##         This script needs to be run on environment that will get the di_dm instance under mibackup account !!!
##         To restore, simple pick up di_dm.{version} and issue
#          rsync -avWL --delete $BACKUP_DIR/di_dm.{version}/. $DI_DM_ROOT/ -- BE CAREFUL with that -- delete flag when restoring; make sure you really meant it. 

## find out LoadMgr installation directory, and source LoadMgr profile
whence ${0}|read exe_dir
LoadMgr_bin_dir=${exe_dir%/*}
. $LoadMgr_bin_dir/../etc/.LoadMgr_profile

## terminate
function error_stop {
  echo "$ERROR_MSG ..."
  exit 1

}

echo "starting backup di_dm " `date`

## backup only di_dm base files
rsync -vaWL --stats --delete  --link-dest=../di_dm.0 $DI_DM_ROOT/. $BACKUP_DIR/di_dm.tmp/
 
if  [[ $? -ne 0 ]]; then
   ERROR_MSG="failed to backup di_dm"
   error_stop
fi 

#remmove the last incremental backup that max out the # of backup
[[ -d $BACKUP_DIR/di_dm.$MAX_INCREMANTAL_BACKUP ]] && rm -rf $BACKUP_DIR/di_dm.$MAX_INCREMANTAL_BACKUP

#push back the existing backup if they exist
i=$MAX_INCREMANTAL_BACKUP
while (( i > 0 ))
do
   (( j=i-1 ))
      [[ -d $BACKUP_DIR/di_dm.$j ]] && mv  $BACKUP_DIR/di_dm.$j $BACKUP_DIR/di_dm.$i
   (( i=i-1 ))
done

#move the current one as the latest backup
[[ -d $BACKUP_DIR/di_dm.tmp ]] && mv $BACKUP_DIR/di_dm.tmp $BACKUP_DIR/di_dm.0

touch $BACKUP_DIR/di_dm.0

echo "ending backup di_dm " `date`
