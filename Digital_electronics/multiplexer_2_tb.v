// Multiplexer with testbenches 

module tb_mux_2x1;
    reg a, b, s;
    wire y;

    mux_2x1 uut(a, b, s, y);

    initial begin
        $display("a b s | y");
        $display("------+--");
        a=0; b=0; s=0; #10;
        $display("%b %b %b | %b", a, b, s, y);
        a=0; b=1; s=0; #10;
        $display("%b %b %b | %b", a, b, s, y);
        a=1; b=0; s=0; #10;
        $display("%b %b %b | %b", a, b, s, y);
        a=1; b=1; s=0; #10;
        $display("%b %b %b | %b", a, b, s, y);
        a=0; b=0; s=1; #10;
        $display("%b %b %b | %b", a, b, s, y);
        a=0; b=1; s=1; #10;
        $display("%b %b %b | %b", a, b, s, y);
        a=1; b=0; s=1; #10;
        $display("%b %b %b | %b", a, b, s, y);
        a=1; b=1; s=1; #10;
        $display("%b %b %b | %b", a, b, s, y);
        $finish;
    end
endmodule