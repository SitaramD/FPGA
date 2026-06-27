// To work on $ display, $time, $ strobe, $ 


module print_statements();

      initial begin
      $display(" sitaram");
      #10; // 10 nanosecond delay
      $monitor(" sitaram");
      #20; // 10 nanosecond delay
      $strobe("sitaram"); 
      end

endmodule 