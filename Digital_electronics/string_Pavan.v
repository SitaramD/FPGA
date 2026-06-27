module tb;
  
  //reg[103:0] name;
  
  string name;
  
  initial
    begin
      name="PAVAN_VERILOG";//13 *8=96 bits
      $display("NAME=%0s bits=%0d ",name,$bits(name));
    end
endmodule