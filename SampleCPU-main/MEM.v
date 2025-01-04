`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,

    output wire [37:0] mem_to_id_bus,
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    
    input wire [65:0] ex_to_mem1,
    output wire[65:0] mem_to_wb1,
    output wire[65:0] mem_to_id_2 
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;
    reg [65:0] ex_to_mem1_r;

    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            ex_to_mem1_r <= 66'b0;
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            ex_to_mem1_r <= 65'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
            ex_to_mem1_r <= ex_to_mem1;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire [3:0] data_ram_read;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;
    
     wire w_hi_we;
     wire w_lo_we;
     wire [31:0]hi_i;
     wire [31:0]lo_i;
  

    assign {
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result,       // 31:0
        data_ram_read
    } =  ex_to_mem_bus_r;
    
    assign 
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    }=ex_to_mem1_r ;
    /*是 MEM 段要发送给 WB 的值，其包括了写 hi 和 lo 寄存器
    的使能信号，用于判断是否进行写寄存器的操作*/
    assign mem_to_wb1 =
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };
    /*MEM 段要发送给 ID 段中的regfile.v,用于解决下一条指令
    要用到上一条指令存入hilo寄存器值的问题*/
    assign mem_to_id_2 =
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };

    assign mem_result = data_sram_rdata;

    assign rf_wdata =  (data_ram_read==4'b1111 && data_ram_en==1'b1) ? mem_result :
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{24{mem_result[7]}},mem_result[7:0]}):
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({{24{mem_result[15]}},mem_result[15:8]}):
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{24{mem_result[23]}},mem_result[23:16]}):
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({{24{mem_result[31]}},mem_result[31:24]}):
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({24'b0,mem_result[7:0]}):
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({24'b0,mem_result[15:8]}):
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({24'b0,mem_result[23:16]}):
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({24'b0,mem_result[31:24]}):
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{16{mem_result[15]}},mem_result[15:0]}):
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{16{mem_result[31]}},mem_result[31:16]}):
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({16'b0,mem_result[15:0]}):
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({16'b0,mem_result[31:16]}):
                        ex_result;
//MEM 段要发送给 WB 段的值
    assign mem_to_wb_bus = {
        mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };
/*数据相关有关的指令，当当前指令需要取前面还未存入寄存器的值的时候，
由 MEM 段提前发给 ID 段，再由 ID 段发送给regfile.v文件中，
进行赋给 rs 和 rt 所需要的寄存器的值。*/
    assign mem_to_id_bus = {
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };




endmodule