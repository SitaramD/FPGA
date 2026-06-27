// Code your testbench here
// or browse Examples

// Code your testbench here
// or browse Examples

 module test();
   integer data;
    integer a,b;
  
   function integer sum(input [4:0] a,b);
     sum=a+b;
     sum1();// task inside function
         $display($time,"Function sum=%0d A=%0d B=%0d ",sum,a,b);
   endfunction
  
    task  sum1();
      integer a,b,sum1;
    //   #2;
        a=4;
        b=9;
     sum1=a+b;
      $display("TASK sum1=%0d A=%0d B=%0d ",sum1,a,b);
      sum(a,b);// function inside task
    endtask

   initial
     begin
       integer x,y;
       x=7;
       y=10;
    
       sum(x,y);//fun
       sum1();// task
      
     end
 endmodule