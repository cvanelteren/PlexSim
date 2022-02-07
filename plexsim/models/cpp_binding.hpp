typedef struct {
  int x;
} x_t;

typedef struct {
  x_t a;
} y_t;

void f(y_t x);
void print_hello() { printf("hello"); }
