/*
	Name: Joe Alcini
	Course: STA 402
	Date: 12/08/2021
	File: CPI.sas

	Description: This program creates a
	macro used to display graphs of the consumer
	price index for regions specified by a user
	for a given time range and calculation interval.
	The user can input 1-4 regions that consist of:
	Midwest, Northeast, Sout and West using the regions parameter. 
	The user can enter a starting and ending year to
	limit the number of data points that make up the graph by
	using the start_time and end_time parameters.
	Finally the user can choose how what calculation interval
	is used by choosing between: Month, Quarter,or Year
	using the calc_period parameter. User can specify path
	to data using the path variable before macro heading.
	Refrain from using qutation marks in the path declaration.

	Example Inputs: 
	%cpi(regions="South Northeast Midwest West", start_time=1970, end_time=2021, calc_period=Year);
	%cpi(regions="Midwest South Northeast West", start_time=1975, end_time=1995, calc_period=Month);
	%cpi(regions="Midwest West", start_time=2010, end_time=2021, calc_period=Quarter);
*/

/* Set path to the folder conatining the datasets */
%let path = ;

/* Declares the macro */
%macro cpi(regions=, start_time=, end_time=, calc_period=);
	/* Take user given locations */
	data input_regions;
		/* Specify max length for a region */
		length area_name $ 9;

		/* Count number of regions */
		num = 0;

		/* Searches for names */
		do until (area_name=" ");
			/* Searches for the region */
			area_name = scan(&regions, num + 1);

			/* Space deliminated finds the space*/
			if area_name~=' ' then do;
				num = num + 1;* adds 1 to the counter;
				output;* outputs the region into the dataset;
			end;
		end;

		/* Creates a macro variable storing the number of regions */
		call symput("num_regions", num);
	run;
	

	/* Sorts the user reigons for merging */
	proc sort data=input_regions;
		by area_name;
	run;

	/* 	area data: 
		pull out area code and name 
		filter out user regions
	*/
	data cu_area;
		/* Takes input from the given file */
		infile "&path\cu.area"
			firstobs=2
			obs = 14
			expandtabs;

		/* Specifies lengths of taarget variables */
		length area_code $ 4;
		length area_name $ 49;
		
		/* Inputs data */
		input area_code $ area_name & display_level selectable $ @;

		/* Filters out target regions */
		if area_name not = "Northeast" 
			and area_name not = "Midwest 0" 
			and area_name not = "South"
			and area_name not = "West" then delete;

		/* Cleans midwest data due to layout of the file */
		if area_name = "Midwest 0" then area_name = substr(area_name, 1, 7);

		/* Merges with user specified regions*/
		merge input_regions(in=in_regions);
			by area_name;

		/* Retains entry if specified*/
		if in_regions;

		/* Keeps the following columns */
		keep area_code area_name;
	run;
			
	/* 	series data:
		pull out series id and merge with regions area code 
		filter by selected area codes in input
	*/
	data cu_series;
		/* Takes input from the given file */
		infile "&path\cu.series"
			firstobs=2
			expandtabs;

		/* Specifies lengths of taarget variables */
		length series_id $ 15;
		length series_title $ 74;
		length area_code $ 4;

		/* Inputs data */
		input series_id $ area_code $ item_code $ seasonal $ periodicity_code $ base_code $ base_period $ series_title & @;

		/* Filters by target parameters */
		if seasonal = 'S' then delete;
		else if periodicity_code not = 'R' then delete;
		else if not find(series_title, 'All items') or not find(series_title, 'not seasonally adjusted') then delete;

		/* Keeps selected columns */
		keep series_id area_code;
	run;

	/* Merges the areas and series*/
	data cu_ids;
		/* Merges with desired regions */
		merge cu_area(in=in_area) cu_series;
			by area_code;

		/* Retains if present in user regions */
		if in_area;

		/* Keeps the following columns */
		keep series_id area_name;
	run;

	/*	allItems data: 
		keep the series, period val (M--), and monatary value
		retain periods that match the period type specified
	*/
	data cu_allItems;
		/* Takes input from the given file */
		infile "&path\cu.data.1.AllItems"
			firstobs=2
			expandtabs;

		/* Specifies lengths of taarget variables */
		length series_id $ 15;
		input series_id $ year $ period $ value @;

		/* Removes entries outside of the time bounds */
		if &start_time > year or &end_time < year then delete;

		/* Removes periods based on the period calulation */
		if "&calc_period" = "Year" and period = 'M13' then output;
	    if "&calc_period" = "Month" and period not = 'M13' then output;
		if "&calc_period" = "Quarter" then do;
			if period = 'M03' then output;
			else if period = 'M06' then output;
			else if period = 'M09' then output;
			else if period = 'M12' then output;
			else delete;
		end;
	run;

	/* final data:
		merges with series
		creates dates using the combination of year and period
	*/
	data cu_allItems_final;
		/* Merges series and item data */
		merge cu_ids(in=in_series) cu_allItems;
			by series_id;

		/* Must contain only items from the series data */
		if in_series;

		/* Creates valid dates */
		if period not = 'M13' then date = input(cats(substr(period, 2, 2), '-01-', year), mmddyy10.);
		else date = input(cats('01-01-', year), mmddyy10.);

		/* Keeps the following columns */
		keep area_name date value;
	run;

	/*Titles the plot*/
	title "&calc_period.ly Consumer Price Index Over Time by Region";

	/*
		Smoothed line sgplot series x=date y=CPI_Value
		format by using axis labels
		use a different plot in the same grouping for each plot
	*/
	proc sgpanel data=cu_allItems_final;
		/* Create 1 row of side by side plots */
		panelby area_name / novarname columns=&num_regions;

		/* Creates the series for each region*/
		series x=date y=value;

		/* Labels the axes */
		colaxis label = "&calc_period.s (Days from 01-01-1960)";
		rowaxis label = "Value of the CPI";
	run;
%mend cpi;
