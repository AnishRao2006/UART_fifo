`timescale 1ns / 1ns

module simple_uart();

localparam DEPTH = 16;
localparam DATA_WIDTH   = 8;   // Configurable data width (typically 8)
localparam CLKS_PER_BIT = 4;  // Example: 50MHz clock / 115200 baud = 434

logic clk = 0;
always #5 clk = ~clk;

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

// instantiation
UART #(.DEPTH(DEPTH),.DATA_WIDTH(DATA_WIDTH),.CLKS_PER_BIT(CLKS_PER_BIT)) DUT 
        (
            .clk(clk),
            .reset(reset),
            .wr_en(wr_en),
            .wr_data(wr_data),
            .full(full),
            .rd_en(rd_en),
            .rd_data(rd_data),
            .empty(empty)
        );
        
initial begin
reset = 1;wr_en = 0;wr_data = 0;rd_en = 0;
#10;
reset = 0;

#30;
wr_data = 221;
wr_en = 1;
#10;
wr_en = 0;

wait(!empty);
repeat(2) @(posedge clk);
rd_en = 1;
#10;
rd_en = 0;

#50;
$finish;
end    

endmodule : simple_uart
