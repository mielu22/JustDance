`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Kevin Zheng Class of 2012 
//           Dept of Electrical Engineering &  Computer Science
// 
// Create Date:    18:45:01 11/10/2010 
// Design Name: 
// Module Name:    rgb2hsv 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module rgb2hsv(clock, reset, r, g, b, h, s, v, hue_valid);
        input wire clock;
        input wire reset;
        input wire [7:0] r;
        input wire [7:0] g;
        input wire [7:0] b;
        output reg [7:0] h;
        output reg [7:0] s;
        output reg [7:0] v;
        output reg hue_valid;
        reg [7:0] my_r_delay1, my_g_delay1, my_b_delay1;
        reg [7:0] my_r_delay2, my_g_delay2, my_b_delay2;
        reg [7:0] my_r, my_g, my_b;
        reg [7:0] min, max, delta;
        reg [15:0] s_top;
        reg [15:0] s_bottom;
        reg [15:0] h_top;
        reg [15:0] h_bottom;
        wire [15:0] s_quotient;
        wire [15:0] s_remainder;
        wire s_rfd;
        wire [15:0] h_quotient;
        wire [15:0] h_remainder;
        wire h_rfd;
        reg [7:0] v_delay [19:0];
        reg [18:0] h_negative;
        reg [15:0] h_add [18:0];
        reg [4:0] i;
        // Clocks 4-18: perform all the divisions
        //the s_divider (16/16) has delay 18
        //the hue_div (16/16) has delay 18

        divider hue_div1(
        .clk(clock),
        .dividend(s_top),
        .divisor(s_bottom),
        .quotient(s_quotient),
            // note: the "fractional" output was originally named "remainder" in this
        // file -- it seems coregen will name this output "fractional" even if
        // you didn't select the remainder type as fractional.
        .fractional(s_remainder),
        .rfd(s_rfd)
        );
        divider hue_div2(
        .clk(clock),
        .dividend(h_top),
        .divisor(h_bottom),
        .quotient(h_quotient),
        .fractional(h_remainder),
        .rfd(h_rfd)
        );
        always @ (posedge clock) begin
        
            // Clock 1: latch the inputs (always positive)
            {my_r, my_g, my_b} <= {r, g, b};
            
            // Clock 2: compute min, max
            {my_r_delay1, my_g_delay1, my_b_delay1} <= {my_r, my_g, my_b};
            
            if((my_r >= my_g) && (my_r >= my_b)) //(B,S,S)
                max <= my_r;
            else if((my_g >= my_r) && (my_g >= my_b)) //(S,B,S)
                max <= my_g;
            else    max <= my_b;
            
            if((my_r <= my_g) && (my_r <= my_b)) //(S,B,B)
                min <= my_r;
            else if((my_g <= my_r) && (my_g <= my_b)) //(B,S,B)
                min <= my_g;
            else
                min <= my_b;
                
            // Clock 3: compute the delta
            {my_r_delay2, my_g_delay2, my_b_delay2} <= {my_r_delay1, my_g_delay1, my_b_delay1};
            v_delay[0] <= max;
            delta <= max - min;
            
            // Clock 4: compute the top and bottom of whatever divisions we need to do
            s_top <= 8'd255 * delta;
            s_bottom <= (v_delay[0]>0)?{8'd0, v_delay[0]}: 16'd1;
            
            
            if(my_r_delay2 == v_delay[0]) begin
                h_top <= (my_g_delay2 >= my_b_delay2)?(my_g_delay2 - my_b_delay2) * 8'd255:(my_b_delay2 - my_g_delay2) * 8'd255;
                h_negative[0] <= (my_g_delay2 >= my_b_delay2)?0:1;
                h_add[0] <= 16'd0;
            end 
            else if(my_g_delay2 == v_delay[0]) begin
                h_top <= (my_b_delay2 >= my_r_delay2)?(my_b_delay2 - my_r_delay2) * 8'd255:(my_r_delay2 - my_b_delay2) * 8'd255;
                h_negative[0] <= (my_b_delay2 >= my_r_delay2)?0:1;
                h_add[0] <= 16'd85;
            end 
            else if(my_b_delay2 == v_delay[0]) begin
                h_top <= (my_r_delay2 >= my_g_delay2)?(my_r_delay2 - my_g_delay2) * 8'd255:(my_g_delay2 - my_r_delay2) * 8'd255;
                h_negative[0] <= (my_r_delay2 >= my_g_delay2)?0:1;
                h_add[0] <= 16'd170;
            end
            
            h_bottom <= (delta > 0)?delta * 8'd6:16'd6;
        
            
            //delay the v and h_negative signals 18 times
            for(i=1; i<19; i=i+1) begin
                v_delay[i] <= v_delay[i-1];
                h_negative[i] <= h_negative[i-1];
                h_add[i] <= h_add[i-1];
            end
        
            v_delay[19] <= v_delay[18];
            //Clock 22: compute the final value of h
            //depending on the value of h_delay[18], we need to subtract 255 from it to make it come back around the circle
            if(h_negative[18] && (h_quotient > h_add[18])) begin
                h <= 8'd255 - h_quotient[7:0] + h_add[18];
                hue_valid <= 1;
            end 
            else if(h_negative[18]) begin
                h <= h_add[18] - h_quotient[7:0];
                hue_valid <= 1;
            end 
            else if (h_quotient > h_add[18]) begin //I have no idea about this but there was a syntax error before, so consider this a placeholder
                h <= h_quotient[7:0] + h_add[18];
                hue_valid <= 1;
            end else hue_valid <= 0;
            
            //pass out s and v straight
            s <= s_quotient;
            v <= v_delay[19];
        end
endmodule


// The divider module divides one number by another. It
// produces a signal named "ready" when the quotient output
// is ready, and takes a signal named "start" to indicate
// the the input dividend and divider is ready.
// sign -- 0 for unsigned, 1 for twos complement
// It uses a simple restoring divide algorithm.
// http://en.wikipedia.org/wiki/Division_(digital)#Restoring_division
//
// Author Logan Williams, updated 11/25/2018 gph

module divider #(parameter WIDTH = 8)
    (input clk, sign, start,
    input [WIDTH-1:0] dividend,
    input [WIDTH-1:0] divider,
    output reg [WIDTH-1:0] quotient,
    output [WIDTH-1:0] remainder,
    output ready
    );
    reg [WIDTH-1:0] quotient_temp;
    reg [WIDTH*2-1:0] dividend_copy, divider_copy, diff;
    reg negative_output;
    assign remainder = (!negative_output) ?
    dividend_copy[WIDTH-1:0] : ~dividend_copy[WIDTH-1:0] + 1'b1;
    reg [5:0] a_bit = 0;
    reg del_ready = 1;
    assign ready = (a_bit==0) & ~del_ready;
    wire [WIDTH-2:0] zeros = 0;
    initial a_bit = 0;
    initial negative_output = 0;
    
    always @( posedge clk ) begin
        del_ready <= (a_bit==0);
        if( start ) begin
            a_bit = WIDTH;
            quotient = 0;
            quotient_temp = 0;
            dividend_copy = (!sign || !dividend[WIDTH-1]) ?
            {1'b0,zeros,dividend} :
            {1'b0,zeros,~dividend + 1'b1};
            divider_copy = (!sign || !divider[WIDTH-1]) ?
            {1'b0,divider,zeros} :
            {1'b0,~divider + 1'b1,zeros};
            negative_output = sign &&
            ((divider[WIDTH-1] && !dividend[WIDTH-1])
            ||(!divider[WIDTH-1] && dividend[WIDTH-1]));
        end
        else if ( a_bit > 0 ) begin
            diff = dividend_copy - divider_copy;
            quotient_temp = quotient_temp << 1;
            if( !diff[WIDTH*2-1] ) begin
                dividend_copy = diff;
                quotient_temp[0] = 1'd1;
            end
            quotient = (!negative_output) ?
            quotient_temp :
            ~quotient_temp + 1'b1;
            divider_copy = divider_copy >> 1;
            a_bit = a_bit - 1'b1;
        end
    end
endmodule