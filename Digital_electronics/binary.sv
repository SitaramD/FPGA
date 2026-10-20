// Write a module with an initial block that declares these numbers and prints each in binary, hex and decimal (%b, %h, %d):
// 4'b1010, 8'd100, 8'hFF, 6'o25, 12'h14x, 11'bzzz_011_010.   
// Check: Which ones print x or z in decimal? Explain why.   

module print_number();

     reg [3:0] a;
     reg [7:0] b;
     reg [7:0] c;
     reg [5:0] d;
     reg [11:0] e;
     reg [10:0] f;

     initial begin

               a = 4'b1010;
               b = 8'd100;
               c = 8'hFF;
               d = 6'o25;
               e = 12'h14x;
               f = 11'bzzz_011_010;
            

               $display(" Literal 4'b1010");
               $display(" Binary: %b", a);
               $display(" Hex: %h", a);
               $display(" Decimal: %d\n", a); 
               
               $display(" Literal 8'b100");
               $display(" Binary: %b", b);
               $display(" Hex: %h", b);
               $display(" Decimal: %d\n", b);

               $display(" Literal: 8'hFF");
               $display(" Binary: %b", c);
               $display(" Hex: %h", c);
               $display(" Decimal: %d \n", c);  
 
               $display(" Literal: 6'o25");  
               $display(" Binary: %b", d);
               $display(" Hex: %h", d);
               $display(" Decimal: %d \n", d);

               $display(" Literal: 12'h14x");
               $display(" Binary: %b", e);
               $display(" Hex: %h", e);
               $display(" Decimal: %d\n", e);

               $display(" Literal: 11'bzzz_011_010");
               $display(" Binary: %b", f);
               $display(" Hex: %h", f);
               $display(" Decimal: %d\n", f);

                  


     end

endmodule

 
