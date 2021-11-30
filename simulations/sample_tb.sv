`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////

module buffer_tb;

   // Inputs
   logic clk;
   logic reset;
   logic [16:0] read_addr;
   logic [23:0] pixel_in;

   // Outputs
   logic [23:0] pixel_out;

   // Instantiate the Unit Under Test (UUT)
   interlaced_buffer uut (
      .clk(clk), 
      .reset(reset), 
      .read_addr(read_addr),
      .pixel_in(pixel_in),
      .pixel_out(pixel_out)
   );

   always #5 clk = !clk;
   
   initial begin
      // Initialize Inputs
      clk = 0;
      reset = 0;
      #5
      reset = 1;

      // Wait 100 ns for global reset to finish
      #100;
        
      // Add stimulus here

   end
      
endmodule