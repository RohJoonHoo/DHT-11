`timescale 1ns / 1ps

module fnd_controller (
    input clk,
    input reset,
    input [15:0] number,
    output [7:0] seg,
    output [3:0] an
);

    wire [3:0]  w_bcd,
                w_digit_1, w_digit_10, 
                w_digit_100, w_digit_1000; 

    wire [2:0] w_seg_sel;
    wire w_clk_100hz;

    clk_divider U_Clk_Divider (
        .clk  (clk),
        .reset(reset),
        .o_clk(w_clk_100hz)
    );
    counter_8 U_Counter_8 (
        .clk  (w_clk_100hz),
        .reset(reset),
        .o_sel(w_seg_sel)
    );
    decoder_3x8 U_decoder_3x8 (
        .seg_sel (w_seg_sel),
        .seg_comm(an)
    );

    
    digit_splitter U_digit_splitter (
        .bcd(number),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );

    mux_8x1 U_Mux_8x1 (
        .sel(w_seg_sel),
        .x_0(w_digit_1),
        .x_1(w_digit_10),
        .x_2(w_digit_100),
        .x_3(w_digit_1000),
        .x_4(4'ha),
        .x_5(4'ha),
        .x_6(4'ha),
        .x_7(4'ha),
        .y  (w_bcd)
    );

    bcdtoseg U_bcdtoseg (
        .bcd(w_bcd),    // [3:0] sum 값 
        .seg(seg)
    );

endmodule

module clk_divider (
    input  clk,
    input  reset,
    output o_clk
);
    parameter FCOUNT = 10_000;  // 이름을 상수화하여 사용.
    // $clog2 : 수를 나타내는데 필요한 비트수 계산
    reg [$clog2(FCOUNT)-1:0] r_counter;
    reg r_clk;
    assign o_clk = r_clk;

    always @(posedge clk, posedge reset) begin
        if (reset) begin  // 
            r_counter <= 0;  // 리셋상태
            r_clk <= 1'b0;
        end else begin
            // clock divide 계산, 100Mhz -> 200hz
            if (r_counter == FCOUNT - 1) begin
                r_counter <= 0;
                r_clk <= 1'b1;  // r_clk : 0->1
            end else begin
                r_counter <= r_counter + 1;
                r_clk <= 1'b0;  // r_clk : 0으로 유지.;
            end
        end
    end
endmodule

module counter_8 (
    input        clk,
    input        reset,
    output [3:0] o_sel
);

    reg [3:0] r_counter;
    assign o_sel = r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
        end else begin
            r_counter <= r_counter + 1;
        end
    end
endmodule

module digit_splitter (
    input  [15:0] bcd,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
    assign digit_1  = bcd % 10;  
    assign digit_10 = bcd / 10 % 10; 
    assign digit_100 = bcd / 100 % 10;  
    assign digit_1000 = bcd / 1000 % 10;  
endmodule

module decoder_3x8 (
    input [2:0] seg_sel,
    output reg [3:0] seg_comm
);

    // 2x4 decoder
    always @(seg_sel) begin
        case (seg_sel)
            3'b000:  seg_comm = 4'b1110;
            3'b001:  seg_comm = 4'b1101;
            3'b010:  seg_comm = 4'b1011;
            3'b011:  seg_comm = 4'b0111;
            3'b100:  seg_comm = 4'b1110;
            3'b101:  seg_comm = 4'b1101;
            3'b110:  seg_comm = 4'b1011;
            3'b111:  seg_comm = 4'b0111;
            default: seg_comm = 4'b1110;
        endcase
    end
endmodule

module mux_8x1 (
    input [2:0] sel,
    input [3:0] x_0,
    input [3:0] x_1,
    input [3:0] x_2,
    input [3:0] x_3,
    input [3:0] x_4,
    input [3:0] x_5,
    input [3:0] x_6,
    input [3:0] x_7,
    output reg [3:0] y
);
    always @(*) begin
        case (sel)
            3'b000:  y = x_0;
            3'b001:  y = x_1;
            3'b010:  y = x_2;
            3'b011:  y = x_3;
            3'b100:  y = x_4;
            3'b101:  y = x_5;
            3'b110:  y = x_6;
            3'b111:  y = x_7;
            default: y = 4'bx;
        endcase
    end
endmodule

module bcdtoseg (
    input [3:0] bcd,  // [3:0] sum 값 
    output reg [7:0] seg
);
    // always 구문 출력으로 reg type을 가져야 한다.
    always @(bcd) begin

        case (bcd)
            4'h0: seg = 8'hc0;
            4'h1: seg = 8'hF9;
            4'h2: seg = 8'hA4;
            4'h3: seg = 8'hB0;
            4'h4: seg = 8'h99;
            4'h5: seg = 8'h92;
            4'h6: seg = 8'h82;
            4'h7: seg = 8'hf8;
            4'h8: seg = 8'h80;
            4'h9: seg = 8'h90;
            4'hf: seg = 8'h7f; //dot만 on
            default: seg = 8'hff; // all off
        endcase
    end
endmodule
