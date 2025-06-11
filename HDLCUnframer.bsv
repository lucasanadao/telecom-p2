import GetPut::*;
import FIFOF::*;
import Assert::*;

interface HDLCUnframer;
    interface Put#(Bit#(1)) in;
    interface Get#(Tuple2#(Bool, Bit#(8))) out;
endinterface

typedef enum {
    IDLE,
    PROCESS_FRAME,
    CHECK_BIT_STUFFING
} State deriving (Eq, Bits, FShow);

module mkHDLCUnframer(HDLCUnframer);
    FIFOF#(Tuple2#(Bool, Bit#(8))) fifo_out <- mkFIFOF;
    Reg#(Bool) start_of_frame <- mkReg(True);
    Reg#(State) state <- mkReg(IDLE);
    Reg#(Bit#(3)) current_index_k <- mkReg(0);
    Reg#(Bit#(8)) frame_byte <- mkRegU;
    Reg#(Bit#(8)) recent_bits <- mkReg(0);

    let hdlc_flag = 8'b01111110;

    interface out = toGet(fifo_out);

    interface Put in;
        method Action put(Bit#(1) b);
            let new_recent_bits = {b, recent_bits[7:1]};
            let next_index_k = current_index_k + 1;
            let new_frame_byte = {b, frame_byte[7:1]};
            let next_state = state;
            let possible_bit_stuffing = new_recent_bits[7:3] == 5'b11111;

            case (state)
                IDLE:
                    if (new_recent_bits == hdlc_flag) begin
                        next_state = PROCESS_FRAME;
                        next_index_k = 0;
                        start_of_frame <= True;
                    end
                PROCESS_FRAME: begin
                    if (possible_bit_stuffing) begin
                        next_state = CHECK_BIT_STUFFING;
                    end
                    
                    if (current_index_k == 7) begin
                        fifo_out.enq(tuple2(start_of_frame, new_frame_byte));
                        start_of_frame <= False;
                    end
                    
                    frame_byte <= new_frame_byte;
                end
                CHECK_BIT_STUFFING:
                    if (b == 0) begin
                        next_state = PROCESS_FRAME;
                        next_index_k = current_index_k;
                    end else begin
                        next_state = IDLE;
                    end
            endcase

            recent_bits <= new_recent_bits;
            current_index_k <= next_index_k;
            state <= next_state;
        endmethod
    endinterface
endmodule