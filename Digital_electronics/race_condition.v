// Race condition: Two blocks compete to read/write the same variable at the same time
 module tb;
   reg[7:0] data;
  
   initial
     begin
      #0;
       data=9;
     end
  
   initial
     begin
        $display("DATA=%0d",data);
     end
 endmodule