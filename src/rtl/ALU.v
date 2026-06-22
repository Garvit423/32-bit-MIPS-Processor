`timescale 1ns / 1ps

`include "defs.vh"
module ALU(
    input [31:0] src1,
    input [31:0] src2,
    input [4:0] shift_amount,
    input [5:0] opcode,
    input [5:0] func,
    input [7:0] pc,
    input [31:0] branch_offset, 
    input [4:0] rt,
    output [31:0] dest,
    output dest_valid,
    output reg branch_taken
    );
    
    reg [31:0] result;
    reg result_valid;
    
    assign dest = result;
    assign dest_valid = result_valid;
    
    always @(*) begin
        result = 32'b0;
        result_valid = 0;
        branch_taken = 0;
        
        case (opcode)
            `OP_REG: begin
                case (func)
                    `FUNC_SLL: begin
                        result = src1 << shift_amount;
                        result_valid = 1'b1;
                    end
                    `FUNC_SRL: begin
                        result = src1 >>> shift_amount;
                        result_valid = 1'b1;
                    end
                    `FUNC_SRA: begin
                        result = $signed(src1) >>> shift_amount;
                        result_valid = 1'b1;
                    end
                    `FUNC_SLLV: begin
                        result = src1 << src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_SRLV: begin
                        result = src1 >>> src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_SRAV: begin
                        result = $signed(src1) >>> src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_SYSCALL: begin
                        result = 32'b0;
                        result_valid = 1'b0;
                    end
                    `FUNC_ADD: begin
                        result = src1 + src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_SUB: begin
                        result = src1 - src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_AND: begin
                        result = src1 & src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_OR: begin
                        result = src1 | src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_XOR: begin
                        result = src1 ^ src2;
                        result_valid = 1'b1;
                    end
                    `FUNC_NOR: begin
                        result = ~(src1 | src2);
                        result_valid = 1'b1;
                    end
                    `FUNC_SLT: begin 
                        result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0;
                        result_valid = 1'b1; 
                    end
                    `FUNC_SLTU: begin 
                        result = (src1 < src2) ? 32'd1 : 32'd0;
                        result_valid = 1'b1;
                    end
                    `FUNC_JR: begin 
                        result = src1; branch_taken = 1'b1;
                        result_valid = 1'b0; 
                    end
                    `FUNC_JALR: begin 
                        result = {24'b0, pc + 8'b1}; branch_taken = 1'b1;
                        result_valid = 1'b1; 
                     end
                endcase
            end
            `OP_ADDI: begin
                result = src1 + src2;
                result_valid = 1'b1;    
            end
            `OP_ANDI: begin
                result = src1 & src2;
                result_valid = 1'b1;
            end
            `OP_ORI: begin
                result = src1 | src2;
                result_valid = 1'b1;
            end
            `OP_XORI: begin
                result = src1 ^ src2;
                result_valid = 1'b1;
            end
            `OP_SLTI:  begin 
                result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; 
                result_valid = 1'b1; 
            end
            `OP_SLTIU: begin 
                result = (src1 < src2) ? 32'd1 : 32'd0; 
                result_valid = 1'b1; 
            end
            
            `OP_J: begin 
                result = branch_offset; 
                branch_taken = 1'b1; 
                result_valid = 1'b0; 
            end
            `OP_JAL: begin 
                result = {24'b0, pc + 8'b1}; 
                branch_taken = 1'b1; 
                result_valid = 1'b1; 
            end
            
            `OP_BEQ: begin 
                result = {24'b0, pc} + branch_offset; 
                branch_taken = (src1 == src2); 
                result_valid = 1'b0; 
            end
            `OP_BNE: begin 
                result = {24'b0, pc} + branch_offset; 
                branch_taken = (src1 != src2); 
                result_valid = 1'b0; 
            end
            `OP_BLEZ: begin 
                result = {24'b0, pc} + branch_offset; 
                branch_taken = ($signed(src1) <= 0); 
                result_valid = 1'b0; 
            end
            `OP_BGTZ: begin 
                result = {24'b0, pc} + branch_offset; 
                branch_taken = ($signed(src1) > 0); 
                result_valid = 1'b0; 
            end
            `OP_REGIMM: begin // Handles bltz and bgez based on rt field
                result = {24'b0, pc} + branch_offset;
                result_valid = 1'b0;
                if (rt == 5'b00000)      branch_taken = ($signed(src1) < 0);  // bltz
                else if (rt == 5'b00001) branch_taken = ($signed(src1) >= 0); // bgez
            end
            `OP_LUI: begin
                result = {src2[15:0], 16'b0};
                result_valid = 1'b1;
            end
            `OP_LB, `OP_LH, `OP_LW, `OP_LBU, `OP_LHU: begin
                result = src1 + branch_offset;
                result_valid = 1'b1;
            end
            `OP_SB, `OP_SH, `OP_SW: begin
                result = src1 + branch_offset;
                result_valid = 1'b0;
            end
        endcase
    end
    
endmodule
