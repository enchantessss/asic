module test;

  /* Make a rst_n that pulses once. */
  reg rst_n = 0;
  initial begin
     # 17 rst_n = 0;
     # 11 rst_n = 1;
     # 29 rst_n = 0;
     # 11 rst_n = 1;
     # 100 $stop;
  end

  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #5 clk = !clk;

  wire [7:0] value;
  counter c1 (value, clk, rst_n);

  initial begin
  #30;
     $display("vcs running: ============= >>>>  <<<< ================= ");
     $monitor("At time %t, value = %h (%0d)",$time, value, value);
     $dumpfile("test.vcd");
     $dumpvars(0,test);
  end



endmodule // test
