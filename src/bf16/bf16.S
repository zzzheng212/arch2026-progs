# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    #取出 8 位元 expo
    srli t0, a0, 23
    andi t0, t0, 0xFF

    #處理 Inf/NaN
    li t1, 0xFF
    beq t1, t0, f32_expofull
    #做rounding
    srli t0, a0, 16 #右移 16bits 因要捨棄 0 - 15
    andi t0, t0 ,1  #取得第 16 單 bit => lsb
    
    #加上 0x7FFF 跟 lsb
    li t1, 0x7FFF
    add a0, a0, t1
    add a0, a0, t0

f32_expofull: #Inf/NaN 直接回傳高 16bits
    srli a0, a0, 16
    ret


    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2

# bf16 相乘
bf16_mul_asm:
    xor t0, a0, a1 #為了看同號或是異號 sign bit
    li t1, 0x8000
    and t0, t0, t1 # 0 為同號相乘為正，反之
    #取 expo
    srli t2, a0, 7
    andi t2, t2, 0xFF # t2 為 a_expo
    srli t3, a1, 7
    andi t3, t3, 0xFF # t3 為 b_expo

    #取 frac
    andi t1, a0, 0x7F # t1 為 a_frac
    andi t4, a1, 0x7F # t4 為 b_frac

    #進檢查判斷式
    #先檢查 a
    li t5, 0xFF
    bne t2, t5, b_check # 看 a_expo是不是全 1，不是就跳
    # 再看 frac 是否為 0
    bne t1, zero, a_nan_return # 非零代表是 NaN，直接回傳 a

    # 沒跳代表 a 是 Inf，then check b 是不是正負 0
    li t6, 0x7FFF
    and t6, t6, a1
    beq t6, zero, is_nan #b 是 0
    j is_inf

# a 非全 1，看 b 是啥
b_check:
    bne t3, t5, check_zero # 看 b_expo 是不是全 1
    # 沒跳代表 b_expo全 1
    # 接著檢查 b_frac
    bne t4, zero, b_nan_return
    #沒跳代表 b 是 Inf
    #檢查 a 是否為 0
    li t6, 0x7FFF
    and t6, t6, a0
    beq t6, zero, is_nan #跳了代表 a 是 0
    j is_inf # a不是 0 且 b 是 Inf

check_zero:
    li t5, 0x7FFF
    and t6, a0, t5
    beq t6, zero, is_zero # a 為 0
    and t6, a1, t5
    beq t6, zero, is_zero # b 為 0
    #皆沒跳，兩者皆非 0，且非特殊值
    j both_finite

b_nan_return: # b 為 NaN 且 a 非特殊值， then 回傳 b
    mv a0, a1 #往下跑到return a ，剛好回傳 a0  
a_nan_return: # a 為 NaN 且 b 非特殊值， then 回傳 a
    ret
is_nan:
    li a0, 0x7FC0 #return NaN
    ret
is_inf: # 要記得看正負號
    li a0, 0x7F80
    or a0, a0, t0
    ret
is_zero:# 一樣有分正負，但 t0 已處理好
    mv a0, t0
    ret 
both_finite:
    beq t2, zero, a_denormal # a 為非正規化數
    # 沒跳 => a 為正常數
    addi t1, t1, 128 # mantissa
    addi t2, t2, -127 # 扣 bias
    j prepare_b

a_denormal:
    li t2, -126
a_normalize:
    li t5, 128
    bgeu t1, t5, prepare_b

    slli t1, t1, 1
    addi t2, t2,-1
    j a_normalize

prepare_b:
    beq t3, zero, b_denormal

    addi t4, t4, 128
    addi t3, t3, -127
    j multiply

b_denormal:
    li t3, -126
b_normalize:
    li t5, 128
    bgeu t4, t5, multiply

    slli t4, t4, 1
    addi t3, t3,-1
    j b_normalize

# 用位移加法算成績
multiply:
    add t2, t2, t3 # 乘完的真正指數
    li a0, 0 # product = 0

mul_loop:
    andi t5, t4, 1
    beq t5, zero, mul_shift

    add a0, a0, t1 # product += 被乘數

mul_shift:
    slli t1, t1, 1
    slli t4, t4, 1
    bne t4, zero, mul_loop

# 正規化 product ， 再截斷
    li t5, 32768
    bltu a0, t5, truncate

    srli a0, a0, 1
    addi t2, t2, 1

truncate:
    # 多乘一次128(frantion換mant乘過了) 相乘又多乘一次
    srli a0, a0, 7
    addi t2, t2, 127
    li t5, 255
    bge t2, t5, is_inf
    bge zero, t2, underflow

    # 正常結果
    andi a0, a0, 127
    slli t1, t1, 7
    or a0, a0, t2
    or a0, a0, t0
    ret

underflow:
    li t5, -6
    blt t2, t5, is_zero

    # denormal number
    li t5, 1
    sub t5, t5, t2
    srl a0, a0, t5
    or a0, a0, t0
    ret

    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2


# bf16 開根號
bf16_sqrt_asm:
    srli t0, a0, 7
    andi t0, t0, 0xFF # 取得 expo

    andi t1, a0, 0x7F # 取得 frac
    srli t2, a0, 15
    andi t2, t2, 1 # 取得 sign

    li t3, 0xFF
    bne t0, t3, sqrt_check_zero # 沒跳代表 expo 全 1

    #expo == 0xFF 看 frac 是啥

    bne t1, zero, return_same

    # +Inf 原樣回傳；負的回傳 NaN
    beq t2, zero, return_same
    j nan_return

sqrt_check_zero: # expo 非全 1
    li t3, 0x7FFF
    and t3, t3, a0
    beq t3, zero,  
return_same:

nan_return:







    
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
