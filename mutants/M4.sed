# M4 (R05): full asserts one entry early
s/assign full = int'(count) == FULL;/assign full = int'(count) >= FULL - 1;/
