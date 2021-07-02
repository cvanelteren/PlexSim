#include "crawler.hpp"

ColorNode::ColorNode(){};

ColorNode::ColorNode(size_t name, double state) {
  this->name = name;
  this->state = state;
}

EdgeColor::EdgeColor(){};

EdgeColor::EdgeColor(ColorNode current, ColorNode other) {
  this->current = current;
  this->other = other;
}

EdgeColor::EdgeColor(size_t name, size_t name_other, double name_state,
                     double other_state) {
  this->current = ColorNode(name, name_state);
  this->other = ColorNode(name_other, other_state);
}

bool EdgeColor::operator=(const EdgeColor &other) const {
  return (this->current.name == other.current.name) &&
         (this->current.state == other.current.state);
}

void EdgeColor::print() const {
  std::cout << this->current.name << " ";
  std::cout << this->other.name << " ";

  std::cout << this->current.state << " ";
  std::cout << this->other.state << std::endl;
}

bool operator<(const EdgeColor &current, const EdgeColor &other) {
  return (current.current.name < other.current.name);
}

bool operator==(const EdgeColor &current, const EdgeColor &other) {
  return ((current.current.name == other.current.name) &&
          (current.current.state == other.current.state) &&
          (current.other.state == other.other.state) &&
          (current.other.name == other.other.name));
}

Crawler::Crawler(size_t start, size_t bounded_rational) {
  this->bounded_rational = bounded_rational;
  this->queue.push_back(
      EdgeColor(ColorNode(start, start), ColorNode(start, start)));

  // default
  this->verbose = false;
}

Crawler::Crawler(size_t start, size_t bouned_rational, bool verbose)
    : Crawler(start, bounded_rational) {

  // override default
  this->verbose = verbose;
}

void Crawler::add_result(std::vector<EdgeColor> option) {
  bool add = true;
  if (option.size()) {
    if (std::find(this->results.begin(), this->results.end(), option) !=
        this->results.end()) {
      this->results.push_back(option);
    }
  }
}

bool Crawler::in_path(EdgeColor option) {
  return (std::find(this->path.begin(), this->path.end(), option) !=
          this->path.end());
}

void Crawler::merge_options() {
  if (this->results.size() < 2)
    return;

  auto to_merge = this->options;
  bool can_merge = true;
  bool merge_option = false;

  std::vector<EdgeColor> opti, optj, option;
  while (can_merge) {
    can_merge = false;
    // check all combinations
    for (auto idx = 0; idx < to_merge.size(); idx++) {
      for (auto jdx = 0; jdx < to_merge.size(); jdx++) {
        if (idx < jdx) {
          // unpack options
          opti = to_merge[idx];
          optj = to_merge[jdx];
          // clear option
          option.clear();

          // check intersection
          // if intersection then options are not unique
          set_intersection(opti.begin(), opti.end(), optj.begin(), optj.end(),
                           option.begin());

          // reset merge to true
          merge_option = true;
          // if there is an intersection don't merge
          // keep options separate
          if (option.size() > 0)
            merge_option = false;

          if (merge_option) {
            // clear intermitten results
            option.clear();
            // create the union
            set_union(opti.begin(), opti.end(), optj.begin(), optj.end(),
                      option.begin());
            // check if option already exists
            if (std::find(to_merge.begin(), to_merge.end(), option) !=
                to_merge.end()) {
              if (option.size() == this->bounded_rational)
                this->add_result(option);
              else {
                to_merge.push_back(option);
                can_merge = true;
              }
            }
          }
        }
      }
    }
  }
  // put options back in plac
  if (to_merge.size()) {
    this->options = to_merge;
  }
}
