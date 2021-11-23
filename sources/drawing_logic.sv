`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/23/2021 08:38:44 AM
// Design Name: 
// Module Name: drawing_logic
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

module drawing_logic(
    input wire clk_in,
    input wire [2:0] alpha_in,
    input wire [11:0] truth_image,
    input wire [23:0] user_extraction,
    input wire [10:0] hcount_in, // horizontal index of current pixel  
    input wire [9:0]  vcount_in, // vertical index of current pixel
    output logic [11:0] pixel_out 
);  

    logic [9:0] truth_y = 200;
    logic [11:0] truth_x = 200;
    logic [11:0] truth_pixel;
    
    logic [11:0] blended_image;
//    logic [11:0] resized_truth_image;
    logic [11:0] recolored_user_image;
    
    // truth image        
    picture_blob #(.WIDTH(320), .HEIGHT(240)) 
        truth_picture (.pixel_clk_in(clk_in), .x_in(truth_x), .y_in(truth_y), .hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(truth_pixel));

// rescaler module not currently being used
//    rescaler resize_truth(.input_img(truth_image), .output_img(resized_truth_image));
    recolor user_recolor (.clk(clk_in), .isUser(1), .input_img(user_extraction), .output_img(recolored_user_image));
    alpha_blending merged_image (.image_1(truth_pixel), .image_2(recolored_user_image), .blend_factor(alpha_in), .blended(blended_image));
//    alpha_blending merged_image (.image_1(resized_truth_image), .image_2(recolored_user_image), .blend_factor(alpha_in), .blended(blended_image));

    assign pixel_out = blended_image; 

endmodule // drawing logic


///////////////////////////////////////////////////////////////////////////////////
//
// recolor
//
///////////////////////////////////////////////////////////////////////////////////
module recolor(
    input wire clk,
    input wire input_pixel,
    input wire isUser,
    output logic [11:0] output_pixel
);

    logic [11:0] temp;

    always_ff @(posedge clk) begin
        if (input_pixel === 1) begin
            if (isUser) begin // convert to rgb green
                temp[3:0] <= 4'b0; // red to 0
                temp[7:4] <= 4'b1111; // green to max value
                temp[11:8] <= 4'b0; // blue to 0
                output_pixel <= temp;
            end else begin // make pixel rgb for white
                output_pixel <= 12'b1111_1111_1111;
            end
        end else begin
            output_pixel <= 12'b0;
        end
    end

endmodule // recolor



///////////////////////////////////////////////////////////////////////////////////
//
// rescaler
//
///////////////////////////////////////////////////////////////////////////////////

module rescaler(
    input wire clk,
    input wire start,
    
    input wire [5:0] x1, y1, // top-left
    input wire [5:0] x2, y2, // bottom right
    
    // Goes to big frame buffer
    input wire [11:0] img_read_data_in,
    output logic [18:0] img_read_addr_out,
    
    output logic [11:0] img_write_data_out,
    output logic [14:0] img_write_addr_out,
    output logic we_out,
    output logic done
);
    
    // States
    
    parameter IDLE = 0;
    parameter DIV_X_START = 1;
    parameter DIV_X_END = 2;
    parameter DIV_Y_START = 3;
    parameter DIV_Y_END = 4;
    parameter RESCALING = 5;
    
    reg[3:0] state = 0;

    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 480;
    
    // Actual parameters 
    parameter IMWIDTH = 80;
    parameter IMHEIGHT = 60;
    
    parameter TARGETWIDTH = 'd320;
    parameter TARGETHEIGHT = 'd240;
    
    // Divider variables
    reg div_start = 0;
    wire div_ready;
    
    wire [9:0] quotient, remainder;
    
    reg[9:0] dividend = 0;
    
    // Quotient, remainder for x
    reg[9:0] q_x = 0;
    reg[9:0] r_x = 0;
    
    // Quotient, remainder for y
    reg[9:0] q_y = 0;
    reg[9:0] r_y = 0;
    
    // Accumulators
    reg[9:0] accl_x = 0;
    reg[9:0] accl_y = 0;
    wire[9:0] accl_x_temp;
    wire[9:0] accl_y_temp;
    
    // Screen positions
    reg[9:0] hcount, vcount;
    
    // Memory mapping stuff
    wire[18:0] read_addr = hcount + SCREEN_WIDTH * vcount;   
    assign img_read_addr_out = read_addr;
    
    divider #(.WIDTH(10)) divider_1 (
        .clk(clk),
        .sign(1'b0), // always positive
        .start(div_start),
        .dividend(dividend),
        .divisor(TARGETWIDTH - 1),
        .quotient(quotient),
        .remainder(remainder),
        .ready(div_ready));
        
    wire[14:0] write_addr;
    reg rescale_start = 0;
    wire rescale_done;
    
    frame_transfer #(.TARGET(TARGETWIDTH)) frame_transfer_1 (
        .clk(clk),
        .read_addr(read_addr),
        .read_data(img_read_data_in),
        .write_addr_out(img_write_addr_out),
        .write_data_out(img_write_data_out),
        .we_out(we_out),
        .start(rescale_start),
        .done(rescale_done));
    
    always @(posedge clk) begin
        case(state)
            IDLE: begin
                if(start) begin
                    state <= DIV_X_START;
                end
            end
            DIV_X_START: begin
                // Load variables we want to divide
                dividend <= x2 - x1;
                div_start <= 1;
                state <= DIV_X_END;
            end
            DIV_X_END: begin
                if(div_ready) begin
                    q_x <= quotient;
                    r_x <= remainder;
                    state <= DIV_Y_START;
                end
            end
            DIV_Y_START: begin
                dividend <= y2 - y1;
                div_start <= 1;
                state <= DIV_Y_END;
            end
            DIV_Y_END: begin
                if(div_ready) begin
                    q_y <= quotient;
                    r_y <= remainder;
                    state <= RESCALING;
                    // Prepare for rescaling...
                    hcount <= x1;
                    vcount <= y1;
                    
                    rescale_start <= 1;
                end
            end
            RESCALING: begin
                // Memory address mapping stuff...
                // Basically a while loop here 
                accl_x = accl_x + r_x;
                
                if(hcount < (x2 - q_x)) begin
                    if(accl_x >= TARGETWIDTH) begin
                        hcount <= hcount + q_x + 1;
                        accl_x <= accl_x - TARGETWIDTH;
                    end else begin
                        hcount <= hcount + q_x;
                    end
                end else if (vcount < (y2 - q_y)) begin
                    hcount <= x1;
                    accl_x <= 0;
                    accl_y = accl_y + r_y;
    
                    if(accl_y >= TARGETHEIGHT) begin
                        vcount <= vcount + q_y + 1;
                        accl_y <= accl_y - TARGETHEIGHT;
                    end else begin
                        vcount <= vcount + q_y;
                    end
                end else if (rescale_done) begin
                    state <= IDLE;
                end          
            end
        endcase
        
        // Reset start signals
        if(div_start) div_start <= 0;
        if(rescale_start) rescale_start <= 0;
    end
    
    assign done = (state == 0);
    
endmodule // rescaler


///////////////////////////////////////////////////////////////////////////////////
//
// alpha blending
//
///////////////////////////////////////////////////////////////////////////////////

module alpha_blending (
    input wire [11:0] image_1,
    input wire [11:0] image_2, 
    input wire [2:0] blend_factor,
    output logic [11:0] blended 
);

    logic [2:0] m = blend_factor;
    logic [2:0] n = 3'b100 - blend_factor;
    logic [7:0] temp_val_1;
    logic [7:0] temp_val_2;
    logic [7:0] temp_val_3;
    logic [12:0] temp;
    
    always_comb begin
        temp_val_1 = ((image_1[11:8] * m) >> 2) + ((image_2[11:8] * n) >> 2);
        temp[11:8] = temp_val_1[3:0];
        temp_val_2 = ((image_1[7:4] * m) >> 2) + ((image_2[7:4] * n) >> 2);
        temp[7:4] = temp_val_2[3:0];
        temp_val_3 = ((image_1[3:0] * m) >> 2) + ((image_2[3:0] * n) >> 2);
        temp[3:0] = temp_val_3[3:0];
        
        if (image_1 && image_2) begin
            blended = temp;
        end else begin
            blended = image_1 | image_2;
        end
    end

endmodule //alpha blending

////////////////////////////////////////////////////
//
// picture_blob: display a picture
//
//////////////////////////////////////////////////
module picture_blob
   #(parameter WIDTH = 256,     // default picture width
               HEIGHT = 240)    // default picture height
   (input wire pixel_clk_in,
    input wire [10:0] x_in,hcount_in,
    input wire [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [15:0] image_addr;   // num of bits for 320*240 ROM
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;

   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   image_rom  rom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   color_map_coe rcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   //green_coe gcm (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   //blue_coe bcm (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always_ff @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
        pixel_out <= {red_mapped[7:4], red_mapped[7:4], red_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 0;
   end
endmodule

`default_nettype wire
