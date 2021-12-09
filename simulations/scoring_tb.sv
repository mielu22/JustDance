`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////

module scoring_tb;

   logic [5:0] tally; // up to 63
   logic [4:0] rounds;


   // Inputs
   logic clk;
   logic reset;
   logic [11:0] pixel;
   logic counting;
   logic update;

   // Outputs
   logic [31:0] out;

   // Instantiate the Unit Under Test (UUT)
   scoring #(.THRESHOLD(3)) uut
              (.clk(clk),
               .reset(reset),
               .pixel(pixel),
               .counting(counting),
               .update(update),
               .out(out));

   always #5 clk = !clk;
   
   initial begin
      // Initialize Inputs
      clk = 0;
      reset = 0;
      #5
      reset = 1;

      // Wait 100 ns for global reset to finish
      #100;
      reset = 0;
        
      // Add stimulus here
   end
   
   
   always @(posedge clk) begin
      if (reset) begin
          tally <= 0;
          rounds <= 0;
      end else begin
          tally <= tally + 1;
          counting <= (rounds % 4 == 3) ? 1 : 0;
          case (tally)
            0: begin
                pixel <= 12'h000;
                update <= 0;
            end
            1: begin
                pixel <= 12'h0F0;
            end
            8: begin
                pixel <= 12'h000;
            end
            15: begin
                pixel <= 12'h0F0;
            end
            //should be counted as overlaps
            60: begin
                pixel <= 12'hFF0;
            end
            61: begin
                pixel <= 12'hFF1;
            end
            62: begin
                pixel <= 12'h8F0;
            end
            63: begin
                pixel <= 12'h040;
                rounds <= rounds + 1;
                update <= (counting) ? 1 : 0;
            end
            default: begin
                pixel <= 12'hFFF;
            end
          endcase
      end 
   end
      
endmodule