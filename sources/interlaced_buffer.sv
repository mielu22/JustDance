`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

module interlaced_buffer(
    input wire clk, //perhaps have write share camera clock and have read be 100MHz?
    input wire reset,
    input wire [16:0] read_addr, //should only go 0->76799
    input wire [23:0] pixel_in,
    //input wire frame, //delay in top_level before it tries to read camera --> counts frames for this to use to keep track
    //output logic [8:0] kernel_out, //since the whole point of 3 BRAMS is to do synchronous retrieval
    // output logic ready, //when a out has been filled and is ready to transfer to kernel_out
    output logic [23:0] pixel_out
    );
    parameter X = 320;
    parameter THIRD_OF_Y = 80;
    
    /* ASSUME read_addr DOES GO IN CONSECUTIVE ORDER */
    blk_mem_gen_0 aram(.addra(addra),.clka(clk),.dina(pixel_in),.wea(writea),.addrb(reada),.clkb(clk),.doutb(dataa));
    blk_mem_gen_0 bram(.addra(addrb),.clka(clk),.dina(pixel_in),.wea(writeb),.addrb(readb),.clkb(clk),.doutb(datab));
    blk_mem_gen_0 cram(.addra(addrc),.clka(clk),.dina(pixel_in),.wea(writec),.addrb(readc),.clkb(clk),.doutb(datac));
    
    logic [16:0] write_addr; //76,800 = 1 frame
    logic [16:0] addra; // 0->319, 960->
    logic [16:0] addrb; // 320->639
    logic [16:0] addrc; // 640->959
    logic writea; //determines which buffer to write into
    logic writeb;
    logic writec;
    logic [1:0] state;

    logic [1:0] frame; //so we know which "row" to read from (since each BRAM holds 1/3 for a total of 3 frames)
//    logic [2:0] segment; //3x1 for a kernel
    logic [8:0] [23:0] kernel; //transfers to kernel_out eventually
    logic ready;
    logic [7:0] chunk; //since each frame had 240 lines of 320 pixels
    logic [8:0] index; //cycles through for each line
    logic [16:0] reada; //internal addresses
    logic [16:0] readb;
    logic [16:0] readc;
    logic [1:0] status;
    
    logic [23:0] dataa; //pixels returned
    logic [23:0] datab;
    logic [23:0] datac;

    
    
    always_ff @(posedge clk) begin
        if (reset) begin
            write_addr <= 0;
            addra <= 0;
            addrb <= 0;
            addrc <= 0;
            writea <= 1;
            writeb <= 0;
            writec <= 0;
            state <= 0;
            
            frame <= 0;
            chunk <= 0;
            index <= 0;
            kernel <= 0;
            ready <= 0;
            reada <= 0;
            readb <= 0;
            readc <= 0;
            status <= 0;
        end else begin
            // WRITING
            if (write_addr >= X*3*THIRD_OF_Y - 1) begin
                write_addr <= 0;
            end else begin
                write_addr <= write_addr + 1;
            end
            case (state)
                0: begin
                    if (addra >= X*3*THIRD_OF_Y - 1) begin
                        addra <= 0;
                    end else begin
                        addra <= addra + 1;
                    end
                    if (write_addr%X == X - 1) begin
                        state <= 1;
                        writea <= 0;
                        writeb <= 1;
                    end
                end
                1: begin
                    if (addrb >= X*3*THIRD_OF_Y - 1) begin
                        addrb <= 0;
                    end else begin
                        addrb <= addrb + 1;
                    end
                    if (write_addr%X == X - 1) begin
                        state <= 2;
                        writeb <= 0;
                        writec <= 1;
                    end
                end
                2: begin
                    if (addrc >= X*3*THIRD_OF_Y - 1) begin
                        addrc <= 0;
                    end else begin
                        addrc <= addrc + 1;
                    end
                    if (write_addr%X == X - 1) begin
                        state <= 0;
                        writec <= 0;
                        writea <= 1;
                    end
                end
            endcase
            
            // READING --> just deal with reading single addresses for now
            
            if (read_addr >= X*3*THIRD_OF_Y - 1) begin //WARNING: not needed if frame is input
                frame <= (frame >= 2) ? 0 : frame + 1;
                chunk <= (chunk >= THIRD_OF_Y - 1) ? 0 : chunk + 1;
                index <= 0;
            end else if (read_addr%X == X - 1) begin
                index <= 0;
                chunk <= (read_addr%(3*X) == 3*X - 1) ? chunk + 1 : chunk;
            end else index <= index + 1;
            
            
            if (read_addr %(3*X) <= X - 1) begin          // center is in A FRAME
                         //invalid on top edge
                //readc <= (read_addr < 320) ? 0 : 320*80*frame + 320*(chunk-1) + index;
                reada <= X*THIRD_OF_Y*frame + chunk*X + index;
                //readb <= 320*80*frame + chunk*320 + index;
                pixel_out <= dataa;
            
            end else if (read_addr%(3*X) <= 2*X - 1) begin // center is in B FRAME
                //reada <= 320*80*frame + chunk*320 + index;
                readb <= X*THIRD_OF_Y*frame + chunk*X + index;
                //readc <= 320*80*frame + chunk*320 + index;
                pixel_out <= datab;
            
            end else begin                             // center is in C FRAME
                //readb <= 320*80*frame + chunk*320 + index;
                readc <= X*THIRD_OF_Y*frame + chunk*X + index;
                          //invalid on bottom edge
                //reada <= (read_addr >= 76480) ? 0 : 320*80*frame + 320*(chunk+1) + index;
                pixel_out <= datac;
            end
            
            /*            
            case (status)
                0: begin // center segment of kernel
                    ready <= 0;
                    if (read_addr < 320) begin // top edge = A FRAME
                        kernel[2:0] <= {dataa, dataa, datab};
                    end else if (read_addr >= 76480) begin // bottom edge = C FRAME
                        kernel[2:0] <= {datab, datac, datac};
                    end else begin // normal
                        kernel[2:0] <= {dataa, datab, datac};
                    end
                    status <= 1;
                end
                1: begin // left column
                    if (read_addr % 320 == 0) begin //off left edge
                        kernel[5:3] <= (read_addr == 0) ? {} : ;
                    end else begin // normal
                    end
                    status <= 2;
                end
                2: begin // right column
                    if (read_addr % 320 == 319) begin //off right edge
                        kernel[8:6] <= ;
                    end else begin // normal
                    end
                    status <= 3;
                end
                3: begin // send it
                    kernel_out <= kernel;
                    ready <= 1;
                    status <= 0;
                end
            endcase
            */
        end
    end


endmodule
`default_nettype wire