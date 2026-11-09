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
    xor t0, a0, a1
    srli t0, t0, 31 # t0 存 a,b是否同號或異號 t0 = 0 代表同號相乘為正，反之

    bge a0, zero, aready #檢查A是否大於 0，大於就跳
    sub a0, zero, a0 # 取絕對值

aready:
    bge a1, zero, bready
    sub a1, zero, a1

bready:
    li t1, 0 # product low
    li t2, 0 # product high

    mv t3, a0 # x low
    li t4, 0 # x high

q_mul_loop:
    beq a1, zero, q_muldone #while(ub != 0)條件式 
    andi t5, a1, 1 #ub & 1u

    beq t5, zero, q_shift # if(ub & 1) == 0 跳走
    # product += x :先加低32bits 
    add t5, t1, t3
    sltu t6, t5, t1 #t5(相加後的值) 若小於相加前的值 t1 及overflow 代表有進位要傳到上32bits
    mv t1, t5
    # 再加高 32 bits
    add t2, t2, t4
    add t2, t2, t6 #t6 為剛剛low 32 bits 之進位

q_shift:
    # 因 product (x) 是 64 bits故分段時 左移右移要特別處理
    # 目前 t4：高32位 | t3：低32位 => x
    # t2：乘積高32位 | t1：乘積低32位 => product
    # x <<= 1：低位的最高bit移入高位
    srli t5, t3, 31 # 右移 31 bits 取得 low 最高為bits 
    slli t4, t4, 1 # x 之 high 左移 1 bit
    or   t4, t4, t5 # 做 or 把 low 最高位放進來
    slli t3, t3, 1 # low 正常左移 補0

    srli a1, a1, 1 # ub >> 1
    j q_mul_loop

q_muldone:
    beq t0, zero, q_round #t0 != 0 代表異號 相乘結果為負
    not t1, t1
    not t2, t2 #product 高低位全部反轉
    #即 2的補數 1->0, 0->1 再加一
    addi t1, t1, 1 #低位加一
    sltiu t5, t1, 1 #若加完為零，代表有進位
    add t2, t2, t5 #進位加上高位 => 若有進位t5會等於 1 否則為 0 就沒差 

q_round:
    li t3, 0x80000 # 2^19
    add t5, t1, t3 # t5 = t1 + 2^19
    sltu t6, t5, t1 #一樣檢查是否 overflow
    mv t1, t5
    add t2, t2, t6 #一樣若有overflow，t6 會是 1

    #取第 20-51 位bits 作為回傳值
    srli t1, t1, 20 #low 20 bits
    slli t2, t2, 12 #high 12 bits
    or a0, t1, t2
    ret

    .size   q_mul_asm, .-q_mul_asm
