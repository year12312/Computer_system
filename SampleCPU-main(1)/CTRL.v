`include "lib/defines.vh"
module CTRL(
    input wire rst,     //���룺��λ�źţ���Ϊ��ʱ��ʾ����
    input wire stallreq_for_ex,    // ���룺ִ�н׶Σ�EX������ͣ�����ź�
//    input wire stallreq_for_load,  // ���룺���ؽ׶Σ�LOAD������ͣ�����źţ���ǰδʹ�ã�  
    input wire stallreq_for_id,    // ���룺ָ�����׶Σ�ID������ͣ�����ź�
    // output reg flush,    // �����ˢ���źţ���ǰδʹ�ã�
    // output reg [31:0] new_pc,    // ������µĳ��������ֵ��PC������ǰδʹ�ã�
    output reg [`StallBus-1:0] stall    // �������ͣ�źţ�������ˮ�߸��׶��Ƿ���ͣ
);  
    always @ (*) begin    // always��������������߼���(*)��ʾ�����������źű仯����
        if (rst) begin    // �����λ�ź�Ϊ�ߣ�rstΪ1��������ͣ�ź�stall��Ϊȫ�㣨����ͣ��
            stall = `StallBus'b0;
        end
        else if(stallreq_for_id == `Stop) begin    // ���ID�׶�����ͣ����stallreq_for_id == `Stop����������ͣ�ź�Ϊ6'b000111����ʾ��ID�׶ο�ʼ��ͣ��ˮ��
            stall = 6'b000111;
        end
        else if( stallreq_for_ex == `Stop) begin    // ���EX�׶�����ͣ����stallreq_for_ex == `Stop����������ͣ�ź�Ϊ6'b001111����ʾ��EX�׶ο�ʼ��ͣ��ˮ��
            stall = 6'b001111;
        end
        else begin    // Ĭ������£����û����ͣ��������ͣ�ź�stall��Ϊȫ�㣨����ͣ��
            stall = `StallBus'b0;
        end
    end

endmodule