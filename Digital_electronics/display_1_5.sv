// To print from 1 to 5 numbers    

module display_1_5();     
   
     initial begin
     integer i;
        for ( i=1; i<=195252; i=i+1) begin            
               $display("%d",i);
            end
      end
endmodule
