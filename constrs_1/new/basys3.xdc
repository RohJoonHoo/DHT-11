`timescale 1ns / 1ps

module tb_dht_11;

    reg clk = 0;
    reg reset = 1;
    reg btn_start = 0;

    reg dht_sensor_data;
    reg io_oe;

    wire [3:0] led;
    wire [7:0] humidity;
    wire [7:0] temperature;
    wire dht_io;

    assign dht_io = (io_oe) ? dht_sensor_data : 1'bz;

    // DUT
    dht11 dut (
        .clk(clk),
        .reset(reset),
        .btn_start(btn_start),
        .led(led),
        .humidity(humidity),
        .temperature(temperature),
        .dht_io(dht_io)
    );

    // 100MHz clk
    always #5 clk = ~clk;

    // 1bit 전송 (50us Low + Xus High)
    task send_bit(input b);
        begin
            dht_sensor_data = 0;
            #50000;  // 50us low
            dht_sensor_data = 1;
            if (b) #70000;  // 1 → 70us high
            else #26000;  // 0 → 26us high
        end
    endtask

    task send_40bits(input [39:0] bits);
        integer i;
        begin
            for (i = 39; i >= 0; i = i - 1) send_bit(bits[i]);
        end
    endtask

    initial begin
        // 초기 상태
        clk = 0;
        reset = 1;
        io_oe = 0;
        btn_start = 0;
        dht_sensor_data = 1;

        #100;
        reset = 0;
        #100;

        btn_start = 1;
        #20;
        btn_start = 0;

        wait (dht_io === 1'b1);  // FSM이 dht_io를 Z로 만든 시점
        #3000;

        // 응답 시뮬레이션
        io_oe = 1;
        dht_sensor_data = 0;
        #80000;  // 80us LOW
        dht_sensor_data = 1;
        #80000;  // 80us HIGH

        // 40bit 전송: humidity(0x2A), 0x00, temp(0x1C), 0x00, checksum(0x46)
        send_40bits({8'h2A, 8'h00, 8'h1C, 8'h00, 8'h46});

        dht_sensor_data = 0;
        #50000;
        io_oe = 0;
        #500000;


        btn_start = 1;
        #20;
        btn_start = 0;

        wait (dht_io === 1'b1);  // FSM이 dht_io를 Z로 만든 시점
        #30000;

        // 응답 시뮬레이션
        io_oe = 1;
        dht_sensor_data = 0;
        #80000;  // 80us LOW
        dht_sensor_data = 1;
        #80000;  // 80us HIGH

        // 40bit 전송: humidity(0x2A), 0x00, temp(0x1C), 0x00, checksum(0x46)
        send_40bits({8'h55, 8'h00, 8'h44, 8'h00, 8'h99});

        dht_sensor_data = 0;
        #50000;
        io_oe = 0;

        #500000;

        $display("Humidity: %d", humidity);
        $display("Temperature: %d", temperature);

        $stop;
    end

endmodule
