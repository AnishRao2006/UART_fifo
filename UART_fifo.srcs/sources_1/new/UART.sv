`timescale 1ns / 1ps

/*
TOP-MODULE of the whole system.
*/ 

module UART
    #(
    parameter DEPTH = 16,
    parameter DATA_WIDTH   = 8,   // Configurable data width (typically 8)
    parameter CLKS_PER_BIT = 868  // Example: 50MHz clock / 115200 baud = 434
    )(
    //system inputs
    input logic clk,
    input logic reset,
    //write side FIFO
    input logic wr_en,
    input logic [(DATA_WIDTH)-1:0] wr_data,
    output logic full, 
    //read side FIFO
    input logic rd_en,
    output logic [(DATA_WIDTH)-1:0] rd_data,
    output logic empty
    );
    
//internal wires between modules    
logic [(DATA_WIDTH)-1:0] tx_data;   
logic tx_out;
logic tx_valid;

logic [(DATA_WIDTH)-1:0] rx_data; 
logic rx_valid;
    
//fifo_tx
fifo #(DATA_WIDTH,DEPTH) fifo_tx (.clk(clk),
                                  .reset(~reset),
                                  .wr_en(wr_en),
                                  .full(full),
                                  .wr_data(wr_data),
                                  .rd_data(tx_data),
                                  .empty(tx_valid),
                                  .rd_en(tx_ready)); 
     
//transmitter
uart_tx #(DATA_WIDTH,CLKS_PER_BIT) transmit (.clk(clk),
                                            .reset(reset),
                                            .tx_data(tx_data),
                                            .tx_valid(~tx_valid),
                                            .tx_ready(tx_ready),
                                            .tx_out(tx_out),
                                            .busy());

//reciever
uart_rx #(DATA_WIDTH,CLKS_PER_BIT) recieve (.clk(clk),
                                           .reset(reset),
                                           .rx_in(tx_out),
                                           .rx_data(rx_data),
                                           .rx_valid(rx_valid),
                                           .busy(),
                                           .framing_error(),
                                           .parity_error());

//fifo_rx    
fifo #(DATA_WIDTH,DEPTH) fifo_rx (.clk(clk),
                                  .reset(~reset),
                                  .rd_en(rd_en),
                                  .empty(empty),
                                  .rd_data(rd_data),
                                  .wr_data(rx_data),
                                  .full(),
                                  .wr_en(rx_valid));     
    
endmodule : UART
