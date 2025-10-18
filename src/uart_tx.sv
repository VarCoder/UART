module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx_serial,
    output logic       tx_busy,
    output logic       tx_done
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
    logic       start_received;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            bit_counter <= 0;
            shift_reg <= 8'hFF;
            start_received <= 0;
        end else begin
            // Latch start signal to avoid missing it
            if (tx_start && current_state == IDLE) begin
                start_received <= 1;
                shift_reg <= tx_data;
            end
            
            case (current_state)
                IDLE: begin
                    bit_counter <= 0;
                    if (start_received) begin
                        current_state <= START;
                        start_received <= 0;
                    end
                end
                
                START: begin
                    if (baud_tick) begin
                        current_state <= DATA;
                        bit_counter <= 0;
                    end
                end
                
                DATA: begin
                    if (baud_tick) begin
                        shift_reg <= {1'b0, shift_reg[7:1]}; // Shift right, fill with 0
                        bit_counter <= bit_counter + 1;
                        if (bit_counter == 7) begin
                            current_state <= STOP;
                        end
                    end
                end
                
                STOP: begin
                    if (baud_tick) begin
                        current_state <= IDLE;
                    end
                end
                
                default: begin
                    current_state <= IDLE;
                end
            endcase
        end
    end
    
    // FIXED: Output logic with proper bit selection
    always_comb begin
        tx_busy = (current_state != IDLE);
        tx_done = (current_state == STOP) && baud_tick;
        
        case (current_state)
            IDLE:    tx_serial = 1'b1;      // Idle high
            START:   tx_serial = 1'b0;      // Start bit low
            DATA:    tx_serial = shift_reg[0]; // LSB first
            STOP:    tx_serial = 1'b1;      // Stop bit high
            default: tx_serial = 1'b1;
        endcase
    end

endmodule