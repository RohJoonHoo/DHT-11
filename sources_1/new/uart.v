`timescale 1ns / 1ps

module fifo (
    input clk,
    input reset,

    // write
    input  [7:0] wdata,
    input        wr,
    output       full,

    // read
    input        rd,
    output [7:0] rdata,
    output       empty
);
    wire [3:0] waddr, raddr;

    // module instance
    fifo_control_unit U_FIFO_CU (
        .clk(clk),
        .reset(reset),
        .wr(wr),
        .waddr(waddr),
        .full(full),
        .rd(rd),
        .raddr(raddr),
        .empty(empty)
    );

    register_file U_REG_FILE (
        .clk(clk),
        .waddr(waddr),
        .wdata(wdata),
        .wr((~full & wr)),
        .raddr(raddr),
        .rdata(rdata)
    );

endmodule


module uart_rx (
    input        clk,
    input        reset,
    input        tick,
    input        rx,
    output       rx_done,
    output [7:0] rx_data
);
    localparam IDLE = 2'b00;
    localparam START = 2'b01;
    localparam DATA = 2'b10;
    localparam STOP = 2'b11;

    reg [1:0] state, next_state;
    reg rx_done_reg, rx_done_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [4:0] tick_count_reg, tick_count_next;
    reg [7:0] rx_data_reg, rx_data_next;

    assign rx_done = rx_done_reg;
    assign rx_data = rx_data_reg;

    // state
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state          <= 0;
            rx_done_reg    <= 0;
            rx_data_reg    <= 0;
            bit_count_reg  <= 0;
            tick_count_reg <= 0;
        end else begin
            state          <= next_state;
            rx_done_reg    <= rx_done_next;
            rx_data_reg    <= rx_data_next;
            bit_count_reg  <= bit_count_next;
            tick_count_reg <= tick_count_next;
        end
    end

    always @(*) begin
        next_state = state;
        tick_count_next = tick_count_reg;
        bit_count_next = bit_count_reg;
        rx_data_next = rx_data_reg;
        rx_done_next = rx_done_reg;
        case (state)
            IDLE: begin
                tick_count_next = 0;
                bit_count_next = 0;
                rx_done_next = 0;
                if (rx == 1'b0) begin
                    next_state = START;
                end
            end
            START: begin
                if (tick == 1'b1) begin
                    if (tick_count_reg == 7) begin
                        next_state = DATA;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        rx_data_next[bit_count_reg] = rx;
                        tick_count_next = 0;
                        if (bit_count_reg == 7) begin
                            next_state = STOP;
                            bit_count_next = 0;
                        end else begin
                            next_state = DATA;
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                if (tick == 1'b1) begin
                    if (tick_count_reg == 23) begin
                        rx_done_next = 1'b1;
                        next_state = IDLE;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule

module baud_tick_gen (
    input  clk,
    input  reset,
    output baud_tick
);

    parameter BAUD_RATE = 9600;
    localparam BAUD_COUNT = (100_000_000 / BAUD_RATE) / 16;
    reg [$clog2(BAUD_COUNT)-1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;

    assign baud_tick = tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count_reg <= 0;
            tick_reg  <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg  <= tick_next;
        end
    end

    always @(*) begin
        count_next = count_reg;
        tick_next  = tick_reg;
        if (count_reg == BAUD_COUNT - 1) begin
            count_next = 0;
            tick_next  = tick_reg + 1;
        end else begin
            count_next = count_reg + 1;
            tick_next  = 1'b0;
        end
    end
endmodule

module uart_tx (
    input clk,
    input reset,
    input tick,
    input start_trigger,
    input [7:0] data_in,
    output o_tx,
    output o_tx_done
);
    // fsm
    parameter IDLE = 2'b00;
    parameter START = 2'b01;
    parameter DATA = 2'b10;
    parameter STOP = 2'b11;
    reg [7:0] data_in_reg, data_in_next;
    reg [2:0] state, next_state;
    reg tx_reg, tx_next;
    reg tx_done, tx_done_next;

    reg [2:0] data_counter, data_counter_next;
    reg [3:0] tick_count_reg, tick_count_next;

    assign o_tx = tx_reg;
    assign o_tx_done = tx_done;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= 1'b0;
            tx_reg <= 1'b1;
            tx_done <= 1'b0;
            data_counter <= 3'b000;
            tick_count_reg <= 4'h0;
            data_in_reg <= 0;
        end else begin
            state <= next_state;
            tx_reg <= tx_next;
            tx_done <= tx_done_next;
            data_counter <= data_counter_next;
            tick_count_reg <= tick_count_next;
            data_in_reg <= data_in_next;
        end
    end

    always @(*) begin
        next_state = state;
        tx_next = tx_reg;
        tx_done_next = tx_done;
        data_counter_next = data_counter;
        tick_count_next = tick_count_reg;
        data_in_next = data_in_reg;
        case (state)
            IDLE: begin
                tx_next = 1'b1;
                tx_done_next = 1'b0;
                tick_count_next = 4'h0;
                if (start_trigger) begin
                    next_state   = START;
                    data_in_next = data_in;
                end
            end
            START: begin
                tx_done_next = 1'b1;
                tx_next = 1'b0;
                if (tick == 1'b1) begin
                    if (tick_count_reg == 4'hf) begin
                        next_state = DATA;
                        data_counter_next = 3'b000;
                        tick_count_next = 4'h0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_reg[data_counter];
                if (tick == 1'b1) begin
                    if (tick_count_reg == 4'hf) begin
                        tick_count_next = 4'h0;
                        if (data_counter == 3'b111) begin
                            next_state = STOP;
                        end else begin
                            next_state = DATA;
                            data_counter_next = data_counter + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (tick == 1'b1) begin
                    if (tick_count_reg == 4'hf) begin
                        next_state = IDLE;
                        tick_count_next = 4'h0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module register_file (
    input clk,

    // write
    input [3:0] waddr,
    input [7:0] wdata,
    input wr,

    // read
    input  [3:0] raddr,
    output [7:0] rdata
);

    reg [7:0] mem[0:15];  // 4bit address

    //write
    always @(posedge clk) begin
        if (wr) begin
            mem[waddr] <= wdata;
        end
    end

    //read
    assign rdata = mem[raddr];

endmodule

module fifo_control_unit (
    input clk,
    input reset,
    // write
    input wr,
    output [3:0] waddr,
    output full,
    // read
    input rd,
    output [3:0] raddr,
    output empty
);

    reg full_reg, full_next;
    reg empty_reg, empty_next;

    reg [3:0] wptr_reg, wptr_next;
    reg [3:0] rptr_reg, rptr_next;

    assign full  = full_reg;
    assign empty = empty_reg;
    assign waddr = wptr_reg;
    assign raddr = rptr_reg;

    //state
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            full_reg  <= 0;
            empty_reg <= 1;
            wptr_reg  <= 0;
            rptr_reg  <= 0;
        end else begin
            full_reg  <= full_next;
            empty_reg <= empty_next;
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
        end
    end

    // next
    always @(*) begin
        full_next  = full_reg;
        empty_next = empty_reg;
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        case ({
            wr, rd
        })  // state 외부에서 입력으로 변경됨.
            2'b01: begin  // rd만 1 일때, read
                if (empty_reg == 1'b0) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                    if (wptr_reg == rptr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b10: begin  // wr만 1 일때, write
                if (full_reg == 1'b0) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b11: begin
                if (empty_reg == 1'b1) begin  // pop 먼저
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else if (full_reg == 1'b1) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else begin
                    wptr_next  = wptr_reg + 1;
                    rptr_next  = rptr_reg + 1;
                    empty_next = empty_reg;
                    full_next  = full_reg;
                end
            end
            default: begin
                wptr_next  = wptr_reg;
                rptr_next  = rptr_reg;
                full_next  = full_reg;
                empty_next = empty_reg;
            end
        endcase
    end

endmodule

module uart_ht_sender (
    input             clk,
    input             reset,
    input      [8:0]  humidity,
    input      [8:0]  temperature,
    input             fifo_full,     // TX FIFO 상태
    input             data_valid,    // 유효 데이터 신호
    output reg        wr,            // FIFO 쓰기 신호
    output reg [7:0]  wdata          // 전송 데이터
);

    parameter IDLE          = 0,
              LOAD_TEMP_STR = 1,
              WR_TEMP_STR   = 2,
              LOAD_TEMP     = 3,
              WR_TEMP       = 4,
              SEND_T        = 5,
              SEND_C        = 6,
              SEND_NL1      = 7,
              LOAD_HUMI_STR = 8,
              WR_HUMI_STR   = 9,
              LOAD_HUMI     = 10,
              WR_HUMI       = 11,
              SEND_P        = 12,
              SEND_NL2      = 13,
              WAIT = 14;

    reg [3:0] state;
    reg [8:0] latched_temp, latched_humi;
    reg [4:0] str_index;
    reg [2:0] num_index;
    reg [7:0] num_ascii_1 [0:2];
    reg [7:0] num_ascii_2 [0:2];

    wire [7:0] DIST_STR [0:20] = {
        "t","e","m","p","e","r","a","t","e"," ",":",
        "h","u","m","i","n","i","t","y"," ",":"
    };

    task convert_to_ascii;
        input [15:0] val;
        output [7:0] out0, out1, out2;
        reg [3:0] h, t, o;
        begin
            h = (val / 100) % 10;
            t = (val / 10) % 10;
            o = val % 10;

            if (val >= 100) begin
                out0 = h + 8'd48;
                out1 = t + 8'd48;
                out2 = o + 8'd48;
            end else if (val >= 10) begin
                out0 = t + 8'd48;
                out1 = o + 8'd48;
                out2 = 8'd0;
            end else begin
                out0 = o + 8'd48;
                out1 = 8'd0;
                out2 = 8'd0;
            end
        end
    endtask

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            wr <= 0;
            wdata <= 0;
            str_index <= 0;
            num_index <= 0;
            latched_temp <= 0;
            latched_humi <= 0;
        end else begin
            wr <= 0;
            case (state)
                IDLE: begin
                    if (data_valid && !fifo_full) begin
                        latched_temp <= temperature;
                        latched_humi <= humidity;
                        convert_to_ascii(temperature, num_ascii_1[0], num_ascii_1[1], num_ascii_1[2]);
                        convert_to_ascii(humidity, num_ascii_2[0], num_ascii_2[1], num_ascii_2[2]);
                        str_index <= 0;
                        state <= LOAD_TEMP_STR;
                    end
                end

                LOAD_TEMP_STR: begin
                    if (str_index < 11) begin
                        if (!fifo_full) begin
                            wdata <= DIST_STR[str_index];
                            wr <= 1;
                            state <= WR_TEMP_STR;
                        end
                    end else begin
                        num_index <= 0;
                        state <= LOAD_TEMP;
                    end
                end

                WR_TEMP_STR: begin
                    str_index <= str_index + 1;
                    state <= LOAD_TEMP_STR;
                end

                LOAD_TEMP: begin
                    if (num_index < 3) begin
                        if (num_ascii_1[num_index] != 8'd0 && !fifo_full) begin
                            wdata <= num_ascii_1[num_index];
                            wr <= 1;
                            state <= WR_TEMP;
                        end else if (num_ascii_1[num_index] == 8'd0) begin
                            num_index <= num_index + 1;
                        end
                    end else begin
                        state <= SEND_T;
                    end
                end

                WR_TEMP: begin
                    num_index <= num_index + 1;
                    state <= LOAD_TEMP;
                end

                SEND_T: begin
                    if (!fifo_full) begin
                        wdata <= "'";
                        wr <= 1;
                        state <= SEND_C;
                    end
                end

                SEND_C: begin
                    if (!fifo_full) begin
                        wdata <= "C";
                        wr <= 1;
                        state <= SEND_NL1;
                    end
                end

                SEND_NL1: begin
                    if (!fifo_full) begin
                        wdata <= "\n";
                        wr <= 1;
                        str_index <= 11;
                        state <= LOAD_HUMI_STR;
                    end
                end

                LOAD_HUMI_STR: begin
                    if (str_index < 21) begin
                        if (!fifo_full) begin
                            wdata <= DIST_STR[str_index];
                            wr <= 1;
                            state <= WR_HUMI_STR;
                        end
                    end else begin
                        num_index <= 0;
                        state <= LOAD_HUMI;
                    end
                end

                WR_HUMI_STR: begin
                    str_index <= str_index + 1;
                    state <= LOAD_HUMI_STR;
                end

                LOAD_HUMI: begin
                    if (num_index < 3) begin
                        if (num_ascii_2[num_index] != 8'd0 && !fifo_full) begin
                            wdata <= num_ascii_2[num_index];
                            wr <= 1;
                            state <= WR_HUMI;
                        end else if (num_ascii_2[num_index] == 8'd0) begin
                            num_index <= num_index + 1;
                        end
                    end else begin
                        state <= SEND_P;
                    end
                end

                WR_HUMI: begin
                    num_index <= num_index + 1;
                    state <= LOAD_HUMI;
                end

                SEND_P: begin
                    if (!fifo_full) begin
                        wdata <= "%";
                        wr <= 1;
                        state <= SEND_NL2;
                    end
                end

                SEND_NL2: begin
                    if (!fifo_full) begin
                        wr <= 1;
                        wdata <= "\n";
                        state <= WAIT;
                    end
                end
                WAIT: begin
                    if (!fifo_full) begin
                        wr <= 1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule

