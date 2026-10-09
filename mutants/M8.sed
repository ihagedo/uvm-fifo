# M8 (R15): the read pointer skips slot 0 when it wraps
s/read_ptr_next = read_ptr + 1;/read_ptr_next = (read_ptr == ADDR_BITS'(DEPTH - 1)) ? 1 : read_ptr + 1;/
