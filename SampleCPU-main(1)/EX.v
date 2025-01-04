`include "lib/defines.vh"
module EX(
    input wire clk,                        // 时钟信号
    input wire rst,                        // 复位信号
    // input wire flush,                  // 刷新信号（未使用）
    input wire [`StallBus-1:0] stall,     // 停顿信号，控制流水线暂停
    
    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,    // 来自 ID 阶段的数据总线
    
//    input wire [67:0] id_to_ex_2,    // 额外的总线（未使用）

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,    // 传送到 MEM 阶段的数据总线
    
    output wire [37:0] ex_to_id_bus,    // 传送到 ID 阶段的数据总线

    output wire data_sram_en,              // 数据存储器使能信号
    output wire [3:0] data_sram_wen,       // 数据存储器写使能信号
    output wire [31:0] data_sram_addr,     // 数据存储器地址
    output wire [31:0] data_sram_wdata,    // 数据存储器写入的数据
    output wire inst_is_load,              // 指示当前指令是否是加载指令
    
    output wire stallreq_for_ex,           // EX 阶段是否请求停顿
    output wire [65:0] ex_to_mem1,         // 传送到 MEM 阶段的额外数据
    output wire [65:0] ex_to_id_2,         // 传送到 ID 阶段的额外数据
    output wire ready_ex_to_id             // EX 阶段到 ID 阶段的准备信号
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;    // 寄存器，用于存储来自 ID 阶段的总线数据
//    reg [67:0] id_to_ex_2_r;    // 用于存储额外的总线数据（未使用）

    always @ (posedge clk) begin    // 每个时钟周期更新寄存器的值
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;    // 复位时清空数据
//            id_to_ex_2_r <= 68'b0;    // 复位时清空额外数据
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;    // 刷新时清空数据
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;    // 如果接收到停顿信号，清空数据
//            id_to_ex_2_r <= 68'b0;    // 同样清空额外数据
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;     // 没有停顿时传递来自 ID 阶段的数据
//            id_to_ex_2_r <= id_to_ex_2;    // 同样传递额外数据
        end
    end
    // 定义 EX 阶段的一些信号和寄存器
    wire [31:0] ex_pc, inst;                    // 指令计数器和指令
    wire [11:0] alu_op;                         // ALU 操作信号
    wire [2:0] sel_alu_src1;                    // ALU 源1选择信号
    wire [3:0] sel_alu_src2;                    // ALU 源2选择信号
    wire data_ram_en;                           // 数据存储器使能信号
    wire [3:0] data_ram_wen;                    // 数据存储器写使能信号
    wire [3:0] data_ram_read;                   // 数据存储器读信号
    wire rf_we;                                 // 寄存器文件写使能信号
    wire [4:0] rf_waddr;                        // 寄存器文件写地址
    wire sel_rf_res;                            // 寄存器文件结果选择信号
    wire [31:0] rf_rdata1, rf_rdata2;           // 寄存器文件读取的数据
    reg is_in_delayslot;                        // 标记是否处于延迟槽
    wire [1:0] lo_hi_r;                         // hi 和 lo 寄存器的读信号
    wire [1:0] lo_hi_w;                         // hi 和 lo 寄存器的写信号
    wire w_hi_we;                               // hi 寄存器写使能信号
    wire w_lo_we;                               // lo 寄存器写使能信号
    wire w_hi_we3;                              // hi 寄存器的另一个写使能信号
    wire w_lo_we3;                              // lo 寄存器的另一个写使能信号
    wire [31:0] hi_i;                          // hi 寄存器输入数据
    wire [31:0] lo_i;                          // lo 寄存器输入数据
    wire [31:0] hi_o;                          // hi 寄存器输出数据
    wire [31:0] lo_o;                          // lo 寄存器输出数据
    assign {    // 从 id_to_ex_bus 寄存器中获取数据并进行拆解
        ex_pc,          // 程序计数器值    158:127
        inst,           // 当前指令    126:95
        alu_op,         // ALU 操作码    94:83
        sel_alu_src1,   // ALU 源1选择    82:80
        sel_alu_src2,   // ALU 源2选择    79:76
        data_ram_en,    // 数据存储器使能    75
        data_ram_wen,   // 数据存储器写使能    74:71
        rf_we,          // 寄存器写使能    70
        rf_waddr,       // 寄存器写地址    69:65
        sel_rf_res,     // 寄存器文件写回数据选择    64
        rf_rdata1,      // rs 寄存器数据    63:32
        rf_rdata2,      // rt 寄存器数据    31:0 
        lo_hi_r,        // hi 和 lo 寄存器的读取信号    
        lo_hi_w,        // hi 和 lo 寄存器的写入信号    
        lo_o,           // lo 寄存器输出    
        hi_o,           // hi 寄存器输出    
        data_ram_read   // 数据存储器读信号    
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
//        lo_hi_r,                        //read信号
//        lo_hi_w,                        //write信号
//        lo_o,                           //lo值
//        hi_o                            //hi值
//      }= id_to_ex_2_r;
    
    assign w_lo_we3 = lo_hi_w[0]==1'b1 ? 1'b1:1'b0;    // 判断是否需要写 LO 寄存器
    assign w_hi_we3 = lo_hi_w[1]==1'b1 ? 1'b1:1'b0;    // 判断是否需要写 HI 寄存器
    
    assign inst_is_load =  (inst[31:26] == 6'b10_0011) ? 1'b1 :1'b0;    // 判断当前指令是否是 load 指令（即 LW 指令）
    
    
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;    // 立即数扩展：符号扩展
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};    // 符号扩展：将立即数的高 16 位根据符号位进行扩展
    assign imm_zero_extend = {16'b0, inst[15:0]};    // 零扩展：将高 16 位填充为 0
    assign sa_zero_extend = {27'b0,inst[10:6]};    // 将位移量（sa）扩展到 32 位，低 5 位为立即数的值，其他位为 0
    // 选择 ALU 输入的操作数
    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;
    // 根据选择信号 sel_alu_src1 和 sel_alu_src2 来选择 ALU 的输入源
    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    // 调用 ALU 模块进行计算
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );
    // 计算 EX 段的最终结果，选择 LO、HI 或 ALU 计算结果
    assign ex_result =  lo_hi_r[0] ? lo_o :
                         lo_hi_r[1] ? hi_o :
                         alu_result;

    // 数据存储器使能信号
    assign data_sram_en = data_ram_en ;
    assign data_sram_wen = (data_ram_read==4'b0101 && ex_result[1:0] == 2'b00 )? 4'b0001:     // 根据 ALU 结果的低 2 位和数据存储器读取控制信号来选择写使能信号
                            (data_ram_read==4'b0101 && ex_result[1:0] == 2'b01 )? 4'b0010:
                            (data_ram_read==4'b0101 && ex_result[1:0] == 2'b10 )? 4'b0100:
                            (data_ram_read==4'b0101 && ex_result[1:0] == 2'b11 )? 4'b1000:
                            (data_ram_read==4'b0111 && ex_result[1:0] == 2'b00 )? 4'b0011:
                            (data_ram_read==4'b0111 && ex_result[1:0] == 2'b10 )? 4'b1100:
                            data_ram_wen;
    //将 EX 段中算出的结果传给存储器进行寻址，并将寻址得到的值传递到 MEM 段中
    assign data_sram_addr = ex_result ;
    assign data_sram_wdata = data_sram_wen==4'b1111 ? rf_rdata2 : 
                              data_sram_wen==4'b0001 ? {24'b0,rf_rdata2[7:0]} :
                              data_sram_wen==4'b0010 ? {16'b0,rf_rdata2[7:0],8'b0} :
                              data_sram_wen==4'b0100 ? {8'b0,rf_rdata2[7:0],16'b0} :
                              data_sram_wen==4'b1000 ? {rf_rdata2[7:0],24'b0} :
                              data_sram_wen==4'b0011 ? {16'b0,rf_rdata2[15:0]} :
                              data_sram_wen==4'b1100 ? {rf_rdata2[15:0],16'b0} :
                              32'b0;
    // 将 EX 段中计算的结果打包成数据总线，传给 MEM 阶段
    assign ex_to_mem_bus = {
        ex_pc,         // 75:44 PC 地址
        data_ram_en,   // 43 数据存储器使能信号
        data_ram_wen,  // 42:39 数据存储器写使能
        sel_rf_res,    // 38 是否选择 RF 结果
        rf_we,         // 37 寄存器文件写使能
        rf_waddr,      // 36:32 写入寄存器的地址
        ex_result,     // 31:0 EX 段的运算结果
        data_ram_read  // 数据存储器的读取控制信号
    };
   
    /*跟数据相关有关的指令，当当前指令需要取前面还未存入寄存器的值的时候，
    EX 段提前发给 ID 段，再由 ID 段发送给 regfile 文件*/
    assign ex_to_id_bus = {
        rf_we,         // 37 寄存器文件写使能
        rf_waddr,      // 36:32 寄存器写入地址
        ex_result      // 31:0 EX 段的运算结果
    };
    // 处理乘法指令
    wire w_hi_we1;
    wire w_lo_we1;
    wire mult;
    wire multu;
    assign mult = (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1000);    // 判断是否是有符号乘法指令
    assign multu= (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1001);    // 判断是否是无符号乘法指令
    assign w_hi_we1 = mult | multu ;    // 判断是否需要写 HI、LO 寄存器
    assign w_lo_we1 = mult | multu ;
    
    // MUL part
//    wire [63:0] mul_result;
//    wire mul_signed; // 锟叫凤拷锟脚乘凤拷锟斤拷锟?
//    wire [31:0] mul_1;
//    wire [31:0] mul_2;
//    assign mul_1 = w_hi_we1 ? alu_src1 : 32'b0;
//    assign mul_2 = w_hi_we1 ? alu_src2 : 32'b0;
//    assign mul_signed = mult;

//    mul u_mul(
//    	.clk        (clk            ),
//        .resetn     (~rst           ),
//        .mul_signed (mul_signed     ),
//        .ina        (  mul_1    ), // 锟剿凤拷源锟斤拷锟斤拷锟斤拷1
//        .inb        (  mul_2    ), // 锟剿凤拷源锟斤拷锟斤拷锟斤拷2
//        .result     (mul_result     ) // 锟剿凤拷锟斤拷锟? 64bit
//    );
    wire [63:0] mul_result;    // 乘法结果，64 位
    wire mul_ready_i;    // 乘法操作是否准备好，表示乘法是否完成
//    wire [31:0] mul_1;
//    wire [31:0] mul_2;
    wire mul_begin;     // 乘法操作开始信号
//    assign mul_1 = w_hi_we1 ? alu_src1 : 32'b0;
//    assign mul_2 = w_hi_we1 ? alu_src2 : 32'b0;
    wire mul_signed;         // 是否进行有符号乘法
    assign mul_signed = mult;  // 如果是乘法指令，则设置为有符号乘法
    assign mul_begin = mult | multu;  // 当是乘法指令时开始乘法操作
    
    /*其中 mul_begin 用来判断乘法的开始，如果为1'b1，则进行乘法操作，
    并且通过指令来判断此次乘法为有符号乘法还是无符号乘法并传输进mul_plus.v 中。*/
    mul_plus u_mul_plus(
    .clk        (clk),            // 时钟信号
    .start_i    (mul_begin),      // 乘法开始信号
    .mul_sign   (mul_signed),     // 是否有符号乘法
    .opdata1_i  (rf_rdata1),      // 源操作数1
    .opdata2_i  (rf_rdata2),      // 源操作数2
    .result_o   (mul_result),     // 乘法结果，64 位
    .ready_o    (mul_ready_i)     // 乘法是否完成信号
);

    // DIV part
    wire [63:0] div_result;       // 除法结果，64 位
    wire inst_div, inst_divu;     // 是否为除法指令，分别是有符号除法和无符号除法
    wire div_ready_i;             // 除法操作是否准备好，表示除法是否完成
    reg stallreq_for_div;         // 除法请求暂停信号
    wire w_hi_we2;                // 写 HI 寄存器信号（除法相关）
    wire w_lo_we2;                // 写 LO 寄存器信号（除法相关）
    assign stallreq_for_ex = (stallreq_for_div & div_ready_i==1'b0) | (mul_begin & mul_ready_i==1'b0);    // 当除法尚未完成或乘法尚未完成时，需要暂停流水线
    assign ready_ex_to_id = div_ready_i | mul_ready_i;
    // 判断指令是否为除法指令
    assign inst_div = (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1010);
    assign inst_divu= (inst[31:26] == 6'b00_0000) & (inst[15:6] == 10'b0000000000) & (inst[5:0] == 6'b01_1011);
    assign w_hi_we2 = inst_div | inst_divu;    // 判断是否需要写 HI 和 LO 寄存器（除法相关）
    assign w_lo_we2 = inst_div | inst_divu;
    
// 定义除法操作的数据和控制信号
    reg [31:0] div_opdata1_o;  // 除法操作数1
    reg [31:0] div_opdata2_o;  // 除法操作数2
    reg div_start_o;            // 除法启动信号
    reg signed_div_o;           // 是否有符号除法
    

    // 实例化除法模块
    div u_div(
        .rst          (rst),          // 复位信号
        .clk          (clk),          // 时钟信号
        .signed_div_i (signed_div_o), // 是否有符号除法
        .opdata1_i    (div_opdata1_o), // 除法操作数1
        .opdata2_i    (div_opdata2_o), // 除法操作数2
        .start_i      (div_start_o),    // 除法开始信号
        .annul_i      (1'b0),           // 不取消除法
        .result_o     (div_result),     // 除法结果，64 位
        .ready_o      (div_ready_i)     // 除法是否完成信号
    );

    always @ (*) begin
        if (rst) begin    // 复位时，初始化信号
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin    // 正常情况下，初始化除法信号
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})    // 根据指令类型，决定除法操作的行为
                2'b10: begin  // 有符号除法
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1; // 有符号除法
                        stallreq_for_div = `Stop; // 暂停流水线
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;    // 恢复流水线
                    end
                    else begin    // 其他情况，停止除法操作
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin    // 无符号除法
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0; // 无符号除法
                        stallreq_for_div = `Stop; // 暂停流水线
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;    // 恢复流水线
                    end
                    else begin    // 其他情况，停止除法操作
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin    // 默认情况下，保持除法操作的停止状态
                end
            endcase
        end
    end
    // 根据乘法和除法操作的结果，决定是否将数据写入 LO 和 HI 寄存器
    assign lo_i = w_lo_we1 ? mul_result[31:0] :     // 如果是乘法，写入 LO 寄存器的低 32 位
                  w_lo_we2 ? div_result[31:0] :     // 如果是除法，写入 LO 寄存器的低 32 位
                  w_lo_we3 ? rf_rdata1 :            // 如果是其他情况，写入 RF 寄存器数据
                  32'b0;                            // 默认为 0
    assign hi_i = w_hi_we1 ? mul_result[63:32] :     // 如果是乘法，写入 HI 寄存器的高 32 位
                  w_hi_we2 ? div_result[63:32] :     // 如果是除法，写入 HI 寄存器的高 32 位
                  w_hi_we3 ? rf_rdata1 :            // 如果是其他情况，写入 RF 寄存器数据
                  32'b0;                            // 默认为 0
    assign w_hi_we = w_hi_we1 | w_hi_we2 | w_hi_we3;    // 如果任何一个写使能信号为 1，则 HI 寄存器可以被写入
    assign w_lo_we = w_lo_we1 | w_lo_we2 | w_lo_we3;
    
    /*EX 段要发送给 MEM 的值，其包括了写 hi 和 lo 寄存器的使能信号，
    用于判断是否进行写寄存器的操作，还有包括了将要写入 hi 和 lo 寄存器的值*/
        assign ex_to_mem1 =
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };
    //EX 段要发送给 ID 段中的regfile.v,用于解决下一条指令
    //要用到上一条指令存入 hilo 寄存器值的问题
    assign ex_to_id_2=
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };

    // mul_result 锟斤拷 div_result 锟斤拷锟斤拷直锟斤拷使锟斤拷
    
    
endmodule