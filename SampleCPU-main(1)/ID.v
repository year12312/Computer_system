`include "lib/defines.vh"
module ID(    // ID��ָ����룩ģ��
    input wire clk,    // ʱ���ź�
    input wire rst,    // ��λ�ź�
    // input wire flush,
    input wire [`StallBus-1:0] stall,    // ���Կ��Ƶ�Ԫ����ͣ�ź�
    
    output wire stallreq_for_id,    // ����ID�׶���ͣ���ź�
    
    output wire stallreq,    // ������ͣ���ź�
    
    input wire [37:0] ex_to_id_bus,    // ����EX�׶ε���������
    
    input wire [37:0] mem_to_id_bus,    // ����MEM�׶ε���������
    
    input wire [37:0] wb_to_id_bus,    // ����WB�׶ε���������
    
    input wire [65:0] ex_to_id_2,    // ����EX�׶εĵڶ���������
    
    input wire[65:0] mem_to_id_2,     // ����MEM�׶εĵڶ���������
    
    input wire[65:0] wb_to_id_2,     // ����WB�׶εĵڶ���������

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,    // ����IF�׶ε���������

    input wire [31:0] inst_sram_rdata,    // ָ��洢����ȡ������

    input wire inst_is_load,    // �Ƿ�Ϊ����ָ����Կ��Ƶ�Ԫ��

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,    // ����WB�׶ε�����

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,    // ���ݸ�EX�׶ε�����
//    output wire [67:0] id_to_ex_2,

    output wire [`BR_WD-1:0] br_bus,    // ��֧��ת�������
    
    input wire [65:0] wb_to_id_wf,    // ����WB�׶ε���ˮ�����ݣ�д�ؼĴ���ֵ��
    input wire ready_ex_to_id      // EX�׶�׼��������
);
    // �Ĵ����������źų�ʼ��
    reg [31:0] inst_stall;    // ��ͣʱ�洢��ǰָ��ļĴ���
    reg inst_stall_en;    // ��ͣʹ���ź�
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;    // �洢����IF�׶ε�ָ����Ϣ
    // �����źŵļĴ���
    wire [31:0] inst;   // ��ǰָ��
    wire [31:0] id_pc;  // ID�׶εĳ��������ֵ
    wire ce;    // �����źţ�ָ��ʹ��
    wire [31:0] inst_stall1;    // ��ָͣ��Ĵ���
    wire inst_stall_en1;    // ��ͣʹ���ź�1
    // д�ؽ׶��ź�
    wire wb_rf_we;    // д��ʹ���ź�
    wire [4:0] wb_rf_waddr;    // д�ؼĴ����ĵ�ַ
    wire [31:0] wb_rf_wdata;    // д�ؼĴ���������
// �Ĵ������£�������ͣ���ƣ�
    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;    // ��λʱ��ռĴ���
//            wb_to_id_wf_r <= 66'b0;     
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;    // ��ͣʱ��ռĴ���
//            wb_to_id_wf_r <= 66'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;    // ���¼Ĵ���
//            wb_to_id_wf_r <= wb_to_id_wf;
        end
    end
    always @ (posedge clk) begin   // ��ͣ�����߼����� EX�׶εĳ˳���δ���ʱ����ͣ��ǰָ��    //��� ID ����Ҫ��ͣ���򽫵�ǰ�� inst ֵ��ֵ��inst_stal1��ʱ�Ĵ�����
        inst_stall_en<=1'b0;    // ��λ��ͣʹ��
        inst_stall <=32'b0;    // �����ָͣ��
        /*ready_ex_to_id�������յ� EX ���г˳��������Ƿ���ɣ����û����ɣ�����ź�ֵΪ 0��
        �����ɸ��źŵ�ֵΪ 1������� EX �ν��е�ָ���ǳ˳�������Ϊ����Ҫ���� 32 ��ʱ�����ڣ�
        ����Ҫ���������ˮ�ν�����ͣ*/
        if(stall[1] == 1'b1 & ready_ex_to_id ==1'b0)begin
        inst_stall <= inst;    // �洢��ǰָ��
        inst_stall_en<=1'b1;    // ������ͣ
        end
 
    end
    assign inst_stall1 = inst_stall;
    assign inst_stall_en1 = inst_stall_en ;
    
    assign inst = inst_stall_en1 ? inst_stall1  :inst_sram_rdata;    // �����ͣʹ�ܣ�ʹ����ָͣ��
    assign {    // �� IF �׶λ�ȡ�����������PC���Ϳ����źţ�ce��
        ce,
        id_pc
    } = if_to_id_bus_r;    

    assign {    // �� WB �׶λ�ȡд���ź�
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;    
    // ����ָ��ĸ����ֶ�
    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;
    // �����������������ֶ�
    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;
    // ALU ����ѡ���ź�
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;
    // ���ݴ洢�������ź�
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire [3:0] data_ram_read;
    // �Ĵ����ļ������ź�
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;
    // �Ĵ�����ȡ�ź�
    wire [31:0] rdata1, rdata2;
    // Hi/Lo�Ĵ��������ź�
    wire w_hi_we;
    wire w_lo_we;
    wire [31:0]hi_i;
    wire [31:0]lo_i;
    
    wire r_hi_we;
    wire r_lo_we;
    wire[31:0] hi_o;
    wire[31:0] lo_o;
    // Hi/Lo�Ĵ�����д�����ź�
    wire [1:0] lo_hi_r;
    wire [1:0] lo_hi_w;
    
    wire inst_lsa;    // Load/Store Addressָ���ź�
    
    // ����WB�׶ε�Hi/Lo�Ĵ���д���ź�
    assign 
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    } = wb_to_id_wf;
    // �Ĵ����ļ�ʵ��
    regfile u_regfile(
        .inst   (inst),
    	.clk    (clk    ),
    	// ��ȡ�Ĵ���
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        // д�ؼĴ���
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  ),
        // ���ݴ�������
        .ex_to_id_bus(ex_to_id_bus),
        .mem_to_id_bus(mem_to_id_bus),
        .wb_to_id_bus(wb_to_id_bus),
        .ex_to_id_2(ex_to_id_2),
        .mem_to_id_2(mem_to_id_2),
        .wb_to_id_2(wb_to_id_2),
        // Hi/Lo�Ĵ���д��
        .w_hi_we  (w_hi_we),
        .w_lo_we  (w_lo_we),
        .hi_i(hi_i),
        .lo_i(lo_i),
        // Hi/Lo�Ĵ�����
        .r_hi_we (lo_hi_r[0]),
        .r_lo_we (lo_hi_r[1]),
        .hi_o(hi_o),
        .lo_o(lo_o),
        .inst_lsa(inst_lsa)
    );
    
    
// ����ָ���ֶΣ������롢�Ĵ������������ȣ�
    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];
    // ָ����ͣ���������
    assign stallreq_for_id = (inst_is_load == 1'b1 && (rs == ex_to_id_bus[36:32] || rt == ex_to_id_bus[36:32] ));
//    assign inst_stall =  (stallreq_for_id) ? inst : 32'b0; 
//////////////////////////ָ����ͣ////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
// ���岻ͬMIPSָ����ź��ߣ���Щ�źű�ʾָ������ͻ����
    wire inst_ori, inst_lui, inst_addiu, inst_beq, inst_subu, inst_jr, inst_jal, inst_addu, inst_bne, inst_sll, inst_or,
         inst_lw, inst_sw, inst_xor ,inst_sltu, inst_slt, inst_slti, inst_sltiu, inst_j, inst_add, inst_addi ,inst_sub,
         inst_and , inst_andi, inst_nor, inst_xori, inst_sllv, inst_sra, inst_bgez, inst_bltz, inst_bgtz, inst_blez,
         inst_bgezal,inst_bltzal, inst_jalr, inst_mflo, inst_mfhi, inst_mthi, inst_mtlo, inst_div, inst_divi, inst_mult,
         inst_multu, inst_lb, inst_lbu, inst_lh, inst_lhu, inst_sb, inst_sh;
// ��������ź��ߣ����ڱ�ʾ��ָͬ�����Ŀ����ź�
    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;
// ʵ������������decoder�������벻ͬ���ֵ�ָ��ֱ�Ϊopcode��func��rs��rt�ֶ�
    decoder_6_64 u0_decoder_6_64(    // ����6λ�����루opcode��
    	.in  (opcode  ),    // ������6λ������
        .out (op_d )     // �����64λ�����Ĳ�����
    );
// ����6λ�����루func��
    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),    // ������6λ�����ֶ�
        .out (func_d )    // �����64λ�����Ĺ����ֶ�
    );
// ����5λ��rs�ֶ�
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),    // ������5λrs�ֶ�
        .out (rs_d )    // �����32λ������rs�ֶ�
    );
// ����5λ��rt�ֶ�
    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),    // ������5λrt�ֶ�
        .out (rt_d )    // �����32λ������rt�ֶ�
    );
// ���ڽ�����opcode��func�����ɲ�ָͬ��Ŀ����ź�
    assign inst_ori     = op_d[6'b00_1101];     // oriָ��    OR������ָ��
    assign inst_lui     = op_d[6'b00_1111];     // luiָ��    �����ϰ벿��������ָ��
    assign inst_addiu   = op_d[6'b00_1001];     // addiuָ��    �޷��żӷ�������ָ��
    assign inst_beq     = op_d[6'b00_0100];     // beqָ��    ��֧������ָ��
    assign inst_subu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0011];      // subuָ�R����ָ���������0x23��    �޷��ż�����R���ͣ�
    assign inst_jr      = op_d[6'b00_0000] & (inst[20:11]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b00_1000];      // ����jrָ���ת���Ĵ�����ַ��    ��ת�Ĵ�����R���ͣ�
    assign inst_jal     = op_d[6'b00_0011];     // jalָ���ת�����ӣ�    ��ת�����ӣ�J���ͣ�
    assign inst_addu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0001];      // adduָ�R����ָ���������0x21��    �޷��żӷ���R���ͣ�
    assign inst_sll     = op_d[6'b00_0000] & rs_d[5'b0_0000] & func_d[6'b00_0000];      // sllָ��߼����ƣ�    �߼����ƣ�R���ͣ�
    assign inst_bne     = op_d[6'b00_0101];     // bneָ�����ȷ�֧��    ��֧��������ָ��
    assign inst_or      = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0101];      // orָ�R���ͣ���������0x25��    ORָ�R���ͣ�
    
    assign inst_lw      = op_d[6'b10_0011];     // lwָ������֣�    ������ָ�I���ͣ�
    assign inst_sw      = op_d[6'b10_1011];     // swָ��洢�֣�    �洢��ָ�I���ͣ�
    assign inst_xor     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0110];      // xorָ�R���ͣ���������0x26��    XORָ�R���ͣ�
    assign inst_sltu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_1011];      // sltuָ�R���ͣ���������0x2B��    С���޷��ţ�R���ͣ�
    assign inst_slt     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_1010];      // sltָ�R���ͣ���������0x2A��    С�ڣ�R���ͣ�
    assign inst_slti    = op_d[6'b00_1010];     // sltiָ�I���ͣ�    С����������I���ͣ�
    assign inst_sltiu   = op_d[6'b00_1011];     // sltiuָ�I���ͣ�    С���޷�����������I���ͣ�
    assign inst_j       = op_d[6'b00_0010];     // jָ���תָ�    ��תָ�J���ͣ�
    assign inst_add     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0000];      // ����addָ�R���ͣ���������0x20��    �ӷ�ָ�R���ͣ�
    assign inst_addi    = op_d[6'b00_1000];     // addiָ�I���ͣ�    �ӷ�������ָ�I���ͣ�
    assign inst_sub     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0010];     // subָ�R���ͣ���������0x22��    ����ָ�R���ͣ�
    assign inst_and     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0100];      // andָ�R���ͣ���������0x24��    ��ָ�R���ͣ�
    assign inst_andi    = op_d[6'b00_1100];    // andiָ�I���ͣ�    ��������ָ�I���ͣ�
    assign inst_nor     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0111];    // ����norָ�R���ͣ���������0x27��    NORָ�R���ͣ�
    assign inst_xori    = op_d[6'b00_1110];    // xoriָ�I���ͣ�    XOR������ָ�I���ͣ�
    assign inst_sllv    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0100];    // sllvָ�R���ͣ���������0x04��    �������ƣ�R���ͣ�
    assign inst_sra     = op_d[6'b00_0000] & (rs==5'b0_0000) & func_d[6'b00_0011];    // sraָ�R���ͣ���������0x03��    �������ƣ�R���ͣ�
    assign inst_srav    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0111];   // SRAVָ��������ƣ�R����ָ��
    assign inst_srl     = op_d[6'b00_0000] & (rs==5'b0_0000) & func_d[6'b00_0010];    // SRLָ��߼����ƣ�R����ָ��
    assign inst_srlv    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0110];    // SRLVָ������߼����ƣ�R����ָ��
    assign inst_bgez    = op_d[6'b00_0001] & (rt==5'b0_0001);    // BGEZָ����ڻ������ʱ��ת��I����ָ��
    assign inst_bltz    = op_d[6'b00_0001] & (rt==5'b0_0000);   // BLTZָ�С����ʱ��ת��I����ָ��
    assign inst_bgtz    = op_d[6'b00_0111] & (rt==5'b0_0000);    // BGTZָ�������ʱ��ת��I����ָ��
    assign inst_blez    = op_d[6'b00_0110] & (rt==5'b0_0000);    // BLEZָ�С�ڵ�����ʱ��ת��I����ָ��
    assign inst_bgezal  = op_d[6'b00_0001] & (rt==5'b1_0001);    // BGEZALָ����ڻ������ʱ��ת�����ӣ�I����ָ��
    assign inst_bltzal  = op_d[6'b00_0001] & (rt==5'b1_0000);    // BLTZALָ�С����ʱ��ת�����ӣ�I����ָ��
    assign inst_jalr    = op_d[6'b00_0000] & (rt==5'b0_0000) & (sa==5'b0_0000) & func_d[6'b00_1001];    // JALRָ���ת�����ӼĴ�����R����ָ��
    
    assign inst_mflo    = op_d[6'b00_0000] & (inst[25:16]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b01_0010];    // MFLOָ���LO�Ĵ�����ȡ���ݣ�R����ָ��
    assign inst_mfhi    = op_d[6'b00_0000] & (inst[25:16]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b01_0000];    // MFHIָ���HI�Ĵ�����ȡ���ݣ�R����ָ��
    assign inst_mthi    = op_d[6'b00_0000] & (inst[20:6]==10'b000000000000000)  & func_d[6'b01_0001];    // MTHIָ�������д��HI�Ĵ�����R����ָ��
    assign inst_mtlo    = op_d[6'b00_0000] & (inst[20:6]==10'b000000000000000)  & func_d[6'b01_0011];    // MTLOָ�������д��LO�Ĵ�����R����ָ��
    assign inst_div     = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1010];    // DIVָ��з��ų�����R����ָ��
    assign inst_divu    = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1011];    // DIVUָ��޷��ų�����R����ָ��
    assign inst_mult    = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1000];    // MULTָ��з��ų˷���R����ָ��
    assign inst_multu   = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1001];    // MULTUָ��޷��ų˷���R����ָ��
    
    assign inst_lb      = op_d[6'b10_0000];    // LBָ������ֽڣ�I����ָ��
    assign inst_lbu     = op_d[6'b10_0100];    // LBUָ������޷����ֽڣ�I����ָ��
    assign inst_lh      = op_d[6'b10_0001];    // LHָ����ذ��֣�I����ָ��
    assign inst_lhu     = op_d[6'b10_0101];     // LHUָ������޷��Ű��֣�I����ָ��
    assign inst_sb      = op_d[6'b10_1000];    // SBָ��洢�ֽڣ�I����ָ��
    assign inst_sh      = op_d[6'b10_1001];    // SHָ��洢���֣�I����ָ��
    
    assign inst_lsa     = op_d[6'b01_1100] & inst[10:8]==3'b111 & inst[5:0]==6'b11_0111;    // LSAָ�����ָ��ض�����´�������ĳЩ������͹��������ϣ�
    

    // rs to reg1: �� rs �Ĵ��������ݴ��͸� ALU ��Դ1
    assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_addu | inst_or | inst_lw | inst_sw | inst_xor | inst_sltu | inst_slt
                                | inst_slti | inst_sltiu | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor | inst_xori
                                | inst_sllv | inst_srav | inst_srlv | inst_mthi | inst_mtlo | inst_div | inst_divu | inst_mult | inst_multu
                                | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lsa;

    // pc to reg1: �� PC �����ݴ��ݸ� ALU ��Դ1
    assign sel_alu_src1[1] = inst_jal | inst_bgezal |inst_bltzal | inst_jalr;

    // sa_zero_extend to reg1: �� sa ��չΪ�㴫�� ALU ��Դ1��������λ������
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl;

    
    // rt to reg2: �� rt �Ĵ��������ݴ��͸� ALU ��Դ2
    assign sel_alu_src2[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_add | inst_sub | inst_and |
                              inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_div | inst_divu | inst_mult | inst_multu | inst_lsa;
    
    // imm_sign_extend to reg2: ��������������չ�󴫸� ALU ��Դ2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw | inst_sw | inst_slti | inst_sltiu | inst_addi | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

    // 32'b8 to reg2: 32'b8 ���� ALU ��Դ2��������ת��ַ��
    assign sel_alu_src2[2] = inst_jal | inst_bgezal | inst_bltzal | inst_jalr;

    // imm_zero_extend to reg2: ������������չ�󴫸� ALU ��Դ2
    assign sel_alu_src2[3] = inst_ori | inst_andi | inst_xori;
   
    // lo to: �� lo �Ĵ��������ݴ��� lo_hi_r[0]�����ڶ�ȡ lo �Ĵ�����ֵ��
    assign lo_hi_r[0] = inst_mflo;
    
    // hi to: �� hi �Ĵ��������ݴ��� lo_hi_r[1]�����ڶ�ȡ hi �Ĵ�����ֵ��
    assign lo_hi_r[1] = inst_mfhi;


    // �������Ͷ���
    assign op_add = inst_addiu | inst_jal | inst_addu | inst_lw | inst_sw | inst_add | inst_addi | inst_bgezal | inst_bltzal
         | inst_jalr | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lsa;
    assign op_sub = inst_subu | inst_sub;
    assign op_slt = inst_slt | inst_slti;
    assign op_sltu = inst_sltu | inst_sltiu;
    assign op_and = inst_and | inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor | inst_xori;
    assign op_sll = inst_sll | inst_sllv;
    assign op_srl = inst_srl | inst_srlv;
    assign op_sra = inst_sra | inst_srav ;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable: �����Ƿ����������ڴ����
    assign data_ram_en = inst_lw | inst_sw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

    // write enable 0:load  1:store: ���ݴ洢����дʹ���źţ������Ƿ���д洢����
    assign data_ram_wen = inst_sw ? 4'b1111 : 4'b0000;
    // data_ram_read: ���ݴ洢���Ķ�ȡ�źţ�������ȡ��Щ�ֽ�
    assign data_ram_read    =  inst_lw  ? 4'b1111 :
                               inst_lb  ? 4'b0001 :
                               inst_lbu ? 4'b0010 :
                               inst_lh  ? 4'b0011 :
                               inst_lhu ? 4'b0100 :
                               inst_sb  ? 4'b0101 :
                               inst_sh  ? 4'b0111 :
                               4'b0000;


    // regfile store enable: ���ƼĴ����ļ��Ƿ�д������
    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_subu | inst_jal |inst_addu | inst_sll | inst_or | inst_xor | inst_lw | inst_sltu
      | inst_slt | inst_slti | inst_sltiu | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor | inst_sllv | inst_xori | inst_sra
      | inst_srav | inst_srl | inst_srlv | inst_bgezal | inst_bltzal | inst_jalr  | inst_mfhi | inst_mflo | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lsa;



    // store in [rd]: ��д��Ĵ�����ʱ��ѡ��Ĵ��� rd������ R ��ָ�
    assign sel_rf_dst[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_add | inst_sub | inst_and | inst_nor
                             | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_jalr | inst_mflo | inst_mfhi | inst_lsa;
    // store in [rt]: ��д��Ĵ�����ʱ��ѡ��Ĵ��� rt������ I ��ָ�
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw | inst_slti | inst_sltiu | inst_addi | inst_andi | inst_xori | inst_lb | inst_lbu | inst_lh | inst_lhu;
    // store in [31]: ������ת������ָ�ѡ��Ĵ��� 31 (���ӼĴ���)
    assign sel_rf_dst[2] = inst_jal | inst_bgezal | inst_bltzal ;
    
    // store in lo: �� lo �Ĵ��������ݴ��� lo_hi_w[0]������д�� lo �Ĵ�����ֵ��
    assign lo_hi_w[0] = inst_mtlo;
    
    // store in hi: �� hi �Ĵ��������ݴ��� lo_hi_w[1]������д�� hi �Ĵ�����ֵ��
    assign lo_hi_w[1] = inst_mthi ;

    // sel for regfile address: ���� sel_rf_dst �źţ�ѡ��Ҫд��ļĴ�����ַ��rd, rt �� 31��
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res; 1 from ld_res: ����д�ؼĴ��������������� ALU ����������Լ��ؽ��
    assign sel_rf_res = (inst_lw | inst_lb | inst_lbu) ? 1'b1 : 1'b0; 
    
//    wire [2:0] zuoyi;
//    assign zuoyi = inst_lsa ? (inst[7:6] + 1'b1) :  3'b0;
//    assign 
//    assign 
//       wire [31:0] aaa;
    
//    assign aaa = inst[7:6] == 2'b11 ?  ({rdata1[27:0],4'b0}):
//                  inst[7:6] == 2'b00 ?  ({rdata1[30:0],1'b0}):
//                  inst[7:6] == 2'b01 ?  ({rdata1[29:0],2'b0}):
//                  inst[7:6] == 2'b10 ?  ({rdata1[28:0],3'b0}):
//                  32'b0;
//    assign rdata1 = inst_lsa ? aaa : rdata1;

    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70           //write
        rf_waddr,       // 69:65        //write
        sel_rf_res,     // 64
        rdata1,         // 63:32        //rs
        rdata2,          // 31:0        //rt
        lo_hi_r,                        //read�ź�
        lo_hi_w,                        //write�ź�
        lo_o,                           //loֵ
        hi_o,                            //hiֵ
        data_ram_read
    };
    
//    assign id_to_ex_2 = {
//        lo_hi_r,                        //read�ź�
//        lo_hi_w,                        //write�ź�
//        lo_o,                           //loֵ
//        hi_o                            //hiֵ
//     };

    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    wire re_bne_rt;
//    wire [31:0] pc_plus_8;
    assign pc_plus_4 = id_pc + 32'h4;
//    assign pc_plus_8 = id_pc + 32'h8;

    assign rs_eq_rt = (rdata1 == rdata2);
    assign re_bne_rt = (rdata1 != rdata2);
    assign re_bgez_rt = (rdata1[31] == 1'b0);
    assign re_bltz_rt = (rdata1[31] == 1'b1);     
    assign re_blez_rt = (rdata1[31] == 1'b1 || rdata1 == 32'b0);
    assign re_bgtz_rt = (rdata1[31] == 1'b0 && rdata1 != 32'b0);

    // Branch logic: ������ת����
    assign br_e = (inst_beq && rs_eq_rt) | inst_jr | inst_jal | (inst_bne && re_bne_rt) | inst_j |(inst_bgez && re_bgez_rt)
                     | (inst_bltz && re_bltz_rt) |(inst_bgtz && re_bgtz_rt) | (inst_blez && re_blez_rt) | (inst_bgezal && re_bgez_rt)
                     | (inst_bltzal && re_bltz_rt) | inst_jalr;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :     // br_addr: ����ָ�����ͼ�����ת��ַ
    inst_jr ? (rdata1) :
    inst_jal ? ({pc_plus_4[31:28],inst[25:0],2'b0}):
    inst_bne ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
    inst_bgez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :   
    inst_bgtz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :  
    inst_bltz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :   
    inst_blez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
    inst_bgezal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
    inst_bltzal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :  
    inst_j   ?  ({pc_plus_4[31:28],inst[25:0],2'b0}):
    inst_jalr ? (rdata1) :
    32'b0;
 
    //assign id_pc = inst_jal ? pc_plus_8 : id_pc;

    assign br_bus = {
        br_e,
        br_addr
    };
    


endmodule