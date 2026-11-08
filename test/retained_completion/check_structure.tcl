# Copyright 2026 CheshireAra contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
set out [file normalize $env(OUT)]
set variant $env(VARIANT)
set module $env(MODULE)
set top $env(TOP)
set file [open $out/sources.list r];set sources [split [string trim [read $file]] "\n"];close $file
set file [open $out/includes.list r];set include_paths [split [string trim [read $file]] "\n"];close $file
set_app_var search_path [concat [get_app_var search_path] $include_paths]
set_app_var target_library [list gtech.db]
set_app_var synthetic_library [list standard.sldb]
set_app_var link_library [list * gtech.db standard.sldb]
file mkdir $out/work
define_design_lib WORK -path $out/work
set frozen_inputs [concat $sources [list [file normalize [info script]]]]
foreach directory $include_paths {
 foreach sub [glob -nocomplain -types d -directory $directory *] {
  foreach path [glob -nocomplain -directory $sub *.svh] {lappend frozen_inputs $path}
 }
}
proc source_rows {paths} {
 set rows [list]
 foreach path $paths {
  if {![file isfile $path]} {error "Missing frozen input $path"}
  set digest [lindex [exec sha256sum -- $path] 0]
  lappend rows [join [list $path $digest [file size $path] [file attributes $path -permissions] [file type $path]] "\t"]
 }
 return $rows
}
set frozen_rows [source_rows $frozen_inputs]
set file [open $out/sources.tsv w];puts $file "path\tsha256\tsize\tmode\ttype"
foreach row $frozen_rows {puts $file $row};close $file
set stats [open $out/structure.tsv w];puts $stats "stage\tproperty\tvalue"
proc pre_generic_blackbox_kind {ref hierarchical unmapped blackbox sequential combinational synlib ndesigns nlibs} {
    if {$blackbox ne "true" || $hierarchical ne "false" ||
        $sequential ne "false" || $ndesigns != 0 || $nlibs != 0} {return ""}
    if {$ref in {**logic_0** **logic_1**} && $unmapped eq "false" &&
        $combinational eq "true" && $synlib eq "false"} {return constant}
    if {$unmapped ne "true" || $synlib ne "true"} {return ""}
    if {$combinational eq "true" &&
        [regexp {^\*(ADD|SUB|EQ|NE|GT|LT|GEQ|LEQ|ASH|ASHR)(_(UNS|TC))*_OP(_[0-9]+(\.[0-9]+)?)+$} $ref]} {return operator}
    # DC reports this elaborated unsigned multiplier with the same synthetic
    # operator attributes and is_combinational false. Do not infer this from a
    # reference name alone: all required attributes above must still match.
    if {$combinational eq "false" &&
        [regexp {^\*MULT_UNS_OP(_[0-9]+)+$} $ref]} {return multiplier}
    # SELECT/MUX are synthetic operators although DC marks is_combinational false.
    if {$combinational eq "false" &&
        [regexp {^\*(SELECT|MUX)_OP(_[0-9]+(\.[0-9]+)?)+$} $ref]} {return selector}
    return ""
}
proc capture_structure {stage out stats} {
    redirect -file $out/${stage}_check_design.rpt {set design_ok [check_design -nosplit]}
    puts $stats "$stage\tcheck_design_status\t$design_ok"
    redirect -file $out/${stage}_check_timing.rpt {set timing_ok [check_timing -include {loops} -nosplit]}
    puts $stats "$stage\tcheck_timing_status\t$timing_ok"
    set latches [all_registers -cells -level_sensitive -include_operator_register]
    set flops [all_registers -cells -edge_triggered -include_operator_register]
    puts $stats "$stage\tlatches\t[sizeof_collection $latches]"
    puts $stats "$stage\tflipflops\t[sizeof_collection $flops]"
    set f [open $out/${stage}_sequential_cells.tsv w]
    puts $f "kind\tcell\tref"
    foreach_in_collection cell $latches {puts $f "latch\t[get_object_name $cell]\t[get_attribute $cell ref_name]"}
    foreach_in_collection cell $flops {puts $f "flipflop\t[get_object_name $cell]\t[get_attribute $cell ref_name]"}
    close $f
    set multi_drivers 0
    set df [open $out/${stage}_net_drivers.tsv w]
    puts $df "net\tdrivers\tpins_and_ports"
    foreach_in_collection net [get_nets -hierarchical *] {
        # Count physical driving endpoints, not a hierarchy output pin and
        # the same internal gate twice. Transparent output aliases are loads.
        set endpoints [all_connected -leaf $net]
        set drivers [filter_collection $endpoints {object_class == pin && (direction == out || direction == inout)}]
        set ports [filter_collection $endpoints {object_class == port && (direction == in || direction == inout)}]
        set count [expr {[sizeof_collection $drivers] + [sizeof_collection $ports]}]
        if {$count > 1} {incr multi_drivers}
        puts $df "[get_object_name $net]\t$count\t[get_object_name $drivers] [get_object_name $ports]"
    }
    close $df
    puts $stats "$stage\tmulti_driver_nets\t$multi_drivers"
    redirect -file $out/${stage}_references.rpt {report_reference -hierarchy -nosplit}
    redirect -file $out/${stage}_cells.rpt {report_cell -nosplit [get_cells -hierarchical *]}
    set refs [list]
    foreach_in_collection cell [get_cells -hierarchical *] {lappend refs [get_attribute $cell ref_name]}
    set f [open $out/${stage}_reference_resolution.tsv w]
    puts $f "reference\tdesigns\tlibrary_cells\tblack_box_attr\tis_black_box_attr"
    set unresolved 0
    set blackboxes 0
    foreach ref [lsort -unique $refs] {
        set designs [get_designs -quiet $ref]
        set libs [get_lib_cells -quiet */$ref]
        set black [get_attribute -quiet $designs black_box]
        set isblack [get_attribute -quiet $designs is_black_box]
        if {[sizeof_collection $designs] == 0 && [sizeof_collection $libs] == 0} {incr unresolved}
        if {$black eq "true" || $black eq "1" || $isblack eq "true" || $isblack eq "1"} {incr blackboxes}
        puts $f "$ref\t[sizeof_collection $designs]\t[sizeof_collection $libs]\t$black\t$isblack"
    }
    close $f
    puts $stats "$stage\traw_no_design_or_library_references\t$unresolved"
    puts $stats "$stage\traw_reference_blackbox_attributes\t$blackboxes"
    puts $stats "$stage\tcells\t[sizeof_collection [get_cells -hierarchical *]]"
    # A no_map operator need not have a get_designs/get_lib_cells object.
    # Classify real cell attributes; an absent attribute is not false.
    redirect -file $out/${stage}_available_cell_attributes.rpt {list_attributes -application -class cell}
    set f [open $out/${stage}_actual_cell_attributes.tsv w]
    puts $f "cell\tref\tis_hierarchical\tis_unmapped\tis_black_box\tis_sequential\tis_combinational\tis_synlib_operator\tdesigns\tlibrary_cells\tclassification"
    set true_unresolved 0
    set actual_blackboxes 0
    set allowed_pre_generic_blackboxes 0
    set unexpected_blackboxes 0
    foreach_in_collection cell [get_cells -hierarchical *] {
        set ref [get_attribute $cell ref_name]
        set hierarchical [get_attribute -quiet $cell is_hierarchical]
        set unmapped [get_attribute -quiet $cell is_unmapped]
        set blackbox [get_attribute -quiet $cell is_black_box]
        set sequential [get_attribute -quiet $cell is_sequential]
        set combinational [get_attribute -quiet $cell is_combinational]
        set synlib [get_attribute -quiet $cell is_synlib_operator]
        set ndesigns [sizeof_collection [get_designs -quiet $ref]]
        set nlibs [sizeof_collection [get_lib_cells -quiet */$ref]]
        set classification unexplained
        if {$blackbox eq "true" || $blackbox eq "1"} {
            incr actual_blackboxes
            set generic_kind [pre_generic_blackbox_kind $ref $hierarchical $unmapped $blackbox $sequential $combinational $synlib $ndesigns $nlibs]
            if {$stage eq "pre" && $generic_kind ne ""} {
                set classification pre_generic_$generic_kind
                incr allowed_pre_generic_blackboxes
            } else {
                set classification black_box
                incr unexpected_blackboxes
            }
        } elseif {$blackbox eq "false" || $blackbox eq "0"} {
            if {($hierarchical eq "true" || $hierarchical eq "1") && $ndesigns > 0} {
                set classification resolved_hierarchical
            } elseif {$nlibs > 0} {
                set classification resolved_library
            } elseif {([string first "*GEN*" $ref] == 0) && $unmapped eq "true" && $combinational eq "true" && $sequential eq "false"} {
                set classification generic_combinational
            } elseif {$ref eq "**SEQGEN**" && $unmapped eq "true" && $sequential eq "true" && $combinational eq "false"} {
                set classification generic_sequential
            } elseif {$synlib eq "true" && $unmapped eq "true" && ($combinational eq "true" || $sequential eq "true")} {
                set classification synlib_operator
            }
        }
        if {$classification eq "unexplained"} {incr true_unresolved}
        puts $f [join [list [get_object_name $cell] $ref $hierarchical $unmapped $blackbox $sequential $combinational $synlib $ndesigns $nlibs $classification] "\t"]
    }
    close $f
    puts $stats "$stage\ttrue_unexplained_cells\t$true_unresolved"
    puts $stats "$stage\tactual_blackbox_cells\t$actual_blackboxes"
    puts $stats "$stage\tallowed_pre_generic_blackbox_cells\t$allowed_pre_generic_blackboxes"
    puts $stats "$stage\tunexpected_blackbox_cells\t$unexpected_blackboxes"
    flush $stats
    return [dict create multi_drivers $multi_drivers design_ok $design_ok timing_ok $timing_ok latches [sizeof_collection $latches] flops [sizeof_collection $flops] unexplained $true_unresolved blackboxes $actual_blackboxes unexpected_blackboxes $unexpected_blackboxes]
}
if {[catch {
    set analyze_ok [analyze -format sverilog -define SYNTHESIS -library WORK $sources]
    puts $stats "setup\tanalyze_status\t$analyze_ok"
    if {!$analyze_ok} {error "Analyze failed"}
    if {[info exists env(DEPTH)]} {
      set elaborate_ok [elaborate $top -parameters "Depth=$env(DEPTH)" -library WORK]
    } else {set elaborate_ok [elaborate $top -library WORK]}
    puts $stats "setup\telaborate_status\t$elaborate_ok"
    if {!$elaborate_ok} {error "Elaborate failed"}
    set top [get_object_name [current_design]]
    current_design $top
    set link_ok [link]
    puts $stats "setup\tlink_status\t$link_ok"
    if {!$link_ok} {error "Link failed"}
    # A reference clock permits loop checking. This is not a frequency claim.
    create_clock -name clk_i -period 5 [get_ports clk_i]
    redirect -file $out/ports.rpt {report_port -verbose}
    redirect -file $out/pre_design.rpt {report_design}
    set pre [capture_structure pre $out $stats]
    write -format verilog -hierarchy -output $out/pre_generic.v
    write -format ddc -hierarchy -output $out/pre_generic.ddc
    set compile_ok [compile -no_map]
    puts $stats "compile\tno_map_status\t$compile_ok"
    if {!$compile_ok} {error "Compile -no_map failed"}
    redirect -file $out/post_design.rpt {report_design}
    set post [capture_structure post $out $stats]
    foreach phase [list $pre $post] {
        if {![dict get $phase design_ok] || ![dict get $phase timing_ok]} {error "Design/loop check failed"}
        if {[dict get $phase multi_drivers] != 0} {error "Multiple drivers"}
        if {[dict get $phase latches] != 0} {error "Unexpected latches"}
        if {[dict get $phase flops] == 0} {error "Real sequential DUT was optimized away"}
        if {[dict get $phase unexplained] != 0 || [dict get $phase unexpected_blackboxes] != 0} {error "Unexplained or black-box cells; inspect actual attributes"}
    }
    if {[dict get $post blackboxes] != 0} {error "Post-compile black-box cells"}
    write -format verilog -hierarchy -output $out/post_generic.v
    write -format ddc -hierarchy -output $out/post_generic.ddc
    if {[source_rows $frozen_inputs] ne $frozen_rows} {error "An implementation-check input changed"}
    puts "VGA_DC_COMPLETED module=$module variant=$variant"
} failure]} {
    puts $stats "control\terror\t$failure"
    puts "VGA_DC_FAILED module=$module variant=$variant $failure"
    close $stats
    exit 2
}
close $stats
exit 0
