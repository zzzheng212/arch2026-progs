#include "rubik.h"
#include "rubik_tables.h"

enum {
    CUBIES = 7,           // Seven movable corners
    PERMUTATIONS = 5040,  // 7! 種排列
    ORIENTATIONS = 729,   // 3^6 種合法方向
    MOVES = 9,            // R、R2、R'、B、B2、B'、D、D2、D'
    MAX_DEPTH = 11        // 最短解最多11步
};

typedef struct {  // define rubik
    uint8_t p[CUBIES];
    uint8_t o[CUBIES];
} state_t;

static int parse_input(const char *input, state_t *s);
static uint16_t rank_permutation(const state_t *s);
static uint16_t rank_orientation(const state_t *s);

// 記錄找到的解，每個數字對應一種轉動
static uint8_t path[MAX_DEPTH];

// p、o：目前排列與方向索引
// remaining：還能走幾步
// depth：目前走了幾步
// last_face：上一步轉哪個面；3代表沒有
static int search(unsigned p,
                  unsigned o,
                  unsigned remaining,
                  unsigned depth,
                  unsigned last_face)
{
    if (p == 0 && o == 0) {
        return 1;
    }

    // 兩種距離都不能高估，取較大者作為下界
    unsigned h = dist_p[p];

    if (dist_o[o] > h) {
        h = dist_o[o];
    }

    if (h > remaining || remaining == 0) {
        return 0;
    }

    for (unsigned face = 0; face < 3; face++) {
        // 同一面連轉可以合併，不會是最短解
        if (face == last_face) {
            continue;
        }

        unsigned np = p;
        unsigned no = o;

        for (unsigned turn = 0; turn < 3; turn++) {
            // 依序累積轉90、180、270度
            np = permutation[face][np];
            no = orientation[face][no];

            path[depth] = (uint8_t) (face * 3u + turn);

            if (search(np, no, remaining - 1u, depth + 1u, face)) {
                return 1;
            }
        }
    }

    return 0;
}
/* Return the shortest move count, or the contract error code. */
int rubik_solve(const char *state, char *out, size_t cap)
{
    state_t s;

    // 無效輸入不能改動 out
    if (!parse_input(state, &s)) {
        return -1;
    }

    unsigned p = rank_permutation(&s);
    unsigned o = rank_orientation(&s);

    unsigned bound = dist_p[p];

    if (dist_o[o] > bound) {
        bound = dist_o[o];
    }

    // 從下界開始增加步數，第一次成功就是最短解
    while (bound <= MAX_DEPTH) {
        if (search(p, o, bound, 0, 3)) {
            break;
        }

        bound++;
    }

    // 合法狀態理應都能在11步內完成
    if (bound > MAX_DEPTH) {
        return -1;
    }

    static const char names[MOVES][3] = {"R",  "R2", "R'", "B", "B2",
                                         "B'", "D",  "D2", "D'"};

    // 計算字元數，包含結尾 '\0'
    size_t need = 1;

    for (unsigned i = 0; i < bound; i++) {
        if (i != 0) {
            need++;
        }

        need++;  // 面名稱

        if (names[path[i]][1] != '\0') {
            need++;  // 2 或 '
        }
    }

    if (need > cap) {
        if (cap > 0) {
            out[0] = '\0';
        }

        return -2;
    }

    size_t w = 0;

    for (unsigned i = 0; i < bound; i++) {
        if (i != 0) {
            out[w++] = ' ';
        }

        out[w++] = names[path[i]][0];

        if (names[path[i]][1] != '\0') {
            out[w++] = names[path[i]][1];
        }
    }

    out[w] = '\0';
    return (int) bound;  // 回傳步數，不是字元數
}
static int parse_input(const char *input, state_t *s)
{  // 沿用上次作業函式座改良去檢查輸入是否正確
    unsigned seen = 0;
    unsigned sum = 0;

    for (unsigned i = 0; i < RUBIK_STATE_LEN; i++)  // 檢查是否為正常14bits
    {
        if (input[i] == '\0') {  // 沒有完整 14 bits
            return 0;
        }
    }
    if (input[RUBIK_STATE_LEN] != '\0') {  // 第 15 bit 不為結束符號也錯誤
        return 0;
    }
    for (unsigned i = 0; i < CUBIES; i++) {
        char p = input[i];
        char o = input[i + CUBIES];

        if (p < '1' || p > '7' || o < '1' || o > '3') {  // 超過正常範圍也錯誤
            return 0;
        }

        unsigned bit = 1u << (unsigned) (p - '1');

        if (seen & bit) {  // 如果已看過且標記位元是 1，就代表重複
            return 0;
        }

        seen |= bit;                    // bitwise operation用來記錄該 p 已看過
        s->p[i] = (uint8_t) (p - '1');  // p轉成 0 ~ 6 存入S排列陣列中
        s->o[i] = (uint8_t) (o - '1');  // 一樣改存到朝向陣列中
        sum += s->o[i];                 // 累加朝向值，共七個方向總和
    }
    while (sum >= 3u) {
        sum -= 3u;
    }

    return sum == 0;
    ;  // 若非三之倍數代表不合法
}
/*把 s -> p || s -> o 轉成兩個整數，用來查表
 *跟舊函式不太相同，不拆成兩部分，直接做解析
 */
static uint16_t rank_permutation(const state_t *s)
{
    unsigned rank = 0;

    // 依序處理 7 個位置
    for (unsigned i = 0; i < CUBIES; i++) {
        unsigned smaller = 0;  // 看自己右邊有幾個比自己小的編號
        // 掃描目前位置右邊所有cubie
        for (unsigned j = i + 1; j < CUBIES; j++) {
            if (s->p[j] < s->p[i]) {
                smaller++;
            }
        }
        // 用混和進位方式累積排列編號 若是{0,1,2,3,4,5,6} 就會是 0
        // 下次權重回是這次 rank 結果
        rank = rank * (CUBIES - i) + smaller;
    }
    // 這樣 rank 不會有重複的
    return (uint16_t) rank;
}
// 將前六個方向編成 0～728
static uint16_t rank_orientation(const state_t *s)
{
    unsigned rank = 0;  // 累積方向編號

    // 第七個方向可由方向總和推回，因此只存前六個
    for (unsigned i = 0; i < CUBIES - 1; i++) {
        // 乘3空出一位三進位，再加入目前方向 0、1或2
        rank = rank * 3u + s->o[i];
    }

    return (uint16_t) rank;
}
