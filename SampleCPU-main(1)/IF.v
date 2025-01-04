`include "lib/defines.vh"
module IF(
    input wire clk,           // ���룺ʱ���źţ�����ͬ����·
    input wire rst,           // ���룺��λ�źţ�����λΪ��ʱ��ϵͳ���ʼ��
    input wire [`StallBus-1:0] stall,   // ���룺��ͣ�źţ����Կ��Ƶ�Ԫ����ͣ�źţ����ڿ����Ƿ���ͣ��ˮ��
    
    input wire [`BR_WD-1:0] br_bus,      // ���룺����ID�ε���תָ����Ϣ��������תʹ�ܺ���ת��ַ

    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus,   // ���������ID�ε��������ߣ��������������ֵ��ʹ���ź�
    
    output wire inst_sram_en,                   // �����ָ��SRAMʹ���źţ������Ƿ���SRAM��ȡָ��
    output wire [3:0] inst_sram_wen,           // �����ָ��SRAM��дʹ���źţ���ʾ�Ƿ�д��SRAM
    output wire [31:0] inst_sram_addr,         // �����ָ��SRAM�ĵ�ַ��ָ��ָ��洢�ĵ�ַ
    output wire [31:0] inst_sram_wdata        // �����ָ��SRAMд������ݣ���ǰΪ��
);
    reg [31:0] pc_reg;  // �Ĵ����������������PC��ֵ�����ڱ��浱ǰ��PC
    reg ce_reg;         // �Ĵ�����ָ��Ĵ���ʹ���ź�
    wire [31:0] next_pc;  // �źţ���һ�����������ֵ
    wire br_e;          // �źţ���תʹ���źţ���ʾ�Ƿ���Ҫ��ת
    wire [31:0] br_addr; // �źţ���ת��ַ������תʹ���ź�Ϊ1����ʹ�øõ�ַ
/*br_bus [32:0]�Ǵ� ID ���н��յ�����תָ��ı���һ��ָ����źš�
���а����� br_e ��תʹ���źţ�br_addr[31:0]��ת��ֵַ��
��br_eΪ1ʱ���� br_addr[31:0]��ֵʱ���� br_addr[31:0]��ֵ����ǰָ��� pc ֵ��
���ҽ��� pc ֵ����ָ��Ĵ������Ӷ��� ID �εó���ת���ָ��*/
    assign {    // �� `br_bus` ���Ϊ `br_e` �� `br_addr`������ br_e ��ʾ��תʹ�ܣ�br_addr Ϊ��ת��ַ
        br_e,
        br_addr
    } = br_bus;

    always @ (posedge clk) begin    // ��ʱ�ӵ������أ����ݸ�λ����ͣ�źŸ���PCֵ
        if (rst) begin    // ����λ�ź�Ϊ��ʱ����pc�Ĵ������㣬��ʼ��Ϊ32'hbfbf_fffc������Ϊ������ַ��
            pc_reg <= 32'hbfbf_fffc;
        end
        else if (stall[0]==`NoStop) begin     // ���û����ͣ�źţ�����PCΪ��һ��PC
            pc_reg <= next_pc;
        end
    end
/*stall[5:0]�Ǵ�CTRL.v�ļ��н��յ�����ͣ�źţ�
���stall[0]==1'b1,�� pc ֵ������һ��ʱ�����ڵ�ֵ���䣬ʹ֮������ͣ������*/
    always @ (posedge clk) begin     // ��ʱ�ӵ������أ����ݸ�λ����ͣ�źŸ���CE�Ĵ�����ʹ���ź�
        if (rst) begin    // �����λ�ź�Ϊ�ߣ����ʹ���ź�
            ce_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop) begin    // ���û����ͣ�źţ�����CEʹ���ź�Ϊ1
            ce_reg <= 1'b1;
        end
    end
    // ������һ��PCֵ��
    // ��� br_e Ϊ1����ʾ������ת��PCֵ�� br_addr �ṩ������PCֵ����4��������һ��ָ�
    assign next_pc = br_e ? br_addr 
                   : pc_reg + 32'h4;
 
    // ����ָ��SRAM����ź�
    assign inst_sram_en = ce_reg;     //CE�Ĵ���ʹ���źſ���ָ��SRAM�Ƿ���Զ�ȡָ��
    assign inst_sram_wen = 4'b0;    // ָ��SRAM������д����������дʹ���ź�Ϊ0
    assign inst_sram_addr =pc_reg;    // ָ��SRAM�ĵ�ַ�ɵ�ǰPCֵ�ṩ
    assign inst_sram_wdata = 32'b0;    // ָ��SRAM��д���ݣ�����д����Ϊ0
    assign if_to_id_bus = {     // ��PCֵ��CEʹ���źŴ�������͵�ID�׶�
        ce_reg,
        pc_reg
    };

endmodule