
`timescale 1ns / 1ps
`default_nettype none
//assuming line index starts at 0

//packed arrays give the values the opposite way from what we expect, so array of 3X3, 
//when we call array[0] it will give the last 3 bits

module solver #(parameter MAX_ROWS = 11, parameter MAX_COLS = 11, parameter MAX_NUM_OPTIONS=84)(
        //TODO: confirm sizes for everything
        input wire clk,
        input wire rst,
        input wire started, //indicates board has been parsed, ready to solve
        input wire [15:0] option,
        input wire [$clog2(MAX_ROWS) - 1:0] num_rows,
        input wire [$clog2(MAX_COLS) - 1:0] num_cols,
        input wire [MAX_ROWS + MAX_COLS - 1:0] [6:0] old_options_amnt,  //[0:2*SIZE] [6:0]
        //Taken from the BRAM in the top level- how many options for this line
        output logic new_line,
        output logic [15:0] new_option,
        output logic [(MAX_ROWS * MAX_COLS) - 1:0] assigned,  //changed to 1D array for correct indexing
        output logic [(MAX_ROWS * MAX_COLS) - 1:0] known,      // changed to 1D array for correct indexing
        output logic put_back_to_FIFO,  //boolean- do we need to push to fifo
        output logic solved //1 when solution is good
    );
    localparam IDLE = 0;
    localparam NEW_LINE_INDEX = 1;
    localparam ONE_OPTION = 2;
    localparam MULTIPLE_OPTIONS = 3;

    logic [1:0] state;

    localparam LARGEST_DIM = (MAX_ROWS > MAX_COLS)? MAX_ROWS : MAX_COLS;
    logic [MAX_ROWS + MAX_COLS - 1:0] [6:0] options_amnt; 
    logic [MAX_ROWS + MAX_COLS - 1:0] line_ind; //was $clog2(SIZE)*2  but I(dana) changed it cuz anyway line index come from option which is in spec size
                                    //(veronica) changed again to match options amount (2*Size) -1
    logic row;
    assign row = line_ind < num_rows;
    assign new_line = (state != IDLE);
    
    logic valid_in_simplify;

    logic [$clog2(MAX_NUM_OPTIONS) - 1:0] options_left; //options left to get from the fifo
    logic [$clog2(MAX_NUM_OPTIONS) - 1:0] net_valid_opts; //how many valid options we checked

    //logic [SIZE-1:0] last_valid_option; //that is the last valid option we got for this line. we need it for when we transition we want to use it to assign
    logic simp_valid; //out put valid for simplify

    logic one_option_case;

    logic [LARGEST_DIM-1:0] curr_assign; //one line input of assigned input to simplify
    logic [LARGEST_DIM-1:0] curr_known; //one line input of known input to simplif

    logic [LARGEST_DIM-1:0] always1;// a and b
    logic [LARGEST_DIM-1:0] always0;

    logic  [(MAX_ROWS * MAX_COLS) - 1:0] known_t; //transpose
    logic  [(MAX_ROWS * MAX_COLS) - 1:0] assigned_t; //transpose


    //TRANSPOSING:
    genvar m; //rows
    genvar n; //cols
    for(m = 0; m < MAX_ROWS; m = m + 1) begin
        for(n = 0; n < MAX_COLS; n = n + 1) begin
            assign known_t[n*MAX_ROWS + m] = known[m*MAX_COLS + n];
            assign assigned_t[n*MAX_ROWS + m] = assigned[m*MAX_COLS + n];
        end
    end

//Grab the line from relevant known and assigned blocks
    always_comb begin
        //inputs to simplify
        //gets relevant line from assigned and known
        if (row) begin
            curr_assign = assigned[MAX_COLS*line_ind +: MAX_COLS];
            curr_known = known[MAX_COLS*line_ind +: MAX_COLS];
        end else begin
            curr_assign = assigned_t[MAX_ROWS*(line_ind - num_rows) +: MAX_ROWS];
            curr_known = known_t[MAX_ROWS*(line_ind - num_rows) +: MAX_ROWS];
        end
    end
    
    always_ff @(posedge clk)begin
        if(rst)begin
            known <= 0;
            assigned <= 0;
            net_valid_opts <=0;
            solved <= 0;
            state <= IDLE;
        end else begin
            case(state)
                IDLE: begin
                    if (started)begin
                        options_amnt <= old_options_amnt;
                        options_left <= old_options_amnt[option];
                        state <= (old_options_amnt[option] == 1)? ONE_OPTION : MULTIPLE_OPTIONS;
                        line_ind <= option;
                        net_valid_opts <= 0;
                        put_back_to_FIFO <= 1;
                        new_option <= option;
                        always1 <= '1;
                        always0 <= '1;
                    end
                    solved <= 0;
                end
                MULTIPLE_OPTIONS: begin
                    if (known == '1)begin
                        solved <= 1;
                        state <= IDLE;
                    end else begin
                        if (((curr_assign ^ option) & curr_known) > 0) put_back_to_FIFO <= 0;
                        else begin
                            new_option <= option;
                            net_valid_opts <= net_valid_opts + 1;
                            always1 <= always1 & option;
                            always0 <= always0 & ~option;
                            put_back_to_FIFO <= 1;
                        end
                        options_left <= options_left - 1;
                        state <= (options_left - 1 == 0)? NEW_LINE_INDEX : MULTIPLE_OPTIONS;
                    end
                end
                ONE_OPTION: begin
                    if (known == '1)begin
                        solved <= 1;
                        state <= IDLE;
                    end else begin
                        put_back_to_FIFO <= 0;
                        net_valid_opts <= 0;
                        always1 <= always1 & option;
                        always0 <= always0 & ~option;
                        options_left <= 0;
                        state <= NEW_LINE_INDEX;
                    end
                end
                NEW_LINE_INDEX: begin
                    //TODO check if specific bits of always1 or always0 are 1, if so assign it to known and assigned accordingly
                    if (row) begin
                        for(integer i = 0; i < MAX_COLS; i = i + 1) begin
                            if(i < num_cols) begin
                                if (always1[i] == 1) begin 
                                    known[MAX_COLS*line_ind + i] <= 1; //-1;//this might be wroing '{1}, suppose to be a whole ist of 1
                                    assigned[MAX_COLS*line_ind + i] <= 1;
                                end
                                if (always0[i] == 1) begin 
                                    known[MAX_COLS*line_ind + i] <= 1; //-1;//this might be wroing '{1}, suppose to be a whole ist of 1
                                    assigned[MAX_COLS*line_ind + i] <= 0;
                                end
                            end
                        end
                    end else begin
                        for(integer j = 0; j < MAX_ROWS; j = j + 1) begin
                            // I think the row we indexing into is j
                            //and the column is line index-size
                            if(j < num_rows) begin
                                if (always1[j]) begin 
                                    known[MAX_COLS*j + (line_ind - num_rows)] <= 1; //-1;//this might be wroing '{1}, suppose to be a whole ist of 1
                                    assigned[MAX_COLS*j + (line_ind - num_rows)] <= 1;
                                end
                                if (always0[j]) begin 
                                    known[MAX_COLS*j + (line_ind - num_rows)] <= 1; //-1;//this might be wroing '{1}, suppose to be a whole ist of 1
                                    assigned[MAX_COLS*j + (line_ind - num_rows)] <= 0;
                                end
                            end
                        end
                    end
                    options_amnt[line_ind] <= net_valid_opts;
                    options_left <= options_amnt[option];
                    line_ind <= option;
                    put_back_to_FIFO <= 1;
                    new_option <= option;
                    net_valid_opts <= 0;
                    always1 <= '1;
                    always0 <= '1;
                    state <= (options_amnt[option] == 1)? ONE_OPTION : MULTIPLE_OPTIONS;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
