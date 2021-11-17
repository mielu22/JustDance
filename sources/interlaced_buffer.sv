`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

module interlaced_buffer(
    input wire clk, //perhaps have write share camera clock and have read be 100MHz?
    input wire reset,
    input wire [16:0] read_addr,
    input wire pixel_in,
    //output logic [8:0] or [2:0] kernel,
    output logic pixel_out
    );


/*        
    blk_mem_gen_0 aram(.addra(addra),.clka(clk),.dina(pixel_in),.wea(writea),.addrb(),.clkb(clk),.doutb());
    blk_mem_gen_0 bram(.addra(addrb),.clka(clk),.dina(pixel_in),.wea(writeb),.addrb(),.clkb(),.doutb());
    blk_mem_gen_0 cram(.addra(addrc),.clka(clk),.dina(pixel_in),.wea(writec),.addrb(),.clkb(),.doutb());
*/
    
    logic [16:0] write_addr; //76,800 = 1 frame but 
    logic [16:0] addra; // 0->319, 961->
    logic [16:0] addrb; // 320->639
    logic [16:0] addrc;
    logic writea; //determines which buffer to write into
    logic writeb;
    logic writec;
    logic [1:0] state;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            write_addr <= 0;
            addra <= 0;
            addrb <= 0;
            addrc <= 0;
            writea <= 1;
            writeb <= 0;
            writec <= 0;
        end else begin
            if (write_addr >= 76799) begin
                write_addr <= 0;
            end 
            write_addr <= write_addr + 1;
            case (state)
                0: begin
                    if (addra >= 75999) begin
                        addra <= 0;
                    end else begin
                        addra <= addra + 1;
                    end
                    if (write_addr%320 == 319) begin
                        state <= 1;
                        writea <= 0;
                        writeb <= 1;
                    end
                end
                1: begin
                    if (addrb >= 75999) begin
                        addrb <= 0;
                    end else begin
                        addrb <= addrb + 1;
                    end
                    if (write_addr%320 == 319) begin
                        state <= 2;
                        writeb <= 0;
                        writec <= 1;
                    end
                end
                2: begin
                    if (addrc >= 75999) begin
                        addrc <= 0;
                    end else begin
                        addrc <= addrc + 1;
                    end
                    if (write_addr%320 == 319) begin
                        state <= 0;
                        writec <= 0;
                        writea <= 1;
                    end
                end
            endcase
        end
    end


endmodule
`default_nettype wire