data _null_;
   call sleep(10, 1);
   sysparm = sysparm();
   put "start to process income file " sysparm;
run;

endsas;
data a;
  set b;
run;
