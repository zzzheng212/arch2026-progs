#include "bf16.h"
#include <stdio.h>
uint16_t bf16_from_f32(uint32_t f32bits);
uint16_t bf16_mul(uint16_t a, uint16_t b);
uint16_t bf16_sqrt(uint16_t a);
int main()
{
    uint32_t f32bits;
    uint16_t a;
    uint16_t b;
}
uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint32_t exponent = (f32bits >> 23) & 0xFFu;  // exponent為8位
    if (exponent == 0xFF) {
        return (f32bits >> 16);
    }
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    (void) a;
    (void) b;
    return 0;
}

uint16_t bf16_sqrt(uint16_t a)
{
    (void) a;
    return 0;
}
