# ECE552 Extra Credit

file mkdir ./reports
file mkdir ./outputs

read_file -format verilog {hart.v decode_stage.v dmem_rdata_mask_logic.v dmem_wdata_mask_logic.v MEM_WB_register.v IF_ID_register.v hazard_detection_unit.v ID_EX_register.v decoder.v EX_MEM_register.v execute_stage.v fetch_stage.v forwarding_unit.v alu.v control.v alu_control.v load_logic.v PC.v rf.v store_logic.v}
set current_design hart
link

###########################################
# Define clock and set don't mess with it #
###########################################
# clk with frequency of 400 MHz
set clk_port [get_ports i_clk]

if {[llength $clk_port] == 1} {
    create_clock -name "clk" -period 8 -waveform {0 4} $clk_port
    set_false_path -from [get_ports i_rst]
    set compile_delete_unloaded_sequential_cells false
    set compile_seqmap_propagate_constants false
    set_dont_touch_network $clk_port

    # pointer to all inputs except clk
    set prim_inputs [remove_from_collection [all_inputs] $clk_port]
    # pointer to all inputs except clk and rst
    set prim_inputs_no_rst [remove_from_collection $prim_inputs [get_ports i_rst]]


    #########################################
    # Set input delay & drive on all inputs #
    #########################################
    set_input_delay -clock [get_clocks clk] 0.25 [copy_collection $prim_inputs]
    # rst goes to many places so don't touch
    set_dont_touch_network [get_ports i_rst]

    ##########################################
    # Set output delay & load on all outputs #
    ##########################################
    set_output_delay -clock [get_clocks clk] 0.5 [all_outputs]
    set_load 0.1 [all_outputs]
} else {
    puts "Warning: i_clk not found or not an input — skipping timing constraints"
}

######################################################
# Max transition time is important for Hot-E reasons #
######################################################
set_max_transition 0.1 [current_design]

########################################
# Now actually synthesize for 1st time #
######################################## 
compile -map_effort medium
check_design

# Unflatten design now that its compiled
set_flatten true
uniquify -force
ungroup -all -flatten
# force hold time to be met for all flops
set_fix_hold [get_clocks clk]

# Compile again with higher effort
compile -map_effort high
check_design

#############################################
# Take a look at area, max, and min timings #
#############################################
report_area > ./reports/dut_area.syn.txt
report_power > ./reports/dut_power.syn.txt
report_timing -delay min > ./reports/dut_min_delay.syn.txt
report_timing -delay max > ./reports/dut_max_delay.syn.txt

#### write out final netlist ######
write -format verilog -output ./outputs/dut.vg
#### write out sdc ######
write_sdc ./outputs/dut.sdc
exit


