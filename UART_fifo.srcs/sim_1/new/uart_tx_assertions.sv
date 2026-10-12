`timescale 1ns / 1ps

module uart_tx_assertions #(
parameter DATA_WIDTH   = 8,   
parameter CLKS_PER_BIT = 434, 
parameter BIT_CNT_W    = $clog2(DATA_WIDTH)
)(
input  logic                   clk,
input  logic                   reset,
// Parallel data input (FIFO read interface)
input  logic [DATA_WIDTH-1:0] tx_data,
input  logic                   tx_valid,
input  logic                   tx_ready,
// Serial output
input  logic                   tx_out,
// Status
input  logic                   busy,

// Internal design signals bound from the target RTL
// NOTE: Replace the 3-bit logic with the actual internal state enum type if needed
input  logic [2:0]             state,
input  logic [31:0]            clk_count,
input  logic [BIT_CNT_W-1:0]   bit_index,
input  logic [DATA_WIDTH-1:0]  tx_data_reg
);

// Local parameters matching the FSM encoding of your TX module
localparam IDLE       = 3'b000;
localparam START_BIT  = 3'b001;
localparam DATA_BITS  = 3'b010;
localparam STOP_BIT   = 3'b011;
localparam CLEANUP    = 3'b100;

// Local expression representing the end of a bit window duration
logic bit_done_tick;
assign bit_done_tick = (clk_count == (CLKS_PER_BIT - 1));

// =========================================================================
// Category 1: Reset & Idle State Assertions
// =========================================================================

// Post-Reset Initial States: Validating output initializations upon falling edge of reset
property p1;
@(posedge clk) $fell(reset) |=> (tx_out == 1'b1 && tx_ready == 1'b1 && busy == 1'b0);
endproperty  
assert property(p1);  

// Idle Line State: In IDLE, the TX serial line must be held high at all times
property p2;
@(posedge clk) disable iff (reset) 
(state == IDLE) |-> (tx_out == 1'b1);
endproperty  
assert property(p2);  

// =========================================================================
// Category 2: Start Bit & Timing Accuracy
// =========================================================================

// Start Bit Generation: In START_BIT, the TX serial line must drop low to alert the receiver
property p3;
@(posedge clk) disable iff (reset) 
(state == START_BIT) |-> (tx_out == 1'b0);
endproperty  
assert property(p3);

// Intra-bit Stability: TX line cannot glitched or change outside of defined baud boundaries
property check_timing;
@(posedge clk) disable iff (reset) 
(!bit_done_tick && state != IDLE && state != CLEANUP) |-> $stable(tx_out);
endproperty
assert property(check_timing);

// =========================================================================
// Category 3: FIFO Protocol Handshaking
// =========================================================================

// Ready State Verification: Ready is asserted strictly when FSM sits in the IDLE loop
property ready_state;
@(posedge clk) disable iff (reset) 
(state == IDLE) |-> (tx_ready == 1'b1);
endproperty
assert property(ready_state);

// Handshake Capture: When valid and ready match, input parallel data must transfer into the shadow register
property both_high;
@(posedge clk) disable iff (reset) 
(tx_ready && tx_valid) |=> (tx_data_reg == $past(tx_data));
endproperty
assert property(both_high);

// Ready Protection: tx_ready must drop down the instant a frame leaves the IDLE loop
property tx_ready_low;
@(posedge clk) disable iff (reset)
(state != IDLE) |-> (~tx_ready);
endproperty
assert property(tx_ready_low);

// =========================================================================
// Category 4: Serialization & Bit Shifting
// =========================================================================

// Data Bit Driving: Checks if the correct array indexed bit is present on the serial line during the window
property serial_prop;
@(posedge clk) disable iff (reset) 
(state == DATA_BITS) |-> (tx_out == tx_data_reg[bit_index]);
endproperty
assert property(serial_prop);

// Bit Index Counter Progressions: Index steps forward on bit cycle completion boundaries
property bit_cnt_inc;
@(posedge clk) disable iff (reset)
(state == DATA_BITS && bit_done_tick && bit_index < (DATA_WIDTH - 1)) |=> (bit_index == $past(bit_index) + 1'b1);
endproperty
assert property(bit_cnt_inc);

// =========================================================================
// Category 5: Stop Bit & FSM Cleanup Sequencing
// =========================================================================

// Stop Bit Signaling: During the stop window, the serial output must return to line high
property check_stop;
@(posedge clk) disable iff (reset)
(state == STOP_BIT) |-> (tx_out == 1'b1);
endproperty 
assert property(check_stop);

// FSM Exit Sequencing: Final stop bit clock transition drives the core back through CLEANUP to IDLE
property final_clean;
@(posedge clk) disable iff (reset)
(state == STOP_BIT && bit_done_tick) |=> (state == CLEANUP) ##1 (state == IDLE && tx_ready);
endproperty
assert property(final_clean);

// =========================================================================
// Category 6: Busy Tracking Logic
// =========================================================================

// Busy Active Status: Asserted any time processing takes place away from the IDLE baseline
property busy_nidle;
@(posedge clk) disable iff (reset) 
(state != IDLE) |-> (busy == 1'b1);
endproperty
assert property(busy_nidle);

// Busy Idle Status: Dropped entirely when resting inside IDLE
property busy_idle;
@(posedge clk) disable iff (reset) 
(state == IDLE) |-> (busy == 1'b0);
endproperty
assert property(busy_idle);

endmodule : uart_tx_assertions
