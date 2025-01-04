`include "lib/defines.vh"
module CTRL(
    input wire rst,     //输入：复位信号，当为高时表示重置
    input wire stallreq_for_ex,    // 输入：执行阶段（EX）的暂停请求信号
//    input wire stallreq_for_load,  // 输入：加载阶段（LOAD）的暂停请求信号（当前未使用）  
    input wire stallreq_for_id,    // 输入：指令解码阶段（ID）的暂停请求信号
    // output reg flush,    // 输出：刷新信号（当前未使用）
    // output reg [31:0] new_pc,    // 输出：新的程序计数器值（PC）（当前未使用）
    output reg [`StallBus-1:0] stall    // 输出：暂停信号，控制流水线各阶段是否暂停
);  
    always @ (*) begin    // always块用于描述组合逻辑，(*)表示对所有输入信号变化敏感
        if (rst) begin    // 如果复位信号为高（rst为1），则将暂停信号stall置为全零（无暂停）
            stall = `StallBus'b0;
        end
        else if(stallreq_for_id == `Stop) begin    // 如果ID阶段有暂停请求（stallreq_for_id == `Stop），设置暂停信号为6'b000111，表示从ID阶段开始暂停流水线
            stall = 6'b000111;
        end
        else if( stallreq_for_ex == `Stop) begin    // 如果EX阶段有暂停请求（stallreq_for_ex == `Stop），设置暂停信号为6'b001111，表示从EX阶段开始暂停流水线
            stall = 6'b001111;
        end
        else begin    // 默认情况下，如果没有暂停请求，则将暂停信号stall置为全零（无暂停）
            stall = `StallBus'b0;
        end
    end

endmodule