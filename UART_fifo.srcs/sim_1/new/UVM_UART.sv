`timescale 1ns/1ns  

/*
UVM verification environment for a UART FIFO design.
This consists of all the UVM components and objects which makes this a complete testing environment.
First we verify if our FIFO works properly or no.
then we verify UART, then both integrated together.
*/

`include "uvm_macros.svh"
import uvm_pkg :: *;

// interface for UART
interface uart_if
    #(
    parameter DEPTH = 4,
    parameter DATA_WIDTH   = 8,   // Configurable data width (typically 8)
    parameter CLKS_PER_BIT = 4  // Example: 50MHz clock / 115200 baud = 434
    )(
    input logic clk
    );

//system inputs
logic reset;
//write side FIFO
logic wr_en;
logic [(DATA_WIDTH)-1:0] wr_data;
logic full;
//read side FIFO
logic rd_en;
logic [(DATA_WIDTH)-1:0] rd_data;
logic empty;

endinterface : uart_if

// transaction class
class transaction extends uvm_sequence_item;

`uvm_object_utils_begin(transaction)
`uvm_field_int(rx_data, UVM_ALL_ON)
`uvm_field_int(full, UVM_ALL_ON)
`uvm_field_int(empty, UVM_ALL_ON)
`uvm_object_utils_end

function new(string name = "transaction");
super.new(name);
endfunction

rand logic [7:0] tx_data;  //send data
logic [7:0] in_data;  //data for the input monitor
logic [7:0] rx_data;  //data for the output monitor
rand logic reset; // reset signal
rand logic [1:0] dir;  // 0 write-read 1 write only 2 read only
logic full,empty;

// signals to represent which sequence is active
rand logic [2:0] test_cases;

typedef enum logic [1:0] 
{
KIND_DATA = 0,
KIND_FULL = 1,
KIND_EMPTY = 2
}kinde;
kinde kind;
 
endclass : transaction

// reset sequence
class reset_sequence extends uvm_sequence #(transaction);

`uvm_object_utils(reset_sequence);

function new(string name = "reset_sequence");
super.new(name);
endfunction

task body();
transaction tx;
int count = 1;
repeat(count) begin
tx = transaction :: type_id :: create("tx");
tx.randomize() with {reset == 1;dir == 1;test_cases == 0;};
start_item(tx);
finish_item(tx);
end
endtask

endclass : reset_sequence

// random data written and read back to compare
class random_data extends uvm_sequence #(transaction);

`uvm_object_utils(random_data);

function new(string name = "random_data");
super.new(name);
endfunction

task body();
transaction tx;
int count = 1;
repeat(count) begin
tx = transaction::type_id::create("tx");
tx.randomize() with {reset == 0;dir == 0;test_cases == 1;};
start_item(tx);
finish_item(tx);
end
endtask

endclass : random_data

// writting continuosly 0x00
class data_0x00 extends uvm_sequence #(transaction);

`uvm_object_utils(data_0x00);

function new(string name = "data_0x00");
super.new(name);
endfunction

task body();
transaction tx;
int count = 1;
repeat(count) begin
tx = transaction::type_id::create("tx");
tx.randomize() with {reset == 0;dir == 0;tx_data == 'h00;test_cases == 2;};
start_item(tx);
finish_item(tx);
end
endtask

endclass : data_0x00

// writting continuosly 0xFF
class data_0xFF extends uvm_sequence #(transaction);

`uvm_object_utils(data_0xFF);

function new(string name = "data_0xFF");
super.new(name);
endfunction

task body();
transaction tx;
int count = 1;
repeat(count) begin
tx = transaction::type_id::create("tx");
tx.randomize() with {reset == 0;dir == 0;tx_data == 'hFF;test_cases == 3;};
start_item(tx);
finish_item(tx);
end
endtask

endclass : data_0xFF

// fill to full
class fill_to_full extends uvm_sequence #(transaction);

`uvm_object_utils(fill_to_full);

function new(string name = "fill_to_full");
super.new(name);
endfunction

task body();
transaction tx;
int count = 4;  //depth count
repeat(count) begin
tx = transaction::type_id::create("tx");
tx.randomize() with {reset == 0;dir == 1;test_cases == 4;};
start_item(tx);
finish_item(tx);
end
endtask

endclass : fill_to_full

// drain_to_empty
class drain_to_empty extends uvm_sequence #(transaction);

`uvm_object_utils(drain_to_empty);

function new(string name = "drain_to_empty");
super.new(name);
endfunction

task body();
transaction tx;
int count = 4;  //depth count
repeat(count) begin
tx = transaction::type_id::create("tx");
tx.randomize() with {reset == 0;dir == 2;test_cases == 5;};
start_item(tx);
finish_item(tx);
end
endtask

endclass : drain_to_empty

// input monitor to see what is being driven to compare.
class input_monitor extends uvm_monitor;

virtual uart_if in; 
uvm_analysis_port #(transaction) input_to_scoreboard;   

`uvm_component_utils(input_monitor);

function new(string name = "input_monitor",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
if(!uvm_config_db #(virtual uart_if) :: get(this,"","vif",in)) begin
`uvm_fatal("IMON", $sformatf("FAILED TO RECIEVE INTERFACE"));
end
input_to_scoreboard = new("input_to_scoreboard",this);
endfunction

task run_phase(uvm_phase phase);
transaction tx;
forever begin
@(negedge in.clk);
if(in.wr_en) begin
tx = transaction::type_id::create("tx");
tx.in_data = in.wr_data;
tx.full = in.full;
input_to_scoreboard.write(tx);
`uvm_info("IMON", $sformatf("data being driven to DUT = %d", in.wr_data), UVM_LOW);
end
end
endtask

endclass : input_monitor

// driver class
class driver extends uvm_driver #(transaction);

virtual uart_if in; 
uvm_analysis_port #(transaction) test_case;
transaction temp_tx;

`uvm_component_utils(driver);

function new(string name = "driver",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
if(!uvm_config_db #(virtual uart_if) :: get(this,"","vif",in)) begin
`uvm_fatal("DRV", $sformatf("FAILED TO RECIEVE INTERFACE"));
end
test_case = new("test_case",this);
endfunction

task run_phase(uvm_phase phase);
transaction tx;
forever begin
seq_item_port.get_next_item(tx);
temp_tx = transaction :: type_id :: create("temp_tx");
temp_tx = tx;
test_case.write(temp_tx);
if(tx.reset) begin
in.reset = 1;
in.wr_data = '0;
in.rd_en = 0;
in.wr_en = 0;
@(posedge in.clk);
in.reset = 0;
end
else begin
if(tx.dir == 0) begin
in.wr_data = tx.tx_data;
in.wr_en = 1;
`uvm_info("DRV", $sformatf("data driven to DUT is %d", tx.tx_data), UVM_LOW);
@(posedge in.clk);
in.wr_data = '0;
in.wr_en = 0;
// waiting for transmission to end
@(posedge in.clk);
`uvm_info("DRV", $sformatf("waiting for transmission to end..."), UVM_LOW);
wait(in.empty == 0);
repeat(3) @(posedge in.clk);
in.rd_en = 1;
`uvm_info("DRV", $sformatf("reading data out of fifo..."), UVM_LOW);
repeat(2) @(posedge in.clk);
in.rd_en = 0;
end
else if(tx.dir == 1) begin
in.wr_data = tx.tx_data;
in.wr_en = 1;
`uvm_info("DRV", $sformatf("data driven to DUT is %d", tx.tx_data), UVM_LOW);
@(posedge in.clk);
in.wr_data = '0;
in.wr_en = 0;
end
else if(tx.dir == 2) begin
@(posedge in.clk);
wait(in.empty == 0);
while(in.empty != 1) begin
repeat(2) @(posedge in.clk);
in.rd_en = 1;
`uvm_info("DRV", $sformatf("reading data out of fifo..."), UVM_LOW);
repeat(2) @(posedge in.clk);
in.rd_en = 0;
end
end
end
seq_item_port.item_done();
end
endtask

endclass : driver

// output monitor to get what was transmitted
class output_monitor extends uvm_monitor;

virtual uart_if in;
uvm_analysis_port #(transaction) mon_to_scoreboard;   
uvm_analysis_port #(transaction) mon_to_coverage; 
logic prev_full;
logic prev_empty;
transaction::kinde kind;

`uvm_component_utils(output_monitor);

function new(string name = "output_monitor",uvm_component parent);
super.new(name,parent);
endfunction    

function void build_phase(uvm_phase phase);
super.build_phase(phase);
if(!uvm_config_db #(virtual uart_if) :: get(this,"","vif",in)) begin
`uvm_fatal("OMON", $sformatf("FAILED TO RECIEVE INTERFACE"));
end
mon_to_scoreboard = new("mon_to_scoreboard",this);
mon_to_coverage = new("mon_to_coverage",this);
endfunction

task run_phase(uvm_phase phase);
transaction tx;
forever begin
@(posedge in.clk) begin
prev_full <= in.full;
prev_empty <= in.empty;
end
if(in.rd_en) begin
repeat(2) @(posedge in.clk);
tx = transaction::type_id::create("tx");
tx.rx_data = in.rd_data;
tx.empty = in.empty;
tx.full = in.full;
tx.kind = transaction::KIND_DATA;
`uvm_info("OMON", $sformatf("data being driven out of DUT = %d", in.rd_data), UVM_LOW);
mon_to_coverage.write(tx);
mon_to_scoreboard.write(tx);
end
if(in.full && !prev_full) begin
tx = transaction::type_id::create("tx");
tx.full = in.full;
tx.kind = transaction::KIND_FULL;
`uvm_info("OMON", $sformatf("full"), UVM_LOW);
mon_to_scoreboard.write(tx);
end
if(in.empty && !prev_empty) begin
tx = transaction::type_id::create("tx");
tx.empty = in.empty;
tx.kind = transaction::KIND_EMPTY;
`uvm_info("OMON", $sformatf("empty"), UVM_LOW);
mon_to_scoreboard.write(tx);
end
end
endtask

endclass : output_monitor

// scoreboard to test data integrity
class scoreboard extends uvm_scoreboard;

uvm_tlm_analysis_fifo #(transaction) input_to_scoreboard;
uvm_tlm_analysis_fifo #(transaction) mon_to_scoreboard;
uvm_tlm_analysis_fifo #(transaction) driver_to_scoreboard;
transaction tx_act,tx_exp,temp_tx;

int pass_count = 0;
int fail_count = 0;
int current_case = -1;

`uvm_component_utils(scoreboard);

function new(string name = "scoreboard", uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
input_to_scoreboard = new("input_to_scoreboard",this);
mon_to_scoreboard = new("mon_to_scoreboard",this);
driver_to_scoreboard = new("driver_to_scoreboard",this);
endfunction

task run_phase(uvm_phase phase);
forever begin
driver_to_scoreboard.get(temp_tx);
if(temp_tx.test_cases == current_case) continue;
current_case = temp_tx.test_cases;
case(current_case)
0 : check_reset();
1 : check_random_data();
2 : check_00();
3 : check_ff();
4 : fillfull();
5 : drainempty();
default : ;
endcase
end
endtask

// functions for scoreaboard
task get_act_tx(output transaction t);
do begin
mon_to_scoreboard.get(t);
end while(t.kind != transaction::KIND_DATA);
endtask

function void check_reset();
pass_count++;
`uvm_info("SCR", $sformatf("reset test pass"), UVM_LOW);
endfunction

task check_random_data();
input_to_scoreboard.get(tx_exp);
get_act_tx(tx_act);
if(tx_exp.in_data == tx_act.rx_data) begin
pass_count++;
`uvm_info("SCR", $sformatf("random test pass"), UVM_LOW);
end
else begin
fail_count++;
`uvm_info("SCR", $sformatf("random test fail"), UVM_LOW);
end
endtask

task check_00();
input_to_scoreboard.get(tx_exp);
get_act_tx(tx_act);
if(tx_exp.in_data == 'h00 && tx_act.rx_data == 'h00) begin
pass_count++;
`uvm_info("SCR", $sformatf("data 00 test pass"), UVM_LOW);
end
else begin
fail_count++;
`uvm_info("SCR", $sformatf("data 00 test fail"), UVM_LOW);
end
endtask

task check_ff();
input_to_scoreboard.get(tx_exp);
get_act_tx(tx_act);
if(tx_exp.in_data == 'hff && tx_act.rx_data == 'hff) begin
pass_count++;
`uvm_info("SCR", $sformatf("data ff test pass"), UVM_LOW);
end
else begin
fail_count++;
`uvm_info("SCR", $sformatf("data ff test fail"), UVM_LOW);
end
endtask

task fillfull();
repeat(4) input_to_scoreboard.get(tx_exp);
do begin
mon_to_scoreboard.get(tx_act);
end while(tx_act.kind != transaction::KIND_FULL);
if(tx_act.full) begin
pass_count++;
`uvm_info("SCR", $sformatf("full test pass"), UVM_LOW);
end
else begin
fail_count++;
`uvm_info("SCR", $sformatf("full test fail"), UVM_LOW);
end
endtask

task drainempty();
do begin
mon_to_scoreboard.get(tx_act);
end while(tx_act.kind != transaction::KIND_EMPTY);
if(tx_act.empty) begin
pass_count++;
`uvm_info("SCR", $sformatf("empty test pass"), UVM_LOW);
end
else begin
fail_count++;
`uvm_info("SCR", $sformatf("empty test fail"), UVM_LOW);
end
endtask

function void check_phase(uvm_phase phase);
super.check_phase(phase);
`uvm_info("SCR", $sformatf("Pass: %0d  Fail: %0d", pass_count, fail_count), UVM_LOW);
if(fail_count > 0) begin `uvm_error("SCR", $sformatf("DUT FAILED THE TEST")); end
else begin `uvm_info("SCR", $sformatf("DUT PASSED ALL THE TEST"), UVM_LOW); end
endfunction

endclass : scoreboard

// agent to connect classes
class agent extends uvm_agent;

driver drv;
uvm_sequencer #(transaction) seqr;
input_monitor imon;
output_monitor omon;

`uvm_component_utils(agent);

function new(string name = "agent", uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
drv = driver :: type_id :: create("drv",this);
seqr = uvm_sequencer #(transaction) :: type_id :: create("seqr",this);
imon = input_monitor :: type_id :: create("imon",this);
omon = output_monitor :: type_id :: create("omon",this);
endfunction

function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
drv.seq_item_port.connect(seqr.seq_item_export);
endfunction

endclass : agent

// coverage class
class coverage_class extends uvm_subscriber #(transaction);

transaction tx;
real get_cover;

`uvm_component_utils(coverage_class);

function new(string name = "coverage_class", uvm_component parent);
super.new(name,parent);
uart_cg = new();
endfunction

covergroup uart_cg;
//option.per_instance = 1;
RX_DATA : coverpoint tx.rx_data
{
    bins d00 = {'h00};
    bins dff = {'hff};
}
FULL : coverpoint tx.full;
EMPTY : coverpoint tx.empty;
endgroup

function void write(transaction t);
$cast(tx,t.clone());
//tx = t;
`uvm_info("CVRG",$sformatf("data is %d",tx.rx_data),UVM_LOW);
uart_cg.sample();
endfunction

function void report_phase(uvm_phase phase);
super.report_phase(phase);
get_cover = uart_cg.get_inst_coverage();
`uvm_info("CVRG", $sformatf("coverage percent = %.2f%%",get_cover), UVM_LOW);
endfunction

endclass : coverage_class

// environment class
class env extends uvm_env;

`uvm_component_utils(env);

function new(string name = "env", uvm_component parent);
super.new(name,parent);
endfunction

agent a;
scoreboard scr;
coverage_class cvr;

function void build_phase(uvm_phase phase);
super.build_phase(phase);
a = agent :: type_id :: create("a",this);
scr = scoreboard :: type_id :: create("scr",this);
cvr = coverage_class :: type_id :: create("cvr",this);
endfunction

function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
a.imon.input_to_scoreboard.connect(scr.input_to_scoreboard.analysis_export);
a.omon.mon_to_scoreboard.connect(scr.mon_to_scoreboard.analysis_export);
a.drv.test_case.connect(scr.driver_to_scoreboard.analysis_export);
a.omon.mon_to_coverage.connect(cvr.analysis_export);
endfunction

endclass : env

// test class
class test extends uvm_test;

`uvm_component_utils(test);

function new(string name = "test", uvm_component parent);
super.new(name,parent); 
endfunction

env e;

function void build_phase(uvm_phase phase);
super.build_phase(phase);
e = env :: type_id :: create("e",this);
endfunction 

task run_phase(uvm_phase phase);
random_data rd;
reset_sequence rs;
data_0x00 d00;
data_0xFF dff;
fill_to_full ftf;
drain_to_empty dte;
phase.raise_objection(this);
begin
rs = reset_sequence :: type_id :: create("rs");
rs.start(e.a.seqr);
end
#50;
begin
rd = random_data :: type_id :: create("rd");
rd.start(e.a.seqr);
end
#50;
begin
d00 = data_0x00 :: type_id :: create("d00");
d00.start(e.a.seqr);
end
#50;
begin
dff = data_0xFF :: type_id :: create("dff");
dff.start(e.a.seqr);
end
begin
ftf = fill_to_full :: type_id :: create("ftf");
ftf.start(e.a.seqr);
end
#50;
begin
dte = drain_to_empty :: type_id :: create("dte");
dte.start(e.a.seqr);
end
#50;
phase.drop_objection(this);
endtask

endclass : test

// MAIN MODULE
module UVM_UART();

logic clk = 0;
always #5 clk = ~clk;

localparam DEPTH = 4;
localparam DATA_WIDTH   = 8;   // Configurable data width (typically 8)
localparam CLKS_PER_BIT = 4;  // Example: 50MHz clock / 115200 baud = 434

uart_if phys_if(clk);

// instantiation
UART #(.DEPTH(DEPTH),.DATA_WIDTH(DATA_WIDTH),.CLKS_PER_BIT(CLKS_PER_BIT)) DUT 
        (
            .clk(phys_if.clk),
            .reset(phys_if.reset),
            .wr_en(phys_if.wr_en),
            .wr_data(phys_if.wr_data),
            .full(phys_if.full),
            .rd_en(phys_if.rd_en),
            .rd_data(phys_if.rd_data),
            .empty(phys_if.empty)
        );

initial begin
uvm_config_db #(virtual uart_if) :: set(null,"*","vif",phys_if);
run_test("test");
end

endmodule : UVM_UART