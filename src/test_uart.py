"""
Correct Cocotb testbench for UART module with FIFO
"""

import cocotb
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.clock import Clock


class UARTDriver:
    def __init__(self, dut):
        self.dut = dut
        
    async def reset(self):
        """Reset the DUT"""
        self.dut.rst_n.value = 0
        self.dut.tx_wr_en.value = 0
        self.dut.tx_wr_data.value = 0
        self.dut.rx_rd_en.value = 0
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst_n.value = 1
        await ClockCycles(self.dut.clk, 5)
        
    async def write_tx_byte(self, data):
        """Write a byte to TX FIFO"""
        # Wait for FIFO to have space
        timeout = 0
        while self.dut.tx_full.value == 1 and timeout < 1000:
            await RisingEdge(self.dut.clk)
            timeout += 1
            
        if timeout >= 1000:
            raise TimeoutError("TX FIFO full timeout")
            
        await RisingEdge(self.dut.clk)
        self.dut.tx_wr_data.value = data
        self.dut.tx_wr_en.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.tx_wr_en.value = 0
        
    async def read_rx_byte(self):
        """Read a byte from RX FIFO - FIXED timing"""
        # Wait for data to be available
        timeout = 0
        while self.dut.rx_empty.value == 1 and timeout < 50000:
            await RisingEdge(self.dut.clk)
            timeout += 1
            
        if timeout >= 50000:
            raise TimeoutError("Timeout waiting for RX data")
        
        # The FIFO rd_data is combinational, so it's valid immediately
        self.dut.rx_rd_en.value = 1
        await RisingEdge(self.dut.clk)
        # Capture data before the clock edge updates the pointer
        data = int(self.dut.rx_rd_data.value)
        self.dut.rx_rd_en.value = 0
        await RisingEdge(self.dut.clk)
        
        return data
        
    async def wait_for_tx_idle(self):
        """Wait for TX to become idle"""
        timeout = 0
        while self.dut.tx_active.value == 1 and timeout < 50000:
            await RisingEdge(self.dut.clk)
            timeout += 1
            
        if timeout >= 50000:
            raise TimeoutError("Timeout waiting for TX idle")


@cocotb.test()
async def test_uart_reset(dut):
    """Test reset functionality"""
    clock = Clock(dut.clk, 20, units="ns")  # 50MHz
    cocotb.start_soon(clock.start())
    
    driver = UARTDriver(dut)
    
    # Connect TX to RX for loopback
    dut.rx_serial.value = dut.tx_serial.value
    
    await driver.reset()
    
    # Check initial conditions
    assert dut.tx_full.value == 0, "TX FIFO should not be full after reset"
    assert dut.rx_empty.value == 1, "RX FIFO should be empty after reset"
    assert dut.tx_active.value == 0, "TX should be idle after reset"
    assert dut.rx_error.value == 0, "No RX error after reset"
    
    dut._log.info("Reset test PASSED")


@cocotb.test()
async def test_single_byte_loopback(dut):
    """Test single byte transmission through loopback"""
    clock = Clock(dut.clk, 20, units="ns")  # 50MHz
    cocotb.start_soon(clock.start())
    
    driver = UARTDriver(dut)
    
    # Setup loopback connection
    async def loopback_connection():
        while True:
            dut.rx_serial.value = dut.tx_serial.value
            await Timer(1, units="ns")
    
    cocotb.start_soon(loopback_connection())
    
    await driver.reset()
    
    test_byte = 0x55
    
    # Send byte
    await driver.write_tx_byte(test_byte)
    dut._log.info(f"Sent byte: 0x{test_byte:02X}")
    
    # Receive byte
    received_byte = await driver.read_rx_byte()
    dut._log.info(f"Received byte: 0x{received_byte:02X}")
    
    # Verify
    assert received_byte == test_byte, f"Mismatch: sent 0x{test_byte:02X}, got 0x{received_byte:02X}"
    
    dut._log.info("Single byte loopback test PASSED")


@cocotb.test()
async def test_multiple_byte_loopback(dut):
    """Test multiple byte transmission"""
    clock = Clock(dut.clk, 20, units="ns")  # 50MHz
    cocotb.start_soon(clock.start())
    
    driver = UARTDriver(dut)
    
    # Setup loopback connection
    async def loopback_connection():
        while True:
            dut.rx_serial.value = dut.tx_serial.value
            await RisingEdge(dut.clk)
    
    cocotb.start_soon(loopback_connection())
    
    await driver.reset()
    
    # Test data
    test_data = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  # "Hello"
    
    # Send all bytes
    for i, byte_val in enumerate(test_data):
        await driver.write_tx_byte(byte_val)
        dut._log.info(f"Sent[{i}]: 0x{byte_val:02X}")
    
    # Wait for all transmissions to complete
    await driver.wait_for_tx_idle()
    await ClockCycles(dut.clk, 1000)
    
    # Verify RX FIFO has all the data
    rx_count = int(dut.rx_count.value)
    dut._log.info(f"RX FIFO count: {rx_count}")
    
    # Receive all bytes
    received_data = []
    for i in range(len(test_data)):
        received_byte = await driver.read_rx_byte()
        received_data.append(received_byte)
        dut._log.info(f"Received[{i}]: 0x{received_byte:02X}")
    
    # Verify data
    errors = 0
    for i, (sent, received) in enumerate(zip(test_data, received_data)):
        if sent != received:
            dut._log.error(f"Byte {i}: sent 0x{sent:02X}, got 0x{received:02X}")
            errors += 1
        else:
            dut._log.info(f"Byte {i}: PASS")
    
    assert errors == 0, f"Failed {errors} out of {len(test_data)} bytes"
    
    dut._log.info("Multiple byte loopback test PASSED")


@cocotb.test()
async def test_fifo_functionality(dut):
    """Test FIFO operations"""
    clock = Clock(dut.clk, 20, units="ns")  # 50MHz
    cocotb.start_soon(clock.start())
    
    driver = UARTDriver(dut)
    
    await driver.reset()
    
    # Test TX FIFO count
    initial_count = int(dut.tx_count.value)
    dut._log.info(f"Initial TX count: {initial_count}")
    assert initial_count == 0, f"Initial TX count should be 0, got {initial_count}"
    
    # Add some bytes to TX FIFO quickly (faster than TX can send)
    for i in range(5):
        # Write directly without waiting
        await RisingEdge(dut.clk)
        dut.tx_wr_data.value = i
        dut.tx_wr_en.value = 1
        await RisingEdge(dut.clk)
        dut.tx_wr_en.value = 0
        
        # Give it a moment for the write to take effect
        await RisingEdge(dut.clk)
        actual_count = int(dut.tx_count.value)
        dut._log.info(f"After write {i}: TX count = {actual_count}")
    
    # Final count should be non-zero (some might have been consumed by TX)
    final_count = int(dut.tx_count.value)
    dut._log.info(f"Final TX count: {final_count}")
    assert final_count > 0, f"TX count should be > 0 after writing, got {final_count}"
    
    dut._log.info("FIFO functionality test PASSED")


@cocotb.test()
async def test_tx_timing(dut):
    """Test TX timing and state machine"""
    clock = Clock(dut.clk, 20, units="ns")  # 50MHz
    cocotb.start_soon(clock.start())
    
    driver = UARTDriver(dut)
    
    await driver.reset()
    
    # Send a byte and monitor TX activity
    test_byte = 0xA5
    
    # Check initial state
    assert dut.tx_active.value == 0, "TX should start idle"
    
    # Send byte
    await driver.write_tx_byte(test_byte)
    
    # TX should become active
    await ClockCycles(dut.clk, 10)
    assert dut.tx_active.value == 1, "TX should be active after sending byte"
    
    # Wait for completion
    await driver.wait_for_tx_idle()
    assert dut.tx_active.value == 0, "TX should return to idle"
    
    dut._log.info("TX timing test PASSED")