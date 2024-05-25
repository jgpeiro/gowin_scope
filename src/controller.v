module Controller(
    input i_rst,
    input i_clk,
    input i_single,
    input i_run_stop,
  
    output reg o_start,
    output reg o_stop,
    input i_busy,
    input i_done
);
    reg run;
    reg run_stop_bck;
    reg run_stop;
    reg single_bck;
    reg single;

    reg [3:0] state;

    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            state <= 0;
            o_start <= 0;
            o_stop <= 0;
            run_stop_bck <= 0;
            run_stop <= 0;
            run <= 0;
            single_bck <= 0;
            single <= 0;
        end else begin
            run_stop_bck <= i_run_stop;
            single_bck <= i_single;
            run_stop <= i_run_stop & !run_stop_bck;
            single <= i_single & !single_bck;
            run <= (single)?0:((run_stop)?!run:run);
            case(state)
                0: begin
                    state <= (single==1)?1:((run==1)?1:0);
                end
                1: begin
                    state <= (i_busy==1)?2:1;
                    o_start <= 1;
                end
                2: begin
                    state <= (i_done==1)?3:2;
                    o_start <= 0;
                end
                3: begin
                    state <= (i_done==0)?4:3;
                    o_stop <= 1;
                end
                4: begin
                    state <= 0;
                    o_stop <= 0;
                end
            endcase
        end
    end
endmodule