module table_of_2;
    integer i;
    initial begin
        $display("2 Times Table");
        $display("=============");
        for (i = 1; i <= 10000; i = i + 1) begin
            $display("2 x %0d = %0d", i, 2*i);
        end
        $finish;
    end
endmodule
