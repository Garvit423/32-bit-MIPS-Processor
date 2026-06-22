`timescale 1ns / 1ps

`include "defs.vh"
module Processor(
    input clk, 
    output halt, 
    input reset, 
    output reg [7:0] pc, 
    input [31:0] ins, 
    output [31:0] io_reg1,
    output [31:0] io_reg2, 
    output [31:0] io_reg3, 
    output [31:0] io_reg4,
    output reg io_stall,
    input copied_io_regs,
    output [2:0] io_regs_index_out,
    output reg waiting_for_input,
    input [31:0] input_value,
    input input_value_valid,
    output [7:0] data_addr,
    output data_addr_valid,
    output [1:0] data_mem_command,
    output reg [31:0] store_value,
    input [31:0] load_value
    );
    
    reg [5:0] OPCODE, FUNC;
    reg [4:0] SHAMT, DEST_ADDR;
    reg [31:0] SRC1, SRCV;
    
    reg [31:0] BRANCH_OFFSET;
    reg [4:0] RT;
    
    wire [5:0] opcode; // Extracted from ins
    wire [5:0] func; // Extracted from ins
    wire [4:0] shift_amount; // Extracted from ins
    wire [4:0] src1_addr; // rs extracted from ins (input to RF)
    wire [4:0] src2_addr; // rt extracted from ins (input to RF)
    
    wire [31:0] src1; // Output of RF, input to ALU
    wire [31:0] src2;
    wire [31:0] srcv; // Output of RF, input to ALU
    wire [4:0] dest_addr; // rt/rd extracted from ins (input to RF) 
    wire [31:0] dest_data; // Output of ALU, input to RF
    wire dest_data_valid; // Output of ALU, input to RF
    wire [7:0] next_pc; // Next instruction address
    
    wire branch_taken;
    
    wire [15:0] imm; // Immediate extracted from ins
    
    reg [31:0] io_reg [0:3]; // Circular I/O buffer
    reg [2:0] io_count; // Index to circular I/O buffer
    reg fetched; // Is first instruction fetched?
    
    reg [2:0] state;
    reg [31:0] wdata;
    reg [4:0] waddr;
    reg wen;
    
    assign io_reg1 = io_reg[0];
    assign io_reg2 = io_reg[1];
    assign io_reg3 = io_reg[2];
    assign io_reg4 = io_reg[3];
    assign io_regs_index_out = io_count;
    
    wire use_imm = (opcode == `OP_ADDI) || (opcode == `OP_ANDI) || (opcode == `OP_ORI) || (opcode == `OP_XORI) || (opcode == `OP_SLTI) || (opcode == `OP_SLTIU) || (opcode == `OP_LUI);
    wire is_sign_ext = (opcode == `OP_ADDI) || (opcode == `OP_SLTI) || (opcode == `OP_SLTIU);
    
    assign srcv = use_imm ? (is_sign_ext ? {{16{imm[15]}}, imm} : {{16{1'b0}}, imm}) : src2;
    
    RegisterFile rf (src1_addr, src2_addr, waddr, wdata, wen, clk, src1, src2);
    ALU alu (SRC1, SRCV, SHAMT, OPCODE, FUNC, pc, BRANCH_OFFSET, RT, dest_data, dest_data_valid, branch_taken);
    assign next_pc = (fetched & ~halt) ? pc + 1 : 8'b0;
    
    wire is_print = ((OPCODE == `OP_REG) && (FUNC == `FUNC_SYSCALL) && (SRC1 == `SYS_write));
    wire is_read  = ((OPCODE == `OP_REG) && (FUNC == `FUNC_SYSCALL) && (SRC1 == `SYS_read));
    wire is_load = (OPCODE == `OP_LW || OPCODE == `OP_LB || OPCODE == `OP_LBU || OPCODE == `OP_LH || OPCODE == `OP_LHU);
    wire is_store = (OPCODE == `OP_SW || OPCODE == `OP_SB || OPCODE == `OP_SH);
    
    wire [31:0] fast_mem_addr = SRC1 + BRANCH_OFFSET;

    assign data_addr_valid = (state == 1) && (is_load || is_store);
    assign data_addr = fast_mem_addr[9:2];
    assign data_mem_command = (OPCODE == `OP_SW) ? `WRITE_COMMAND : (OPCODE == `OP_SB || OPCODE == `OP_SH) ? `SUBWORD_WRITE_COMMAND : `READ_COMMAND;

    wire [1:0] byte_offset = fast_mem_addr[1:0];
    
    always @(*) begin
        store_value = SRCV; // Default for word store (sw)
        if (OPCODE == `OP_SB) begin
            case (byte_offset)
                2'b00: store_value = {SRCV[7:0], load_value[23:0]};
                2'b01: store_value = {load_value[31:24], SRCV[7:0], load_value[15:0]};
                2'b10: store_value = {load_value[31:16], SRCV[7:0], load_value[7:0]};
                2'b11: store_value = {load_value[31:8], SRCV[7:0]};
            endcase
        end
        else if (OPCODE == `OP_SH) begin
            case (byte_offset[1])
                1'b0: store_value = {SRCV[15:0], load_value[15:0]};
                1'b1: store_value = {load_value[31:16], SRCV[15:0]};
            endcase
        end
    end
    
    // SUBWORD LOAD EXTRACTION & EXTENSION (Big-Endian)
    reg [31:0] final_load_value;
    always @(*) begin
        final_load_value = load_value; // Default for word load (lw)
        if (OPCODE == `OP_LB) begin
            case (byte_offset)
                2'b00: final_load_value = {{24{load_value[31]}}, load_value[31:24]};
                2'b01: final_load_value = {{24{load_value[23]}}, load_value[23:16]};
                2'b10: final_load_value = {{24{load_value[15]}}, load_value[15:8]};
                2'b11: final_load_value = {{24{load_value[7]}}, load_value[7:0]};
            endcase
        end
        else if (OPCODE == `OP_LBU) begin
            case (byte_offset)
                2'b00: final_load_value = {24'b0, load_value[31:24]};
                2'b01: final_load_value = {24'b0, load_value[23:16]};
                2'b10: final_load_value = {24'b0, load_value[15:8]};
                2'b11: final_load_value = {24'b0, load_value[7:0]};
            endcase
        end
        else if (OPCODE == `OP_LH) begin
            case (byte_offset[1])
                1'b0: final_load_value = {{16{load_value[31]}}, load_value[31:16]};
                1'b1: final_load_value = {{16{load_value[15]}}, load_value[15:0]};
            endcase
        end
        else if (OPCODE == `OP_LHU) begin
            case (byte_offset[1])
                1'b0: final_load_value = {16'b0, load_value[31:16]};
                1'b1: final_load_value = {16'b0, load_value[15:0]};
            endcase
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'b0;
            io_count <= 2'b0;
            fetched <= 1'b0;
            state <= 0;
            wen <= 1'b0;
            io_stall <= 0;  
            waiting_for_input <= 0;
        end
        else begin
            if (state == 0) begin
                OPCODE <= opcode;
                FUNC <= func;
                SRC1 <= src1;
                SRCV <= srcv;
                SHAMT <= shift_amount;
                
                DEST_ADDR <= dest_addr;
                
                BRANCH_OFFSET <= (opcode == `OP_J || opcode == `OP_JAL) ? {6'b0, ins[25:0]} : {{16{imm[15]}}, imm};
                RT <= ins[20:16];
                
                fetched <= 1'b1;
                state <= 1;
                wen <= 1'b0;
            end
            else if (state == 1) begin
                if (is_print && io_count == 3'd4) begin
                    io_stall <= 1;
                    state <= 3;    
                end
                else if (is_read) begin
                    waiting_for_input <= 1;
                    state <= 5; 
                end
                else begin
                    if (is_print) io_count <= io_count + 1;
                    
                    wdata <= is_load ? final_load_value : dest_data;
                    waddr <= DEST_ADDR;
                    wen <= dest_data_valid & fetched;
                    state <= 2;
                end
            end
            else if (state == 2) begin
                if (halt) begin
                    pc <= pc;
                end
                else if (branch_taken) begin
                    if (OPCODE == `OP_JAL) pc <= BRANCH_OFFSET[7:0];
                    else if (OPCODE == `OP_REG && FUNC == `FUNC_JALR) pc <= SRC1[7:0];
                    else pc <= dest_data[7:0];
                end
                else begin
                    pc <= pc + 1;
                end
                
                state <= 0;
            end
            else if (state == 3) begin
                if (copied_io_regs) begin
                    io_stall <= 0;
                    state <= 4;
                end
            end
            else if (state == 4) begin
                if (!copied_io_regs) begin
                    io_count <= 3'b0;
                    state <= 1;
                end
            end
            else if (state == 5) begin
                if (input_value_valid) begin
                    waiting_for_input <= 0;
                    state <= 6;
                end
            end
            else if (state == 6) begin
                if (!input_value_valid) begin
                    wdata <= input_value;
                    waddr <= ins[15:11];
                    wen <= 1'b1;
                    state <= 2;
                end
            end
        end
    end
    
    always @(negedge clk) begin
        if (is_print && state == 1 && io_count < 3'd4) io_reg[io_count] <= SRCV;
    end
    
    assign opcode = ins[31:26];
    assign src1_addr = ins[25:21];
    assign src2_addr = ins[20:16];
    assign dest_addr = (opcode == `OP_JAL || (opcode == `OP_REG && func == `FUNC_JALR)) ? 5'd31 : (opcode == `OP_REG) ? ins[15:11] : ins[20:16];
    assign shift_amount = ins[10:6];
    assign func = ins[5:0];
    assign imm = ins[15:0];
    assign halt = (reset | ~fetched) ? 1'b0 : (((OPCODE == `OP_REG) && (FUNC == `FUNC_SYSCALL) && (SRC1 == `SYS_exit)) ? 1'b1 : 1'b0);

endmodule
