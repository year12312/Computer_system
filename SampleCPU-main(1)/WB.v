`include "lib/defines.vh"
module WB(
    input wire clk,  // 时钟信号
    input wire rst,  // 重置信号
    // input wire flush,  // 清空信号（此行被注释掉，说明未使用）
    input wire [`StallBus-1:0] stall,  // 流水线暂停信号，用于控制数据流

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,  // 从 MEM 阶段传来的数据

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,  // 传递给 RF（寄存器文件）的数据总线
    
    output wire [37:0] wb_to_id_bus,  // 传递给 ID 阶段的总线
    
    output wire [31:0] debug_wb_pc,  // 用于调试的 WB 阶段指令地址
    output wire [3:0] debug_wb_rf_wen,  // 用于调试的寄存器写使能信号
    output wire [4:0] debug_wb_rf_wnum,  // 用于调试的寄存器写地址
    output wire [31:0] debug_wb_rf_wdata,  // 用于调试的寄存器写数据
    
    input wire[65:0] mem_to_wb1,  // 从 MEM 阶段传来的其他数据
    output wire[65:0] wb_to_id_wf,  // 传递给 ID 阶段的数据（包含高位和低位寄存器）
    output wire[65:0] wb_to_id_2  // 另一个传递给 ID 阶段的数据（包含高位和低位寄存器）
);
// 声明寄存器用于存储从 MEM 阶段传来的数据
    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;  // 存储 MEM 阶段的主数据
    reg [65:0] mem_to_wb1_r;  // 存储 MEM 阶段的高低寄存器数据
// 时序逻辑，处理 MEM 阶段到 WB 阶段的数据传递
    always @ (posedge clk) begin
        if (rst) begin  // 如果有复位信号，则将寄存器清零
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;  // 清空 MEM 到 WB 的数据
            mem_to_wb1_r <= 66'b0;  // 清空 MEM 到 WB 的其他数据
        end
        // else if (flush) begin  // 如果有 flush 信号，可以清空数据（此行被注释，未使用）
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin  // 如果流水线处于停止状态
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;  // 清空数据
            mem_to_wb1_r <= 66'b0;  // 清空数据
        end
        else if (stall[4]==`NoStop) begin  // 如果流水线未停止
            mem_to_wb_bus_r <= mem_to_wb_bus;  // 将 MEM 阶段的数据传递给 WB 阶段
            mem_to_wb1_r <= mem_to_wb1;  // 将其他数据传递给 WB 阶段
        end
    end

    // 声明从 MEM 阶段传来的信号
    wire [31:0] wb_pc;  // WB 阶段指令的地址
    wire rf_we;  // 寄存器写使能信号
    wire [4:0] rf_waddr;  // 寄存器写地址
    wire [31:0] rf_wdata;  // 寄存器写数据
    
    wire w_hi_we;  // 高位寄存器写使能信号
    wire w_lo_we;  // 低位寄存器写使能信号
    wire [31:0] hi_i;  // 高位寄存器的数据
    wire [31:0] lo_i;  // 低位寄存器的数据

    // 从 mem_to_wb_bus_r 寄存器中解码数据
    assign {
        wb_pc,  // 取出 MEM 阶段的指令地址
        rf_we,  // 取出寄存器写使能信号
        rf_waddr,  // 取出寄存器写地址
        rf_wdata  // 取出寄存器写数据
    } = mem_to_wb_bus_r;
    // 从 mem_to_wb1_r 寄存器中解码高低位寄存器的数据
    assign {
        w_hi_we,  // 高位寄存器写使能
        w_lo_we,  // 低位寄存器写使能
        hi_i,     // 高位寄存器的数据
        lo_i      // 低位寄存器的数据
    } = mem_to_wb1_r;

    // 将高低寄存器数据传递给 ID 阶段
    assign wb_to_id_wf = {
        w_hi_we,  // 高位寄存器写使能
        w_lo_we,  // 低位寄存器写使能
        hi_i,     // 高位寄存器的数据
        lo_i      // 低位寄存器的数据
    };

    assign wb_to_id_2 = {
        w_hi_we,  // 高位寄存器写使能
        w_lo_we,  // 低位寄存器写使能
        hi_i,     // 高位寄存器的数据
        lo_i      // 低位寄存器的数据
    };


    // 传递 WB 阶段要写回寄存器文件的数据
    assign wb_to_rf_bus = {
        rf_we,    // 寄存器写使能信号
        rf_waddr, // 寄存器写地址
        rf_wdata  // 寄存器写数据
    };
   // 数据相关的指令，当前指令需要取前面尚未写入寄存器的数据时，WB 阶段提前将这些数据发给 ID 阶段，
   //由 ID 阶段再转发给寄存器文件（regfile.v）中，确保 rs 和 rt 寄存器能得到正确的值
    assign wb_to_id_bus = {
        rf_we,    // 寄存器写使能信号
        rf_waddr, // 寄存器写地址
        rf_wdata  // 寄存器写数据
    };
// Debug 输出，用于调试 WB 阶段的相关数据
    assign debug_wb_pc = wb_pc;  // 输出当前指令地址
    assign debug_wb_rf_wen = {4{rf_we}};  // 输出寄存器写使能信号（扩展为 4 位）
    assign debug_wb_rf_wnum = rf_waddr;  // 输出寄存器写地址
    assign debug_wb_rf_wdata = rf_wdata;  // 输出寄存器写数据

    
endmodule