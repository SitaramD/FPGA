//* One gate in three modelling styles
//Topics: structural, data flow and behavioral modelling
//Build a 2 input XOR three ways in one file:
//?	xor_struct: using the xor gate primitive
//?	xor_df: using assign
//?	xor_beh: using always_comb with if-else
//Write one testbench that drives all four input combinations into all three and prints a MISMATCH message if any of their outputs differ.
/*
// dataflow modeling
module XOR_dataflow();

    initial begin

    reg a,b,q;
    assign q= a ^ b; // xor operation dataflow modelling
    $display("", q);
    $display("sitaram");   
    end


endmodule
*/
// xor using structural modeling

module struct_XOR();
      
     int a,b,q;
     initial begin
          output wire q;
          input wire a,b;
          xor XOR_inst (q,a,b); // output followed by input variables
          $display("Print XOR", q);
     end

endmodule