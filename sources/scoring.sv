`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

module scoring #(parameter THRESHOLD = 15)
   (input wire clk,
    input wire reset,
    input wire [11:0] pixel,
    input wire counting,
    input wire update,
    output logic [31:0] out //for 8 hex display
    );

    logic [6:0] points;
    logic [1:0] state;
    logic [3:0] count; //how many pixels should count as 1 point (somewhat arbitrary for now)
//    logic add_score;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            out <= 0;
            points <= 0;
            state <= 0;
            count <= 0;
        end else begin
            case (state)
                0: begin //counting
                    if (counting && pixel != 12'h000 && pixel != 12'h0F0 && pixel != 12'hFFF) count <= count + 1;
                                     //not purely black, green, or white means overlap which means points
                    if (update) state <= 2;
                    else if (count == THRESHOLD - 1) state <= 1;
                end
                1: begin
                    points <= points + 1;
                    count <= 0;
                    if (update) begin
                        state <= 2;
                    end else state <= 0;
                end
                2: begin 
                    out <= out + points;
                    points <= 0;
                    state <= 0;
                end 
            endcase
        end
    end

endmodule
`default_nettype wire