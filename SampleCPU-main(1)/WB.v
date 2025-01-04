`include "lib/defines.vh"
module WB(
    input wire clk,  // ʱ���ź�
    input wire rst,  // �����ź�
    // input wire flush,  // ����źţ����б�ע�͵���˵��δʹ�ã�
    input wire [`StallBus-1:0] stall,  // ��ˮ����ͣ�źţ����ڿ���������

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,  // �� MEM �׶δ���������

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,  // ���ݸ� RF���Ĵ����ļ�������������
    
    output wire [37:0] wb_to_id_bus,  // ���ݸ� ID �׶ε�����
    
    output wire [31:0] debug_wb_pc,  // ���ڵ��Ե� WB �׶�ָ���ַ
    output wire [3:0] debug_wb_rf_wen,  // ���ڵ��ԵļĴ���дʹ���ź�
    output wire [4:0] debug_wb_rf_wnum,  // ���ڵ��ԵļĴ���д��ַ
    output wire [31:0] debug_wb_rf_wdata,  // ���ڵ��ԵļĴ���д����
    
    input wire[65:0] mem_to_wb1,  // �� MEM �׶δ�������������
    output wire[65:0] wb_to_id_wf,  // ���ݸ� ID �׶ε����ݣ�������λ�͵�λ�Ĵ�����
    output wire[65:0] wb_to_id_2  // ��һ�����ݸ� ID �׶ε����ݣ�������λ�͵�λ�Ĵ�����
);
// �����Ĵ������ڴ洢�� MEM �׶δ���������
    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;  // �洢 MEM �׶ε�������
    reg [65:0] mem_to_wb1_r;  // �洢 MEM �׶εĸߵͼĴ�������
// ʱ���߼������� MEM �׶ε� WB �׶ε����ݴ���
    always @ (posedge clk) begin
        if (rst) begin  // ����и�λ�źţ��򽫼Ĵ�������
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;  // ��� MEM �� WB ������
            mem_to_wb1_r <= 66'b0;  // ��� MEM �� WB ����������
        end
        // else if (flush) begin  // ����� flush �źţ�����������ݣ����б�ע�ͣ�δʹ�ã�
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin  // �����ˮ�ߴ���ֹͣ״̬
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;  // �������
            mem_to_wb1_r <= 66'b0;  // �������
        end
        else if (stall[4]==`NoStop) begin  // �����ˮ��δֹͣ
            mem_to_wb_bus_r <= mem_to_wb_bus;  // �� MEM �׶ε����ݴ��ݸ� WB �׶�
            mem_to_wb1_r <= mem_to_wb1;  // ���������ݴ��ݸ� WB �׶�
        end
    end

    // ������ MEM �׶δ������ź�
    wire [31:0] wb_pc;  // WB �׶�ָ��ĵ�ַ
    wire rf_we;  // �Ĵ���дʹ���ź�
    wire [4:0] rf_waddr;  // �Ĵ���д��ַ
    wire [31:0] rf_wdata;  // �Ĵ���д����
    
    wire w_hi_we;  // ��λ�Ĵ���дʹ���ź�
    wire w_lo_we;  // ��λ�Ĵ���дʹ���ź�
    wire [31:0] hi_i;  // ��λ�Ĵ���������
    wire [31:0] lo_i;  // ��λ�Ĵ���������

    // �� mem_to_wb_bus_r �Ĵ����н�������
    assign {
        wb_pc,  // ȡ�� MEM �׶ε�ָ���ַ
        rf_we,  // ȡ���Ĵ���дʹ���ź�
        rf_waddr,  // ȡ���Ĵ���д��ַ
        rf_wdata  // ȡ���Ĵ���д����
    } = mem_to_wb_bus_r;
    // �� mem_to_wb1_r �Ĵ����н���ߵ�λ�Ĵ���������
    assign {
        w_hi_we,  // ��λ�Ĵ���дʹ��
        w_lo_we,  // ��λ�Ĵ���дʹ��
        hi_i,     // ��λ�Ĵ���������
        lo_i      // ��λ�Ĵ���������
    } = mem_to_wb1_r;

    // ���ߵͼĴ������ݴ��ݸ� ID �׶�
    assign wb_to_id_wf = {
        w_hi_we,  // ��λ�Ĵ���дʹ��
        w_lo_we,  // ��λ�Ĵ���дʹ��
        hi_i,     // ��λ�Ĵ���������
        lo_i      // ��λ�Ĵ���������
    };

    assign wb_to_id_2 = {
        w_hi_we,  // ��λ�Ĵ���дʹ��
        w_lo_we,  // ��λ�Ĵ���дʹ��
        hi_i,     // ��λ�Ĵ���������
        lo_i      // ��λ�Ĵ���������
    };


    // ���� WB �׶�Ҫд�ؼĴ����ļ�������
    assign wb_to_rf_bus = {
        rf_we,    // �Ĵ���дʹ���ź�
        rf_waddr, // �Ĵ���д��ַ
        rf_wdata  // �Ĵ���д����
    };
   // ������ص�ָ���ǰָ����Ҫȡǰ����δд��Ĵ���������ʱ��WB �׶���ǰ����Щ���ݷ��� ID �׶Σ�
   //�� ID �׶���ת�����Ĵ����ļ���regfile.v���У�ȷ�� rs �� rt �Ĵ����ܵõ���ȷ��ֵ
    assign wb_to_id_bus = {
        rf_we,    // �Ĵ���дʹ���ź�
        rf_waddr, // �Ĵ���д��ַ
        rf_wdata  // �Ĵ���д����
    };
// Debug ��������ڵ��� WB �׶ε��������
    assign debug_wb_pc = wb_pc;  // �����ǰָ���ַ
    assign debug_wb_rf_wen = {4{rf_we}};  // ����Ĵ���дʹ���źţ���չΪ 4 λ��
    assign debug_wb_rf_wnum = rf_waddr;  // ����Ĵ���д��ַ
    assign debug_wb_rf_wdata = rf_wdata;  // ����Ĵ���д����

    
endmodule