// shared self-check helpers (included inside each testbench module)
integer errors = 0;
integer checks = 0;
task chk; input c; input [639:0] m; begin
    checks = checks + 1;
    if (c !== 1'b1) begin $display("  [FAIL] %0s", m); errors = errors + 1; end
    else $display("  [ ok ] %0s", m);
end endtask
task summary; input [639:0] name; begin
    if (errors == 0) $display("%0s: PASS (%0d checks)", name, checks);
    else             $display("%0s: FAIL (%0d/%0d failed)", name, errors, checks);
end endtask
