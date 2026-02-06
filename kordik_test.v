`timescale 1ns/1ps

module cordic_atan #(
    parameter DATA_WIDTH  = 12,
    parameter ANGLE_WIDTH = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire signed [DATA_WIDTH-1:0]  xin,
    input  wire signed [DATA_WIDTH-1:0]  yin,
    input  wire                       vld_in,
    output reg  signed [ANGLE_WIDTH-1:0] angle,  // 输出：角度 × 64
    output reg                        vld_out
);
    
    // ==================== CORDIC参数 ====================
    parameter ITERATIONS = 12;
    
    // 注意：这里角度表存储的是角度值 × 64
    // arctan(2^-i) 的角度值（度）
    localparam real ATAN_DEG_TABLE [0:ITERATIONS-1] = '{
        45.000000,  // arctan(1)
        26.565051,  // arctan(1/2)
        14.036243,  // arctan(1/4)
        7.125016,   // arctan(1/8)
        3.576334,   // arctan(1/16)
        1.789911,   // arctan(1/32)
        0.895174,   // arctan(1/64)
        0.447614,   // arctan(1/128)
        0.223811,   // arctan(1/256)
        0.111906,   // arctan(1/512)
        0.055953,   // arctan(1/1024)
        0.027976    // arctan(1/2048)
    };
    
    // 角度表定点化（×64）
    reg signed [ANGLE_WIDTH-1:0] angle_table [0:ITERATIONS-1];
    
    // ==================== 流水线寄存器 ====================
    reg signed [DATA_WIDTH:0] x [0:ITERATIONS];
    reg signed [DATA_WIDTH:0] y [0:ITERATIONS];
    reg signed [ANGLE_WIDTH-1:0] z [0:ITERATIONS];
    reg vld_pipe [0:ITERATIONS];
    
    // ==================== 初始化角度表 ====================
    integer i;
    initial begin
        for (i = 0; i < ITERATIONS; i = i + 1) begin
            // 将角度值乘以64存储
            angle_table[i] = $rtoi(ATAN_DEG_TABLE[i] * 64.0);
        end
    end
    
    // ==================== CORDIC流水线 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= ITERATIONS; i = i + 1) begin
                x[i] <= 0;
                y[i] <= 0;
                z[i] <= 0;
                vld_pipe[i] <= 0;
            end
            angle <= 0;
            vld_out <= 0;
        end else begin
            // 第0级：预处理和象限映射
            if (vld_in) begin
                // 将输入映射到第一象限
                if (xin < 0 && yin >= 0) begin
                    // 第二象限 => 第一象限，角度增加90度
                    x[0] <= yin;
                    y[0] <= -xin;
                    z[0] <= 90 * 64;  // 90度 × 64
                end else if (xin < 0 && yin < 0) begin
                    // 第三象限 => 第一象限，角度增加180度
                    x[0] <= -xin;
                    y[0] <= -yin;
                    z[0] <= 180 * 64;  // 180度 × 64
                end else if (xin >= 0 && yin < 0) begin
                    // 第四象限 => 第一象限，角度减少90度
                    x[0] <= -yin;
                    y[0] <= xin;
                    z[0] <= -90 * 64;  // -90度 × 64
                end else begin
                    // 第一象限
                    x[0] <= xin;
                    y[0] <= yin;
                    z[0] <= 0;
                end
                vld_pipe[0] <= 1'b1;
            end else begin
                vld_pipe[0] <= 1'b0;
            end
            
            // CORDIC迭代
            for (i = 0; i < ITERATIONS; i = i + 1) begin
                if (vld_pipe[i]) begin
                    if (y[i] >= 0) begin
                        // 顺时针旋转
                        x[i+1] <= x[i] + (y[i] >>> i);
                        y[i+1] <= y[i] - (x[i] >>> i);
                        z[i+1] <= z[i] + angle_table[i];
                    end else begin
                        // 逆时针旋转
                        x[i+1] <= x[i] - (y[i] >>> i);
                        y[i+1] <= y[i] + (x[i] >>> i);
                        z[i+1] <= z[i] - angle_table[i];
                    end
                end
                vld_pipe[i+1] <= vld_pipe[i];
            end
            
            // 输出
            angle <= z[ITERATIONS];
            vld_out <= vld_pipe[ITERATIONS];
        end
    end
    
endmodule