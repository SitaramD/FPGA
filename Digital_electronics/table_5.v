// To write 5 table upto 10000


module table5();
      integer a =5;
      integer m;
      integer i;
      initial begin      
      
      for (i=0;i<=10000; i= i +1)
      begin     
      m = a*i;
      $display(" %0d X %0d = %0d", a,i,m);
      #10; // add a time delay of 10 nanoseconds
      end    
      end
endmodule
