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
    and  t0, a0, a1
    xor  t1, a0, a1
    srli t1, t1, 1
    add  a0, t0, t1
    ret

    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm   
    .type   q_mul_asm, @function
    .align  2

q_mul_asm:
    # 保留 XOR 的符號位，判斷乘積正負
    xor  t0, a0, a1

    # 取得 a 的無號絕對值
    bge  a0, zero, .Lqm_a_ready
    sub  a0, zero, a0

.Lqm_a_ready:
    # 取得 b 的無號絕對值
    bge  a1, zero, .Lqm_b_ready
    sub  a1, zero, a1

.Lqm_b_ready:
    li   t1, 0             # product low
    li   t2, 0             # product high
    mv   t3, a0            # x low
    li   t4, 0             # x high

    beq  a1, zero, .Lqm_done

.Lqm_loop:
    andi t5, a1, 1
    beq  t5, zero, .Lqm_shift

    # product += x
    add  t5, t1, t3
    sltu t6, t5, t1
    mv   t1, t5
    add  t2, t2, t4
    add  t2, t2, t6

.Lqm_shift:
    # 64位元的 x 左移一位
    srli t5, t3, 31
    slli t4, t4, 1
    or   t4, t4, t5
    slli t3, t3, 1

    srli a1, a1, 1
    bne  a1, zero, .Lqm_loop

.Lqm_done:
    # XOR 非負代表同號，不必取負
    bge  t0, zero, .Lqm_round

    # 對64位元乘積取二補數
    not  t1, t1
    not  t2, t2
    addi t1, t1, 1
    sltiu t5, t1, 1
    add  t2, t2, t5

.Lqm_round:
    # 加上 2^19，並補高位進位
    li   t3, 0x80000
    add  t1, t1, t3
    sltu t6, t1, t3
    add  t2, t2, t6

    # 取乘積的 bits 51～20，回傳低32位
    srli t1, t1, 20
    slli t2, t2, 12
    or   a0, t1, t2
    ret 

    .size   q_mul_asm, .-q_mul_asm
