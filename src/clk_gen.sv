module clk_gen #(
    parameter CLK_FREQ = 50000000,  // 50MHz system clock
    parameter BAUD_RATE = 115200    // 115200 baud rate
)(
    input  logic clk,
    input  logic rst_n,
    output logic baud_tick
);

    localparam int DIV = CLK_FREQ / BAUD_RATE;
    localparam int WIDTH = $clog2(DIV);
    
    logic [WIDTH-1:0] counter;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            baud_tick <= 0;
        end else begin
            if (counter == DIV - 1) begin
                counter <= 0;
                baud_tick <= 1;
            end else begin
                counter <= counter + 1;
                baud_tick <= 0;
            end
        end
    end

endmodule
