module Top(
    input i_clk,
    input i_single,
    input i_run_stop,
    output o_adc_clk,
    input [7:0] i_adc_data,
    output ws2812,
    output          LCD_CLK,
    output reg         LCD_VSYNC,
    output reg         LCD_HSYNC,
    output reg         LCD_DE,
    output reg         LCD_BL,
    output reg [4:0]   LCD_R,
    output reg [5:0]   LCD_G,
    output reg [4:0]   LCD_B
);

    parameter RESET_PULSE = 1000;
    parameter BUFFER_LEN = 512;
    parameter SCREEN_WIDTH = 480;
    parameter SCREEN_HEIGHT = 272;
    parameter SCREEN_GRID_SIZE = 32;

    // Disable rgb led
    assign ws2812 = 0;
    
    // Reset generation
    reg rst;
    reg [15:0] rst_cnt = 0;
    always @(negedge i_clk)
    begin
        if( rst_cnt + 1'b1 < RESET_PULSE ) begin
            rst_cnt <= rst_cnt + 1'b1;
            rst <= 1;
        end else begin
            rst <= 0;
        end
    end
    
    // Clock generation
    wire pll_clk;
    Gowin_rPLL rpll(
        //.rstin(rst),
        .clkin(i_clk),
        .clkout(pll_clk)
    );

    // Debug clock
    /*wire pll_clk2;
    Div #( .CNT_MAX(2) ) divDbg (
        .i_rst(rst),
        .i_clk(pll_clk2),
        .o_clk(pll_clk)
    );*/

    // LCD clock
    wire lcd_clk;
    Div #( .CNT_MAX(4) ) div0 (
        .i_rst(rst),
        .i_clk(pll_clk),
        .o_clk(lcd_clk)
    );
    
    // ADC clock
    assign o_adc_clk = !pll_clk;
    
    
    // Debounce buttons
    wire run_stop;
    Debounce #(
        .CNT_MAX(1024)
    )debounce1(
        .i_rst(rst),
        .i_clk(pll_clk),
        .i_btn(i_run_stop),
        .o_btn(run_stop)
    );

    wire single;
    Debounce #(
        .CNT_MAX(1024)
    )debounce2(
        .i_rst(rst),
        .i_clk(pll_clk),
        .i_btn(i_single),
        .o_btn(single)
    );
    
    // Start/Stop Controller
    wire start;
    wire stop;
    wire busy;
    wire done;
    Controller controller(
        .i_rst(rst),
        .i_clk(pll_clk),
        .i_run_stop(run_stop),
        .i_single(single),
        .o_start(start),
        .o_stop(stop),
        .i_busy(busy),
        .i_done(done)
    );
    
    // Scope
    wire start2;
    reg [7:0] adc_data;
    Scope scope (
        .rst(rst),
        .clk(pll_clk),
        .i_start(start & !LCD_DE),
        .i_stop(stop),
        .o_busy(busy),
        .o_done(done),
        .i_adc_data(adc_data)
    );
    
    // Addr generator
    reg [3:0] state;
    reg [15:0] adc_addr;
    reg [15:0] adc_addr_bck0;
    reg [15:0] adc_addr_bck1;
    reg ram_sel;
    always @(posedge pll_clk or posedge rst)
    begin
        if( rst ) begin
            state <= 0;
            adc_data <= 0;
            adc_addr <= 0;
            adc_addr_bck0 <= 0;
            adc_addr_bck1 <= 0;
            ram_sel <= 0;
        end else begin
            adc_data <= i_adc_data;
            case(state)
                0:begin
                    if( busy ) begin 
                        state <= 1;
                    end
                    adc_addr <= 0;
                end
                1:begin
                    if( !busy ) begin 
                        state <= 2;
                    end
                    if( adc_addr + 1 < BUFFER_LEN ) begin
                        adc_addr <= adc_addr + 1'b1;
                    end else begin
                        adc_addr <= 0;
                    end
                end
                2:begin
                    if( LCD_DE == 1'b1 ) begin
                        state <= 3;
                    end
                end
                3:begin
                    if( LCD_DE == 1'b0 ) begin
                        state <= 0;
                        if( ram_sel == 0 ) begin
                            adc_addr_bck0 <= adc_addr;
                            ram_sel <= 1;
                        end else begin
                            adc_addr_bck1 <= adc_addr;
                            ram_sel <= 0;
                        end
                    end
                end
            endcase
        end
    end
    
    wire [7:0]lcd_data0;
    Gowin_SDPB ram0(
        .reseta(rst),
        .clka(pll_clk),
        .cea( (ram_sel==0)?1'b1:1'b0 ),
        .ada( adc_addr[8:0] ),
        .din( adc_data[7:0] ),
        
        .resetb(rst),
        .clkb(lcd_clk),
        .ceb( 1'b1 ),
        .adb( lcd_addr[8:0] ),
        .dout( lcd_data0[7:0] ),

        .oce(1'b0)
    );
    wire [7:0]lcd_data1;
    Gowin_SDPB ram1(
        .reseta( rst ),
        .clka( pll_clk ),
        .cea( (ram_sel==1)?1'b1:1'b0 ),
        .ada( adc_addr[8:0] ),
        .din( adc_data[7:0] ),
        
        .resetb( rst ),
        .clkb( lcd_clk ),
        .ceb( 1'b1 ),
        .adb( lcd_addr[8:0] ),
        .dout( lcd_data1[7:0] ),

        .oce(1'b0)
    );
    
    // LCD control
    wire dclk;
    wire hsync;
    wire vsync;
    wire de;
    wire bl;
    wire [15:0] wx;
    wire [15:0] wy;
    reg [15:0] x;
    reg [15:0] y;
    Vga vga0(
        .i_rst(rst),
        .i_clk(lcd_clk),
        .o_dclk(dclk),
        .o_hsync(hsync),
        .o_vsync(vsync),
        .o_de(de),
        .o_bl(bl),
        .o_x(wx),
        .o_y(wy)
    );
    
    reg [15:0]lcd_addr;
    reg [7:0] y0;
    reg [7:0] y1;
    reg [7:0] y_mn;
    reg [7:0] y_mx;
    always @(negedge lcd_clk or posedge rst)
    begin
        if( rst ) begin
            y0 <= 0;
            y1 <= 0;
            y_mn <= 0;
            y_mx <= 0;
        end else begin
            y1 <= y0;
            y0 <= (ram_sel==0)?lcd_data1:lcd_data0;
            if( y0 < y1 ) begin
                y_mn <= y0;
                y_mx <= y1;
            end else begin
                y_mn <= y1;
                y_mx <= y0;
            end
        end
    end

    assign LCD_CLK = dclk;

    always @(negedge lcd_clk or posedge rst)
    begin
        if( rst ) begin
            LCD_HSYNC <= 0;
            LCD_VSYNC <= 0;
            LCD_DE <= 0;
            LCD_BL <= 0;
            LCD_R <= 0;
            LCD_G <= 0;
            LCD_B <= 0;
            x <= 0;
            y <= 0;
        end else begin
            x <= wx;
            y <= wy;
            lcd_addr <= (((ram_sel==1)?adc_addr_bck0:adc_addr_bck1) + SCREEN_WIDTH-x + 5)&(BUFFER_LEN-1);
            LCD_HSYNC <= hsync;
            LCD_VSYNC <= vsync;
            LCD_DE <= de;
            LCD_BL <= bl;
            LCD_R <= ((x==SCREEN_WIDTH/2-1)||(y==SCREEN_HEIGHT/2-1))? 5'h1F : 5'h00;
            if( y_mn <= y && y <= y_mx ) begin
                LCD_G <= (y_mn == y || y == y_mx)?6'h1F:6'h3F;
            end else begin
                LCD_G <= 6'h00;
            end
            LCD_B <= ((((x+18)&(SCREEN_GRID_SIZE-1))==0)||(((y+25)&(SCREEN_GRID_SIZE-1))==0))? 5'h1F : 5'h00;
        end
    end
endmodule

/*
module Gowin_rPLL(
    input rstin,
    input clkin,
    output reg clkout
);
  always @(posedge clkin or posedge rstin)
    begin
         if( rstin ) begin
            clkout <= 0;
        end else begin
            clkout <= !clkout;
        end
        
    end
endmodule
*/

/*
module Gowin_SDPB (
    input reseta,
    input cea,
    input clka,
    input [8:0] ada,
    input [7:0] din,

    input resetb,
    input ceb,
    input clkb,
    input [8:0] adb,
    output reg [7:0] dout,

    input oce
);

    parameter RAM_SIZE = 32;
    reg [7:0] ram [RAM_SIZE-1:0];
    integer i;
    always @(posedge clka or posedge reseta)
    begin
        if( reseta ) begin
          for( i = 0; i < RAM_SIZE; i = i + 1 ) begin
                ram[i] <= 0;
            end
        end else begin
            if( cea ) begin
                ram[ada] <= din;
            end
        end
    end

    always @(posedge clkb or posedge resetb)
    begin
        if( resetb ) begin
            dout <= 0;
        end else begin
            if( ceb ) begin
                dout <= ram[adb];
            end
        end
    end
endmodule
*/