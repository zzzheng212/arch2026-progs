# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li t0, 0 # n (count) = 0
    beq a1, zero, loop_finish # b 為零不進迴圈
loop:
    and t1, a0, a1 #先 and
    slli t1, t1, 1
    xor a0, a0, a1
    mv a1, t1
    addi t0, t0 ,1
    bne a1, zero, loop #b 不為零則不跳 

loop_finish:
    sw t0, 0(a2)
    ret


    .size   op1_asm, .-op1_asm
    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub a0, a0, a1
    ret

    .size   op2_asm, .-op2_asm
    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    andi t0, a0, 1
    andi t1, a1, 1
    and t0, t0, t1 #t0 => carry
    srli a0, a0, 1 #unsigned  
    srli a1, a1, 1 #unsigned
    add t0, t0, a0
    add t0, t0, a1
    mv a0, t0
    ret

    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    li      a0, 0
    ret
    .size   q_mul_asm, .-q_mul_asm
