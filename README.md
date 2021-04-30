Load Manager (LoadMgr) is a UNIX/Linux shell script application that automates both parallel and sequential batch SAS and shell jobs.

LoadMgr was developed originally using Korn shell 88 (ksh 88) on the AIX operating system for SAS enterprise solutions, including Revenue Optimization (RO) and Size Optimization (SO).  Recently, many SAS solutions are running on Linux Red Hat Enterprise Linux Server release 5.x, which comes with newer Korn Shell, LoadMgr 5.x is re-written in Korn Shell 93(ksh 93).  

What’s New in Version 5.x

LoadMgr 5.5 has significant enhancements as compared to previous releases of LoadMgr.  The following changes are included with LoadMgr 5.5:
•	It is common that a LoadMgr process needs to finish within a time window to meeting SLA (Service Level Agreement).  Therefore, when a job fails, you may want to restart it while the process is still running.  In previous releases, you have to wait for the LoadMgr process to stop before resubmitting it.  LoadMgr 5.5 allows the Admin to re-run the failed process when it is running. 
•	All Configuration files that define a LoadMgr package are now in a single configuration file.  The configuration file will have a .conf extension.  This replaces the .meta, .param, and .email files in LoadMgr 4.x.
•	You can now use a SAS program more than once in a package.  Log file names will include the SAS program name plus the Task ID, which is unique in each package.  This way, you can simply define different parameter values for the same programs. 
•	You can now use fully qualified SAS program names in a configuration (.conf) file.  This removes the requirement of having soft links to program directories, and allow you to have programs from different directories in the same configuration file.  You can still use soft links, if you wish.  You can override the default source code directory in your package configuration file.
•	You can now use a “testing” area for dry runs of production programs.  Us the following syntax to use this feature:
$LOADMGR/bin/controller.sh –d [testing_dir] [Package_name]

•	The Log Analysis Report now has a separate e-mail distribution list.  This will allow remote consultant to receive LoadMgr notification on SMS based devices 
•	Warning notification messages can now be disabled.  When disabled, you will no longer receive e-mail messages for SAS Warnings.
•	LoadMgr 5.5 archives logs like its predecessors.  However, the backup directory is now time-stamped using its last update time.  This will help you find the correct log files when troubleshooting
•	LoadMgr 5.5 integrates a log parser utility to provide FULLSTIMER statistics for performance analyzing.  You need to set FULLSTIMER_PARSE=1 in .LoadMgr_profile to enable this function.

•	LoadMgr 5.5 will enforce the order of jobs defined in the configuration file.  

•	LoadMgr 5.5 support extensions by defining multiple function paths in FPATH parameter in .LoadMgr_profile

•	LoadMgr 5.5 stops a package when it runs more than MAX_RUN_TIME, which is configurable in .LoadMgr profile.

Features
LoadMgr manages a list of SAS jobs and UNIX/Linux shell scripts as an overall process, the entire process is known as a package.  The following is a list of features supported by LoadMgr:
•	Configuration data-driven process automation: 
o	LoadMgr reads a configuration file that lists jobs and their predecessors,
o	LoadMgr then executes the jobs according their dependencies and defined concurrency level.
•	Status and Re-Startability: 
o	LoadMgr logs execution status and run time for each jobs as well as the entire process.  If the process failed on particular jobs, other independent jobs will run to their completion.  You can overwrite the default restart by issue –f at command line like:     controller.sh  -f sample
o	When an entire process stops running due to a job failure, the application’s administrator will need to address the root cause of the job failure.  LoadMgr will resume the process at the point of failure with the same LoadMgr command. 
•	Parameter Driven SAS Application: 
o	LoadMgr supports a job parameter that can define or change job parameters easily.
•	SAS log management: 
o	LoadMgr backs-up job historical log files with date/time stamps for each process.  The backup process includes SAS logs, list files, nmon output, and html reports. 
o	LoadMgr also provides a configurable utility to clean up historical log files based on their age.  This feature is helpful considering that some weekly log file sizes can grow to GBs.
•	Email notification: 
o	LoadMgr can send out email notification messages automatically whenever a job fails
o	LoadMgr can also send notification when an entire package of jobs finishes successfully.
•	SAS Log Analysis: 
o	LoadMgr comes with a SAS log analyzer utility.
•	Enterprise Scheduling: 
o	LoadMgr can be easily integrated with job schedulers such as CRON, ESP, and AutoSys.
•	Performance Monitor:
o	LoadMgr is integrated with NMON and VMstat on Unix/Linux
o	It can automatically start and stop NMON/VMstat to provide runtime performance data collection.

Additional Functionality
•	To prevent the predecessor job from becoming invalid during the update process, the checkconf.sh utility now validates the predecessors to ensure a configuration file is valid.
•	The controller.sh script accepts the –f option to force a fresh restart.
•	Version 2.4 and above comes with a robust full and incremental SAS datamart backup utility using rsync.
•	Starting from 4.0, multiple instances of the LoadMgr installation are supported and can function independently. 
•	LoadMgr stdout and stderr are automatically output to the following log file:
$LOG_ROOT/${package_name}/loadmgr_{timestampe}.log. 
•	All log files for a package are stored under $LOG_ROOT/ {package_name}.

How Does LoadMgr Log Job Status
LoadMgr updates a status file while jobs are running in real-time.  The file is stored in the $LOG_ROOT/status directory when jobs are executing and the moved to the $LOG_ROOT/ directory upon successful completion of a package.  The naming convention of the status file uses the filename of the current configuration file, a date/time stamp, and the file extension .log. 
Therefore, if you started the SAS Revenue Optimization initial load by typing:
controller.sh ro52_src2stg
A status file called ro52_src2stg.log will be created under $LOG_ROOT/status directory.  After all jobs run successfully, the status file will be updated and moved to the $LOG_ROOT/ro52_src2stg directory.
The log file name contains three parts:	
{package_name}_date_timestamp.log
LoadMgr 5.5 comes with sample configuration files and dummy programs for install test.  The configuration file sample.conf is at $LOADMGR_HOME/etc.  If the package is executed at 9:17pm of May 8, 2012, the log file will be named as sample_2012_05_08_211745.log.
Figure below shows a sample status file for package sample. 




