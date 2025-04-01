`timescale 1ns / 1ps

module dht11 (
    input clk,
    input reset,
    input btn_start,
    output [4:0] led,
    output [7:0] humidity,
    output [7:0] temperature,
    output data_valid,
    inout dht_io  // inout port
);

    wire w_tick;
    dht11_cnt U_Dht11_cntl (
        .clk(clk),
        .reset(reset),
        .tick(w_tick),
        .start(btn_start),
        .led(led),
        .humidity(humidity),
        .temperature(temperature),
        .data_valid(data_valid),
        .dht_io(dht_io)
    );

    tick_gen tick_1us (
        .clk  (clk),
        .reset(reset),
        .tick (w_tick)
    );
endmodule



module dht11_cnt (
    input clk,
    input reset,
    input tick,
    input start,
    output [4:0] led,
    output [7:0] humidity,
    output [7:0] temperature,
    output data_valid,
    inout dht_io
);
    parameter START_CNT = 18000, WAIT_CNT = 30, SYNC_CNT = 80, DATA_0 = 40,
              TIME_OUT = 10000;
    parameter DEBOUNCE_TIME = 3000000; // 3초 (1us * 3,000,000 = 3s)

    localparam IDLE = 0, START = 1, WAIT = 2, SYNC_LOW = 3, SYNC_HIGH = 4,
               DATA_S = 5, DATA_READ = 6, CHECK_SUM = 7, STOP = 8;

    reg [3:0] c_state, n_state;
    reg [$clog2(START_CNT)-1:0] count_reg, count_next;
    reg io_oe_reg, io_oe_next;
    reg io_out_reg, io_out_next;
    reg led_ind_reg, led_ind_next;
    reg [5:0] bit_counter, bit_counter_next;
    reg [15:0] high_width_reg, high_width_next;
    reg [39:0] bit_data, bit_data_next;
    reg [39:0] bit_buffer, bit_buffer_next;
    reg [7:0] humidity_o, humidity_o_next, temperature_o, temperature_o_next;
    reg data_valid_reg, data_valid_next;
    //reg start_reg; // start 신호의 이전 값을 저장하는 레지스터 (제거)
    //wire start_edge; // start 신호의 상승 에지를 나타내는 신호 (제거)
    reg [$clog2(DEBOUNCE_TIME)-1:0] debounce_counter, debounce_counter_next;
    reg start_enable, start_enable_next;
    reg start_pressed, start_pressed_next; // 버튼이 눌린 상태를 나타내는 신호 추가

    assign dht_io = (io_oe_reg) ? io_out_reg : 1'bz;
    assign led = {led_ind_reg, c_state};
    assign data_valid = data_valid_reg;
    assign humidity = humidity_o;
    assign temperature = temperature_o;
    //assign start_edge = (start == 1'b1) && (start_reg == 1'b0); // start 신호의 상승 에지 감지 (제거)

    // Sequential logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state        <= IDLE;
            count_reg      <= 0;
            io_out_reg     <= 1'b1;
            io_oe_reg      <= 0;
            bit_counter    <= 0;
            high_width_reg <= 0;
            bit_data       <= 0;
            bit_buffer     <= 0;
            humidity_o     <= 8'h00;
            temperature_o  <= 8'h00;
            data_valid_reg <= 0;
            led_ind_reg    <= 0;
            //start_reg      <= 0; // start_reg 초기화 (제거)
            debounce_counter <= 0;
            start_enable <= 1'b1;
            start_pressed <= 1'b0; // start_pressed 초기화
        end else begin
            c_state        <= n_state;
            count_reg      <= count_next;
            io_out_reg     <= io_out_next;
            io_oe_reg      <= io_oe_next;
            bit_counter    <= bit_counter_next;
            high_width_reg <= high_width_next;
            bit_data       <= bit_data_next;
            bit_buffer     <= bit_buffer_next;
            humidity_o     <= humidity_o_next;
            temperature_o  <= temperature_o_next;
            data_valid_reg <= data_valid_next;
            led_ind_reg    <= led_ind_next;
            //start_reg      <= start; // start 신호의 현재 값을 start_reg에 저장 (제거)
            debounce_counter <= debounce_counter_next;
            start_enable <= start_enable_next;
            start_pressed <= start_pressed_next; // start_pressed 업데이트
        end
    end

    // Combinational logic
    always @(*) begin
        n_state            = c_state;
        count_next         = count_reg;
        io_out_next        = io_out_reg;
        io_oe_next         = io_oe_reg;
        bit_counter_next   = bit_counter;
        high_width_next    = high_width_reg;
        bit_data_next      = bit_data;
        bit_buffer_next    = bit_buffer;
        humidity_o_next    = humidity_o;
        temperature_o_next = temperature_o;
        data_valid_next    = data_valid_reg;
        led_ind_next       = led_ind_reg;
        debounce_counter_next = debounce_counter;
        start_enable_next = start_enable;
        start_pressed_next = start_pressed; // 기본적으로는 이전 값 유지

        case (c_state)
            IDLE: begin
                io_out_next = 1'b1;
                io_oe_next = 1'b1;
                data_valid_next = 0;
                led_ind_next = 1'b1;
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영

                if (start && start_enable) begin // 버튼이 눌리고 start_enable이 활성화된 경우
                    led_ind_next = 1'b0;
                    n_state    = START;
                    count_next = 0;
                    start_enable_next = 1'b0;
                    debounce_counter_next = 0;
                end
                else if(!start_enable) begin
                    if(tick) begin
                        if(debounce_counter == DEBOUNCE_TIME -1) begin
                            start_enable_next = 1'b1;
                            debounce_counter_next = 0;
                        end
                        else begin
                            debounce_counter_next = debounce_counter + 1;
                        end
                    end
                end
            end

            START: begin
                io_out_next = 1'b0;
                io_oe_next  = 1'b1;
                led_ind_next = 1'b0;
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (tick) begin
                    if (count_reg == START_CNT) begin
                        n_state    = WAIT;
                        count_next = 0;
                    end else begin
                        count_next = count_reg + 1;
                    end
                end
            end

            WAIT: begin
                io_out_next = 1'b1;
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (tick) begin
                    if (count_reg == WAIT_CNT) begin
                        n_state    = SYNC_LOW;
                        count_next = 0;
                    end else begin
                        count_next = count_reg + 1;
                    end
                end
            end

            SYNC_LOW: begin
                io_oe_next = 1'b0;
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (tick) begin
                    if (count_reg == SYNC_CNT) begin
                        n_state    = SYNC_HIGH;
                        count_next = 0;
                    end else begin
                        count_next = count_reg + 1;
                    end
                end
            end

            SYNC_HIGH: begin
                io_oe_next = 1'b0;
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (tick) begin
                    if (count_reg == SYNC_CNT) begin
                        n_state    = DATA_S;
                        count_next = 0;
                    end else begin
                        count_next = count_reg + 1;
                    end
                end
            end

            DATA_S: begin
                high_width_next = 0;
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (dht_io == 1'b1) begin
                    n_state         = DATA_READ;
                    count_next      = 0;
                end
            end

            DATA_READ: begin
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (tick) begin // 1us 마다 실행되는 로직
                    if (dht_io == 1'b1) begin // dht_io가 high인 경우 (high pulse 측정 중)
                        high_width_next = high_width_reg + 1; // high pulse 길이 측정 카운터 증가

                    end else begin // dht_io가 low인 경우 (high pulse 종료)
                        bit_data_next = {bit_data[39:0], (high_width_reg > DATA_0)}; // high pulse 길이가 DATA_0보다 길면 '1', 아니면 '0'으로 판단하여 bit_data에 저장
                        high_width_next = 0; // high pulse 길이 측정 카운터 초기화

                        if (bit_counter == 39) begin // 40비트(데이터 40비트)를 모두 읽었으면
                            n_state = CHECK_SUM; // CHECK_SUM 상태로 이동
                            bit_counter_next = 0; // bit_counter 초기화
                            bit_buffer_next = bit_data; // bit_data를 bit_buffer에 저장
                        end else begin // 아직 40비트를 다 읽지 못했으면
                            n_state = DATA_S; // 다음 비트를 읽기 위해 DATA_S 상태로 이동
                            bit_counter_next = bit_counter + 1; // bit_counter 증가
                        end
                    end
                end
            end

            CHECK_SUM: begin
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (tick) begin
                    if (bit_data[7:0] == bit_data[39:32] + bit_data[31:24] + bit_data[23:16] + bit_data[15:8]) begin
                    humidity_o_next    = bit_data[39:32];
                    temperature_o_next = bit_data[23:16];
                    n_state = STOP;
                    end
                    humidity_o_next    = {1'b0,bit_data[38:32]};
                    temperature_o_next = bit_data[23:16];
                    n_state = STOP;
                end
            end

            STOP: begin
                start_pressed_next = start; // 버튼이 눌린 상태를 start_pressed_next에 반영
                if (tick) begin
                    // humidity_o_next    = bit_buffer[39:32];
                    // temperature_o_next = bit_buffer[23:16];
                    if (count_reg == TIME_OUT - 1) begin
                        data_valid_next = 1;
                        n_state = IDLE;
                        count_next = 0;
                    end else begin
                        count_next = count_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule



module tick_gen #(
    parameter DIV = 100
) (
    input clk,
    input reset,
    output reg tick
);

    reg [$clog2(DIV)-1:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;
            tick  <= 0;
        end else if (count == DIV - 1) begin
            count <= 0;
            tick  <= 1;
        end else begin
            count <= count + 1;
            tick  <= 0;
        end
    end
endmodule
