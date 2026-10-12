`timescale 1ns / 1ps

module uart_rx_assertions #(
parameter DATA_WIDTH   = 8,   
parameter CLKS_PER_BIT = 434, 
parameter BIT_CNT_W    = $clog2(DATA_WIDTH)
)(
input  logic                   clk,
input  logic                   reset,
// External Interface Signals
input  logic                   rx_in,
input  logic [DATA_WIDTH-1:0] rx_data,
input  logic                   rx_valid,
input  logic                   busy,
input  logic                   framing_error,
input  logic                   parity_error,

// Internal Design States & Signals for Binding
// NOTE: Replace these with the actual internal state enum type from your design
input  logic [2:0]             state, 
input  logic [31:0]            clk_count,
input  logic [BIT_CNT_W-1:0]   bit_index,
input  logic [DATA_WIDTH-1:0]  rx_data_reg,
input  logic                   rx_sync
);

// Local parameters matching the FSM encoding of your RX module
localparam IDLE       = 3'b000;
localparam START_BIT  = 3'b001;
localparam DATA_BITS  = 3'b010;
localparam STOP_BIT   = 3'b011;
localparam CLEANUP    = 3'b100;

// Derived expressions for sampling midpoints and bit end points
logic sample_tick;
assign sample_tick = (clk_count == (CLKS_PER_BIT / 2));

logic bit_done_tick;
assign bit_done_tick = (clk_count == (CLKS_PER_BIT - 1));

// =========================================================================
// Category 1: Start Bit Detection & Noise Rejection
// =========================================================================

// Start bit detection: A falling edge on synchronized rx line moves FSM from IDLE to START_BIT
property check_start_bit;
@(posedge clk) disable iff (reset)
(state == IDLE && rx_sync == 1'b0) |=> (state == START_BIT);
endproperty     
assert property(check_start_bit);

// Noise rejection: If rx line recovers to 1'b1 at the midpoint check, FSM aborts back to IDLE
property noise_reject;
@(posedge clk) disable iff (reset)
(state == START_BIT && sample_tick && rx_sync == 1'b1) |=> (state == IDLE);
endproperty 
assert property(noise_reject);

// Valid Start Bit: If rx line stays 1'b0 at the midpoint check, FSM holds until full bit duration
property valid_start_bit;
@(posedge clk) disable iff (reset)
(state == START_BIT && sample_tick && rx_sync == 1'b0) |=> (state == DATA_BITS);
endproperty 
assert property(valid_start_bit);

// =========================================================================
// Category 2: Data Bits (Serial-to-Parallel Conversion)
// =========================================================================

// Parallel Shift Verification: Right when a bit timing window closes, the new serial bit is shifted into rx_data_reg LSB first
property data_bits_shift;
@(posedge clk) disable iff (reset)
(state == DATA_BITS && bit_done_tick) |=> (rx_data_reg[$past(bit_index)] == $past(rx_sync));
endproperty
assert property(data_bits_shift);

// Bit Index Increment: The bit index counts upwards while inside DATA_BITS at each bit boundary transition
property bit_cnt_inc;
@(posedge clk) disable iff (reset)
(state == DATA_BITS && bit_done_tick && bit_index < (DATA_WIDTH - 1)) |=> (bit_index == $past(bit_index) + 1'b1);
endproperty
assert property(bit_cnt_inc);

// FSM Transition to Stop Bit: Once all bits have arrived, the FSM moves forward to the STOP_BIT state
property data_to_stop;
@(posedge clk) disable iff (reset)
(state == DATA_BITS && bit_done_tick && bit_index == (DATA_WIDTH - 1)) |=> (state == STOP_BIT);
endproperty
assert property(data_to_stop);

// =========================================================================
// Category 3: Parity Verification (Configured for No Parity)
// =========================================================================

// Your code explicitly forces parity error low since it operates in 8N1 mode
property no_parity_error;
@(posedge clk) disable iff (reset)
parity_error == 1'b0;
endproperty
assert property(no_parity_error);

// =========================================================================
// Category 4: Stop Bits & Framing Errors
// =========================================================================

// Valid Framing Sequence: If stop bit registers high at full duration, FSM transitions to CLEANUP and flags valid data
property stop_to_cleanup_valid;
@(posedge clk) disable iff (reset)
(state == STOP_BIT && bit_done_tick && rx_sync == 1'b1) |=> (state == CLEANUP && rx_valid && rx_data == $past(rx_data_reg));
endproperty
assert property(stop_to_cleanup_valid);

// Framing Error Sequence: If stop bit drops low at full duration, FSM flags framing error and suppresses rx_valid
property framing_error_assert;
@(posedge clk) disable iff (reset)
(state == STOP_BIT && bit_done_tick && rx_sync == 1'b0) |=> (state == CLEANUP && framing_error && !rx_valid);
endproperty
assert property(framing_error_assert);

// Error Persistence: framing_error output should hold its status code until a new start bit transaction arrives
property framing_error_hold;
@(posedge clk) disable iff (reset)
(framing_error && state != IDLE) |=> framing_error;
endproperty
assert property(framing_error_hold);

// =========================================================================
// Category 5: Output Handshake (rx_valid / Timing)
// =========================================================================

// rx_valid Single Pulse Enforcement: rx_valid must fall back down right on the next clock edge
property rx_valid_pulse_width;
@(posedge clk) disable iff (reset)
rx_valid |=> !rx_valid;
endproperty
assert property(rx_valid_pulse_width);

// Cleanup to IDLE Transition: The cleanup block serves to separate frames and drops cleanly back to IDLE
property cleanup_to_idle;
@(posedge clk) disable iff (reset)
(state == CLEANUP) |=> (state == IDLE);
endproperty
assert property(cleanup_to_idle);

// =========================================================================
// Category 6: Busy Flag Tracking
// =========================================================================

// Busy Flag True Condition: Output asserts whenever execution is happening outside of the IDLE node
property busy_active;
@(posedge clk) disable iff (reset)
(state != IDLE) |-> busy;
endproperty
assert property(busy_active);

// Busy Flag False Condition: Output unsets completely when waiting for a frame inside IDLE
property busy_inactive;
@(posedge clk) disable iff (reset)
(state == IDLE) |-> !busy;
endproperty
assert property(busy_inactive);

endmodule : uart_rx_assertions
