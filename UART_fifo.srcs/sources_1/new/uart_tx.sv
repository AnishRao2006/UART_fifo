`timescale 1ns/1ns

package uarttx_pkg;
typedef enum logic [2:0] {
IDLE       = 3'b000,
START_BIT  = 3'b001,
DATA_BITS  = 3'b010,
STOP_BIT   = 3'b011,
CLEANUP    = 3'b100,
SAMPLE     = 3'b101
} state_t;
endpackage

module uart_tx 
    #(
    parameter DATA_WIDTH   = 8,   // Configurable data width (typically 8)
    parameter CLKS_PER_BIT = 434  // Example: 50MHz clock / 115200 baud = 434
    )(
    input  logic                   clk,
    input  logic                   reset,
    // Parallel data input (FIFO read interface)
    input  logic [DATA_WIDTH-1:0] tx_data,
    input  logic                   tx_valid,
    output logic                   tx_ready,
    // Serial output
    output logic                   tx_out,
    // Status
    output logic                   busy
    );

// FSM State Encoding
import uarttx_pkg :: *;
state_t state;

// Internal counters and registers
logic [31:0]             clk_count;
logic [$clog2(DATA_WIDTH)-1:0] bit_index;
logic [DATA_WIDTH-1:0]   tx_data_reg;

// tx_ready handling: Ready to accept data only when in IDLE
assign tx_ready = (state == IDLE);

// busy handling: Active whenever we are processing a transaction
assign busy     = (state != IDLE);

always_ff @(posedge clk or posedge reset) begin
if (reset) begin
state       <= IDLE;
tx_out      <= 1'b1; // UART protocol idle state is high
clk_count   <= 0;
bit_index   <= 0;
tx_data_reg <= '0;
end else begin
case (state)

IDLE: begin
tx_out    <= 1'b1;
clk_count <= 0;
bit_index <= 0;

// Handshake occurs when both valid and ready (implicitly true in IDLE) are high
if (tx_valid) begin
state       <= SAMPLE;
end
end

SAMPLE: begin
tx_data_reg <= tx_data;
state  <= START_BIT;
end

START_BIT: begin
tx_out <= 1'b0; // Start bit is driven low

if (clk_count < CLKS_PER_BIT - 1) begin
clk_count <= clk_count + 1;
end else begin
clk_count <= 0;
state     <= DATA_BITS;
end
end

DATA_BITS: begin
tx_out <= tx_data_reg[bit_index];

if (clk_count < CLKS_PER_BIT - 1) begin
clk_count <= clk_count + 1;
end else begin
clk_count <= 0;
if (bit_index < DATA_WIDTH - 1) begin
bit_index <= bit_index + 1;
end else begin
bit_index <= 0;
state     <= STOP_BIT;
end
end
end

STOP_BIT: begin
tx_out <= 1'b1; // Stop bit is driven high

if (clk_count < CLKS_PER_BIT - 1) begin
clk_count <= clk_count + 1;
end else begin
clk_count <= 0;
state     <= CLEANUP;
end
end

// Short 1-clock state to ensure FSM gracefully resets counters
CLEANUP: begin
state <= IDLE;
end

default: state <= IDLE;
endcase
end
end

endmodule : uart_tx
