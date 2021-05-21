#include <iostream>
template <class T> class top {
public:
  top(){};
  int a = 0;
};

template <class T> class mid : public top<T> {
public:
  mid(){};
  int b = 0;
};

class bottom : public mid<bottom> {
public:
  bottom() {}
};

int main() {
  auto a = new bottom();
  std::cout << a->a << a->b << std::endl;
}
