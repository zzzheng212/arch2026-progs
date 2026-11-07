# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beq a0, zero, one_zero
    beq a1, zero, one_zero
    
    #t0 存 shift 
    li t0, 0

common: #直到a or b變成奇數
    or t1, a0, a1
    andi t1, t1, 1
    bne t1, zero, afactor_by_two


    srli a0, a0, 1
    srli a1, a1, 1
    addi t0, t0 ,1
    j common

#將 a 變成奇數
afactor_by_two:
    andi t1, a0, 1 #檢查最低bit
    bne  t1, zero, bfactor_by_two

    srli a0, a0, 1
    j    afactor_by_two    

#將 b 變成奇數
bfactor_by_two:
    andi t1, a1, 1
    bne t1, zero, compare
    srli a1, a1, 1
    j bfactor_by_two

#比較 a , b 大小
compare:
    #看 a 是否小於 b
    bgeu a1, a0, subtract

    #交換 a , b
    mv t1, a0
    mv a0, a1
    mv a1, t1
subtract:
    sub a1, a1, a0
    bne a1, zero, bfactor_by_two

    #return a<<shift

    sll a0, ,a0, t0
    ret

#a or b 為 0，回傳非零值
one_zero: 
    or      a0, a0, a1
    ret 

.size   gcd_u32_asm, .-gcd_u32_asm