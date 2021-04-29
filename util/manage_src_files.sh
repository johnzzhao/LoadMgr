#!/bin/ksh

## 
## $Id: manage_src_files.sh,v 1.9 2012/09/28 18:58:00 jozhao Exp $
## Usage:  This is part of source file ETL process.  It checks income files first before doing the ETL load 
##         for a hosted deployment.  It can handle encryption and gzip files automatically.  The script takes
##         a request file as input, which contains the list of source files and process type.   The scripts will
##         first decrypt and unzip the source files if needed, and then validate the existence and record count of
##         of each source files. It assume the original files have .txt extension; the zipped file with .gz extension
##         and encrypted files have .gpg extension.
##
##         manage_src_files.sh  <request_file_name> 
## Date       By        Comment
## 2012/08/30 Jozhao    This is a part of LoadMgr
##

## find out LoadMgr installation directory, and source profile
whence ${0}|read exe_dir
script_dir=${exe_dir%/*}
. ${exe_dir%/*}/../etc/.LoadMgr_profile

## define variables
typeset i=0
typeset rc=0
typeset request_file=$1
typeset shell_name=${0%.*}
typeset num_rec
typeset -l ext
typeset timestamp_srt=$(date +"%Y_%m_%d_%H%M%S")
typeset src_file_archive_dir=${SRC_FILE_ARCHIVE_ROOT}/${timestamp_srt}

## parse request file
function parse_request {
   print `date` ": Parsing request file ..."
   i=0
   ## remove comment lines, empty line  and parse the configuration file
   grep  "^[^#| #|   #]" ${request_file}  | grep -v "^[[:blank:]]$"  |{ 
    while read line
    do
          case $line in
          [[SOURCE_FILE_LIST]])
             section=$"src_files"
             continue
             ;;
          [[REQUEST_TYPE]])
             section=$"process_type"
             continue
             ;;
          esac

          ## parse the three different sections
          case $section in
          src_files)
             set -A file_list $line 
             file_name[$i]=${file_list[0]}
             rec_cnt[$i]=${file_list[1]}
             # echo "just one line">${SRC_FILE_LANDING_DIR}/${file_list[0]}

             ((i+=1))
              ;;
          process_type)
              line=${line%%#*}
              export $line 
              ;;
          *)
              print "Invalid section head ..."  
              exit 1
          esac  
   done 
   }
}
function check_files {
   typeset i=0
   typeset rc=0
   print `date` ": Check whether the listed files exist..."
   while (( $i < ${#file_name[*]} )) 
   do 
      test ! -e ${SRC_FILE_LANDING_DIR}/${file_name[$i]}* &&  
         print "ERROR: ${SRC_FILE_LANDING_DIR}/${file_name[$i]} doesn't exist ..." &&  rc=1 
      ((i+=1))
   done
   
   ## exit if any files are missing
   test $rc -eq 1 && exit 1

   return $rc 
}

function archive_file {
   ## move files to archive directory

   print `data` ":  archive files and peform decryption and uncompression if needed..."
   mkdir ${src_file_archive_dir}
   test $? -ne 0 && print "ERROR: failed to create directory  ${src_file_archive_dir}" && exit 1

   mv  ${SRC_FILE_LANDING_DIR}/*  ${src_file_archive_dir}

   test $? -ne 0 && rc=1 &&  print "ERROR: failed to move files to $src_file_archive_dir"  

   return 0
}

function validate {
   typeset i=0
   typeset phyaical_file_name

   print `date` ": Check whether the files have expeted number of records ..."
   while (( $i < ${#file_name[*]} )) 
   do 
      ## get physical file extension and unzip and decrypt, if necessary 
      phyaical_file_name=`ls $src_file_archive_dir/${file_name[$i]}*`
      ext=${phyaical_file_name#*.}
      if [[ $ext = txt.gz ]]; then
         gunzip $phyaical_file_name
      elif [[ $ext = txt.gpg ]]; then
         echo "${ENCRYPTION_PASSPHRASE}" | gpg --batch --passphrase-fd 0  -o $src_file_archive_dir/${file_name[$i]} \
            -d $phyaical_file_name 
         test $? -ne 0 && rc=1
      elif [[ $ext = txt.gpg.gz ]]; then
         gunzip  $phyaical_file_name
         test $? -nw 0 && rc=1
         echo "${ENCRYPTION_PASSPHRASE}" | gpg --batch --passphrase-fd 0  -o $src_file_archive_dir/${file_name[$i]} \
         -d $src_file_archive_dir/${file_name[$i]}.gpg 
         test $? -ne 0 && rc=1
      elif [[ $ext = txt.gz.gpg ]]; then
         echo "${ENCRYPTION_PASSPHRASE}" | gpg --batch --passphrase-fd 0  -o $src_file_archive_dir/${file_name[$i]}.gz \
         -d $phyaical_file_name 
         test $? -ne 0 && rc=1
         gunzip  $src_file_archive_dir/${file_name[$i]}
         test $? -ne  0 && rc=1
      fi
      num_rec=`wc -l $src_file_archive_dir/${file_name[$i]} | cut -f1 -d ' '`

      if [[ ${num_rec} -ne ${rec_cnt[$i]} ]]; then
         print "ERROR:  ${file_name[$i]} has ${num_rec} records, doesn't match ${rec_cnt[$i]} in request" 
         rc=1
      fi
      ((i+=1))
   done
   return $rc
}

function copy_to_di_src {
   i=0
   print `date` ":  Copy files to di_src directory ..."
   while (( $i < ${#file_name[*]} )) 
   do 
      ## if the incoming file is .txt, just copy
      if [[ `ls -l $src_file_archive_dir/${file_name[$i]}* | wc -l` -eq 1 ]]; then
         cp -p $src_file_archive_dir/${file_name[$i]} ${DI_SRC_ROOT}/
      else 
         mv $src_file_archive_dir/${file_name[$i]} ${DI_SRC_ROOT}/  
      fi
      test $? -ne 0 && rc=1
      ((i+=1))
   done
   return $rc
}

## wait to make sure the request file is closed
sleep 5

parse_request

test $? = 0 && check_files

test $? = 0 && archive_file

test $? = 0 && validate

test $? = 0 && copy_to_di_src 

test $? -ne 0 && exit 1
