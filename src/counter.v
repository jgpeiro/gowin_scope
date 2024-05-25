module Counter(
    input wire rst,
    input wire clk,
    input wire [15:0] period,
    output wire done
);

reg [15:0] counter;

always @(posedge clk or posedge rst)
begin
    if(rst)
        counter <= 0;
    else if(counter == period)
        counter <= counter;
    else
        counter <= counter + 1;
end

assign done = (counter == period);

endmodule