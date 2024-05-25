module Debounce #(
  parameter CNT_MAX = 1024
)(
    input   i_rst,
    input   i_clk,
    input   i_btn,
    output reg   o_btn
);
    reg [15:0] cnt;

    always @(posedge i_clk or posedge i_rst)
    begin
        if( i_rst ) begin
            cnt <= 0;
            o_btn <= 0;
        end else begin
            
            if( i_btn ) begin
                if( cnt < CNT_MAX ) begin
                    cnt <= cnt + 1'b1;
                end
            end else begin
                if( cnt > 0 ) begin
                    cnt <= cnt - 1'b1;
                end
            end
            
            if( cnt > 3*CNT_MAX/4 ) begin
                o_btn <= 1;
            end else if( cnt < 1*CNT_MAX/4 ) begin
                o_btn <= 0;
            end
        end
    end
endmodule