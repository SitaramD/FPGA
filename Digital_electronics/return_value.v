module return_tb;  
  
   function fun(input [4:0] data);
   integer value;
   begin
      value = data * data;
      $display("VALUE=%0d", value);

      //fun = value;   

      $display("AFTER RETURN"); 
   end
   endfunction
   
   integer y;

   initial
      begin
      y = fun(4); // Calling function fun with an agrument 9, sent to the function
      $display("fun = %0d",y);
      end

endmodule 