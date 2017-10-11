proc leakage_opt {text1 arrivalTime text2 criticalPaths text3 slackWin} {
	######################### messages that can be suppressed #################################################################
	suppress_message NLE-019
	suppress_message TIM-104
	###########################################################################################################################
	if { [regexp "^-arrivalTime" $text1] == 0 && [regexp "^-criticalPaths" $text2] == 0 && [regexp "^-slackWin" $text3] == 0 } {
		error "Input Error" "Input: -arrivalTime X -criticalPaths Y -slackWin Z"
	}
	#########################variables##############################################################
	global clockPeriod
	set time_ini [clock clicks -milliseconds]
	set list_flag [list]
	set clock_uncertainty 0.15
	set output_external_delay 0.30
	set left [ expr { ($clockPeriod - $clock_uncertainty - $output_external_delay) - $arrivalTime } ] ;#left bound slackWin
	set right [ expr { ($clockPeriod - $clock_uncertainty - $output_external_delay) - $arrivalTime + $slackWin } ] ;#right bound slackWin
	set flag1 0	;#this flag is used to check the numerbs of paths in the window, if flag 0 there isn't violation for the numbers of the path in the window
	set flag2 0 ;#this flag is used to check the violation of the arrivalTime , if flag 0 there isn't violation
	set power_ini 0
	set power_fin 0
	set factor_exit 1.4 ;#factor used to exit the simulation: it is chosen with a trade-off between simulation time and accuracy
	###########################################################################################################################

	######################### Computation of initial leakage power ############################################################
	set power_ini [power_from_report]

	###########################################################################################################################

	######################### check  initial condition (criticalPaths and violation of arrivalTime) #########################
	set path_collection_window [get_timing_paths -nworst [expr {$criticalPaths+1}] -slack_greater_than $left -slack_lesser_than $right] 
	set path_critical [get_timing_paths -nworst 1]
	set num_path_window [sizeof_collection $path_collection_window]
	if {$num_path_window <= $criticalPaths} {
		set flag1 1
	}
	set max_arrival_time [get_attribute $path_critical arrival]
	if { $max_arrival_time < $arrivalTime} {
		set flag2 1
	}
	############################################################################################################################

	######################### if initial conditions are respected, it goes inside in the if statement ########################
	if { $flag1 == 1 && $flag2 == 1 } {		
		set list_par_cell [list]

	#################### cycle of the acquisition of k ##################

		foreach_in_collection point_cell [get_cells] {
			set cell_full_name [get_attribute $point_cell full_name]
			set cell_ref_name_LVT [get_attribute $point_cell ref_name]			
			set leak_power_LVT [leak_power $cell_full_name]

			set k [ expr { ($leak_power_LVT - $factor_exit ) } ]		

			#creation of the list
			if { $k > 0 } {		#only cells with a significant value are allowed into the list
				set row_list $cell_full_name
				lappend row_list $k			
				lappend list_par_cell $row_list
			}
		}
	###################################################################################
		set list_par_cell [ lsort -real -decreasing -index 1 $list_par_cell ] ;#sort the list according k
	#################### cycle for the swapping of the cells ##########################
		foreach row_list $list_par_cell { 
			set cell_full_name [lindex $row_list 0] ;#full_name			
	
			#cells_swapping HVT
			set cell_ref_name_LVT [get_attribute $cell_full_name ref_name]
			if { [regsub {_LL_} $cell_ref_name_LVT {_LH_} cell_ref_name_HVT] == 0 } { 
				regsub {_LLS_} $cell_ref_name_LVT {_LHS_} cell_ref_name_HVT	
			}
			size_cell $cell_full_name CORE65LPHVT_nom_1.00V_25C.db:CORE65LPHVT/$cell_ref_name_HVT

			#function that checks conditions for the swapping
			set list_flag [opt_control $arrivalTime $criticalPaths $left $right]
			
			#if at least one flag is set to 0 , the swapping isn't required and the cell is swapped again in lvt
			if { [lindex $list_flag 0]==0 || [lindex $list_flag 1]==0 } { 
				#cells_swapping LVT			
				size_cell $cell_full_name CORE65LPLVT_nom_1.00V_25C.db:CORE65LPLVT/$cell_ref_name_LVT
			}
		}
	###################################################################################		
	} else {
		if { $flag1 == 0 } { puts "Paths numbers inside the window number is greater than number of $criticalPaths" }	
		if { $flag2 == 0 } { puts "Arrival Time of the critical path is greater than $arrivalTime" }
	}
	############################################################################################################################	
	
	########################### computing percentage of lvt and hvt##########################################################
	redirect -variable report_text {report_threshold_voltage_group -nosplit}
	set report_text [split $report_text "\n"]
	set percentuale [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - 10]]] 2]
	scan $percentuale {%[(]%d%[%]} word percentuale word1
	if { $percentuale == 100 } {
		set tipo_cell [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - 10]]] 0]
		if {$tipo_cell == "HVT" } {	
			set HVT_percentuale 1
			set LVT_percentuale 0
		} else {
			set LVT_percentuale 1
			set HVT_percentuale 0
		}
	} else {
		set HVT_percentuale [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - 14]]] 2]
		set LVT_percentuale [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - 13]]] 2]
		scan $HVT_percentuale {%[(]%f} word HVT_percentuale 
		scan $LVT_percentuale {%[(]%f} word LVT_percentuale
		set LVT_percentuale [ expr { $LVT_percentuale / 100.0 } ]
		set HVT_percentuale [ expr { $HVT_percentuale / 100.0 } ]
	
	}
	############################################################################################################################

	######################### Computation of final leakage power ###############################################################
	set power_fin [power_from_report]

	if {$power_ini==$power_fin} {
		set resList 0	 
	} else {
		set resList [expr {($power_ini - $power_fin)/$power_ini}]
	}
	############################################################################################################################

	set time_fin [clock clicks -milliseconds]

	lappend resList [expr { ($time_fin - $time_ini) / 1000.0 } ]
	lappend resList $LVT_percentuale
	lappend resList $HVT_percentuale	
	
    return $resList
}

proc opt_control {arrivalTime criticalPaths left right} { 
	suppress_message TIM-104
	global clockPeriod
	set flag_ctr1 0
	set flag_ctr2 0
	set path_critical [get_timing_paths -nworst 1] 
	
	set path_collection_window [get_timing_paths -nworst [expr {$criticalPaths+1}] -slack_greater_than $left -slack_lesser_than $right]
	set num_path_window [sizeof_collection $path_collection_window]
	if {$num_path_window <= $criticalPaths} {
		set flag_ctr1 1
	}

	#check violation on the arrivalTime
	set max_arrival_time [get_attribute $path_critical arrival] 
	if { $max_arrival_time < $arrivalTime} {
		set flag_ctr2 1
	}

	set list_flag $flag_ctr1
	lappend list_flag $flag_ctr2 
	
	return $list_flag
}


proc leak_power {cell_name} {
  set report_text ""  ;# Contains the output of the report_power command
  set lnr 3           ;# Leakage info is in the 2nd line from the bottom
  set wnr 7           ;# Leakage info is the eighth word in the $lnr line 
  redirect -variable report_text {report_power -only $cell_name -cell -nosplit}
  set report_text [split $report_text "\n"]
  set leakage_cell [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $lnr]]] $wnr]

  if { [regexp "pW" $leakage_cell] == 1 } {
	regsub {pW} $leakage_cell {0} leakage_cell
	set leakage_cell [expr { $leakage_cell / 1000.0} ]	
  }
  if { [regexp "uW" $leakage_cell] == 1 } {
	regsub {uW} $leakage_cell {0} leakage_cell
	set leakage_cell [expr { $leakage_cell * 1000.0} ]	
  }
  if { [regexp "nW" $leakage_cell] == 1 } {
	regsub {nW} $leakage_cell {0} leakage_cell	
  }
  return $leakage_cell ;# nW
}

proc power_from_report { } {

	redirect -variable report_text {report_power -nosplit}
	set report_text [split $report_text "\n"]
	for {set i 0} { $i < [llength $report_text] } { incr i } {
		set text [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $i]]] 1]
		if { [regexp "Leakage" $text] == 1 } {
		
			set power_tot [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $i]]] 4]
			break
		}
	}
	
	set m_unit [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $i]]] 5]

	if { [regexp "pW" $m_unit] == 1 } {
		set power_tot [expr { $power_tot / 1000.0} ]	
  	}
  	if { [regexp "uW" $m_unit] == 1 } {
		set power_tot [expr { $power_tot * 1000.0} ]	
  	}

	return $power_tot
}

