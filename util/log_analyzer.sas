/** 
** $Id: log_analyzer.sas,v 1.2 2012/03/28 20:58:05 jozhao Exp $
** Usage:
** Date       By        Comment
** 2012/03/24 Jozhao    This is a part of LoadMgr
*/
%macro analyze_log(package_nm=, report_lvl=1);
   %if %sysfunc(fileexist(&log_dir/&package_nm._current.msg)) = 0 %then %goto exit_macro;
   %put &log_dir ...;

   ** read in current run parsed log message; 
   data current_msg;
      infile "&log_dir/&package_nm._current.msg" lrecl = 1000 delimiter = '|' dsd firstobs = 1 missover;
      attrib package_nm  length = $150;
      attrib file_name length = $150;
      attrib msg_type  length = $20;
      attrib action    length = $20;
      attrib note     length = $150;
      attrib msg_date  length = 8 format = yymmddn8. informat=YYMMDD.;
      attrib msg       length = $300;
      input package_nm  file_name  msg_type  action note  msg_date msg ;
   run;

   ** read in historical parsed log message; 
   data hist_msg;
      infile "&log_dir/&package_nm..msg" lrecl = 1000 delimiter = '|' dsd firstobs = 1 missover;
      attrib package_nm  length = $150;
      attrib file_name length = $150;
      attrib msg_type  length = $20;
      attrib action    length = $20;
      attrib msg_date  length = 8 format = yymmddn8. informat= YYMMDD.;
      attrib note     length = $150;
      attrib msg       length = $300;
      input package_nm  file_name  msg_type  action note  msg_date msg ;
   run;

   ***************************************************;
   *         ceate new message report                 ;
   ***************************************************;
   proc sql noprint;
      create table new_msg_head as 
      select file_name, msg_type, msg from  current_msg 
      except 
      select a.file_name, a.msg_type, a.msg from current_msg a, hist_msg b where a.file_name =  b.file_name and  a.msg=b.msg;

      create table new_msg_summary_by_type as select file_name, msg_type, count(*) as counts from new_msg_head group by file_name, msg_type
         order by file_name;
   quit;

   data _null_;
      file "&log_dir/log_analysis_report.lst";
      set new_msg_summary_by_type;
      by file_name;
      if _N_ =  1 then do;
         put "       New Log Message Summary Report By Message Type";
         put;
      end;
      if first.file_name then do;
         put file_name;
         put "-------------------------------------------";
      end;
      if msg_type = "ERROR" then put "   total number of new ERROR message: " counts;
      else if msg_type = "WARNING" then put "   total number of new WARNING message: " counts; 
      else put "   total number of new selected NOTE message: " counts;  
      if last.file_name then do;
         put "-------------------------------------------";
      end;
   run;

   ***************************************************;
   *         ceate message report by action           ;
   ***************************************************;
   proc sql noprint;
      create table msg_summary_by_action as select a.file_name, b.action, count(*) as counts from current_msg a, hist_msg b
         where a.file_name =  b.file_name and a.msg_type = b.msg_type and a.msg =  b.msg group by a.file_name, b.action
         order by file_name;
   quit;

   data _null_;
      file "&log_dir/log_analysis_report.lst" mod;
      set msg_summary_by_action;
      by file_name;
      if _N_ =  1 then do;
         put;
         put "       Known Log Message Summary Report By Suggested Action";
         put;
      end;
      if first.file_name then do;
         put file_name;
         put "-------------------------------------------";
      end;
      put "   Suggested Action - "  action +(-1) ": " counts; 
      if last.file_name then do;
         put "-------------------------------------------";
      end;
   run;


   ***************************************************;
   *         ceate total message report by type             ;
   ***************************************************;
   proc sql noprint;
      create table msg_summary_by_type as select file_name, msg_type, count(*) as counts from current_msg group by file_name, msg_type
         order by file_name;
   quit;

   data _null_;
      file "&log_dir/log_analysis_report.lst" mod;
      set msg_summary_by_type;
      by file_name;
      if _N_ =  1 then do;
         put;
         put "       Total Log Message Summary Report By Message Type";
         put;
      end;
      if first.file_name then do;
         put file_name;
         put "-------------------------------------------";
      end;
      if msg_type = "ERROR" then put "   total number of ERROR message: " counts;
      else if msg_type = "WARNING" then put "   total number of WARNING message: " counts; 
      else put "total number of selected NOTE message: " counts;  
      if last.file_name then do;
         put "-------------------------------------------";
      end;
   run;

   ***************************************************;
   *         ceate detail report                      ;
   ***************************************************;
   %if &report_lvl = 2 %then %do;
      proc sql;
         create index file_msg on current_msg (file_name, msg);
      quit;

      data current_msg;
         modify current_msg 
                hist_msg ;
         by file_name msg;

         if %sysrc(_dsenmr) eq _iorc_ then put " new record .... ";
            
         ** if the record exists in the master, then replace for update;
         else if %sysrc(_sok) eq _iorc_ then replace;

         _iorc_ = 0;
         _error_ = 0;
      run;  

      data _null_;
         file "&log_dir/log_analysis_report.lst" mod;
         set current_msg; 
         by file_name;
         if _N_ =  1 then do;
            put;
            put "       Detail Message and Suggested Action Report";
            put;
         end;
         if first.file_name then do;
            put file_name;
            put "-------------------------------------------";
         end;
         put "   "    action  @20  msg;
         if note ^= "{Add_notes_here}" then put  @23 "LOADMGR NOTES:  "   note;
         if last.file_name then do;
            put "-------------------------------------------";
         end;
      run;
   %end;

   ** update historical message file;
   proc sql;
      create table new_msg as select a.* from current_msg a, new_msg_head b  where a.file_name =  b.file_name and a.msg = b.msg;
   quit;

   data _null_;
      set new_msg;
      file "&log_dir/&package_nm..msg"  lrecl = 1000 mod;
      put package_nm +(-1) "|"  file_name +(-1) "|"  msg_type +(-1) "|"  action +(-1) "|" note +(-1) "|" msg_date +(-1) "|" msg ;
   run;
   */

   %exit_macro:
%mend;
   %let log_dir=%SYSGET(LOG_DIR);

%analyze_log(package_nm=%sysget(PACKAGE_NAME), report_lvl=%sysget(report_lvl));
