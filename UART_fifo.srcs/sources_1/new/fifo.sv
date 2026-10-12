`timescale 1ns / 1ps

module fifo
    #(
    parameter data_width = 8,
    parameter depth = 16
    )
    (
    input logic clk,reset,
    //status probes
    input logic rd_en,wr_en,
    //output probes
    output logic full,empty,
    //input,output write/read
    input logic [(data_width)-1:0] wr_data,
    output logic [(data_width)-1:0] rd_data
    );
    
    
(*ram_type = "block"*) logic [(data_width)-1:0] data_mem [depth];
logic [$clog2(depth):0] wr_ptr,rd_ptr;

initial begin
data_mem = '{default : '0};
wr_ptr = 0;
rd_ptr = 0;
end

always_ff @(posedge clk or negedge reset) begin
if(!reset) begin
data_mem <= '{default : '0};
wr_ptr <= 0;
rd_ptr <= 0;
end
else begin
if(wr_en && !full) begin
data_mem[wr_ptr[$clog2(depth)-1:0]] <= wr_data;
wr_ptr <= wr_ptr + 1;
end
else if(rd_en && !empty) begin
rd_data <= data_mem[rd_ptr[$clog2(depth)-1:0]];
rd_ptr <= rd_ptr + 1;
end
else begin
wr_ptr <= wr_ptr;
rd_ptr <= rd_ptr;
end
end
end     

assign empty = (wr_ptr == rd_ptr);
assign full = (wr_ptr[$clog2(depth)] != rd_ptr[$clog2(depth)] && (wr_ptr[$clog2(depth)-1:0] == rd_ptr[$clog2(depth)-1:0]));
    
endmodule : fifo
