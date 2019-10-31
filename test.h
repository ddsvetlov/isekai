#pragma once
struct Input {
 int a, b, key;
};
struct NzikInput {
 int c;
};
struct Output {
 int x;
 int y;
 int key;
};
void outsource(struct Input *input, struct NzikInput *nzik, struct Output *output);