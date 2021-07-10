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
  std::cout << "(";
  std::cout << this->current.name << " ";
  std::cout << this->other.name << " ";
  std::cout << ")";

  std::cout << "(";
  std::cout << this->current.state << " ";
  std::cout << this->other.state;
  std::cout << ")";
  std::cout << std::endl;
}

EdgeColor EdgeColor::sort() {
  /**
   * @brief      Sorts the edgecolor for set insertion
   *
   * @details    All solution paths are unique, by sorting the
   * edge we can ensure that comparison won't have to check for the
   * reverse edge. Note that for directed graphs this method will
   * not properly reflect the paths.
   *
   * FIXME: directed graphs need to be corrected
   **/

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

Crawler::Crawler(size_t start, double state, size_t bounded_rational,
                 bool verbose)
    : Crawler(start, state, bounded_rational) {

  // override default
  this->verbose = verbose;
}

// TODO make results sets so that unique paths are only in there
void Crawler::add_result(std::vector<EdgeColor> option) {

  std::vector<EdgeColor> overlap;
  bool add = true;
  for (auto result : this->results) {

    overlap.clear();
    std::set_intersection(result.begin(), result.end(), option.begin(),
                          option.end(),
                          std::inserter(overlap, overlap.begin()));

    if (overlap.size() == option.size()) {
      add = false;
      break;
    }
  }

  if (this->verbose) {
    printf("Considered option: \n");
    this->print(option);
  }

  if (add == true && option.size() == this->bounded_rational) {

    if (this->verbose) {
      printf("Pushing result ");
      this->print(option);
    }

    this->results.push_back(option);
    // this->results.insert(tmp);
  }
}

bool Crawler::in_options(EdgeColor option) {
  /**
   * @brief      Confirms option is in options
   *
   * @details    The edge :option: is checked whether it is already present
   * in the options.
   *
   * @param      proposal candidate for solution.
   *
   * @return     bool; true if in path, false otherwise.
   */
  std::vector<EdgeColor> vopt = {option};
  std::vector<EdgeColor> overlap;

  if (this->verbose) {
    printf("Checking overlaps in options\n");
    this->print(vopt);
  }

  for (auto opt : this->options) {
    overlap.clear();
    std::set_intersection(opt.begin(), opt.end(), vopt.begin(), vopt.end(),
                          std::inserter(overlap, overlap.begin()));

    if (this->verbose) {
      printf("Overlap size %d\n", overlap.size());
      this->print(opt);
    }

    if (overlap.size()) {
      return true;
    }
  }
  return false;
}

bool Crawler::in_path(EdgeColor option) {
  /**
   * @brief      Checks if option is in path
   *
   * @details    Checks if the current proposal edge is in the current path
   * of the crawler
   *
   * @param     Proposal candidate edge
   *
   * @return     true if in path, false otherwise
   */
  return this->in_path(option, this->path);
}

bool Crawler::in_path(EdgeColor option, std::vector<EdgeColor> path) {
  /**
   * @brief      Checks if option is in path
   *
   * @details    Checks if the current proposal edge is in the current path
   * of the crawler
   *
   * @param     Proposal candidate edge
   *
   * @param    path to check
   *
   * @return     true if in path, false otherwise
   */

  bool a = std::find(path.begin(), path.end(), option) != path.end();
  std::swap(option.current, option.other);

  bool b = std::find(path.begin(), path.end(), option) != path.end();
  std::swap(option.current, option.other);
  return a || b;
}

bool Crawler::merge_option(std::vector<EdgeColor> opti,
                           std::vector<EdgeColor> optj,
                           std::vector<std::vector<EdgeColor>> *to_merge) {

  // hold option
  std::vector<EdgeColor> option;

  // declare logical operator
  std::vector<std::vector<EdgeColor>>::iterator in_path;

  // check intersection
  // if intersection then options are not unique
  set_intersection(opti.begin(), opti.end(), optj.begin(), optj.end(),
                   std::inserter(option, option.begin()));

  if (option.size() == 0) {
    // clear intermitten results
    option.clear();
    // create the union
    set_union(opti.begin(), opti.end(), optj.begin(), optj.end(),
              std::inserter(option, option.begin()));
    // check if option already exists
    in_path = std::find(to_merge->begin(), to_merge->end(),
                        std::vector<EdgeColor>(option.begin(), option.end()));

    if (in_path == to_merge->end()) {
      // if solution add to solution
      // else add to option list
      if (option.size() == this->bounded_rational) {

        this->add_result(std::vector<EdgeColor>(option.begin(), option.end()));

      } else if (option.size() < this->bounded_rational) {

        to_merge->push_back(
            std::vector<EdgeColor>(option.begin(), option.end()));

        return true;
      }
    }
  }

  return false;
}

void Crawler::merge_options() {
  /**
   * @brief  Merges  options  together to  build  path  from
   * below.
   *
   * @details The crawler builds the path. If the rule graph
   * splits,  the crawler  needs to  keep track  of possible
   * ends that can be combined. This function merges sperate
   * branches that are pushed in the options.
   *
   * FIXME: Too many options are kept that should be pruned.
   * I  should implement  a pruning  mechanism based  on the
   * traversability  of the  paths. The  biggest speedup  is
   * found there.
   *
   */

  std::vector<std::vector<EdgeColor>> to_merge = this->options;
  bool can_merge = true;
  bool merge_option = false;

  std::vector<EdgeColor> opti, optj;

  if (this->verbose) {
    printf("IN OPTIONS MERGING\n");
    printf("options size = %d", to_merge.size());
  }

  while (can_merge) {
    can_merge = false;
    // check all combinations
    for (auto idx = 0; idx < to_merge.size(); idx++) {
      for (auto jdx = 0; jdx < to_merge.size(); jdx++) {
        if (idx < jdx) {
          can_merge =
              this->merge_option(to_merge[idx], to_merge[jdx], &to_merge);
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

void Crawler::check_options() {
  /**
   * @brief Removes options that are actual solutions
   *
   * @details Options  are pushed  as the  crawler discovers
   * solutions. This  function removes  options that  are of
   * target length and pushes them into the solution vector.
   *
   */
  // erase in reverse order
  for (int idx = this->options.size() - 1; idx >= 0; idx--) {
    if (this->verbose) {
      printf("Considering: \n");
      this->print(this->options[idx]);
    }

    if (this->options[idx].size() == this->bounded_rational) {
      if (this->verbose) {
        printf("Removing %d", idx);
      }
      this->add_result(this->options[idx]);
      // this->options.erase(this->options.begin() + idx);
    }
  }
}
