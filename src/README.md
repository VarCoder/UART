# UART Module with FIFO buffering in SystemVerilog

## Table of Contents
- [About](#about)
- [Getting Started](#getting_started)
- [Usage](#usage)
- [Contributing](../CONTRIBUTING.md)

## About <a name = "about"></a>

This is a UART Serial Communication module in SystemVerilog. I wrote it because I wanted to learn SystemVerilog in an actually useful real-world application while also trying things like creating a testbench in Python (familiar language) and understanding various quirks of SystemVerilog and HDLs compared to a programming language that I'd be used to. 

The module is a full-duplex UART implementation with separated TX and RX submodules, a clock generator to produce a variable baud rate on a certain system clock frequency, and a generalized FIFO submodule to buffer the data outputs in case a receiver or transmitter is outputting data at an increased rate with respect to the other module.

### Why FIFO Buffering?

The FIFO buffers decouple the timing between the application layer and the serial interface, thus reducing timing errors on both the read and write operations. One benefit is that transmitters can dump bytes as fast as they need and the receiver can parse it at any frequency, and the TX FIFO will queue them up for transmission. Similarly, the RX FIFO captures incoming bytes so you won't lose data if your application is temporarily busy. This is especially important in embedded systems where the processor might be handling interrupts or other time-critical tasks. FIFO depth is also adjustable in case huge timing differences are expected

### Full-Duplex Operation

The UART can transmit and receive simultaneously and independently. The TX and RX paths use the same baud rate clock but run separate state machines with their own independent FIFOs. This means you can be sending data on the TX line while receiving different data on the RX line at the same time, maximizing throughput for bidirectional communication.

## Getting Started <a name = "getting_started"></a>

To run this I would recommend installing:
* Verilator (I have 5.020)
* Python 3 (3.8 to 3.12 should be fine)
* CocoTB
* I used the VSCode Extension "VHDL & SystemVerilog IDE by Sigasi" to maintain and write the SystemVerilog (not necessary)

After that I just ran the Makefile via `make` in the terminal and modified the test_uart.py file to test it.

### Module Structure

The design consists of several submodules:
* `uart.sv` - Top-level module that integrates everything
* `clk_gen.sv` - Generates baud rate timing from system clock
* `fifo.sv` - Generic FIFO buffer (used for both TX and RX)
* `uart_tx.sv` - Serial transmitter (handles start/data/stop bits)
* `uart_rx.sv` - Serial receiver (includes synchronization and error detection)

### Running Tests

```bash
# Run all tests
make

# Clean everything
make clean_all

# Run specific test
make test_single_byte_loopback

# Generate waveforms for debugging
make waves

# View waveforms
make view
```

## Usage <a name = "usage"></a>

### Basic Example

```systemverilog
uart #(
    .CLK_FREQ(50000000),
    .BAUD_RATE(115200)
) uart_inst (
    .clk(clk),
    .rst_n(rst_n),
    // TX interface
    .tx_wr_en(tx_write),
    .tx_wr_data(data_to_send),
    .tx_full(tx_fifo_full),
    // RX interface
    .rx_rd_en(rx_read),
    .rx_rd_data(received_data),
    .rx_empty(rx_fifo_empty),
    // Serial pins
    .tx_serial(uart_tx_pin),
    .rx_serial(uart_rx_pin),
    // ... other signals
);
```

### Transmitting Data

Check if the TX FIFO has space (`tx_full` is low), then assert `tx_wr_en` and put your byte on `tx_wr_data`. The UART will automatically transmit it.

### Receiving Data

Check if data is available (`rx_empty` is low), then assert `rx_rd_en` to read. The data appears on `rx_rd_data` combinationally.

## Design Notes

The FIFO uses a dual-pointer design with an extra bit for wrap-around detection. The RX path includes a two-stage synchronizer to handle metastability from the async serial input. The receiver samples bits in the middle of each bit period for noise immunity. Edge detection ensures each received byte writes to the FIFO exactly once.

The implementation uses standard 8N1 format (8 data bits, no parity, 1 stop bit) and transmits LSB first, which is the UART standard.


## Credits

I learned a lot from the [Nandland](https://nandland.com/) website, the Sunburst paper on FIFO design, and the ChipVerify page for SystemVerilog/Verilog syntax and wanted to credit the authors for being very helpful in their work.