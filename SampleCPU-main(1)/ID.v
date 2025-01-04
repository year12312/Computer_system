`include "lib/defines.vh"
module ID(    // ID（指令解码）模块
    input wire clk,    // 时钟信号
    input wire rst,    // 复位信号
    // input wire flush,
    input wire [`StallBus-1:0] stall,    // 来自控制单元的暂停信号
    
    output wire stallreq_for_id,    // 请求ID阶段暂停的信号
    
    output wire stallreq,    // 请求暂停的信号
    
    input wire [37:0] ex_to_id_bus,    // 来自EX阶段的输入数据
    
    input wire [37:0] mem_to_id_bus,    // 来自MEM阶段的输入数据
    
    input wire [37:0] wb_to_id_bus,    // 来自WB阶段的输入数据
    
    input wire [65:0] ex_to_id_2,    // 来自EX阶段的第二输入数据
    
    input wire[65:0] mem_to_id_2,     // 来自MEM阶段的第二输入数据
    
    input wire[65:0] wb_to_id_2,     // 来自WB阶段的第二输入数据

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,    // 来自IF阶段的输入数据

    input wire [31:0] inst_sram_rdata,    // 指令存储器读取的数据

    input wire inst_is_load,    // 是否为加载指令（来自控制单元）

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,    // 来自WB阶段的数据

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,    // 传递给EX阶段的数据
//    output wire [67:0] id_to_ex_2,

    output wire [`BR_WD-1:0] br_bus,    // 分支跳转相关数据
    
    input wire [65:0] wb_to_id_wf,    // 来自WB阶段的流水线数据（写回寄存器值）
    input wire ready_ex_to_id      // EX阶段准备好数据
);
    // 寄存器定义与信号初始化
    reg [31:0] inst_stall;    // 暂停时存储当前指令的寄存器
    reg inst_stall_en;    // 暂停使能信号
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;    // 存储来自IF阶段的指令信息
    // 解码信号的寄存器
    wire [31:0] inst;   // 当前指令
    wire [31:0] id_pc;  // ID阶段的程序计数器值
    wire ce;    // 控制信号，指令使能
    wire [31:0] inst_stall1;    // 暂停指令寄存器
    wire inst_stall_en1;    // 暂停使能信号1
    // 写回阶段信号
    wire wb_rf_we;    // 写回使能信号
    wire [4:0] wb_rf_waddr;    // 写回寄存器的地址
    wire [31:0] wb_rf_wdata;    // 写回寄存器的数据
// 寄存器更新（用于暂停控制）
    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;    // 复位时清空寄存器
//            wb_to_id_wf_r <= 66'b0;     
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;    // 暂停时清空寄存器
//            wb_to_id_wf_r <= 66'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;    // 更新寄存器
//            wb_to_id_wf_r <= wb_to_id_wf;
        end
    end
    always @ (posedge clk) begin   // 暂停控制逻辑：当 EX阶段的乘除法未完成时，暂停当前指令    //如果 ID 段需要暂停，则将当前的 inst 值赋值给inst_stal1临时寄存器中
        inst_stall_en<=1'b0;    // 复位暂停使能
        inst_stall <=32'b0;    // 清空暂停指令
        /*ready_ex_to_id用来接收到 EX 段中乘除法操作是否完成，如果没有完成，则该信号值为 0，
        如果完成该信号的值为 1，如果在 EX 段进行的指令是乘除法，因为他们要进行 32 个时钟周期，
        所以要将后面的流水段进行暂停*/
        if(stall[1] == 1'b1 & ready_ex_to_id ==1'b0)begin
        inst_stall <= inst;    // 存储当前指令
        inst_stall_en<=1'b1;    // 启动暂停
        end
 
    end
    assign inst_stall1 = inst_stall;
    assign inst_stall_en1 = inst_stall_en ;
    
    assign inst = inst_stall_en1 ? inst_stall1  :inst_sram_rdata;    // 如果暂停使能，使用暂停指令
    assign {    // 从 IF 阶段获取程序计数器（PC）和控制信号（ce）
        ce,
        id_pc
    } = if_to_id_bus_r;    

    assign {    // 从 WB 阶段获取写回信号
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;    
    // 解析指令的各个字段
    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;
    // 解析操作数、功能字段
    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;
    // ALU 操作选择信号
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;
    // 数据存储器控制信号
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire [3:0] data_ram_read;
    // 寄存器文件操作信号
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;
    // 寄存器读取信号
    wire [31:0] rdata1, rdata2;
    // Hi/Lo寄存器操作信号
    wire w_hi_we;
    wire w_lo_we;
    wire [31:0]hi_i;
    wire [31:0]lo_i;
    
    wire r_hi_we;
    wire r_lo_we;
    wire[31:0] hi_o;
    wire[31:0] lo_o;
    // Hi/Lo寄存器读写控制信号
    wire [1:0] lo_hi_r;
    wire [1:0] lo_hi_w;
    
    wire inst_lsa;    // Load/Store Address指令信号
    
    // 来自WB阶段的Hi/Lo寄存器写回信号
    assign 
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    } = wb_to_id_wf;
    // 寄存器文件实例
    regfile u_regfile(
        .inst   (inst),
    	.clk    (clk    ),
    	// 读取寄存器
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        // 写回寄存器
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  ),
        // 数据传输总线
        .ex_to_id_bus(ex_to_id_bus),
        .mem_to_id_bus(mem_to_id_bus),
        .wb_to_id_bus(wb_to_id_bus),
        .ex_to_id_2(ex_to_id_2),
        .mem_to_id_2(mem_to_id_2),
        .wb_to_id_2(wb_to_id_2),
        // Hi/Lo寄存器写回
        .w_hi_we  (w_hi_we),
        .w_lo_we  (w_lo_we),
        .hi_i(hi_i),
        .lo_i(lo_i),
        // Hi/Lo寄存器读
        .r_hi_we (lo_hi_r[0]),
        .r_lo_we (lo_hi_r[1]),
        .hi_o(hi_o),
        .lo_o(lo_o),
        .inst_lsa(inst_lsa)
    );
    
    
// 解析指令字段（操作码、寄存器、立即数等）
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
    // 指令暂停请求的生成
    assign stallreq_for_id = (inst_is_load == 1'b1 && (rs == ex_to_id_bus[36:32] || rt == ex_to_id_bus[36:32] ));
//    assign inst_stall =  (stallreq_for_id) ? inst : 32'b0; 
//////////////////////////指令暂停////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
// 定义不同MIPS指令的信号线，这些信号表示指令的类型或操作
    wire inst_ori, inst_lui, inst_addiu, inst_beq, inst_subu, inst_jr, inst_jal, inst_addu, inst_bne, inst_sll, inst_or,
         inst_lw, inst_sw, inst_xor ,inst_sltu, inst_slt, inst_slti, inst_sltiu, inst_j, inst_add, inst_addi ,inst_sub,
         inst_and , inst_andi, inst_nor, inst_xori, inst_sllv, inst_sra, inst_bgez, inst_bltz, inst_bgtz, inst_blez,
         inst_bgezal,inst_bltzal, inst_jalr, inst_mflo, inst_mfhi, inst_mthi, inst_mtlo, inst_div, inst_divi, inst_mult,
         inst_multu, inst_lb, inst_lbu, inst_lh, inst_lhu, inst_sb, inst_sh;
// 定义操作信号线，用于表示不同指令类别的控制信号
    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;
// 实例化解码器（decoder）来解码不同部分的指令，分别为opcode、func、rs和rt字段
    decoder_6_64 u0_decoder_6_64(    // 解析6位操作码（opcode）
    	.in  (opcode  ),    // 输入是6位操作码
        .out (op_d )     // 输出是64位解码后的操作码
    );
// 解析6位功能码（func）
    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),    // 输入是6位功能字段
        .out (func_d )    // 输出是64位解码后的功能字段
    );
// 解析5位的rs字段
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),    // 输入是5位rs字段
        .out (rs_d )    // 输出是32位解码后的rs字段
    );
// 解析5位的rt字段
    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),    // 输入是5位rt字段
        .out (rt_d )    // 输出是32位解码后的rt字段
    );
// 基于解码后的opcode和func码生成不同指令的控制信号
    assign inst_ori     = op_d[6'b00_1101];     // ori指令    OR立即数指令
    assign inst_lui     = op_d[6'b00_1111];     // lui指令    加载上半部分立即数指令
    assign inst_addiu   = op_d[6'b00_1001];     // addiu指令    无符号加法立即数指令
    assign inst_beq     = op_d[6'b00_0100];     // beq指令    分支如果相等指令
    assign inst_subu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0011];      // subu指令（R类型指令，功能码是0x23）    无符号减法（R类型）
    assign inst_jr      = op_d[6'b00_0000] & (inst[20:11]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b00_1000];      // 解析jr指令（跳转到寄存器地址）    跳转寄存器（R类型）
    assign inst_jal     = op_d[6'b00_0011];     // jal指令（跳转并链接）    跳转并链接（J类型）
    assign inst_addu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0001];      // addu指令（R类型指令，功能码是0x21）    无符号加法（R类型）
    assign inst_sll     = op_d[6'b00_0000] & rs_d[5'b0_0000] & func_d[6'b00_0000];      // sll指令（逻辑左移）    逻辑左移（R类型）
    assign inst_bne     = op_d[6'b00_0101];     // bne指令（不相等分支）    分支如果不相等指令
    assign inst_or      = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0101];      // or指令（R类型，功能码是0x25）    OR指令（R类型）
    
    assign inst_lw      = op_d[6'b10_0011];     // lw指令（加载字）    加载字指令（I类型）
    assign inst_sw      = op_d[6'b10_1011];     // sw指令（存储字）    存储字指令（I类型）
    assign inst_xor     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0110];      // xor指令（R类型，功能码是0x26）    XOR指令（R类型）
    assign inst_sltu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_1011];      // sltu指令（R类型，功能码是0x2B）    小于无符号（R类型）
    assign inst_slt     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_1010];      // slt指令（R类型，功能码是0x2A）    小于（R类型）
    assign inst_slti    = op_d[6'b00_1010];     // slti指令（I类型）    小于立即数（I类型）
    assign inst_sltiu   = op_d[6'b00_1011];     // sltiu指令（I类型）    小于无符号立即数（I类型）
    assign inst_j       = op_d[6'b00_0010];     // j指令（跳转指令）    跳转指令（J类型）
    assign inst_add     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0000];      // 解析add指令（R类型，功能码是0x20）    加法指令（R类型）
    assign inst_addi    = op_d[6'b00_1000];     // addi指令（I类型）    加法立即数指令（I类型）
    assign inst_sub     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0010];     // sub指令（R类型，功能码是0x22）    减法指令（R类型）
    assign inst_and     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0100];      // and指令（R类型，功能码是0x24）    与指令（R类型）
    assign inst_andi    = op_d[6'b00_1100];    // andi指令（I类型）    与立即数指令（I类型）
    assign inst_nor     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0111];    // 解析nor指令（R类型，功能码是0x27）    NOR指令（R类型）
    assign inst_xori    = op_d[6'b00_1110];    // xori指令（I类型）    XOR立即数指令（I类型）
    assign inst_sllv    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0100];    // sllv指令（R类型，功能码是0x04）    变量左移（R类型）
    assign inst_sra     = op_d[6'b00_0000] & (rs==5'b0_0000) & func_d[6'b00_0011];    // sra指令（R类型，功能码是0x03）    算术右移（R类型）
    assign inst_srav    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0111];   // SRAV指令：算术右移，R类型指令
    assign inst_srl     = op_d[6'b00_0000] & (rs==5'b0_0000) & func_d[6'b00_0010];    // SRL指令：逻辑右移，R类型指令
    assign inst_srlv    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0110];    // SRLV指令：变量逻辑右移，R类型指令
    assign inst_bgez    = op_d[6'b00_0001] & (rt==5'b0_0001);    // BGEZ指令：大于或等于零时跳转，I类型指令
    assign inst_bltz    = op_d[6'b00_0001] & (rt==5'b0_0000);   // BLTZ指令：小于零时跳转，I类型指令
    assign inst_bgtz    = op_d[6'b00_0111] & (rt==5'b0_0000);    // BGTZ指令：大于零时跳转，I类型指令
    assign inst_blez    = op_d[6'b00_0110] & (rt==5'b0_0000);    // BLEZ指令：小于等于零时跳转，I类型指令
    assign inst_bgezal  = op_d[6'b00_0001] & (rt==5'b1_0001);    // BGEZAL指令：大于或等于零时跳转并链接，I类型指令
    assign inst_bltzal  = op_d[6'b00_0001] & (rt==5'b1_0000);    // BLTZAL指令：小于零时跳转并链接，I类型指令
    assign inst_jalr    = op_d[6'b00_0000] & (rt==5'b0_0000) & (sa==5'b0_0000) & func_d[6'b00_1001];    // JALR指令：跳转并链接寄存器，R类型指令
    
    assign inst_mflo    = op_d[6'b00_0000] & (inst[25:16]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b01_0010];    // MFLO指令：从LO寄存器读取数据，R类型指令
    assign inst_mfhi    = op_d[6'b00_0000] & (inst[25:16]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b01_0000];    // MFHI指令：从HI寄存器读取数据，R类型指令
    assign inst_mthi    = op_d[6'b00_0000] & (inst[20:6]==10'b000000000000000)  & func_d[6'b01_0001];    // MTHI指令：将数据写入HI寄存器，R类型指令
    assign inst_mtlo    = op_d[6'b00_0000] & (inst[20:6]==10'b000000000000000)  & func_d[6'b01_0011];    // MTLO指令：将数据写入LO寄存器，R类型指令
    assign inst_div     = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1010];    // DIV指令：有符号除法，R类型指令
    assign inst_divu    = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1011];    // DIVU指令：无符号除法，R类型指令
    assign inst_mult    = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1000];    // MULT指令：有符号乘法，R类型指令
    assign inst_multu   = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1001];    // MULTU指令：无符号乘法，R类型指令
    
    assign inst_lb      = op_d[6'b10_0000];    // LB指令：加载字节，I类型指令
    assign inst_lbu     = op_d[6'b10_0100];    // LBU指令：加载无符号字节，I类型指令
    assign inst_lh      = op_d[6'b10_0001];    // LH指令：加载半字，I类型指令
    assign inst_lhu     = op_d[6'b10_0101];     // LHU指令：加载无符号半字，I类型指令
    assign inst_sb      = op_d[6'b10_1000];    // SB指令：存储字节，I类型指令
    assign inst_sh      = op_d[6'b10_1001];    // SH指令：存储半字，I类型指令
    
    assign inst_lsa     = op_d[6'b01_1100] & inst[10:8]==3'b111 & inst[5:0]==6'b11_0111;    // LSA指令：特殊指令，特定情况下触发（如某些操作码和功能码的组合）
    

    // rs to reg1: 将 rs 寄存器的内容传送给 ALU 的源1
    assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_addu | inst_or | inst_lw | inst_sw | inst_xor | inst_sltu | inst_slt
                                | inst_slti | inst_sltiu | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor | inst_xori
                                | inst_sllv | inst_srav | inst_srlv | inst_mthi | inst_mtlo | inst_div | inst_divu | inst_mult | inst_multu
                                | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lsa;

    // pc to reg1: 将 PC 的内容传递给 ALU 的源1
    assign sel_alu_src1[1] = inst_jal | inst_bgezal |inst_bltzal | inst_jalr;

    // sa_zero_extend to reg1: 将 sa 扩展为零传给 ALU 的源1（用于移位操作）
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl;

    
    // rt to reg2: 将 rt 寄存器的内容传送给 ALU 的源2
    assign sel_alu_src2[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_add | inst_sub | inst_and |
                              inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_div | inst_divu | inst_mult | inst_multu | inst_lsa;
    
    // imm_sign_extend to reg2: 将立即数符号扩展后传给 ALU 的源2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw | inst_sw | inst_slti | inst_sltiu | inst_addi | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

    // 32'b8 to reg2: 32'b8 传给 ALU 的源2（用于跳转地址）
    assign sel_alu_src2[2] = inst_jal | inst_bgezal | inst_bltzal | inst_jalr;

    // imm_zero_extend to reg2: 将立即数零扩展后传给 ALU 的源2
    assign sel_alu_src2[3] = inst_ori | inst_andi | inst_xori;
   
    // lo to: 将 lo 寄存器的内容传给 lo_hi_r[0]（用于读取 lo 寄存器的值）
    assign lo_hi_r[0] = inst_mflo;
    
    // hi to: 将 hi 寄存器的内容传给 lo_hi_r[1]（用于读取 hi 寄存器的值）
    assign lo_hi_r[1] = inst_mfhi;


    // 操作类型定义
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



    // load and store enable: 控制是否启用数据内存操作
    assign data_ram_en = inst_lw | inst_sw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

    // write enable 0:load  1:store: 数据存储器的写使能信号，决定是否进行存储操作
    assign data_ram_wen = inst_sw ? 4'b1111 : 4'b0000;
    // data_ram_read: 数据存储器的读取信号，决定读取哪些字节
    assign data_ram_read    =  inst_lw  ? 4'b1111 :
                               inst_lb  ? 4'b0001 :
                               inst_lbu ? 4'b0010 :
                               inst_lh  ? 4'b0011 :
                               inst_lhu ? 4'b0100 :
                               inst_sb  ? 4'b0101 :
                               inst_sh  ? 4'b0111 :
                               4'b0000;


    // regfile store enable: 控制寄存器文件是否写入数据
    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_subu | inst_jal |inst_addu | inst_sll | inst_or | inst_xor | inst_lw | inst_sltu
      | inst_slt | inst_slti | inst_sltiu | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor | inst_sllv | inst_xori | inst_sra
      | inst_srav | inst_srl | inst_srlv | inst_bgezal | inst_bltzal | inst_jalr  | inst_mfhi | inst_mflo | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lsa;



    // store in [rd]: 当写入寄存器堆时，选择寄存器 rd（对于 R 型指令）
    assign sel_rf_dst[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_add | inst_sub | inst_and | inst_nor
                             | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_jalr | inst_mflo | inst_mfhi | inst_lsa;
    // store in [rt]: 当写入寄存器堆时，选择寄存器 rt（对于 I 型指令）
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw | inst_slti | inst_sltiu | inst_addi | inst_andi | inst_xori | inst_lb | inst_lbu | inst_lh | inst_lhu;
    // store in [31]: 对于跳转和链接指令，选择寄存器 31 (链接寄存器)
    assign sel_rf_dst[2] = inst_jal | inst_bgezal | inst_bltzal ;
    
    // store in lo: 将 lo 寄存器的内容传给 lo_hi_w[0]（用于写入 lo 寄存器的值）
    assign lo_hi_w[0] = inst_mtlo;
    
    // store in hi: 将 hi 寄存器的内容传给 lo_hi_w[1]（用于写入 hi 寄存器的值）
    assign lo_hi_w[1] = inst_mthi ;

    // sel for regfile address: 根据 sel_rf_dst 信号，选择要写入的寄存器地址（rd, rt 或 31）
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res; 1 from ld_res: 决定写回寄存器的数据是来自 ALU 结果还是来自加载结果
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
        lo_hi_r,                        //read信号
        lo_hi_w,                        //write信号
        lo_o,                           //lo值
        hi_o,                            //hi值
        data_ram_read
    };
    
//    assign id_to_ex_2 = {
//        lo_hi_r,                        //read信号
//        lo_hi_w,                        //write信号
//        lo_o,                           //lo值
//        hi_o                            //hi值
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

    // Branch logic: 控制跳转操作
    assign br_e = (inst_beq && rs_eq_rt) | inst_jr | inst_jal | (inst_bne && re_bne_rt) | inst_j |(inst_bgez && re_bgez_rt)
                     | (inst_bltz && re_bltz_rt) |(inst_bgtz && re_bgtz_rt) | (inst_blez && re_blez_rt) | (inst_bgezal && re_bgez_rt)
                     | (inst_bltzal && re_bltz_rt) | inst_jalr;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :     // br_addr: 根据指令类型计算跳转地址
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