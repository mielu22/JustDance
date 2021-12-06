`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////

module buffer_tb;

   // Inputs
   logic clk;
   logic reset;
   logic [16:0] read_addr;
   logic pixel_in;

   // Outputs
   logic pixel_out;

   // Instantiate the Unit Under Test (UUT)
   interlaced_buffer uut (
      .clk(clk), 
      .reset(reset), 
      .read_addr(read_addr),
      .pixel_in(pixel_in),
      .pixel_out(pixel_out)
   );
   
   //extras
   logic [16:0] input_addr;
   logic read_ready;

   always #5 clk = !clk;
   
   initial begin
      // Initialize Inputs
      clk = 0;
      reset = 1;
      // Wait 100 ns for global reset to finish
      #100;
      reset = 0;
      $display("BEGIN SIMULATION");
              
      // Add stimulus here
      if (read_addr == 76799) $display("read through a frame");
   end
   
   always_ff @ (posedge clk) begin
      if (reset) begin
        input_addr <= 0;
        read_ready <= 0;
        read_addr <= 0;
      end else begin
        input_addr <= (input_addr < 76799) ? input_addr + 1 : 0;
        pixel_in <= (input_addr < 38400) ? 0 : 1;
        
        if (input_addr > 25600) read_ready <= 1;
        if (read_ready) read_addr <= (read_addr < 76799) ? read_addr + 1 : 0;

        /*
        if (input_addr < 38400) begin
            pixel_in <= 0;
        end else 
            pixel_in <= 1;
        end
        
        if (read_ready) begin
            read_addr <= (read_addr < 76799) ? read_addr + 1 : 0;
            if (read_addr >= 5 && read_addr < 25606) begin
                assert(pixel_out == 24'hFF0000) else $display("missed the 1st bar");
            end else if (read_addr < 51206) begin
                assert(pixel_out == 24'h00FF00) else $display("missed the 2nd bar");
            end else begin
                assert(pixel_out == 24'h0000FF) else $display("missed the 3rd bar");
            end
        end
        */
      end
   end
      
endmodule