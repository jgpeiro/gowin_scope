module Div #( 
    parameter CNT_MAX = 10
)(
    input   i_rst,
    input   i_clk,
    output reg o_clk
);
    reg [7:0] cnt;

    always @(posedge i_clk or posedge i_rst)
    begin
        if( i_rst ) begin
            cnt <= 0;
            o_clk <= 0;
        end else begin
            if( cnt < CNT_MAX-1 ) begin
                cnt <= cnt + 1'b1;
            end else begin
                cnt <= 0;
                o_clk <= !o_clk;
            end
        end
    end
endmodule