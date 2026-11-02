#include <stdio.h>
#include "gcd.h"
uint32_t gcd_u32(uint32_t a, uint32_t b);

int main()
{
    uint32_t a = 50;
    uint32_t b = 10;
    printf("%d", gcd_u32(a, b));  // it should return 10
    return 0;
}
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (!a || !b) {    // a or b equal zero
        return a | b;  // | is bitwise or operation
    }
    int shift = 0;  // record 2^^shift
    for (shift = 0; !((a | b) & 1u);
         shift++) {  // 直到 a or b 變成 odd 則跳出迴圈
        a /= 2;
        b /= 2;
    }
    while (!(a & 1)) {  // if a is even 則除 2 到變成奇數 a至少會是 1
        a /= 2;
    }
    do {
        while (!(b & 1)) {
            b /= 2;  // if b is even 則除 2 到變成奇數 a至少會是 1
        }
        if (a > b) {
            a -= b;
        } else {
            uint32_t tmp = b - a;
            a = b;
            b = tmp;  // 這樣每次處理 b 是否為偶數就好
        }
    } while (b);  // 即當 tmp 一直大於 0 代表(tmp)還可以相減

    return a << shift;  // a 的 shift 次方即為解
}