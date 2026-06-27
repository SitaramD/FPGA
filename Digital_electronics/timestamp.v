// to check time nanoseconds i.e delay
//'timescale 1ns/1ps
module delay_time;

   initial begin 
   
   #10; // 10 ns delay
   $display("10 ns delay completed");
   end
endmodule
    