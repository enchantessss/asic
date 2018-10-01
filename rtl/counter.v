module counter
#(  parameter WIDTH = 8)
(
    output reg [WIDTH-1 : 0]  out,
    input                     clk,
    input                     rst_n
);

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        out <= 'b0;
    end
    else begin
        out <= out + 'b1;
    end
end

endmodule 
