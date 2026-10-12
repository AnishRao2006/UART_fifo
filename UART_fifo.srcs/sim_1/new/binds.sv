`timescale 1ns / 1ps

module binds();

//binding it with fifo
bind fifo fifo_assertions f_assert (.*);

//binding it with uart_tx
bind uart_tx uart_tx_assertions tx_assert (.*);

//binding it with the uart_rx
bind uart_rx uart_rx_assertions rx_assert (.*);

endmodule : binds
