// To write a D flip flop

module dflipflop(D,clk, q, qbar);

   input D,clk;
   output q,qbar;

   wire w1, w2, w3;    

   nand g1(w2,D,clk);
   not g2(w1,D); 
   nand g4(q,w2,qbar);
   nand g5(qbar,q,w3);   

    //if(D==1)
    //q <= D;
    //else
    //q=D;
 
endmodule 