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

parameter STATE_IDLE = 8'b000001;
parameter STATE_PREV = 8'b000010;
parameter STATE_TRIG = 8'b000100;
parameter STATE_TRIG2= 8'b001000;
parameter STATE_POST = 8'b010000;
parameter STATE_DONE = 8'b100000;

parameter THRESHOLD = 136;
parameter PREV_MAX = 512/2;
parameter POST_MAX = 512/2;

reg [7:0] state;
reg [15:0] cnt;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        state <= STATE_IDLE;
        cnt <= 0;
        o_busy <= 0;
        o_done <= 0;
    end else begin
        case(state)
            STATE_IDLE: begin
                cnt <= 0;
                o_done <= 0;
                if(i_start == 1)
                    state <= STATE_PREV;
            end
            STATE_PREV: begin
                o_busy <= 1;
                cnt <= cnt + 1'b1;
                if(cnt == PREV_MAX)
                    state <= STATE_TRIG;
            end
            STATE_TRIG: begin
                cnt <= 0;
                if(i_adc_data < THRESHOLD)
                    state <= STATE_TRIG2;
            end
            STATE_TRIG2: begin
                if(i_adc_data >= THRESHOLD)
                    state <= STATE_POST;
            end
            STATE_POST: begin
                cnt <= cnt + 1'b1;
                if(cnt == POST_MAX)
                    state <= STATE_DONE;
            end
            STATE_DONE: begin
                if(i_stop == 1)
                    state <= STATE_IDLE;
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