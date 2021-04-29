data _null_;
   call sleep(10, 1);
   sysparm = sysparm();
   put sysparm=;
run;


