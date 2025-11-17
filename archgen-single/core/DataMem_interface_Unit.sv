module DataMem_interface_Unit (
    input [2:0] funct3,
    input [31:0] write_data_in,
    input [31:0] mem_addr,
    input [31:0] mem_data_in,
    input MemRead,
    input MemWrite,
    output reg [31:0] extended_data,
    output [`DATA_BITS-3:0] address,
    output reg [31:0] write_data_out,
    output reg [3:0] byteena,
    output read_enable_out,
    output write_enable_out
);
    assign address = mem_addr[`DATA_BITS-1:2];
    assign read_enable_out = MemRead;
    assign write_enable_out = MemWrite;
    wire [1:0] byte_offset = mem_addr[1:0];
    // Load data processing
    always @(*) begin
        extended_data = 0;
        if (MemRead) begin
            case (funct3)
                `FUNCT3_MEM_BYTE: 
                    extended_data = {{24{mem_data_in[7+8*byte_offset]}}, mem_data_in[7+8*byte_offset -:8]};
                `FUNCT3_MEM_HALF: 
                    extended_data = {{16{mem_data_in[15+16*byte_offset[1]]}}, mem_data_in[15+16*byte_offset[1] -:16]};
                `FUNCT3_MEM_WORD: 
                    extended_data = mem_data_in;
                `FUNCT3_MEM_BYTE_U: 
                    extended_data = {24'b0, mem_data_in[7+8*byte_offset -:8]};
                `FUNCT3_MEM_HALF_U: 
                    extended_data = {16'b0, mem_data_in[15+16*byte_offset[1] -:16]};
                default: extended_data = 0;
            endcase
        end
    end
    // Store data processing
    always @(*) begin
        byteena = 4'b0000;
        write_data_out = 0;
        if (MemWrite) begin
            case (funct3)
                `FUNCT3_MEM_BYTE: begin
                    case (byte_offset)
                        0: byteena = 4'b0001;
                        1: byteena = 4'b0010;
                        2: byteena = 4'b0100;
                        3: byteena = 4'b1000;
                    endcase
                    write_data_out = write_data_in << (8*byte_offset);
                end
                `FUNCT3_MEM_HALF: begin
                    case (byte_offset)
                        0: byteena = 4'b0011;
                        2: byteena = 4'b1100;
                    endcase
                    write_data_out = write_data_in << (8*byte_offset);
                end
                `FUNCT3_MEM_WORD: begin
                    byteena = 4'b1111;
                    write_data_out = write_data_in;
                end
                default: begin
                    byteena = 4'b0000;
                    write_data_out = 0;
                end
            endcase
        end
    end
endmodule
