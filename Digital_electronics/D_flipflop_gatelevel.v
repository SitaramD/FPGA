// To write the code for the D flip flop using gate level modeling
// A D flip-flop is a fundamental digital memory circuit that captures the value of the Data (D) input at a specific edge of a clock signal and holds it at the output (Q).
// If D = 0, the next state \(Q_{next} = 0\)
// If D = 1, the next state \(Q_{next} = 1\)       
     
module dff_gate (
    input d,
    input clk,
    output q,
    output qb
);

    wire nd;
    wire s1, r1;
    wire qm, qmb;
    wire s2, r2;

    not  G1(nd, d);

    // Master latch
    nand G2(s1, d, ~clk);
    nand G3(r1, nd, ~clk);
    nand G4(qm, s1, qmb);
    nand G5(qmb, r1, qm);

    // Slave latch
    nand G6(s2, qm, clk);
    nand G7(r2, qmb, clk);
    nand G8(q, s2, qb);
    nand G9(qb, r2, q);

endmodule

module tb_dff;   

    reg d, clk; 
    wire q, qb;

    dff_gate DUT (
        .d(d),
        .clk(clk),
        .q(q),
        .qb(qb)
    );

    initial begin
        clk = 0;
        d   = 0;

        #10 d = 1;
        #10 d = 0;
        #10 d = 1;
        #20 $finish;
    end

    always #5 clk = ~clk;

endmodule

