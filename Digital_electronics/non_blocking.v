// To check the value of data, blocking and non blocking assignment
module tb;
  reg[4:0] data;
  integer value;
  
  initial
    begin
      data=3;//blocking
      data<=5; // non blocking
      $display("DATA=%0d",data);//3/ display
      $monitor("MOn DATA=%0d",data);// monitor
    end
endmodule


----------------------------------------------

