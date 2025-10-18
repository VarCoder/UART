module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Write
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic                    full,
    output logic                    almost_full,
    
    // Read
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    empty,
    output logic                    almost_empty,
    
    // Status
    output logic [ADDR_WIDTH:0]     count
);

    // Data Arr
    logic [DATA_WIDTH-1:0] data [0:DEPTH-1];
    
    // Overflow Ptrs
    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;
    
    // Status Flags
    assign count = wr_ptr - rd_ptr;
    assign empty = (wr_ptr == rd_ptr);
    
    assign full = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && 
                  (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    
    assign almost_full = (count >= (DEPTH - 1));
    assign almost_empty = (count == 1);
    
    // Only when write enabled and not full
    always_ff @(posedge clk) begin
        if (wr_en && !full) begin
            data[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (wr_en && !full) begin
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    assign rd_data = data[rd_ptr[ADDR_WIDTH-1:0]];

endmodule