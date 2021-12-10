`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Updated 8/10/2019 Lab 3
// Updated 8/12/2018 V2.lab5c
// Create Date: 10/1/2015 V1.0
// Design Name:
// Module Name: labkit
//
//////////////////////////////////////////////////////////////////////////////////

module top_level(
   input clk_100mhz,
   input[15:0] sw,
   input btnc, btnu, btnl, btnr, btnd,
   input [7:0] ja, //pixel data from camera
   input [2:0] jb, //other data from camera (including clock return)
   output   jbclk, //clock FPGA drives the camera with
   input [2:0] jd,
   output   jdclk,
   output[3:0] vga_r,
   output[3:0] vga_b,
   output[3:0] vga_g,
   output vga_hs,
   output vga_vs,
   output led16_b, led16_g, led16_r,
   output led17_b, led17_g, led17_r,
   output[15:0] led,
   output ca, cb, cc, cd, ce, cf, cg, dp,  // segments a-g, dp
   output[7:0] an    // Display location 0-7
   );
    logic clk_65mhz;
    // create 65mhz system clock, happens to match 1024 x 768 XVGA timing
    clk_wiz_lab3 clkdivider(.clk_in1(clk_100mhz), .clk_out1(clk_65mhz));

    wire [31:0] data;      //  instantiate 7-segment display; display (8) 4-bit hex
    wire [6:0] segments;
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    display_8hex display(.clk_in(clk_65mhz),.data_in({10'b0, data[31:10]}), .seg_out(segments), .strobe_out(an));
    //assign seg[6:0] = segments;
    assign  dp = 1'b1;  // turn off the period

    assign led = sw;                        // turn leds on
//    assign data = {28'h0123456, sw[3:0]};   // display 0123456 + sw[3:0]
    assign led16_r = btnl;                  // left button -> red led
    assign led16_g = btnc;                  // center button -> green led
    assign led16_b = btnr;                  // right button -> blue led
    assign led17_r = btnl;
    assign led17_g = btnc;
    assign led17_b = btnr;

    wire [10:0] hcount;    // pixel on current line
    wire [9:0] vcount;     // line number
    wire hsync, vsync, blank;
    wire [11:0] pixel;
    reg [11:0] rgb;    
    xvga xvga1(.vclock_in(clk_65mhz),.hcount_out(hcount),.vcount_out(vcount),
          .hsync_out(hsync),.vsync_out(vsync),.blank_out(blank));


    // btnc button is user reset
    wire reset;
    debounce db1(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnc),.clean_out(reset));
   
   
    logic xclk;
    logic[1:0] xclk_count;
    
    logic pclk_buff, pclk_in;
    logic vsync_buff, vsync_in;
    logic href_buff, href_in;
    logic[7:0] pixel_buff, pixel_in;
    
    logic [11:0] cam;
    logic [11:0] end_image_scaled;
    logic [11:0] frame_buff_out;
    logic [11:0] end_image;
    logic [15:0] output_pixels;
    logic [15:0] old_output_pixels;
    logic [12:0] processed_pixels;
    logic [3:0] red_diff;
    logic [3:0] green_diff;
    logic [3:0] blue_diff;
    logic valid_pixel;
    logic frame_done_out;
    
    logic [16:0] pixel_addr_in;
    logic [16:0] pixel_addr_out;
    
    assign xclk = (xclk_count >2'b01);
    assign jbclk = xclk;
    assign jdclk = xclk;
    
    assign red_diff = (output_pixels[15:12]>old_output_pixels[15:12])?output_pixels[15:12]-old_output_pixels[15:12]:old_output_pixels[15:12]-output_pixels[15:12];
    assign green_diff = (output_pixels[10:7]>old_output_pixels[10:7])?output_pixels[10:7]-old_output_pixels[10:7]:old_output_pixels[10:7]-output_pixels[10:7];
    assign blue_diff = (output_pixels[4:1]>old_output_pixels[4:1])?output_pixels[4:1]-old_output_pixels[4:1]:old_output_pixels[4:1]-output_pixels[4:1];

    
    
    blk_mem_gen_0 jojos_bram(.addra(pixel_addr_in), 
                             .clka(pclk_in),
                             .dina(processed_pixels),
                             .wea(valid_pixel),
                             .addrb(pixel_addr_out),
                             .clkb(clk_65mhz),
                             .doutb(frame_buff_out));
                             
   drawing_logic art(.clk_in(pclk_in),.alpha_in(3'b101),.user_extraction(cam),.hcount_in(hcount),.vcount_in(vcount),.pixel_out(end_image));

    // ~ RELEVANT TO SCORING ~
    logic counting;
    logic update;
    logic [31:0] old_score;
    logic [4:0] frames; //30 fps
    scoring #(.THRESHOLD(30)) total(.clk(pclk_in),.reset(reset || ~sw[0] || ~sw[5]),.pixel(end_image),.counting(1),.update(1),.out(data));
//    scoring #(.THRESHOLD(30)) total(.clk(pclk_in),.reset(reset || ~sw[0] || ~sw[5]),.pixel(end_image),.counting(counting),.update(update),.out(data));
    
    always_ff @(posedge pclk_in)begin
        if (reset || ~sw[0] || ~sw[5]) begin
            counting <= 0;
            update <= 0;
            frames <= 0;
        end else if (hcount + vcount*320 == 76799) begin
            frames <= frames + 1;
            update <= (frames == 5'b11111) ? 1 : 0;
        end else if (hcount + vcount*320 > 76799) begin
            update <= 0;
            if (data != old_score) begin
                old_score <= data;
                counting <= 0;
            end
        end else begin
            counting <= (frames == 5'b11111) ? 1 : 0; //only scoring last frame
            update <= 0;
        end
    end
    
 // ~ RELEVANT TO SCORING ~
 
    
    always_ff @(posedge pclk_in)begin
        if (frame_done_out)begin
            pixel_addr_in <= 17'b0;  
        end else if (valid_pixel)begin
            pixel_addr_in <= pixel_addr_in +1;  
        end
    end
    
    always_ff @(posedge clk_65mhz) begin
        pclk_buff <= jb[0];//WAS JB
        vsync_buff <= jb[1]; //WAS JB
        href_buff <= jb[2]; //WAS JB
        pixel_buff <= ja;
        pclk_in <= pclk_buff;
        vsync_in <= vsync_buff;
        href_in <= href_buff;
        pixel_in <= pixel_buff;
        old_output_pixels <= output_pixels;
        xclk_count <= xclk_count + 2'b01;

        if (sw[5]) begin
            if ((output_pixels[15:12]<4'b1000)&&(output_pixels[10:7]>4'b1000)&&(output_pixels[4:1]<4'b1000))begin
                processed_pixels <= 12'h000;
            end else begin
                processed_pixels <= 12'h0F0;
            end
        end else begin
            processed_pixels = {output_pixels[15:12],output_pixels[10:7],output_pixels[4:1]};
        end
            
    end
    
    assign pixel_addr_out = sw[2]?((hcount>>1)+(vcount>>1)*32'd320):hcount+vcount*32'd320;
    assign cam = sw[2]&&((hcount<640)&&(vcount<480))?frame_buff_out:~sw[2]&&((hcount<320)&&(vcount<240))?frame_buff_out:12'h000;
//    assign end_image_scaled = sw[2]&&((hcount<640)&&(vcount<480))?end_image:~sw[2]&&((hcount<320)&&(vcount<240))?end_image:12'h000;

    
    ila_0 joes_ila(.clk(clk_65mhz),    .probe0(end_image), 
                                        .probe1(counting), 
                                        .probe2(update),
                                        .probe3(frames),
                                        .probe4(data));

                                        
   camera_read  my_camera(.p_clock_in(pclk_in),
                          .vsync_in(vsync_in),
                          .href_in(href_in),
                          .p_data_in(pixel_in),
                          .pixel_data_out(output_pixels),
                          .pixel_valid_out(valid_pixel),
                          .frame_done_out(frame_done_out));
   
    // UP and DOWN buttons for pong paddle
    wire up,down;
    debounce db2(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnu),.clean_out(up));
    debounce db3(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnd),.clean_out(down));

    wire phsync,pvsync,pblank;
    pong_game pg(.vclock_in(clk_65mhz),.reset_in(reset),
                .up_in(up),.down_in(down),.pspeed_in(sw[15:12]),
                .hcount_in(hcount),.vcount_in(vcount),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank),
                .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(pixel));

    wire border = (hcount==0 | hcount==1023 | vcount==0 | vcount==767 |
                   hcount == 512 | vcount == 384);

    reg b,hs,vs;
    always_ff @(posedge clk_65mhz) begin
      if (sw[0] == 1'b1) begin
         // 1 pixel outline of visible area (white)
         hs <= hsync;
         vs <= vsync;
         b <= blank;
//         rgb <= end_image_scaled;
         rgb <= end_image;
      end else begin
         // default: pong
         hs <= phsync;
         vs <= pvsync;
         b <= pblank;
         rgb <= cam;
      end
    end

//    assign rgb = sw[0] ? {12{border}} : pixel ; //{{4{hcount[7]}}, {4{hcount[6]}}, {4{hcount[5]}}};

    // the following lines are required for the Nexys4 VGA circuit - do not change
    assign vga_r = ~b ? rgb[11:8]: 0;
    assign vga_g = ~b ? rgb[7:4] : 0;
    assign vga_b = ~b ? rgb[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs;

endmodule

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
//    input wire [11:0] truth_image,
    input wire [11:0] user_extraction,
    input wire [10:0] hcount_in, // horizontal index of current pixel  
    input wire [9:0]  vcount_in, // vertical index of current pixel
    output logic [11:0] pixel_out 
);  

    logic [9:0] truth_y = 10;
    logic [11:0] truth_x = 0;
    logic [11:0] truth_pixel;
    
    logic [11:0] blended_image;
    logic [11:0] recolored_user_image;
    
    // truth image        
    picture_blob #(.WIDTH(320), .HEIGHT(240)) 
        truth_picture (.pixel_clk_in(clk_in), .x_in(truth_x), .y_in(truth_y), .hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(truth_pixel));

    alpha_blending merged_image (.image_1(truth_pixel), .image_2(user_extraction), .blend_factor(alpha_in), .blended(blended_image));
    assign pixel_out = blended_image; 

endmodule // drawing logic

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
   #(parameter WIDTH = 320,     // default picture width
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
//   walk_image_rom  walkrom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));


   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
//   walk_color_map wcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
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


////////////////////////////////////////////////////////////////////////////////
//
// pong_game: the game itself!
//
////////////////////////////////////////////////////////////////////////////////

module pong_game (
   input vclock_in,        // 65MHz clock
   input reset_in,         // 1 to initialize module
   input up_in,            // 1 when paddle should move up
   input down_in,          // 1 when paddle should move down
   input [3:0] pspeed_in,  // puck speed in pixels/tick 
   input [10:0] hcount_in, // horizontal index of current pixel (0..1023)
   input [9:0]  vcount_in, // vertical index of current pixel (0..767)
   input hsync_in,         // XVGA horizontal sync signal (active low)
   input vsync_in,         // XVGA vertical sync signal (active low)
   input blank_in,         // XVGA blanking (1 means output black pixel)
        
   output phsync_out,       // pong game's horizontal sync
   output pvsync_out,       // pong game's vertical sync
   output pblank_out,       // pong game's blanking
   output [11:0] pixel_out  // pong game's pixel  // r=23:16, g=15:8, b=7:0 
   );

   wire [2:0] checkerboard;
        
   // REPLACE ME! The code below just generates a color checkerboard
   // using 64 pixel by 64 pixel squares.
   
   assign phsync_out = hsync_in;
   assign pvsync_out = vsync_in;
   assign pblank_out = blank_in;
   assign checkerboard = hcount_in[8:6] + vcount_in[8:6];

   // here we use three bits from hcount and vcount to generate the
   // checkerboard

   assign pixel_out = {{4{checkerboard[2]}}, {4{checkerboard[1]}}, {4{checkerboard[0]}}} ;
     
endmodule

module synchronize #(parameter NSYNC = 3)  // number of sync flops.  must be >= 2
                   (input clk,in,
                    output reg out);

  reg [NSYNC-2:0] sync;

  always_ff @ (posedge clk)
  begin
    {out,sync} <= {sync[NSYNC-2:0],in};
  end
endmodule

///////////////////////////////////////////////////////////////////////////////
//
// Pushbutton Debounce Module (video version - 24 bits)  
//
///////////////////////////////////////////////////////////////////////////////

module debounce (input reset_in, clock_in, noisy_in,
                 output reg clean_out);

   reg [19:0] count;
   reg new_input;

//   always_ff @(posedge clock_in)
//     if (reset_in) begin new <= noisy_in; clean_out <= noisy_in; count <= 0; end
//     else if (noisy_in != new) begin new <= noisy_in; count <= 0; end
//     else if (count == 650000) clean_out <= new;
//     else count <= count+1;

   always_ff @(posedge clock_in)
     if (reset_in) begin 
        new_input <= noisy_in; 
        clean_out <= noisy_in; 
        count <= 0; end
     else if (noisy_in != new_input) begin new_input<=noisy_in; count <= 0; end
     else if (count == 650000) clean_out <= new_input;
     else count <= count+1;


endmodule

//////////////////////////////////////////////////////////////////////////////////
// Engineer:   g.p.hom
// 
// Create Date:    18:18:59 04/21/2013 
// Module Name:    display_8hex 
// Description:  Display 8 hex numbers on 7 segment display
//
//////////////////////////////////////////////////////////////////////////////////

module display_8hex(
    input clk_in,                 // system clock
    input [31:0] data_in,         // 8 hex numbers, msb first
    output reg [6:0] seg_out,     // seven segment display output
    output reg [7:0] strobe_out   // digit strobe
    );

    localparam bits = 13;
     
    reg [bits:0] counter = 0;  // clear on power up
     
    wire [6:0] segments[15:0]; // 16 7 bit memorys
    assign segments[0]  = 7'b100_0000;  // inverted logic
    assign segments[1]  = 7'b111_1001;  // gfedcba
    assign segments[2]  = 7'b010_0100;
    assign segments[3]  = 7'b011_0000;
    assign segments[4]  = 7'b001_1001;
    assign segments[5]  = 7'b001_0010;
    assign segments[6]  = 7'b000_0010;
    assign segments[7]  = 7'b111_1000;
    assign segments[8]  = 7'b000_0000;
    assign segments[9]  = 7'b001_1000;
    assign segments[10] = 7'b000_1000;
    assign segments[11] = 7'b000_0011;
    assign segments[12] = 7'b010_0111;
    assign segments[13] = 7'b010_0001;
    assign segments[14] = 7'b000_0110;
    assign segments[15] = 7'b000_1110;
     
    always_ff @(posedge clk_in) begin
      // Here I am using a counter and select 3 bits which provides
      // a reasonable refresh rate starting the left most digit
      // and moving left.
      counter <= counter + 1;
      case (counter[bits:bits-2])
          3'b000: begin  // use the MSB 4 bits
                  seg_out <= segments[data_in[31:28]];
                  strobe_out <= 8'b0111_1111 ;
                 end

          3'b001: begin
                  seg_out <= segments[data_in[27:24]];
                  strobe_out <= 8'b1011_1111 ;
                 end

          3'b010: begin
                   seg_out <= segments[data_in[23:20]];
                   strobe_out <= 8'b1101_1111 ;
                  end
          3'b011: begin
                  seg_out <= segments[data_in[19:16]];
                  strobe_out <= 8'b1110_1111;        
                 end
          3'b100: begin
                  seg_out <= segments[data_in[15:12]];
                  strobe_out <= 8'b1111_0111;
                 end

          3'b101: begin
                  seg_out <= segments[data_in[11:8]];
                  strobe_out <= 8'b1111_1011;
                 end

          3'b110: begin
                   seg_out <= segments[data_in[7:4]];
                   strobe_out <= 8'b1111_1101;
                  end
          3'b111: begin
                  seg_out <= segments[data_in[3:0]];
                  strobe_out <= 8'b1111_1110;
                 end

       endcase
      end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Update: 8/8/2019 GH 
// Create Date: 10/02/2015 02:05:19 AM
// Module Name: xvga
//
// xvga: Generate VGA display signals (1024 x 768 @ 60Hz)
//
//                              ---- HORIZONTAL -----     ------VERTICAL -----
//                              Active                    Active
//                    Freq      Video   FP  Sync   BP      Video   FP  Sync  BP
//   640x480, 60Hz    25.175    640     16    96   48       480    11   2    31
//   800x600, 60Hz    40.000    800     40   128   88       600     1   4    23
//   1024x768, 60Hz   65.000    1024    24   136  160       768     3   6    29
//   1280x1024, 60Hz  108.00    1280    48   112  248       768     1   3    38
//   1280x720p 60Hz   75.25     1280    72    80  216       720     3   5    30
//   1920x1080 60Hz   148.5     1920    88    44  148      1080     4   5    36
//
// change the clock frequency, front porches, sync's, and back porches to create 
// other screen resolutions
////////////////////////////////////////////////////////////////////////////////

module xvga(input vclock_in,
            output reg [10:0] hcount_out,    // pixel number on current line
            output reg [9:0] vcount_out,     // line number
            output reg vsync_out, hsync_out,
            output reg blank_out);

   parameter DISPLAY_WIDTH  = 1024;      // display width
   parameter DISPLAY_HEIGHT = 768;       // number of lines

   parameter  H_FP = 24;                 // horizontal front porch
   parameter  H_SYNC_PULSE = 136;        // horizontal sync
   parameter  H_BP = 160;                // horizontal back porch

   parameter  V_FP = 3;                  // vertical front porch
   parameter  V_SYNC_PULSE = 6;          // vertical sync 
   parameter  V_BP = 29;                 // vertical back porch

   // horizontal: 1344 pixels total
   // display 1024 pixels per line
   reg hblank,vblank;
   wire hsyncon,hsyncoff,hreset,hblankon;
   assign hblankon = (hcount_out == (DISPLAY_WIDTH -1));    
   assign hsyncon = (hcount_out == (DISPLAY_WIDTH + H_FP - 1));  //1047
   assign hsyncoff = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE - 1));  // 1183
   assign hreset = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE + H_BP - 1));  //1343

   // vertical: 806 lines total
   // display 768 lines
   wire vsyncon,vsyncoff,vreset,vblankon;
   assign vblankon = hreset & (vcount_out == (DISPLAY_HEIGHT - 1));   // 767 
   assign vsyncon = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP - 1));  // 771
   assign vsyncoff = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE - 1));  // 777
   assign vreset = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE + V_BP - 1)); // 805

   // sync and blanking
   wire next_hblank,next_vblank;
   assign next_hblank = hreset ? 0 : hblankon ? 1 : hblank;
   assign next_vblank = vreset ? 0 : vblankon ? 1 : vblank;
   always_ff @(posedge vclock_in) begin
      hcount_out <= hreset ? 0 : hcount_out + 1;
      hblank <= next_hblank;
      hsync_out <= hsyncon ? 0 : hsyncoff ? 1 : hsync_out;  // active low

      vcount_out <= hreset ? (vreset ? 0 : vcount_out + 1) : vcount_out;
      vblank <= next_vblank;
      vsync_out <= vsyncon ? 0 : vsyncoff ? 1 : vsync_out;  // active low

      blank_out <= next_vblank | (next_hblank & ~hreset);
   end
   
endmodule


