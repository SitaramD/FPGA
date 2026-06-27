// 2-to-1 Multiplexer(Behavioural Model) function

//if sel =0 -> output = a
//if sel =1 -> output  =b 

module mux2to1(
       input a, 
	   input b, 
	   input sel,
	   output reg y);
	   
	   always @(*) begin
	   if (sel ==0)
	       y=a;		   
	   else
           y=b;
    end
endmodule		   