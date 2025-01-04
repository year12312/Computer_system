`include "lib/defines.vh"
module IF(
    input wire clk,           //ʱ���ź�
    input wire rst,           //��λ�ź�
    input wire [`StallBus-1:0] stall,   //��ͣ�ź�

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
/*br_bus [32:0]�Ǵ� ID ���н��յ�����תָ��ı���һ��ָ����źš�
���а����� br_e ��תʹ���źţ�br_addr[31:0]��ת��ֵַ��
��br_eΪ1ʱ���� br_addr[31:0]��ֵʱ���� br_addr[31:0]��ֵ����ǰָ��� pc ֵ��
���ҽ��� pc ֵ����ָ��Ĵ������Ӷ��� ID �εó���ת���ָ��*/
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
/*stall[5:0]�Ǵ�CTRL.v�ļ��н��յ�����ͣ�źţ�
���stall[0]==1'b1,�� pc ֵ������һ��ʱ�����ڵ�ֵ���䣬ʹ֮������ͣ������*/
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