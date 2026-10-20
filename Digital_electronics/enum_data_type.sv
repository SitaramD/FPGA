// To work on enum data type in System verilog 

/*
module enum_data();

        initial begin

                   enum { IDLE,RUN,STOP} state_1;
                   state_1 = RUN;
                   $display("  ", state_1);

        end

endmodule
*/
// To work on struct datatype

module struct_header();

      initial begin
      struct {

                       string descriptor;
                       int price;
                       int quantity;
      
              } message_header;
       message_header.descriptor = "RELIANCE";

       $display("   ", message_header.descriptor);


      end

endmodule 