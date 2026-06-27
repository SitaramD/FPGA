// // Code your testbench here

 module tb;
   reg[4:0] data;
   integer value;
  
   initial
     begin
         $monitor("MOn DATA=%0d",data);// monitor
        data=3;//blocking
       #0;
        data<=5; // non blocking
        $display("DATA=%0d",data);//3/ display
      
          data<=6;
         data<=8;
           $display("DATA=%0d",data);
     end
 endmodule

