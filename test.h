#pragma once
struct Input {
 int a, b;
};
struct NzikInput {
 int c;
};
struct Output {
 int x;
 int y;
};
void outsource(struct Input *input, struct NzikInput *nzik, struct Output *output);