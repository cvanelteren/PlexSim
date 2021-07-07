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

EdgeColor EdgeColor::sort() {
  auto newec = EdgeColor(this->current, this->other);
  if (newec.other.name < newec.current.name)
    std::swap(newec.other.name, newec.current.name);
  if (newec.other.state < newec.current.state)
    std::swap(newec.other.state, newec.current.state);
  return newec;
}

bool operator<(const EdgeColor &current, const EdgeColor &other) {
  if (current.current.name == other.current.name) {
    return current.other.name < other.other.name;
  } else
    return current.current.name < other.current.name;
}

bool operator==(const EdgeColor &current, const EdgeColor &other) {
  return ((current.current.name == other.current.name) &&
          (current.current.state == other.current.state) &&
          (current.other.state == other.other.state) &&
          (current.other.name == other.other.name));
}

Crawler::Crawler(size_t start, double state, size_t bounded_rational) {
  this->bounded_rational = bounded_rational;
  this->queue.push_back(
      EdgeColor(ColorNode(start, state), ColorNode(start, state)));

  // default
  this->verbose = false;
}

Crawler::Crawler(size_t start, double state, size_t bouned_rational,
                 bool verbose)
    : Crawler(start, state, bounded_rational) {

  // override default
  this->verbose = verbose;
}

// TODO make results sets so that unique paths are only in there
void Crawler::add_result(std::vector<EdgeColor> option) {
  bool add;
  if (option.size()) {
    // std::set<EdgeColor> tmp = std::set<EdgeColor>(option.begin(),
    // option.end());
    //
    add = true;
    std::set<EdgeColor> overlap;
    for (auto result : this->results) {
      for (auto edge : option) {
        if (this->in_path(edge)) {
          add = false;
          break;
        }
      }
      if (add == false) {
        break;
      }
    }
    if (add == true) {
      this->results.push_back(option);
      // this->results.insert(tmp);
    }
  }
}

bool Crawler::in_options(EdgeColor option) {
  std::vector<EdgeColor> vopt = {option};
  for (auto opt : this->options) {
    if (opt == vopt) {
      return true;
    }
  }
  return false;
}

bool Crawler::in_path(EdgeColor option) {
  return this->in_path(option, this->path);
}

bool Crawler::in_path(EdgeColor option, std::vector<EdgeColor> path) {
  auto a = std::find(path.begin(), path.end(), option) != path.end();
  return a;
  // std::swap(option.current, option.other);

  // auto b = std::find(path.begin(), path.end(), option) != path.end();
  //
  // std::swap(option.current, option.other);
  // return (a || b ? true : false);
}

void Crawler::merge_options() {
  if (this->options.size() < 2) {
    printf("returning\n");
    return;
  }

  std::vector<std::vector<EdgeColor>> to_merge = this->options;
  bool can_merge = true;
  bool merge_option = false;

  std::vector<EdgeColor> opti, optj;
  std::set<EdgeColor> option;

  std::vector<std::vector<EdgeColor>>::iterator in_path;
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
                           std::inserter(option, option.begin()));

          // printf("merge size %ld\n", to_merge.size());
          // printf("IDX: %ld %ld\n", idx, jdx);

          // this->print(std::vector<EdgeColor>(option.begin(), option.end()));
          // // reset merge to true
          // merge_option = true;
          // // if there is an intersection don't merge
          // // keep options separate
          // if () {
          //   merge_option = false;
          // }

          // if (option.size() == 0) {
          //   this->print(opti);
          //   this->print(optj);
          // }

          if (option.size() == 0) {
            // clear intermitten results
            option.clear();
            // create the union
            set_union(opti.begin(), opti.end(), optj.begin(), optj.end(),
                      std::inserter(option, option.begin()));
            // check if option already exists
            in_path =
                std::find(to_merge.begin(), to_merge.end(),
                          std::vector<EdgeColor>(option.begin(), option.end()));

            if (in_path == to_merge.end()) {
              // if solution add to solution
              // else add to option list
              if (option.size() == this->bounded_rational) {
                this->add_result(
                    std::vector<EdgeColor>(option.begin(), option.end()));
              } else if (option.size() < this->bounded_rational) {
                to_merge.push_back(
                    std::vector<EdgeColor>(option.begin(), option.end()));
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

void Crawler::print(std::vector<EdgeColor> path) {
  printf("Option\n");
  for (auto e : path) {
    printf("%d %d\n", e.current.name, e.other.name);
  }
}

void Crawler::print() {
  printf("Printing path");
  for (auto ec : this->path) {
    printf("\n Edge %ld %ld \n", ec.current.name, ec.other.name);
  }
  printf("\n");

  printf("Printing results\n");
  auto it = this->results.begin();
  std::vector<EdgeColor>::iterator jt;
  // got through all the solutions
  while (it != this->results.end()) {
    printf("------------------\n");
    // each solution print path
    jt = (*it).begin();
    while (jt != (*it).end()) {
      printf("Edge %ld %ld \n", jt->current.name, jt->other.name);
      jt++;
    }
    printf("------------------\n");
    it++;
  }

  printf("Printing options\n");
  it = this->options.begin();
  while (it != this->options.end()) {
    jt = (*it).begin();
    printf("------------------\n");
    while (jt != (*it).end()) {
      printf("Edge %ld %ld \n", jt->current.name, jt->other.name);
      jt++;
    }
    printf("------------------\n");
    it++;
  }
  // for (auto i = 0; i < this->results.size(); i++) {
  //   printf("Results %d", i);
  //   for (auto ec : this->results[i]) {
  //     printf("\n Edge %ld %ld \n", ec.current.name, ec.other.name);
  //   }
  // }

  printf("\n");
}
