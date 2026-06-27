// D flip flop
module dff(d, rst,clk,q,qbar);

	input d, rst, clk;
	output q;
        reg q;
	output qbar;

	assign qbar =~q;
	always @(posedge clk)

	begin
	   if (rst)
		 q<=0;
	   else
	   q<=d;
	end
endmodule


// Test bench for D flip flop
module tb;
    reg d, clk, rst;
    wire q, qbar;

    dff DUT(
        .d(d),
        .clk(clk),
        .rst(rst),
        .q(q),
        .qbar(qbar)
    ); 
    initial begin
        $monitor("d =%0d q=%0d time=%0d", d,q,$time);
        clk = 0;
        rst = 1;
        d   = 1;
        #2 rst =0;
        #2 d=0;
        #2 d = 1; 
          
        #30 $finish;
    end
 always #5 clk=~clk;

endmodule
