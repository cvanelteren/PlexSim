#include "model.hpp"
#include "potts.hpp"

#include "config.hpp"
#include <vector>
int main() {
  auto config = Config();
  std::vector<PottsNode> test;
  for (int i = 0; i < 5; i++) {
    test.push_back(PottsNode(config));
  }
}
