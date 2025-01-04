`include "lib/defines.vh"
module MEM(
    input wire clk,                      // 时钟信号
    input wire rst,                      // 重置信号
    // input wire flush,                  // 如果有flush信号，可以用于指令刷新，暂时注释掉
    input wire [`StallBus-1:0] stall,    // 停顿信号，控制流水线暂停

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,    // 从EX阶段传来的总线数据
    input wire [31:0] data_sram_rdata,   // 从数据存储器读取的数据

    output wire [37:0] mem_to_id_bus,    // 向ID阶段发送的总线数据
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,  // 向WB阶段发送的总线数据
    
    input wire [65:0] ex_to_mem1,        // EX阶段传来的第二条数据总线，包含hi、lo寄存器信息
    output wire[65:0] mem_to_wb1,        // 向WB阶段发送hi、lo寄存器信息
    output wire[65:0] mem_to_id_2        // 向ID阶段发送hi、lo寄存器信息，用于解决数据冒险
);
    // 定义寄存器用于保存来自EX阶段的数据
    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;
    reg [65:0] ex_to_mem1_r;
    // 时钟边沿触发时执行
    always @ (posedge clk) begin
        if (rst) begin    // 复位操作，将寄存器清零
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            ex_to_mem1_r <= 66'b0;
        end
        // else if (flush) begin    // 如果有flush信号，清空寄存器（暂时注释掉）
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin    // 如果MEM阶段需要暂停且EX阶段不暂停，则清空寄存器
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            ex_to_mem1_r <= 65'b0;
        end
        else if (stall[3]==`NoStop) begin    // 如果MEM阶段不需要暂停，将EX阶段的数据传递给MEM阶段
            ex_to_mem_bus_r <= ex_to_mem_bus;
            ex_to_mem1_r <= ex_to_mem1;
        end
    end
    // 从ex_to_mem_bus_r中解包各个信号
    wire [31:0] mem_pc;          // 指令地址
    wire data_ram_en;           // 数据存储器使能信号
    wire [3:0] data_ram_wen;    // 数据存储器写使能信号
    wire [3:0] data_ram_read;   // 数据存储器读使能信号
    wire sel_rf_res;            // 用于选择写回到寄存器文件的数据
    wire rf_we;                 // 寄存器文件写使能
    wire [4:0] rf_waddr;        // 寄存器文件写地址
    wire [31:0] rf_wdata;       // 写回寄存器的数据
    wire [31:0] ex_result;      // EX阶段计算的结果
    wire [31:0] mem_result;     // 从数据存储器读取的数据
    // 处理hi和lo寄存器的信号
    wire w_hi_we;               // 写hi寄存器使能
    wire w_lo_we;               // 写lo寄存器使能
    wire [31:0] hi_i;           // 写入hi寄存器的数据
    wire [31:0] lo_i;           // 写入lo寄存器的数据
  
// 解包ex_to_mem_bus_r信号，提取必要的信息
    assign {
        mem_pc,             // 75:44 指令地址
        data_ram_en,        // 43 数据存储器使能
        data_ram_wen,       // 42:39 数据存储器写使能
        sel_rf_res,         // 38 选择是否写回寄存器
        rf_we,              // 37 寄存器写使能
        rf_waddr,           // 36:32 寄存器写地址
        ex_result,          // 31:0 EX阶段计算结果
        data_ram_read       // 读使能信号
    } = ex_to_mem_bus_r;
// 解包ex_to_mem1_r信号，提取hi和lo寄存器的相关数据
    assign {
        w_hi_we,          // hi寄存器写使能
        w_lo_we,          // lo寄存器写使能
        hi_i,             // hi寄存器数据
        lo_i              // lo寄存器数据
    } = ex_to_mem1_r;
    
    /*是 MEM 段要发送给 WB 的值，其包括了写 hi 和 lo 寄存器
    的使能信号，用于判断是否进行写寄存器的操作*/
   assign mem_to_wb1 = {
        w_hi_we,          // hi寄存器写使能
        w_lo_we,          // lo寄存器写使能
        hi_i,             // hi寄存器数据
        lo_i              // lo寄存器数据
    };
    
    /*MEM 段要发送给 ID 段中的regfile.v,用于解决下一条指令
    要用到上一条指令存入hilo寄存器值的问题*/
    assign mem_to_id_2 = {
        w_hi_we,          // hi寄存器写使能
        w_lo_we,          // lo寄存器写使能
        hi_i,             // hi寄存器数据
        lo_i              // lo寄存器数据
    };

// MEM阶段从数据存储器读取的数据，通常是内存数据
    assign mem_result = data_sram_rdata;
// 根据内存访问类型选择将何种数据写回到寄存器文件
    assign rf_wdata =  (data_ram_read==4'b1111 && data_ram_en==1'b1) ? mem_result :    // 如果是读一个完整的32位数据
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{24{mem_result[7]}},mem_result[7:0]}):  // 如果是字节读取并且从最低地址开始，进行符号扩展
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({{24{mem_result[15]}},mem_result[15:8]}):  // 如果是字节读取并且从第1个字节开始，进行符号扩展
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{24{mem_result[23]}},mem_result[23:16]}):  // 如果是字节读取并且从第2个字节开始，进行符号扩展
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({{24{mem_result[31]}},mem_result[31:24]}):  // 如果是字节读取并且从第3个字节开始，进行符号扩展
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({24'b0,mem_result[7:0]}):  // 如果是字节读取并且从最低地址开始，进行零扩展
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({24'b0,mem_result[15:8]}):  // 如果是字节读取并且从第1个字节开始，进行零扩展
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({24'b0,mem_result[23:16]}):  // 如果是字节读取并且从第2个字节开始，进行零扩展
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({24'b0,mem_result[31:24]}):  // 如果是字节读取并且从第3个字节开始，进行零扩展
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{16{mem_result[15]}},mem_result[15:0]}):  // 如果是半字读取并且从最低地址开始，进行符号扩展
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{16{mem_result[31]}},mem_result[31:16]}):  // 如果是半字读取并且从第2个字节开始，进行符号扩展
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({16'b0,mem_result[15:0]}):  // 如果是字读取并且从最低地址开始，进行零扩展
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({16'b0,mem_result[31:16]}):  // 如果是字读取并且从第2个字节开始，进行零扩展
                        ex_result;  // 如果不满足上述条件，则默认返回EX阶段的计算结果
//MEM 段要发送给 WB 段的值
    assign mem_to_wb_bus = {
        mem_pc,    // 69:38 传递指令的地址
        rf_we,     // 37   寄存器写使能信号
        rf_waddr,  // 36:32 寄存器写地址
        rf_wdata   // 31:0 需要写入寄存器的数据
    };
/*数据相关有关的指令，当当前指令需要取前面还未存入寄存器的值的时候，
由 MEM 段提前发给 ID 段，再由 ID 段发送给regfile.v文件中，
进行赋给 rs 和 rt 所需要的寄存器的值。*/
    assign mem_to_id_bus = {
        rf_we,     // 37  寄存器写使能信号
        rf_waddr,  // 36:32 寄存器写地址
        rf_wdata   // 31:0 需要写入寄存器的数据
    };


endmodule