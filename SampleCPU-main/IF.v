`include "lib/defines.vh"
module IF(
    input wire clk,           //时钟信号
    input wire rst,           //复位信号
    input wire [`StallBus-1:0] stall,   //暂停信号

    input wire [`BR_WD-1:0] br_bus,

    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata
);
    reg [31:0] pc_reg;
    reg ce_reg;
    wire [31:0] next_pc;
    wire br_e;
    wire [31:0] br_addr;
/*br_bus [32:0]是从 ID 段中接收到的跳转指令改变下一条指令的信号。
其中包括了 br_e 跳转使能信号，br_addr[31:0]跳转地址值。
当br_e为1时，且 br_addr[31:0]有值时，则将 br_addr[31:0]赋值给当前指令的 pc 值，
并且将此 pc 值发给指令寄存器，从而在 ID 段得出跳转后的指令*/
    assign {
        br_e,
        br_addr
    } = br_bus;

    always @ (posedge clk) begin
        if (rst) begin
            pc_reg <= 32'hbfbf_fffc;
        end
        else if (stall[0]==`NoStop) begin
            pc_reg <= next_pc;
        end
    end
/*stall[5:0]是从CTRL.v文件中接收到的暂停信号，
如果stall[0]==1'b1,则 pc 值保持上一个时钟周期的值不变，使之发生暂停操作。*/
    always @ (posedge clk) begin
        if (rst) begin
            ce_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop) begin
            ce_reg <= 1'b1;
        end
    end


    assign next_pc = br_e ? br_addr 
                   : pc_reg + 32'h4;

    
    assign inst_sram_en = ce_reg; 
    assign inst_sram_wen = 4'b0;
    assign inst_sram_addr =pc_reg;
    assign inst_sram_wdata = 32'b0;
    assign if_to_id_bus = {
        ce_reg,
        pc_reg
    };

endmodule