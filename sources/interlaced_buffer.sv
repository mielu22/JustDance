`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

module interlaced_buffer(
    input wire clk,
    input wire data_in,
    output logic [7:0] data_out
    );

    assign data_out = 8'b0;

endmodule
`default_nettype wire