`timescale 1ns / 1ps

module top_dht11 (
    input clk,
    input reset,
    input rx,
    output tx,
    output [4:0] led,
    output [7:0] seg,
    output [3:0] an,
    inout dht_io
);

    wire [7:0] w_rx_data;
    wire w_rx_done;
    wire start_send;
    wire tick;
    wire [7:0] wdata;
    wire wr_en;
    wire busy;
    wire [7:0] humi, temp;

    // Tick generator (1us)
    baud_tick_gen U_baud_tick (
        .clk(clk),
        .reset(reset),
        .baud_tick(tick)
    );

    // UART RX
    uart_rx uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .tick(tick),
        .rx(rx),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );


    // Start send trigger when 'd' or 'D' is received
    assign start_send = w_rx_done && (w_rx_data == 8'h64 || w_rx_data == 8'h44);

    dht11 U_dht11 (
        .clk(clk),
        .reset(reset),
        .btn_start(start_send),
        .led(led),
        .humidity(humi),
        .temperature(temp),
        .data_valid(data_valid),
        .dht_io(dht_io)
    );

    // FND Display
    fnd_controller fnd_inst (
        .clk(clk),
        .reset(reset),
        .number({8'b0, humi}),
        .seg(seg),
        .an(an)
    );

    assign humidity = humi;
    assign temperature = temp;

    wire tx_fifo_empty;
    wire [7:0] fifo_wdata, o_data;
    wire fifo_wr;
    wire o_tx_done;

    uart_ht_sender u_ht_sender (
        .clk(clk),
        .reset(reset),
        //.fifo_empty(tx_fifo_empty),
        .humidity(humi),
        .temperature(temp),
        .fifo_full(fifo_full),
        .data_valid(data_valid),
        .wdata(fifo_wdata),
        .wr(wr_en)
    );

    fifo tx_fifo (
        .clk(clk),
        .reset(reset),
        .wdata(fifo_wdata),
        .wr(wr_en),
        .full(fifo_full), 
        .rd(~tx_done), 
        .rdata(o_data),
        .empty(tx_fifo_empty)
    );

    uart_tx u_uart_tx (
        .clk(clk),
        .reset(reset),
        .tick(tick),
        .start_trigger(!tx_fifo_empty),
        .data_in(o_data),
        .o_tx(tx),
        .o_tx_done(tx_done)
    );

endmodule
