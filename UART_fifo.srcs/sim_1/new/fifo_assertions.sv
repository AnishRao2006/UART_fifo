`timescale 1ns / 1ps

//assertion file to later bind to the fifo design
module fifo_assertions
    #(
    parameter data_width = 8,
    parameter depth = 16
    )
    (
    input logic clk,reset,
    //status probes
    input logic rd_en,wr_en,
    //output probes
    input logic full,empty,
    //input,output write/read
    input logic [(data_width)-1:0] wr_data,
    input logic [(data_width)-1:0] rd_data,
    //pointers
    input logic [$clog2(depth):0] wr_ptr,rd_ptr
    );
    
//SVA - to check the data and pointer integreties
//full and empty probes cannot be both high anytime in the system
property p1;
@(posedge clk) !(full && empty);
endproperty
assert property (p1);
//initially empty should be asserted
property p2;
@(posedge clk) !reset |-> (empty && !full);
endproperty
assert property (p2);
//just at reset both the pointer much be set to 0
property p3;
@(posedge clk) !reset |-> (wr_ptr == 0) and (rd_ptr == 0);
endproperty
assert property (p3);
//when fifo is full write pointer should not change
property p4;
logic [$clog2(depth):0] temp;
@(posedge clk) (wr_en && full,temp = wr_ptr) |-> ##1 (temp == wr_ptr);
endproperty
assert property (p4);
//when fifo is empty read pointer should not change
property p5;
logic [$clog2(depth):0] temp;
@(posedge clk) (rd_en && empty,temp = rd_ptr) |-> ##1 (temp == rd_ptr);
endproperty
assert property (p5);
//when reading from fifo, the read pointer should increament by only one
property p6;
logic [$clog2(depth):0] temp;
@(posedge clk) (rd_en && !empty,temp = rd_ptr) |-> ##1 (rd_ptr == temp + 1);
endproperty
assert property (p6);
//when writing into a fifo, the write pointer should increament by only one
property p7;
logic [$clog2(depth):0] temp;
@(posedge clk) (wr_en && !full,temp = wr_ptr) |-> ##1 (wr_ptr == temp + 1);
endproperty
assert property (p7);
//when a write is performed when fifo is empty, next clock cycle the empty should be deaserted
property p8;
@(posedge clk) (wr_en && !full && empty) |-> ##1 !empty;
endproperty
assert property (p8);    
    
endmodule : fifo_assertions

