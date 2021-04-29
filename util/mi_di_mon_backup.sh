#!/usr/bin/ksh

## $Id: mi_di_mon_backup.sh,v 1.1 2012/10/04 18:19:59 jozhao Exp $
## Date       By        Comment
## 08/02/11   jozhao    This shell script will backup di_mon to local backup directory 
##                      It use rsync, please work with Sysadm if it is not installed
##                      This script is integrated into LoadMgr package, and runs within the framework.
## Notes:  This script is developed based on rsync 2.6.2, which is available on IBM support site for AIX 5.3
##         The script comes from Mike Rubel's original idea  with enhancement on the configrable incremental running windows
##
## Usage:  mi_di_mon_backup.sh 
##         This script needs to be run on environment that will get the di_mon instance under mibackup account !!!
##         To restore, simple pick up di_mon.{version} and issue
#          rsync -avWL --delete $BACKUP_DIR/di_mon.{version}/. $DI_MON_ROOT/ -- BE CAREFUL with that -- delete flag when restoring; make sure you really meant it. 

## find out LoadMgr installation directory, and source LoadMgr profile
whence ${0}|read exe_dir
LoadMgr_bin_dir=${exe_dir%/*}
. $LoadMgr_bin_dir/../etc/.LoadMgr_profile

## terminate
function error_stop {
  echo "$ERROR_MSG ..."
  exit 1

}

echo "starting backup di_mon " `date`

## backup only di_mon base files
rsync -vaWL --stats --delete  --files-from=$LOADMGR_HOME/etc/di_mon_backup_list.meta  --exclude="*/" --link-dest=../di_mon.0 $DI_MON_ROOT/. $BACKUP_DIR/di_mon.tmp/
 
if  [[ $? -ne 0 ]]; then
   ERROR_MSG="failed to backup di_mon"
   error_stop
fi 

#remmove the last incremental backup that max out the # of backup
[[ -d $BACKUP_DIR/di_mon.$MAX_INCREMANTAL_BACKUP ]] && rm -rf $BACKUP_DIR/di_mon.$MAX_INCREMANTAL_BACKUP

#push back the existing backup if they exist
i=$MAX_INCREMANTAL_BACKUP
while (( i > 0 ))
do
   (( j=i-1 ))
      [[ -d $BACKUP_DIR/di_mon.$j ]] && mv  $BACKUP_DIR/di_mon.$j $BACKUP_DIR/di_mon.$i
   (( i=i-1 ))
done

#move the current one as the latest backup
[[ -d $BACKUP_DIR/di_mon.tmp ]] && mv $BACKUP_DIR/di_mon.tmp $BACKUP_DIR/di_mon.0

touch $BACKUP_DIR/di_mon.0

echo "ending backup di_mon " `date`
