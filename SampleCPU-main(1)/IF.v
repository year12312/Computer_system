`include "lib/defines.vh"
module IF(
    input wire clk,           // 输入：时钟信号，用于同步电路
    input wire rst,           // 输入：复位信号，当复位为高时，系统会初始化
    input wire [`StallBus-1:0] stall,   // 输入：暂停信号，来自控制单元的暂停信号，用于控制是否暂停流水线
    
    input wire [`BR_WD-1:0] br_bus,      // 输入：来自ID段的跳转指令信息，包括跳转使能和跳转地址

    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus,   // 输出：送往ID段的数据总线，包含程序计数器值和使能信号
    
    output wire inst_sram_en,                   // 输出：指令SRAM使能信号，控制是否向SRAM读取指令
    output wire [3:0] inst_sram_wen,           // 输出：指令SRAM的写使能信号，表示是否写入SRAM
    output wire [31:0] inst_sram_addr,         // 输出：指令SRAM的地址，指定指令存储的地址
    output wire [31:0] inst_sram_wdata        // 输出：指令SRAM写入的数据，当前为零
);
    reg [31:0] pc_reg;  // 寄存器：程序计数器（PC）值，用于保存当前的PC
    reg ce_reg;         // 寄存器：指令寄存器使能信号
    wire [31:0] next_pc;  // 信号：下一个程序计数器值
    wire br_e;          // 信号：跳转使能信号，表示是否需要跳转
    wire [31:0] br_addr; // 信号：跳转地址，若跳转使能信号为1，则使用该地址
/*br_bus [32:0]是从 ID 段中接收到的跳转指令改变下一条指令的信号。
其中包括了 br_e 跳转使能信号，br_addr[31:0]跳转地址值。
当br_e为1时，且 br_addr[31:0]有值时，则将 br_addr[31:0]赋值给当前指令的 pc 值，
并且将此 pc 值发给指令寄存器，从而在 ID 段得出跳转后的指令*/
    assign {    // 将 `br_bus` 拆解为 `br_e` 和 `br_addr`，其中 br_e 表示跳转使能，br_addr 为跳转地址
        br_e,
        br_addr
    } = br_bus;

    always @ (posedge clk) begin    // 在时钟的上升沿，根据复位和暂停信号更新PC值
        if (rst) begin    // 当复位信号为高时，将pc寄存器清零，初始化为32'hbfbf_fffc（假设为启动地址）
            pc_reg <= 32'hbfbf_fffc;
        end
        else if (stall[0]==`NoStop) begin     // 如果没有暂停信号，更新PC为下一个PC
            pc_reg <= next_pc;
        end
    end
/*stall[5:0]是从CTRL.v文件中接收到的暂停信号，
如果stall[0]==1'b1,则 pc 值保持上一个时钟周期的值不变，使之发生暂停操作。*/
    always @ (posedge clk) begin     // 在时钟的上升沿，根据复位和暂停信号更新CE寄存器，使能信号
        if (rst) begin    // 如果复位信号为高，清除使能信号
            ce_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop) begin    // 如果没有暂停信号，设置CE使能信号为1
            ce_reg <= 1'b1;
        end
    end
    // 计算下一个PC值：
    // 如果 br_e 为1，表示发生跳转，PC值由 br_addr 提供；否则，PC值自增4（跳到下一条指令）
    assign next_pc = br_e ? br_addr 
                   : pc_reg + 32'h4;
 
    // 配置指令SRAM相关信号
    assign inst_sram_en = ce_reg;     //CE寄存器使能信号控制指令SRAM是否可以读取指令
    assign inst_sram_wen = 4'b0;    // 指令SRAM不进行写操作，设置写使能信号为0
    assign inst_sram_addr =pc_reg;    // 指令SRAM的地址由当前PC值提供
    assign inst_sram_wdata = 32'b0;    // 指令SRAM不写数据，设置写数据为0
    assign if_to_id_bus = {     // 将PC值和CE使能信号打包，发送到ID阶段
        ce_reg,
        pc_reg
    };

endmodule