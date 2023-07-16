
# changes from REGULAR_ad

+ `stw` is now `mem[rB] = reg[rA]` rather than the original `mem[rA] = reg[rB]`
+ initial value of `sp` is now `MEM_SIZE` and not `MEM_SIZE - 4`
