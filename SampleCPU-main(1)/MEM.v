`include "lib/defines.vh"
module MEM(
    input wire clk,                      // ʱ���ź�
    input wire rst,                      // �����ź�
    // input wire flush,                  // �����flush�źţ���������ָ��ˢ�£���ʱע�͵�
    input wire [`StallBus-1:0] stall,    // ͣ���źţ�������ˮ����ͣ

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,    // ��EX�׶δ�������������
    input wire [31:0] data_sram_rdata,   // �����ݴ洢����ȡ������

    output wire [37:0] mem_to_id_bus,    // ��ID�׶η��͵���������
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,  // ��WB�׶η��͵���������
    
    input wire [65:0] ex_to_mem1,        // EX�׶δ����ĵڶ����������ߣ�����hi��lo�Ĵ�����Ϣ
    output wire[65:0] mem_to_wb1,        // ��WB�׶η���hi��lo�Ĵ�����Ϣ
    output wire[65:0] mem_to_id_2        // ��ID�׶η���hi��lo�Ĵ�����Ϣ�����ڽ������ð��
);
    // ����Ĵ������ڱ�������EX�׶ε�����
    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;
    reg [65:0] ex_to_mem1_r;
    // ʱ�ӱ��ش���ʱִ��
    always @ (posedge clk) begin
        if (rst) begin    // ��λ���������Ĵ�������
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            ex_to_mem1_r <= 66'b0;
        end
        // else if (flush) begin    // �����flush�źţ���ռĴ�������ʱע�͵���
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin    // ���MEM�׶���Ҫ��ͣ��EX�׶β���ͣ������ռĴ���
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            ex_to_mem1_r <= 65'b0;
        end
        else if (stall[3]==`NoStop) begin    // ���MEM�׶β���Ҫ��ͣ����EX�׶ε����ݴ��ݸ�MEM�׶�
            ex_to_mem_bus_r <= ex_to_mem_bus;
            ex_to_mem1_r <= ex_to_mem1;
        end
    end
    // ��ex_to_mem_bus_r�н�������ź�
    wire [31:0] mem_pc;          // ָ���ַ
    wire data_ram_en;           // ���ݴ洢��ʹ���ź�
    wire [3:0] data_ram_wen;    // ���ݴ洢��дʹ���ź�
    wire [3:0] data_ram_read;   // ���ݴ洢����ʹ���ź�
    wire sel_rf_res;            // ����ѡ��д�ص��Ĵ����ļ�������
    wire rf_we;                 // �Ĵ����ļ�дʹ��
    wire [4:0] rf_waddr;        // �Ĵ����ļ�д��ַ
    wire [31:0] rf_wdata;       // д�ؼĴ���������
    wire [31:0] ex_result;      // EX�׶μ���Ľ��
    wire [31:0] mem_result;     // �����ݴ洢����ȡ������
    // ����hi��lo�Ĵ������ź�
    wire w_hi_we;               // дhi�Ĵ���ʹ��
    wire w_lo_we;               // дlo�Ĵ���ʹ��
    wire [31:0] hi_i;           // д��hi�Ĵ���������
    wire [31:0] lo_i;           // д��lo�Ĵ���������
  
// ���ex_to_mem_bus_r�źţ���ȡ��Ҫ����Ϣ
    assign {
        mem_pc,             // 75:44 ָ���ַ
        data_ram_en,        // 43 ���ݴ洢��ʹ��
        data_ram_wen,       // 42:39 ���ݴ洢��дʹ��
        sel_rf_res,         // 38 ѡ���Ƿ�д�ؼĴ���
        rf_we,              // 37 �Ĵ���дʹ��
        rf_waddr,           // 36:32 �Ĵ���д��ַ
        ex_result,          // 31:0 EX�׶μ�����
        data_ram_read       // ��ʹ���ź�
    } = ex_to_mem_bus_r;
// ���ex_to_mem1_r�źţ���ȡhi��lo�Ĵ������������
    assign {
        w_hi_we,          // hi�Ĵ���дʹ��
        w_lo_we,          // lo�Ĵ���дʹ��
        hi_i,             // hi�Ĵ�������
        lo_i              // lo�Ĵ�������
    } = ex_to_mem1_r;
    
    /*�� MEM ��Ҫ���͸� WB ��ֵ���������д hi �� lo �Ĵ���
    ��ʹ���źţ������ж��Ƿ����д�Ĵ����Ĳ���*/
   assign mem_to_wb1 = {
        w_hi_we,          // hi�Ĵ���дʹ��
        w_lo_we,          // lo�Ĵ���дʹ��
        hi_i,             // hi�Ĵ�������
        lo_i              // lo�Ĵ�������
    };
    
    /*MEM ��Ҫ���͸� ID ���е�regfile.v,���ڽ����һ��ָ��
    Ҫ�õ���һ��ָ�����hilo�Ĵ���ֵ������*/
    assign mem_to_id_2 = {
        w_hi_we,          // hi�Ĵ���дʹ��
        w_lo_we,          // lo�Ĵ���дʹ��
        hi_i,             // hi�Ĵ�������
        lo_i              // lo�Ĵ�������
    };

// MEM�׶δ����ݴ洢����ȡ�����ݣ�ͨ�����ڴ�����
    assign mem_result = data_sram_rdata;
// �����ڴ��������ѡ�񽫺�������д�ص��Ĵ����ļ�
    assign rf_wdata =  (data_ram_read==4'b1111 && data_ram_en==1'b1) ? mem_result :    // ����Ƕ�һ��������32λ����
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{24{mem_result[7]}},mem_result[7:0]}):  // ������ֽڶ�ȡ���Ҵ���͵�ַ��ʼ�����з�����չ
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({{24{mem_result[15]}},mem_result[15:8]}):  // ������ֽڶ�ȡ���Ҵӵ�1���ֽڿ�ʼ�����з�����չ
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{24{mem_result[23]}},mem_result[23:16]}):  // ������ֽڶ�ȡ���Ҵӵ�2���ֽڿ�ʼ�����з�����չ
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({{24{mem_result[31]}},mem_result[31:24]}):  // ������ֽڶ�ȡ���Ҵӵ�3���ֽڿ�ʼ�����з�����չ
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({24'b0,mem_result[7:0]}):  // ������ֽڶ�ȡ���Ҵ���͵�ַ��ʼ����������չ
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({24'b0,mem_result[15:8]}):  // ������ֽڶ�ȡ���Ҵӵ�1���ֽڿ�ʼ����������չ
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({24'b0,mem_result[23:16]}):  // ������ֽڶ�ȡ���Ҵӵ�2���ֽڿ�ʼ����������չ
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({24'b0,mem_result[31:24]}):  // ������ֽڶ�ȡ���Ҵӵ�3���ֽڿ�ʼ����������չ
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{16{mem_result[15]}},mem_result[15:0]}):  // ����ǰ��ֶ�ȡ���Ҵ���͵�ַ��ʼ�����з�����չ
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{16{mem_result[31]}},mem_result[31:16]}):  // ����ǰ��ֶ�ȡ���Ҵӵ�2���ֽڿ�ʼ�����з�����չ
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({16'b0,mem_result[15:0]}):  // ������ֶ�ȡ���Ҵ���͵�ַ��ʼ����������չ
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({16'b0,mem_result[31:16]}):  // ������ֶ�ȡ���Ҵӵ�2���ֽڿ�ʼ����������չ
                        ex_result;  // ���������������������Ĭ�Ϸ���EX�׶εļ�����
//MEM ��Ҫ���͸� WB �ε�ֵ
    assign mem_to_wb_bus = {
        mem_pc,    // 69:38 ����ָ��ĵ�ַ
        rf_we,     // 37   �Ĵ���дʹ���ź�
        rf_waddr,  // 36:32 �Ĵ���д��ַ
        rf_wdata   // 31:0 ��Ҫд��Ĵ���������
    };
/*��������йص�ָ�����ǰָ����Ҫȡǰ�滹δ����Ĵ�����ֵ��ʱ��
�� MEM ����ǰ���� ID �Σ����� ID �η��͸�regfile.v�ļ��У�
���и��� rs �� rt ����Ҫ�ļĴ�����ֵ��*/
    assign mem_to_id_bus = {
        rf_we,     // 37  �Ĵ���дʹ���ź�
        rf_waddr,  // 36:32 �Ĵ���д��ַ
        rf_wdata   // 31:0 ��Ҫд��Ĵ���������
    };


endmodule