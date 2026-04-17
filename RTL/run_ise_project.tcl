proc fail {message} {
    puts stderr $message
    catch {project close}
    exit 1
}

if {$argc < 2 || $argc > 3} {
    puts stderr "usage: xtclsh run_ise_project.tcl <project.xise> <task> ?defines?"
    exit 2
}

set project_file [lindex $argv 0]
set task [lindex $argv 1]
set defines ""
if {$argc == 3} {
    set defines [lindex $argv 2]
}

if {![file exists $project_file]} {
    fail "Project file not found: $project_file"
}

if {[catch {project open $project_file} err]} {
    fail $err
}

if {[catch {project set "Verilog Macros" $defines -process "Synthesize - XST"} err]} {
    fail $err
}

puts "Running '$task' with defines: $defines"

if {[catch {process run $task -force rerun_all} result]} {
    fail $result
}

set status [process get $task status]
project close

if {(($status ne "up_to_date") && ($status ne "warnings")) || !$result} {
    fail "ISE task '$task' failed with status '$status'"
}
