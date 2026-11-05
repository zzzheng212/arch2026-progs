#include "bf16.h"
#include <stdio.h>
uint16_t bf16_from_f32(uint32_t f32bits);
uint16_t bf16_mul(uint16_t a, uint16_t b);
uint16_t bf16_sqrt(uint16_t a);
int main()
{
    // test
}
uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint32_t exponent = (f32bits >> 23) & 0xFFu;  // exponent為8位
    if (exponent == 0xFFu) {
        return (uint16_t) (f32bits >> 16);
    }
    uint32_t lsb = (f32bits >> 16) & 1u;  // get the last bit
    uint32_t round = f32bits + 0x7FFFu + lsb;
    return (uint16_t) (round >> 16);
}
uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint16_t a_expo = (a >> 7) & 0xFFu;  // first get a's information
    uint16_t a_sign = (a >> 15) & 0x1u;
    uint16_t a_frac = a & 0x7Fu;
    uint16_t a_mant = a_frac;
    uint16_t b_expo = (b >> 7) & 0xFFu;  // get b's information
    uint16_t b_sign = (b >> 15) & 0x1u;
    uint16_t b_frac = b & 0x7Fu;
    uint16_t b_mant = b_frac;

    uint16_t sign = (a ^ b) & 0x8000;  // use xor to get the a*b's sign

    if (a_expo == 0xFFu && a_frac != 0) {  // if a is NaN return a
        return a;
    } else if (a_expo == 0xFFu && a_frac == 0) {  // a is Inf, then check b
        if ((b & 0x7FFFu) == 0) {                 // 看B是不是0 不管正負
            return 0x7FC0;                        // return NaN
        }
        return sign | 0x7F80;                  // return +/- Inf
    } else {                                   // a is normal value or 0
        if (b_expo == 0xFFu && b_frac != 0) {  // b is NaN
            return b;
        } else if (b_expo == 0xFFu && b_frac == 0) {  // b is Inf
            if ((a & 0x7FFFu) == 0) {                 // a is zero
                return 0x7FC0;
            }
            return sign | 0x7F80;  // a is nonzero
        }
    }

    // a and b aren't special value
    // a or b is zero, then return zero with sign
    if ((a & 0x7fff) == 0 || (b & 0x7fff) == 0) {
        return sign;
    }

    // if a or b is denormalized num
    int e_a = (int) a_expo - 127;
    int e_b = (int) b_expo - 127;

    if (a_expo == 0) {
        e_a = -126;
        while (a_mant < 128u) {
            a_mant <<= 1;
            e_a--;
        }
    } else {
        a_mant += 128u;
    }

    if (b_expo == 0) {
        e_b = -126;
        while (b_mant < 128u) {
            b_mant <<= 1;
            e_b--;
        }
    } else {
        b_mant += 128u;
    }


    // a and b are nonzero
    uint32_t product = (uint32_t) a_mant * b_mant;
    int e = e_a + e_b;
    if (product >= 32768u) {  // 2**15 = 32768
        e++;
        product >>= 1;
    }
    uint32_t mant =
        product >> 7;  // 多乘一次128(frantion換mant乘過了) 相乘又多乘一次

    int exp = e + 127;  // bias = 127
    // 分三case
    // 1. exp太大 -> Inf
    if (exp >= 255) {
        return (uint16_t) (sign | 0x7F80);
    }
    // 2. exp太小 -> denormalized num
    else if (exp <= 0) {
        if (exp < -6) {  // exp小於-6六直接當零，因左移7bits仍為0
            return sign;
        }
        uint32_t frac = mant >> (1 - exp);
        return (uint16_t) (sign | frac);
    }
    // 3. 皆正常
    else {
        return (uint16_t) (sign | ((uint32_t) exp << 7) | (mant & 0x7Fu));
    }
}
uint16_t bf16_sqrt(uint16_t a)
{
    uint16_t a_expo = (a >> 7) & 0xFFu;  // first get a's information
    uint16_t a_sign = (a >> 15) & 0x1u;
    uint16_t a_frac = a & 0x7Fu;
    uint16_t a_mant = a_frac;
    /*
     * A NaN is returned unchanged. +Inf is returned unchanged. -Inf, and any
     * negative nonzero value, give the quiet NaN.
     * Any zero (including -0) gives +0 (0x0000). Denormals give +0.
     */
    if (a_expo == 0xFFu && a_frac != 0) {  // if a is NaN return a
        return a;
    } else if (a_expo == 0xFFu && a_frac == 0 &&
               a_sign == 0) {  // a is positive Inf
        return a;              // return a
    }

    // if a's sign is negative
    if (a_sign == 1) {
        if ((a & 0x7fff) == 0) {  // a is negative zero
            return 0;
        }
        // then all negative num return NaN
        else {
            return 0x7fC0u;
        }
    }

    // non-negative finite number
    //+0 and denormalized number reutrn 0
    if (a_sign == 0 && a_expo == 0) {
        return 0;
    }
    // normalized number
    int e = a_expo - 127;
    uint32_t mantissa = 128u + a_frac;  // 128 * (1 + frac/128) = 128 + frac
    if (e % 2 != 0) {                   // exponent not 2's mutiple
        mantissa <<= 1;
        e--;
    }
    int result_e = e / 2;
    /*the integer square root of the scaled significand is found by a search
    over mid in [90, 256] for the largest mid with (mid * mid) / 128 <= m
    (truncating).*/
    int low = 90;
    int high = 256;
    uint32_t root = 0;

    // binary search to find accurate mid
    // root先整數部分下去算，檢查時要右移7bits
    while (low <= high) {
        int mid = low + ((high - low) / 2);
        uint32_t square = (uint32_t) mid * (uint32_t) mid;
        if ((square >> 7) <= mantissa) {
            root = (uint32_t) mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    // turn back to bf16

    if (root >= 256u) {  // mantissa太大，除 2 加回 exponent
        root >>= 1;
        result_e++;
    }
    result_e += 127;

    if (result_e >= 255u) {  // Inf 計算過後是 Inf 的話要回傳 Inf 非 a
        return 0x7F80u;
    }

    if (result_e < 0) {  // 結果為 denormalized number return 0
        return 0;
    }
    // 正常值
    return (uint16_t) ((result_e << 7) | (root) & 0x7F);
}
