#pragma once
struct Input {
 int d;
};
struct NzikInput {
 int a, b;
};
struct Output {
 int x;
};
void outsource(struct Input *input, struct NzikInput *nzik, struct Output *output);