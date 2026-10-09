# M6 (R16): empty depends combinationally on WEN
s/assign empty = count == 0;/assign empty = count == 0 \&\& !WEN;/
