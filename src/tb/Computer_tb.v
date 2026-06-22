`timescale 1ns / 1ps

module Computer_tb();
    
    reg reset, clk, done_storing, done_copying_io_regs;
    reg [7:0] ins_addr;
    reg [31:0] ins;
    reg [2:0] state = 3'b001;
    
    reg [31:0] input_value;
    reg input_value_valid;
    wire waiting_for_input;
    reg [1:0] input_count;
    
    wire [2:0] io_count;
    wire done, io_stall;
    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4, total_cycles, proc_cycles;
    
    Computer PC(
        .reset(reset), 
        .ins_addr(ins_addr), 
        .ins(ins), 
        .clk(clk), 
        .done_storing(done_storing), 
        .done_copying_io_regs(done_copying_io_regs), 
        .input_value(input_value), 
        .input_value_valid(input_value_valid), 
        .done(done), 
        .out_reg1(out_reg1), 
        .out_reg2(out_reg2), 
        .out_reg3(out_reg3), 
        .out_reg4(out_reg4), 
        .total_cycles(total_cycles), 
        .proc_cycles(proc_cycles), 
        .io_stall(io_stall), 
        .io_reg_index(io_count), 
        .waiting_for_input(waiting_for_input));
    
    always @(posedge clk) begin
        if (reset) input_count <= 0;
        if (state == 0) begin
            $display("<%d> outreg1 = %d, outreg2 = %d, outreg3 = %d, outreg4 = %d", $time, out_reg1, out_reg2, out_reg3, out_reg4);
            done_copying_io_regs <= 1;
            state <= 1;
        end
        else if (state == 1) begin
            done_copying_io_regs <= 0;
            if (io_stall) state <= 0;
            else if (waiting_for_input) state <= 4;
            else if (done) state <= 2;
        end
        else if (state == 2) begin
            $display("<%d> outreg1 = %d, outreg2 = %d, outreg3 = %d, outreg4 = %d, total cycles = %d, processor cycles = %d", $time, out_reg1, out_reg2, out_reg3, out_reg4, total_cycles, proc_cycles);
            $display("<%d> Processing of instructions finished", $time);
            state <= 3;
        end
        else if (state == 3) begin
        end
        else if (state == 4) begin
            if (input_count == 0) input_value <= 32'd15;
            else if (input_count == 1) input_value <= 32'd25;
            
            input_value_valid <= 1;
            state <= 5;
        end
        else if (state == 5) begin
            if (!waiting_for_input) begin
                input_value_valid <= 0; // Drop valid signal [cite: 284]
                input_count <= input_count + 1;
                state <= 1; // Return to polling
            end
        end
    end
    
    initial begin
        forever begin
            clk = 0;
            #5;
            clk = 1;
            #5;
            clk = 0;
        end
    end
    
    // Array to hold the translated MIPS program
    reg [31:0] program [0:36];
    integer i;

    initial begin
        reset = 1; done_storing = 0; done_copying_io_regs = 0;
        input_value_valid = 0; input_value = 0;
        
        // --- TRANSLATION OF PAGE 23 PROGRAM --- 
        
        // Setup Syscalls and Base Address
        program[0]  = 32'h201F03EC; // addi $31, $0, 1004 (Print Syscall ID)
        program[1]  = 32'h201E03E9; // addi $30, $0, 1001 (Exit Syscall ID)
        program[2]  = 32'h20020200; // addi $2, $0, 512   (Base Memory Address)

        // Step 1: Store 0xFE7654DC at address 512
        program[3]  = 32'h3C01FE76; // lui $1, 0xFE76     ($1 = 0xFE760000)
        program[4]  = 32'h342154DC; // ori $1, $1, 0x54DC ($1 = 0xFE7654DC)
        program[5]  = 32'hAC410000; // sw $1, 0($2)       (Mem[512] = 0xFE7654DC)

        // Step 2: Load the word using lw and print it
        program[6]  = 32'h8C430000; // lw $3, 0($2)
        program[7]  = 32'h03E3000C; // syscall $31, $3    (Should print 0xFE7654DC)

        // Step 3: Load 4 different bytes using lb and lbu, and print
        program[8]  = 32'h80440000; // lb $4, 0($2)       (Loads 0xFE, Sign Extended)
        program[9]  = 32'h03E4000C; // syscall $31, $4    (Should print 0xFFFFFFFE / -2)
        
        program[10] = 32'h90450001; // lbu $5, 1($2)      (Loads 0x76, Zero Extended)
        program[11] = 32'h03E5000C; // syscall $31, $5    (Should print 0x00000076 / 118)
        
        program[12] = 32'h80460002; // lb $6, 2($2)       (Loads 0x54, Sign Extended)
        program[13] = 32'h03E6000C; // syscall $31, $6    (Should print 0x00000054 / 84)
        
        program[14] = 32'h90470003; // lbu $7, 3($2)      (Loads 0xDC, Zero Extended)
        program[15] = 32'h03E7000C; // syscall $31, $7    (Should print 0x000000DC / 220)

        // Step 4: Load 2 different half words using lh and lhu, and print
        program[16] = 32'h84480000; // lh $8, 0($2)       (Loads 0xFE76, Sign Extended)
        program[17] = 32'h03E8000C; // syscall $31, $8    (Should print 0xFFFFFE76 / -394)
        
        program[18] = 32'h94490002; // lhu $9, 2($2)      (Loads 0x54DC, Zero Extended)
        program[19] = 32'h03E9000C; // syscall $31, $9    (Should print 0x000054DC / 21724)

        // Step 5: Store new byte values using four sb instructions, load word, and print
        program[20] = 32'h200A0012; // addi $10, $0, 0x12
        program[21] = 32'hA04A0000; // sb $10, 0($2)      (Overwrite Byte 0)
        program[22] = 32'h200A0034; // addi $10, $0, 0x34
        program[23] = 32'hA04A0001; // sb $10, 1($2)      (Overwrite Byte 1)
        program[24] = 32'h200A0056; // addi $10, $0, 0x56
        program[25] = 32'hA04A0002; // sb $10, 2($2)      (Overwrite Byte 2)
        program[26] = 32'h200A0078; // addi $10, $0, 0x78
        program[27] = 32'hA04A0003; // sb $10, 3($2)      (Overwrite Byte 3)
        program[28] = 32'h8C430000; // lw $3, 0($2)
        program[29] = 32'h03E3000C; // syscall $31, $3    (Should print 0x12345678)

        // Step 6: Store new half word values using two sh instructions, load word, and print
        program[30] = 32'h340AAAAA; // ori $10, $0, 0xAAAA
        program[31] = 32'hA44A0000; // sh $10, 0($2)      (Overwrite Half 0)
        program[32] = 32'h340ABBBB; // ori $10, $0, 0xBBBB
        program[33] = 32'hA44A0002; // sh $10, 2($2)      (Overwrite Half 1)
        program[34] = 32'h8C430000; // lw $3, 0($2)
        program[35] = 32'h03E3000C; // syscall $31, $3    (Should print 0xAAAABBBB)

        // Step 7: Exit
        program[36] = 32'h03C0000C; // syscall $30, $0    (Exit)

        #7 reset = 0;
        
        // Loop to feed instructions into Computer Memory
        for (i = 0; i < 37; i = i + 1) begin
            ins_addr = i;
            ins = program[i];
            #10;
        end
        
        done_storing = 1;
        
        // Wait for processor to complete the sequence
        #15000 $finish;     
    end
endmodule
