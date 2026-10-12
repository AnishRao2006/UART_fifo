`timescale 1ns/1ns

package uartrx_pkg;
typedef enum logic [2:0] {
IDLE       = 3'b000,
START_BIT  = 3'b001,
DATA_BITS  = 3'b010,
STOP_BIT   = 3'b011,
CLEANUP    = 3'b100
} state_t;
endpackage

module uart_rx 
    #(
    parameter DATA_WIDTH   = 8,   // Configurable data width (typically 8)
    parameter CLKS_PER_BIT = 434  // Example: 50MHz clock / 115200 baud = 434
    )(
    input  logic                   clk,
    input  logic                   reset,
    // Serial input
    input  logic                   rx_in,
    // Parallel data output (FIFO write interface)
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                   rx_valid,
    // Status / error flags
    output logic                   busy,
    output logic                   framing_error,
    output logic                   parity_error // Tied to 0 (Configured for No Parity)
    );

// FSM State Encoding
import uartrx_pkg :: *;
state_t state;

// Double-flop synchronizer to safely bring external async serial line into clock domain
logic rx_sync_0, rx_sync;
always_ff @(posedge clk or posedge reset) begin
if (reset) begin
rx_sync_0 <= 1'b1;
rx_sync   <= 1'b1;
end else begin
rx_sync_0 <= rx_in;
rx_sync   <= rx_sync_0;
end
end

// Internal tracking counters and registers
logic [31:0]             clk_count;
logic [$clog2(DATA_WIDTH)-1:0] bit_index;
logic [DATA_WIDTH-1:0]   rx_data_reg;

// Status mapping: Controller is busy if it is executing outside the IDLE state
assign busy         = (state != IDLE);

// Parity configuration: Standard 8N1 setup implies no parity check logic needed here
assign parity_error = 1'b0; 

always_ff @(posedge clk or posedge reset) begin
if (reset) begin
state         <= IDLE;
rx_valid      <= 1'b0;
rx_data       <= '0;
framing_error <= 1'b0;
clk_count     <= 0;
bit_index     <= 0;
rx_data_reg   <= '0;
end else begin
case (state)

IDLE: begin
rx_valid      <= 1'b0;
clk_count     <= 0;
bit_index     <= 0;

// Clear error flag on arrival of a new candidate transaction frame
if (rx_sync == 1'b0) begin 
framing_error <= 1'b0;
state         <= START_BIT;
end
end

START_BIT: begin
// Verify that the start bit remains driven low at its center point
if (clk_count == (CLKS_PER_BIT / 2)) begin
if (rx_sync == 1'b0) begin
clk_count <= 0; // Align phase timing for data capture cycles
state     <= DATA_BITS;
end else begin
state     <= IDLE; // Spurious noise glitch recovery path
end
end else begin
clk_count <= clk_count + 1;
end
end

DATA_BITS: begin
// Advance counters and record bit value right in the middle of bit width
if (clk_count < CLKS_PER_BIT - 1) begin
clk_count <= clk_count + 1;
end else begin
clk_count              <= 0;
rx_data_reg[bit_index] <= rx_sync;

if (bit_index < DATA_WIDTH - 1) begin
bit_index <= bit_index + 1;
end else begin
bit_index <= 0;
state     <= STOP_BIT;
end
end
end

STOP_BIT: begin
// Wait for the exact middle of the stop bit window to safely validate framing
if (clk_count < (CLKS_PER_BIT - 1)) begin
clk_count <= clk_count + 1;
end else begin
clk_count <= 0;
state     <= CLEANUP;

// Framing Error check: Stop bit must register as standard High (1'b1)
if (rx_sync == 1'b1) begin
rx_valid <= 1'b1; // Trigger downstream FIFO write cycle
rx_data  <= rx_data_reg;
end else begin
framing_error <= 1'b1; // Stop bit dropped or frame misaligned
end
end
end

// Single clock cycle pipeline separation to finalize FIFO valid signals cleanly
CLEANUP: begin
rx_valid <= 1'b0;
state    <= IDLE;
end

default: state <= IDLE;
endcase
end
end

endmodule : uart_rx
