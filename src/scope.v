module Scope(
    input rst,
    input clk,
    input i_start,
    input i_stop,
    output reg o_busy,
    output reg o_done,
//    output reg o_run,
    input [7:0] i_adc_data
);

parameter STATE_IDLE = 4'b0000;
parameter STATE_PREV = 4'b0001;
parameter STATE_TRIG = 4'b0010;
parameter STATE_POST = 4'b0100;
parameter STATE_DONE = 4'b1000;

parameter THRESHOLD = 136;
parameter PREV_MAX = 512/2;
parameter POST_MAX = 512/2;

reg [3:0] state;
reg [15:0] cnt;
reg [2:0] trig;
//reg [7:0] adc_value;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        state <= STATE_IDLE;
        cnt <= 0;
        o_busy <= 0;
        o_done <= 0;
        trig <= 0;
        //o_run <= 0;
    end else begin
        case(state)
            STATE_IDLE: begin
                cnt <= 0;
                state <= (i_start == 1) ? STATE_PREV : STATE_IDLE;
                trig <= 0;
                o_done <= 0;
//                o_run <= 0;
            end
            STATE_PREV: begin
                cnt <= cnt + 1'b1;
                state <= (cnt >= PREV_MAX) ? STATE_TRIG : STATE_PREV;
                trig <= 0;
                o_busy <= 1;
//                o_run <= 1;
            end
            STATE_TRIG: begin
                cnt <= 0;
                state <= (trig == 2) ? STATE_POST : STATE_TRIG;
                trig <= (trig==0)?((i_adc_data < THRESHOLD) ?1:0):((i_adc_data >= THRESHOLD)?2:1);
            end
            STATE_POST: begin
                cnt <= cnt + 1'b1;
                state <= (cnt >= POST_MAX) ? STATE_DONE : STATE_POST;
            end
            STATE_DONE: begin
                state <= (i_stop == 1) ? STATE_IDLE : STATE_DONE;
                o_busy <= 0;
                o_done <= 1;
            end
            default: begin
              state <= STATE_IDLE;
              end
        endcase
    end
end

endmodule