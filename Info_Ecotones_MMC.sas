
%let root= C:\Users\YOURPATH\; 
%let fpath=&root.\YOURDIR\;

%let respvar= Prod_g_m2;
%let period=postdrought;

%let CONUM= 190; *Sample size (number of counties) for AICc calculations;

%put &respvar;
%put &period;

*import the DUST data;

proc import out= Dust_data
	datafile= "&root.Dropbox\SAS\Dust_Project\FINAL DUST ANALYSIS\DUST_FINAL_DATA.xlsx"
		dbms = xlsx replace;
		sheet= COMBINED_VARIABLES;
		getnames = yes;
run;quit;

*import the list of models;
proc import out= Model_list
	datafile= "&fpath.Models_Info_Eco_Bound_nocorr_new_18DEC_2020.xlsx"
		dbms = xlsx replace;
		getnames = yes;
run;quit;

*set log to temp file;
filename myfile "&fpath.mylog3.log";
proc printto log=myfile;
run;

*automatically obtain the number of observations;

%macro get_table_size(inset,macvar);
 data _null_;
  set &inset NOBS=size;
  call symput("&macvar",size);
 stop;
 run;
%mend;

%let reccount=;
%get_table_size(Model_list,reccount);
%put ***&=reccount***; *VERIFY THE NUMBER OF CORRELATED VARIABLES PAIRS TO DROP;

*MACRO LOOP FOR Running models;

proc delete data=results temp_data; *must delete existing appended macro results;
run;

data results; *create an empty data set to append results to. I used the DATA/SET procedure instead of Proc Append since I was appending table with differing variables;
run;

%MACRO DROPCORR;
	%put Model Statement: ***&model***;

	proc reg data=Dust_data outest=temp_data noprint;
	where period="&period" and in_Co_190="yes";
		model &respvar&model ;
	run;quit;

	Data Results;
		set Results Temp_data;
	run;quit;

%MEND;

%MACRO LOOP;
	%DO I=1 %TO &reccount;
		DATA _NULL_;
			SET Model_list; 
				IF _n_ = &i;
				CALL SYMPUT ('model', strip(models)); *creates macro variable var1;
				run;
				%DROPCORR;
				run;
 %End;

%MEND LOOP;

%LOOP;

Run;

*calculate AICc ;

data results;
	set results;
	AICc = _AIC_ + (2*_P_*(_P_+1))/(&conum -_P_-1);
run;quit;

*reset log output;
proc printto;
run;

*resort by smallest AIC;

Proc sort data=results noduprecs; *removes duplicate models;
	by descending _ADJRSQ_ ;
run;quit;

*Export the list of model statements;

proc export data=results
            outfile= "&fpath.MMC_results_190co_18DEC_2020.xlsx" 
            dbms=xlsx replace;
			sheet="&respvar._&period";
run;quit;

/*
*Pre-Drought;
proc reg data=Dust_data;
	where period="predrought" and in_Co_190="yes";
	model Prod_g_m2 = disturb_wt_mean Pcnt_Cropland_abnd FLOW PPT_wy Tmax_gs ;
run;quit;

*Drought;
proc reg data=Dust_data;
	where period="drought" and in_Co_190="yes";
	model Prod_g_m2 = Eros_pct disturb_wt_mean Pcnt_Cropland_abnd PPT_wy Tmax_gs;
run;quit;

*Drought normalized;
proc reg data=Dust_data;
	where period="drought" and in_Co_190="yes";
	model Prod_gm2_rel = Pcnt_Cropland_abnd FLOW Avg_SWC_0_20 PPT_gs Tmax_gs;
run;quit;

*Post-Drought;
proc reg data=Dust_data;
	where period="postdrought" and in_Co_190="yes";
	model Prod_g_m2 = Eros_pct disturb_wt_mean SLOPE_MEAN FLOW PPT_wy Tmax_gs;
run;quit;

*Post-Drought Normalized;
proc reg data=Dust_data;
	where period="postdrought" and in_Co_190="yes";
	model Prod_g_m2 = ELEV_MEAN SLOPE_MEAN Tmax_gs Tmax_gs_rel;
run;quit;

/*
