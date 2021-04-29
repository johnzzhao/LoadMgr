proc options;run;

data _null_;
   call sleep(5, 1);
run;
endsas;
data a;
  set b;
run;
