module uart #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200,
    parameter TX_FIFO_DEPTH = 16,
    parameter RX_FIFO_DEPTH = 16
)(
    input  logic       clk,
    input  logic       rst_n,

    // TX FIFO
    input  logic       tx_wr_en,
    input  logic [7:0] tx_wr_data,
    output logic       tx_full,
    output logic       tx_almost_full,
    output logic [4:0] tx_count,

    // RX FIFO
    input  logic       rx_rd_en,
    output logic [7:0] rx_rd_data,
    output logic       rx_empty,
    output logic       rx_almost_empty,
    output logic [4:0] rx_count,

    // Serial interface
    output logic       tx_serial,
    input  logic       rx_serial,

    // Status
    output logic       tx_active,
    output logic       rx_error
);

    // Internal signals
    logic baud_tick;

    // TX FIFO signals
    logic tx_fifo_rd_en;
    logic [7:0] tx_fifo_rd_data;
    logic tx_fifo_empty;

    // RX FIFO signals
    logic rx_fifo_wr_en;
    logic [7:0] rx_fifo_wr_data;
    logic rx_fifo_full;

    // UART core signals
    logic uart_tx_start;
    logic uart_tx_busy;
    logic uart_tx_done;
    logic uart_rx_valid;
    logic [7:0] uart_rx_data;

    // Clock generator
    clk_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) clk_gen_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick)
    );

    // TX FIFO
    fifo #(
        .DATA_WIDTH(8),
        .DEPTH(TX_FIFO_DEPTH)
    ) tx_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(tx_wr_en),
        .wr_data(tx_wr_data),
        .full(tx_full),
        .almost_full(tx_almost_full),
        .rd_en(tx_fifo_rd_en),
        .rd_data(tx_fifo_rd_data),
        .empty(tx_fifo_empty),
        .almost_empty(),
        .count(tx_count)
    );

    // RX FIFO
    fifo #(
        .DATA_WIDTH(8),
        .DEPTH(RX_FIFO_DEPTH)
    ) rx_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(rx_fifo_wr_en),
        .wr_data(rx_fifo_wr_data),
        .full(rx_fifo_full),
        .almost_full(),
        .rd_en(rx_rd_en),
        .rd_data(rx_rd_data),
        .empty(rx_empty),
        .almost_empty(rx_almost_empty),
        .count(rx_count)
    );

    // UART TX
    uart_tx uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .tx_start(uart_tx_start),
        .tx_data(tx_fifo_rd_data),
        .tx_serial(tx_serial),
        .tx_busy(uart_tx_busy),
        .tx_done(uart_tx_done)
    );

    // UART RX
    uart_rx uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .rx_serial(rx_serial),
        .rx_data(uart_rx_data),
        .rx_valid(uart_rx_valid),
        .rx_error(rx_error)
    );

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_TRANSMITTING
    } tx_state_t;

    tx_state_t tx_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            uart_tx_start <= 0;
            tx_fifo_rd_en <= 0;
        end else begin
            // Default values
            uart_tx_start <= 0;
            tx_fifo_rd_en <= 0;

            case (tx_state)
                TX_IDLE: begin
                    // When FIFO has data and TX is ready, start transmission
                    if (!tx_fifo_empty && !uart_tx_busy) begin
                        tx_fifo_rd_en <= 1;    // Read from FIFO
                        uart_tx_start <= 1;    // Start TX (it will latch the data)
                        tx_state <= TX_TRANSMITTING;
                    end
                end

                TX_TRANSMITTING: begin
                    // Wait for transmission to complete
                    if (uart_tx_done) begin
                        tx_state <= TX_IDLE;
                    end
                end
            endcase
        end
    end

    assign tx_active = (tx_state != TX_IDLE) || uart_tx_busy;

    logic rx_valid_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_valid_prev <= 1'b0;
        end else begin
            rx_valid_prev <= uart_rx_valid;
        end
    end
    
    // Write on rising edge of rx_valid, single cycle pulse
    assign rx_fifo_wr_en = uart_rx_valid && !rx_valid_prev && !rx_fifo_full;
    assign rx_fifo_wr_data = uart_rx_data;

endmodule