`include "lib/defines.vh"
module EX(
    input wire clk,                        // ʱ���ź�
    input wire rst,                        // ��λ�ź�
    // input wire flush,                  // ˢ���źţ�δʹ�ã�
    input wire [`StallBus-1:0] stall,     // ͣ���źţ�������ˮ����ͣ
    
    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,    // ���� ID �׶ε���������
    
//    input wire [67:0] id_to_ex_2,    // ��������ߣ�δʹ�ã�

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,    // ���͵� MEM �׶ε���������
    
    output wire [37:0] ex_to_id_bus,    // ���͵� ID �׶ε���������

    output wire data_sram_en,              // ���ݴ洢��ʹ���ź�
    output wire [3:0] data_sram_wen,       // ���ݴ洢��дʹ���ź�
    output wire [31:0] data_sram_addr,     // ���ݴ洢����ַ
    output wire [31:0] data_sram_wdata,    // ���ݴ洢��д�������
    output wire inst_is_load,              // ָʾ��ǰָ���Ƿ��Ǽ���ָ��
    
    output wire stallreq_for_ex,           // EX �׶��Ƿ�����ͣ��
    output wire [65:0] ex_to_mem1,         // ���͵� MEM �׶εĶ�������
    output wire [65:0] ex_to_id_2,         // ���͵� ID �׶εĶ�������
    output wire ready_ex_to_id             // EX �׶ε� ID �׶ε�׼���ź�
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;    // �Ĵ��������ڴ洢���� ID �׶ε���������
//    reg [67:0] id_to_ex_2_r;    // ���ڴ洢������������ݣ�δʹ�ã�

    always @ (posedge clk) begin    // ÿ��ʱ�����ڸ��¼Ĵ�����ֵ
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;    // ��λʱ�������
//            id_to_ex_2_r <= 68'b0;    // ��λʱ��ն�������
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;    // ˢ��ʱ�������
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;    // ������յ�ͣ���źţ��������
//            id_to_ex_2_r <= 68'b0;    // ͬ����ն�������
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;     // û��ͣ��ʱ�������� ID �׶ε�����
//            id_to_ex_2_r <= id_to_ex_2;    // ͬ�����ݶ�������
        end
    end
    // ���� EX �׶ε�һЩ�źźͼĴ���
    wire [31:0] ex_pc, inst;                    // ָ���������ָ��
    wire [11:0] alu_op;                         // ALU �����ź�
    wire [2:0] sel_alu_src1;                    // ALU Դ1ѡ���ź�
    wire [3:0] sel_alu_src2;                    // ALU Դ2ѡ���ź�
    wire data_ram_en;                           // ���ݴ洢��ʹ���ź�
    wire [3:0] data_ram_wen;                    // ���ݴ洢��дʹ���ź�
    wire [3:0] data_ram_read;                   // ���ݴ洢�����ź�
    wire rf_we;                                 // �Ĵ����ļ�дʹ���ź�
    wire [4:0] rf_waddr;                        // �Ĵ����ļ�д��ַ
    wire sel_rf_res;                            // �Ĵ����ļ����ѡ���ź�
    wire [31:0] rf_rdata1, rf_rdata2;           // �Ĵ����ļ���ȡ������
    reg is_in_delayslot;                        // ����Ƿ����ӳٲ�
    wire [1:0] lo_hi_r;                         // hi �� lo �Ĵ����Ķ��ź�
    wire [1:0] lo_hi_w;                         // hi �� lo �Ĵ�����д�ź�
    wire w_hi_we;                               // hi �Ĵ���дʹ���ź�
    wire w_lo_we;                               // lo �Ĵ���дʹ���ź�
    wire w_hi_we3;                              // hi �Ĵ�������һ��дʹ���ź�
    wire w_lo_we3;                              // lo �Ĵ�������һ��дʹ���ź�
    wire [31:0] hi_i;                          // hi �Ĵ�����������
    wire [31:0] lo_i;                          // lo �Ĵ�����������
    wire [31:0] hi_o;                          // hi �Ĵ����������
    wire [31:0] lo_o;                          // lo �Ĵ����������
    assign {    // �� id_to_ex_bus �Ĵ����л�ȡ���ݲ����в��
        ex_pc,          // ���������ֵ    158:127
        inst,           // ��ǰָ��    126:95
        alu_op,         // ALU ������    94:83
        sel_alu_src1,   // ALU Դ1ѡ��    82:80
        sel_alu_src2,   // ALU Դ2ѡ��    79:76
        data_ram_en,    // ���ݴ洢��ʹ��    75
        data_ram_wen,   // ���ݴ洢��дʹ��    74:71
        rf_we,          // �Ĵ���дʹ��    70
        rf_waddr,       // �Ĵ���д��ַ    69:65
        sel_rf_res,     // �Ĵ����ļ�д������ѡ��    64
        rf_rdata1,      // rs �Ĵ�������    63:32
        rf_rdata2,      // rt �Ĵ�������    31:0 
        lo_hi_r,        // hi �� lo �Ĵ����Ķ�ȡ�ź�    
        lo_hi_w,        // hi �� lo �Ĵ�����д���ź�    
        lo_o,           // lo �Ĵ������    
        hi_o,           // hi �Ĵ������    
        data_ram_read   // ���ݴ洢�����ź�    
    } = id_to_ex_bus_r;
    
    
    
//    wire inst_lsa;
//    assign inst_lsa  = (inst[31:26]==6'b01_1100)  & (inst[10:8]==3'b111) & (inst[5:0]==6'b11_0111);
//    wire [2:0] zuoyi;
//    assign zuoyi = inst_lsa ? (inst[7:6] + 1'b1) :  3'b0;
    
//   wire [31:0] aaa;
    
//    assign aaa = inst[7:6] == 2'b11 ?  ({rf_rdata1[27:0],4'b0}):
//                  inst[7:6] == 2'b00 ?  ({rf_rdata1[30:0],1'b0}):
//                  inst[7:6] == 2'b01 ?  ({rf_rdata1[29:0],2'b0}):
//                  inst[7:6] == 2'b10 ?  ({rf_rdata1[28:0],3'b0}):
//                  32'b0;
//    assign rf_rdata1 = inst_lsa ? aaa : rf_rdata1;
  
//    assign {
//        lo_hi_r,                        //read�ź�
//        lo_hi_w,                        //write�ź�
//        lo_o,                           //loֵ
//        hi_o                            //hiֵ
//      }= id_to_ex_2_r;
    
    assign w_lo_we3 = lo_hi_w[0]==1'b1 ? 1'b1:1'b0;    // �ж��Ƿ���Ҫд LO �Ĵ���
    assign w_hi_we3 = lo_hi_w[1]==1'b1 ? 1'b1:1'b0;    // �ж��Ƿ���Ҫд HI �Ĵ���
    
    assign inst_is_load =  (inst[31:26] == 6'b10_0011) ? 1'b1 :1'b0;    // �жϵ�ǰָ���Ƿ��� load ָ��� LW ָ�
    
    
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;    // ��������չ��������չ
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};    // ������չ�����������ĸ� 16 λ���ݷ���λ������չ
    assign imm_zero_extend = {16'b0, inst[15:0]};    // ����չ������ 16 λ���Ϊ 0
    assign sa_zero_extend = {27'b0,inst[10:6]};    // ��λ������sa����չ�� 32 λ���� 5 λΪ��������ֵ������λΪ 0
    // ѡ�� ALU ����Ĳ�����
    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;
    // ����ѡ���ź� sel_alu_src1 �� sel_alu_src2 ��ѡ�� ALU ������Դ
    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    // ���� ALU ģ����м���
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );
    // ���� EX �ε����ս����ѡ�� LO��HI �� ALU ������
    assign ex_result =  lo_hi_r[0] ? lo_o :
                         lo_hi_r[1] ? hi_o :
                         alu_result;

    // ���ݴ洢��ʹ���ź�
    assign data_sram_en = data_ram_en ;
    assign data_sram_wen = (data_ram_read==4'b0101 && ex_result[1:0] == 2'b00 )? 4'b0001:     // ���� ALU ����ĵ� 2 λ�����ݴ洢����ȡ�����ź���ѡ��дʹ���ź�
                            (data_ram_read==4'b0101 && ex_result[1:0] == 2'b01 )? 4'b0010:
                            (data_ram_read==4'b0101 && ex_result[1:0] == 2'b10 )? 4'b0100:
                            (data_ram_read==4'b0101 && ex_result[1:0] == 2'b11 )? 4'b1000:
                            (data_ram_read==4'b0111 && ex_result[1:0] == 2'b00 )? 4'b0011:
                            (data_ram_read==4'b0111 && ex_result[1:0] == 2'b10 )? 4'b1100:
                            data_ram_wen;
    //�� EX ��������Ľ�������洢������Ѱַ������Ѱַ�õ���ֵ���ݵ� MEM ����
    assign data_sram_addr = ex_result ;
    assign data_sram_wdata = data_sram_wen==4'b1111 ? rf_rdata2 : 
                              data_sram_wen==4'b0001 ? {24'b0,rf_rdata2[7:0]} :
                              data_sram_wen==4'b0010 ? {16'b0,rf_rdata2[7:0],8'b0} :
                              data_sram_wen==4'b0100 ? {8'b0,rf_rdata2[7:0],16'b0} :
                              data_sram_wen==4'b1000 ? {rf_rdata2[7:0],24'b0} :
                              data_sram_wen==4'b0011 ? {16'b0,rf_rdata2[15:0]} :
                              data_sram_wen==4'b1100 ? {rf_rdata2[15:0],16'b0} :
                              32'b0;
    // �� EX ���м���Ľ��������������ߣ����� MEM �׶�
    assign ex_to_mem_bus = {
        ex_pc,         // 75:44 PC ��ַ
        data_ram_en,   // 43 ���ݴ洢��ʹ���ź�
        data_ram_wen,  // 42:39 ���ݴ洢��дʹ��
        sel_rf_res,    // 38 �Ƿ�ѡ�� RF ���
        rf_we,         // 37 �Ĵ����ļ�дʹ��
        rf_waddr,      // 36:32 д��Ĵ����ĵ�ַ
        ex_result,     // 31:0 EX �ε�������
        data_ram_read  // ���ݴ洢���Ķ�ȡ�����ź�
    };
   
    /*����������йص�ָ�����ǰָ����Ҫȡǰ�滹δ����Ĵ�����ֵ��ʱ��
    EX ����ǰ���� ID �Σ����� ID �η��͸� regfile �ļ�*/
    assign ex_to_id_bus = {
        rf_we,         // 37 �Ĵ����ļ�дʹ��
        rf_waddr,      // 36:32 �Ĵ���д���ַ
        ex_result      // 31:0 EX �ε�������
    };
    // ����˷�ָ��
    wire w_hi_we1;
    wire w_lo_we1;
    wire mult;
    wire multu;
    assign mult = (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1000);    // �ж��Ƿ����з��ų˷�ָ��
    assign multu= (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1001);    // �ж��Ƿ����޷��ų˷�ָ��
    assign w_hi_we1 = mult | multu ;    // �ж��Ƿ���Ҫд HI��LO �Ĵ���
    assign w_lo_we1 = mult | multu ;
    
    // MUL part
//    wire [63:0] mul_result;
//    wire mul_signed; // �з��ų˷����?
//    wire [31:0] mul_1;
//    wire [31:0] mul_2;
//    assign mul_1 = w_hi_we1 ? alu_src1 : 32'b0;
//    assign mul_2 = w_hi_we1 ? alu_src2 : 32'b0;
//    assign mul_signed = mult;

//    mul u_mul(
//    	.clk        (clk            ),
//        .resetn     (~rst           ),
//        .mul_signed (mul_signed     ),
//        .ina        (  mul_1    ), // �˷�Դ������1
//        .inb        (  mul_2    ), // �˷�Դ������2
//        .result     (mul_result     ) // �˷����? 64bit
//    );
    wire [63:0] mul_result;    // �˷������64 λ
    wire mul_ready_i;    // �˷������Ƿ�׼���ã���ʾ�˷��Ƿ����
//    wire [31:0] mul_1;
//    wire [31:0] mul_2;
    wire mul_begin;     // �˷�������ʼ�ź�
//    assign mul_1 = w_hi_we1 ? alu_src1 : 32'b0;
//    assign mul_2 = w_hi_we1 ? alu_src2 : 32'b0;
    wire mul_signed;         // �Ƿ�����з��ų˷�
    assign mul_signed = mult;  // ����ǳ˷�ָ�������Ϊ�з��ų˷�
    assign mul_begin = mult | multu;  // ���ǳ˷�ָ��ʱ��ʼ�˷�����
    
    /*���� mul_begin �����жϳ˷��Ŀ�ʼ�����Ϊ1'b1������г˷�������
    ����ͨ��ָ�����жϴ˴γ˷�Ϊ�з��ų˷������޷��ų˷��������mul_plus.v �С�*/
    mul_plus u_mul_plus(
    .clk        (clk),            // ʱ���ź�
    .start_i    (mul_begin),      // �˷���ʼ�ź�
    .mul_sign   (mul_signed),     // �Ƿ��з��ų˷�
    .opdata1_i  (rf_rdata1),      // Դ������1
    .opdata2_i  (rf_rdata2),      // Դ������2
    .result_o   (mul_result),     // �˷������64 λ
    .ready_o    (mul_ready_i)     // �˷��Ƿ�����ź�
);

    // DIV part
    wire [63:0] div_result;       // ���������64 λ
    wire inst_div, inst_divu;     // �Ƿ�Ϊ����ָ��ֱ����з��ų������޷��ų���
    wire div_ready_i;             // ���������Ƿ�׼���ã���ʾ�����Ƿ����
    reg stallreq_for_div;         // ����������ͣ�ź�
    wire w_hi_we2;                // д HI �Ĵ����źţ�������أ�
    wire w_lo_we2;                // д LO �Ĵ����źţ�������أ�
    assign stallreq_for_ex = (stallreq_for_div & div_ready_i==1'b0) | (mul_begin & mul_ready_i==1'b0);    // ��������δ��ɻ�˷���δ���ʱ����Ҫ��ͣ��ˮ��
    assign ready_ex_to_id = div_ready_i | mul_ready_i;
    // �ж�ָ���Ƿ�Ϊ����ָ��
    assign inst_div = (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1010);
    assign inst_divu= (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1011);
    assign w_hi_we2 = inst_div | inst_divu;    // �ж��Ƿ���Ҫд HI �� LO �Ĵ�����������أ�
    assign w_lo_we2 = inst_div | inst_divu;
    
// ����������������ݺͿ����ź�
    reg [31:0] div_opdata1_o;  // ����������1
    reg [31:0] div_opdata2_o;  // ����������2
    reg div_start_o;            // ���������ź�
    reg signed_div_o;           // �Ƿ��з��ų���
    

    // ʵ��������ģ��
    div u_div(
        .rst          (rst),          // ��λ�ź�
        .clk          (clk),          // ʱ���ź�
        .signed_div_i (signed_div_o), // �Ƿ��з��ų���
        .opdata1_i    (div_opdata1_o), // ����������1
        .opdata2_i    (div_opdata2_o), // ����������2
        .start_i      (div_start_o),    // ������ʼ�ź�
        .annul_i      (1'b0),           // ��ȡ������
        .result_o     (div_result),     // ���������64 λ
        .ready_o      (div_ready_i)     // �����Ƿ�����ź�
    );

    always @ (*) begin
        if (rst) begin    // ��λʱ����ʼ���ź�
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin    // ��������£���ʼ�������ź�
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})    // ����ָ�����ͣ�����������������Ϊ
                2'b10: begin  // �з��ų���
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1; // �з��ų���
                        stallreq_for_div = `Stop; // ��ͣ��ˮ��
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;    // �ָ���ˮ��
                    end
                    else begin    // ���������ֹͣ��������
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin    // �޷��ų���
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0; // �޷��ų���
                        stallreq_for_div = `Stop; // ��ͣ��ˮ��
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;    // �ָ���ˮ��
                    end
                    else begin    // ���������ֹͣ��������
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin    // Ĭ������£����ֳ���������ֹͣ״̬
                end
            endcase
        end
    end
    // ���ݳ˷��ͳ��������Ľ���������Ƿ�����д�� LO �� HI �Ĵ���
    assign lo_i = w_lo_we1 ? mul_result[31:0] :     // ����ǳ˷���д�� LO �Ĵ����ĵ� 32 λ
                  w_lo_we2 ? div_result[31:0] :     // ����ǳ�����д�� LO �Ĵ����ĵ� 32 λ
                  w_lo_we3 ? rf_rdata1 :            // ��������������д�� RF �Ĵ�������
                  32'b0;                            // Ĭ��Ϊ 0
    assign hi_i = w_hi_we1 ? mul_result[63:32] :     // ����ǳ˷���д�� HI �Ĵ����ĸ� 32 λ
                  w_hi_we2 ? div_result[63:32] :     // ����ǳ�����д�� HI �Ĵ����ĸ� 32 λ
                  w_hi_we3 ? rf_rdata1 :            // ��������������д�� RF �Ĵ�������
                  32'b0;                            // Ĭ��Ϊ 0
    assign w_hi_we = w_hi_we1 | w_hi_we2 | w_hi_we3;    // ����κ�һ��дʹ���ź�Ϊ 1���� HI �Ĵ������Ա�д��
    assign w_lo_we = w_lo_we1 | w_lo_we2 | w_lo_we3;
    
    /*EX ��Ҫ���͸� MEM ��ֵ���������д hi �� lo �Ĵ�����ʹ���źţ�
    �����ж��Ƿ����д�Ĵ����Ĳ��������а����˽�Ҫд�� hi �� lo �Ĵ�����ֵ*/
        assign ex_to_mem1 =
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };
    //EX ��Ҫ���͸� ID ���е�regfile.v,���ڽ����һ��ָ��
    //Ҫ�õ���һ��ָ����� hilo �Ĵ���ֵ������
    assign ex_to_id_2=
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };

    // mul_result �� div_result ����ֱ��ʹ��
    
    
endmodule