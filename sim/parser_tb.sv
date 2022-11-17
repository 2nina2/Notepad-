`default_nettype none
`timescale 1ns / 1ps

module parser_tb;

    logic [7:0] byte_in;

    logic clk;
    logic rst;
    logic valid_in;

    logic board_done;
    logic write_ready;
    logic [12:0] assignment;

//SHOULD WE ADD M N ROW AND SUCH


    parser parse (
        .clk(clk),
        .rst(rst),
        .byte_in(byte_in),
        .valid_in(valid_in),
        
        .board_done(board_done),  //signals parser is done
        .write_ready(write_ready), //signals when output to be written to BRAM is done
        .assignment(assignment),

    );


    always begin
        #5;
        clk = !clk;
    end
    initial begin
        $dumpfile("parser.vcd");
        $dumpvars(0, parser_tb);
        $display("Starting Sim Parser");
        clk = 0;
        rst = 0;
        valid_in = 0;
        #5;
        rst = 1;
        #10;
        rst = 0;

        logic [25 :0] serial_bits;
        serial_bits = "1110_0000_0000_0_1100_0000_0000_0"//GET BITS FROM PYTHON CODE

        for (int i = 0; i<X; i = i + 8)begin
            valid_in = 1;
            rxd = serial_bits[i+7:i];
            serial_bits = {pre[25-7:0], 8'b00} ;
            #10;
        end

        valid_in = 0;
        #1000;

                rst = 1;
        #10;
        rst = 0;


        logic [61 :0] serial_bits;
        serial_bits = "1110_0000_0000_0110_0000_0000_0001_0000_0000_0010_1000_0000_0110_1000_0000_11"//GET BITS FROM PYTHON CODE

        for (int i = 0; i<X; i = i + 8)begin
            valid_in = 1;
            rxd = serial_bits[i+7:i];
            serial_bits = {pre[61-7:0], 8'b00} ;
            #10;
        end

        valid_in = 0;
        #1000;

                        rst = 1;
        #10;

        rst = 0;

        $display("Finishing Sim");
        $finish;
    end

endmodule

`default_nettype wire