#include "bf16.h"
#include <stdio.h>
uint16_t bf16_from_f32(uint32_t f32bits);
uint16_t bf16_mul(uint16_t a, uint16_t b);
uint16_t bf16_sqrt(uint16_t a);
int main()
{
    uint32_t f32bits = 0xf33323fd;  // 0xf333
    printf("0x%04X\n", bf16_from_f32(f32bits));
    return 0;
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
    uint16_t a_mant = 128u + a_frac;     // 128 * (1 + frac/128) = 128 + frac
    uint16_t b_expo = (b >> 7) & 0xFFu;  // get b's information
    uint16_t b_sign = (b >> 15) & 0x1u;
    uint16_t b_frac = b & 0x7Fu;
    uint16_t b_mant = 128u + b_frac;

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
            return sign | 0x7FC0;  // a is nonzero
        }
    }

    // a and b aren't special value
    // a or b is zero, then return zero with sign
    if ((a & 0x7fff) == 0 || (b & 0x7fff) == 0) {
        return sign;
    }
    // a and b are nonzero
    uint32_t product = a_mant * b_mant;
    int e = a_expo + b_expo;
    if (product > 32768u) {  // 2**15 = 32768
        e++;
        product >> 1;
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
uint16_t bf16_sqrt(uint16_t a) {}
