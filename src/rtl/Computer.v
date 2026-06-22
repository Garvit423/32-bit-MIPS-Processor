`timescale 1ns / 1ps

`include "defs.vh"
module Computer(input reset, 
                input [7:0] ins_addr, 
                input [31:0] ins, 
                input clk, 
                input done_storing, 
                input done_copying_io_regs,
                input [31:0] input_value,
                input input_value_valid,
                output reg done, 
                output [31:0] out_reg1, 
                output [31:0] out_reg2, 
                output [31:0] out_reg3, 
                output [31:0] out_reg4, 
                output [31:0] total_cycles, 
                output [31:0] proc_cycles,
                output io_stall,
                output [2:0] io_reg_index,
                output waiting_for_input);
    
    wire [7:0] pc; // Output of Processor
    wire [31:0] ins_fetched; // Output of Memory
    wire [1:0] ins_mem_command; // Input to Memory
    reg [31:0] counter_total; // Counts total_cycles
    reg [31:0] counter_proc; // Counts proc_cycles
    wire halt; // Output of Processor
    wire [2:0] io_count_wire;
    
    wire [7:0] data_addr;
    wire data_addr_valid;
    wire [1:0] data_mem_command;
    wire [31:0] store_value;
    
    wire [7:0] mem_addr = done_storing ? (data_addr_valid ? data_addr : pc) : ins_addr;
    wire [1:0] mem_cmd  = done_storing ? (data_addr_valid ? data_mem_command : `READ_COMMAND) : `WRITE_COMMAND;
    wire [31:0] mem_in  = done_storing ? store_value : ins;
    
    wire memory_write_enable = (~reset) & (~done_storing | (data_addr_valid & (data_mem_command != `READ_COMMAND)));
    
    Memory mem(
        .write_enable(memory_write_enble),
        .clk(clk), 
        .command(mem_cmd), 
        .address(mem_addr),
        .word_in(mem_in),
        .word_out(ins_fetched)
    );
    Processor proc(
        .clk(clk), 
        .halt(halt), 
        .reset(~done_storing), 
        .pc(pc), 
        .ins(ins_fetched), 
        .io_reg1(out_reg1), 
        .io_reg2(out_reg2), 
        .io_reg3(out_reg3), 
        .io_reg4(out_reg4), 
        .io_stall(io_stall), 
        .copied_io_regs(done_copying_io_regs), 
        .io_regs_index_out(io_count_wire), 
        .waiting_for_input(waiting_for_input), 
        .input_value(input_value), 
        .input_value_valid(input_value_valid),
        .data_addr(data_addr),
        .data_addr_valid(data_addr_valid),
        .data_mem_command(data_mem_command),
        .store_value(store_value),
        .load_value(ins_fetched)
    );
    
    assign total_cycles = counter_total;
    assign proc_cycles = counter_proc;
    assign ins_mem_command = done_storing ? `READ_COMMAND : `WRITE_COMMAND;
    
    assign io_reg_index = io_count_wire;
    
    always @(posedge clk) begin
        if (reset) begin
            counter_total <= 32'b0;
            counter_proc <= 32'b0;
            done <= 1'b0;
        end
        else begin
            done <= halt;
            counter_total <= counter_total + 1;
            counter_proc <= (done_storing & ~halt & ~io_stall & ~waiting_for_input) ? counter_proc + 1 : counter_proc;
        end
    end
endmodule
