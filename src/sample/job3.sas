proc options;run;

data _null_;
   call sleep(10, 1);
   attrib a length = 8;
   sysparm = sysparm();
   put sysparm=; 
   put "NOTES: testing log analyzer";  
   put "WARNING: DMS bold font metrics fail to match DMS font.";
   put "ERROR: A lock is not available for DI_MON.JOB_PARAM.DATA";
run;
endsas;
data a;
  set b;
run;
