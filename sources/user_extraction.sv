`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/23/2021 02:16:35 AM
// Design Name: 
// Module Name: user_extraction
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module user_extraction (input clk,
    input wire [15:0] pixel_in, // pixel that comes in, in rgb
    input wire [10:0] hcount,
    input wire [9:0] vcount,

    output logic pixel_out
);
    logic [23:0] pixel; // pixel that goes in module
    logic thresh_out; // bit leaving hue thresholding
    logic thresh_valid;
    logic [7:0] hue; //hsv
    logic [7:0] sat;
    logic [7:0] val;
    logic is_valid;
    logic frame_over;

    assign pixel = {pixel_in[11:8], 4'b0, pixel_in[7:4], 4'b0, pixel_in[3:0], 4'b0};

    rgb2hsv converter(.clock(clk), .reset(0), .r(pixel[23:16]), .g(pixel[15:8]), .b(pixel[7:0]), .h(hue), .s(sat),
    .v(val), .hue_valid(is_valid));
    
    hue_thresholding thresh(.clk(clk), .hue_val(hue), .isValid(is_valid),
    .thresh_bit(thresh_out), .valid(thresh_valid));
    
    always_ff @(posedge clk) begin
        pixel <= pixel_in;
        if (hcount == 11'd319 && vcount == 10'd239) frame_over <= 1;
        else frame_over <= 0;
    
        pixel_out <= thresh_out;
    end
endmodule

module hue_thresholding (input clk,
    input wire [7:0] hue_val,
    input wire isValid,
    output logic thresh_bit,
    output logic valid
);
    always_ff @(posedge clk) begin
        if (isValid) begin
            if (hue_val < 8'd63 || hue_val > 8'd211) begin // not green
               thresh_bit <= 0;
               valid <= 1; 
            end else begin // green, so thresh bit is 1
               thresh_bit <= 1;
               valid <= 1; 
            end
        end else valid <= 0;
    end
endmodule