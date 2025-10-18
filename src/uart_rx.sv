module uart_rx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick,
    input  logic       rx_serial,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       rx_error
);

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t current_state;
    logic [2:0] bit_counter;
    logic [7:0] shift_reg;
    logic [3:0] sample_counter;

    // Two-FF synchronizer for rx_serial
    logic rx_sync1, rx_sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_serial;
            rx_sync2 <= rx_sync1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            bit_counter   <= 0;
            shift_reg     <= 0;
            rx_data       <= 0;
            rx_valid      <= 0;
            rx_error      <= 0;
            sample_counter <= 0;
        end else begin
            rx_valid <= 0;
            rx_error <= 0;

            case (current_state)
                IDLE: begin
                    bit_counter <= 0;
                    sample_counter <= 0;
                    if (rx_sync2 == 0) begin  // Detect start bit falling edge
                        current_state <= START;
                        sample_counter <= 0;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        sample_counter <= sample_counter + 1;
                        // Sample in the middle of start bit (after half baud period)
                        if (sample_counter == 0) begin
                            if (rx_sync2 == 0) begin  // Valid start bit
                                current_state <= DATA;
                                bit_counter <= 0;
                                sample_counter <= 0;
                            end else begin  // False start
                                rx_error <= 1;
                                current_state <= IDLE;
                            end
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        // Sample data bit (LSB first)
                        shift_reg <= {rx_sync2, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                        
                        if (bit_counter == 7) begin
                            current_state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        if (rx_sync2 == 1) begin  // Valid stop bit
                            rx_data <= shift_reg;
                            rx_valid <= 1;
                        end else begin  // Framing error
                            rx_error <= 1;
                        end
                        current_state <= IDLE;
                    end
                end
                
                default: begin
                    current_state <= IDLE;
                end
            endcase
        end
    end

endmodule