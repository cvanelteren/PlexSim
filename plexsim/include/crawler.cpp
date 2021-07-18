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

bool compare_edge_color(const EdgeColor &current, const EdgeColor &other) {
  // for set comparison
  return (current.current.state != current.other.state) &&
         (current.other.state != other.other.state);
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

  std::set<EdgeColor> u_option =
      std::set<EdgeColor>(option.begin(), option.end());

  bool add = true;
  for (auto result : this->results) {

    overlap.clear();
    std::set_intersection(result.begin(), result.end(), u_option.begin(),
                          u_option.end(),
                          std::inserter(overlap, overlap.begin()));

    if (overlap.size() == option.size()) {
      add = false;
      break;
    }
  }

  // if (this->verbose) {
  //   printf("Considered option: \n");
  //   this->print(option);
  // }

  if (add == true && option.size() == this->bounded_rational) {

    // if (this->verbose) {
    //   printf("Pushing result ");
    //   this->print(option);
    // }

    // this->results.push_back(option);
    // push only unique options
    this->results.push_back(
        std::vector<EdgeColor>(u_option.begin(), u_option.end()));

    // this->results.insert(tmp);
  }
}

bool Crawler::in_options(std::vector<EdgeColor> &option,
                         std::vector<std::vector<EdgeColor>> &options) {
  std::vector<EdgeColor> overlap;

  for (auto opt : options) {
    overlap.clear();
    std::set_intersection(opt.begin(), opt.end(), option.begin(), option.end(),
                          std::inserter(overlap, overlap.begin()));

    if (overlap.size()) {
      return true;
    }
  }
  return false;
};

bool Crawler::in_options(EdgeColor &option,
                         std::vector<std::vector<EdgeColor>> &options) {
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
  return this->in_options(vopt, options);
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

uint8_t Crawler::merge_option(size_t idx, size_t jdx,
                              std::vector<std::vector<EdgeColor>> &to_merge) {

  std::vector<EdgeColor> *opti = &to_merge[idx];
  std::vector<EdgeColor> *optj = &to_merge[jdx];

  if (opti->size() == this->bounded_rational) {
    this->add_result(*opti);
    to_merge.erase(to_merge.begin() + idx);
    return 0;
  }

  if (optj->size() == this->bounded_rational) {
    this->add_result(*optj);
    to_merge.erase(to_merge.begin() + jdx);
    return 0;
  }

  // hold option
  std::set<EdgeColor> option;

  // declare logical operator
  std::vector<std::vector<EdgeColor>>::iterator in_path;

  // check intersection
  // if intersection then options are not unique
  set_intersection(opti->begin(), opti->end(), optj->begin(), optj->end(),
                   std::inserter(option, option.begin()));

  if (option.size() == 0) {
    // clear intermitten results
    option.clear();
    // create the union
    set_union(opti->begin(), opti->end(), optj->begin(), optj->end(),
              std::inserter(option, option.begin()));

    if (this->verbose) {
      printf("PRINTING ADDING OPTION:\n");
      this->print(std::vector<EdgeColor>(option.begin(), option.end()));
    }
    // check if option already exists
    in_path = std::find(to_merge.begin(), to_merge.end(),
                        std::vector<EdgeColor>(option.begin(), option.end()));

    // std::vector<EdgeColor>(option.begin(), option.end()));

    if (in_path == to_merge.end()) {
      // if solution add to solution
      // else add to option list
      if (option.size() == this->bounded_rational) {

        this->add_result(std::vector<EdgeColor>(option.begin(), option.end()));
        // to_merge.erase(to_merge.begin() + idx);
        // to_merge.erase(to_merge.begin() + jdx);
        return 2;

      } else if (option.size() < this->bounded_rational) {

        to_merge.push_back(
            std::vector<EdgeColor>(option.begin(), option.end()));

        return 1;
      }
    }
  }

  return 0;
}

void Crawler::merge_options(
    std::vector<std::vector<EdgeColor>> &options,
    std::vector<std::vector<EdgeColor>> &other_options) {
  /**
   * @brief      Merges @other_option in @option
   */

  std::set<EdgeColor> uni;
  std::vector<EdgeColor> option;
  // options are non-empty
  //
  //
  for (auto &elem : other_options) {
    options.push_back(elem);
  }

  int counter;
  bool can_merge = true;
  bool in_options = false;
  int start_idx = options.size() - 1;
  int end_idx = 0;

  // printf("Printing merging lj;asdkf;jadf options \n");
  // this->print(options);

  // remember the tried combinations
  std::unordered_map<size_t, std::unordered_map<size_t, bool>> memoize;
  while (can_merge) {
    can_merge = false;

    start_idx = end_idx;
    end_idx = options.size() - 1;
    for (int idx = end_idx; idx >= start_idx; idx--) {
      if (options[idx].size() == this->bounded_rational) {
        this->add_result(options[idx]);
        options.erase(options.begin() + idx);
        continue;
      }

      for (size_t jdx = 0; jdx < other_options.size(); jdx++) {
        option.clear();
        uni.clear();
        std::set_union(options[idx].begin(), options[idx].end(),
                       other_options[jdx].begin(), other_options[jdx].end(),
                       std::inserter(uni, uni.begin()), compare_edge_color);

        // printf("overlap size %d option size %d\n", uni.size(),
        // options[idx].size());
        //
        if (uni.size() > options[idx].size() &&
            (uni.size() <= this->bounded_rational)) {
          option = std::vector<EdgeColor>(uni.begin(), uni.end());

          // check for solution

          in_options = false;
          if (!memoize[idx][jdx]) {
            for (auto &elem : options) {
              uni.clear();
              std::set_intersection(option.begin(), option.end(), elem.begin(),
                                    elem.end(),
                                    std::inserter(uni, uni.begin()));
              if (uni.size() == option.size()) {
                in_options = true;
                // keep track of combinations
                memoize[idx][jdx] = true;
                break;
              }
            }
            if (!in_options) {
              options.push_back(option);
              can_merge = true;
            }
          }
        }
      }
    }
  }
}

// void Crawler::merge_options(
//     std::vector<std::vector<EdgeColor>> &options,
//     std::vector<std::vector<EdgeColor>> &other_options) {
//   /**
//    * @brief      Merges @other_option in @option
//    */
//   std::set<EdgeColor> uni;
//   // empty options
//   if (options.size() == 0) {
//     // options = other_options;
//     std::swap(options, other_options);
//     return;
//   }

//   int start_idx = options.size() - 1;
//   int idx = start_idx;

//   std::vector<EdgeColor> option;
//   // options are non-empty
//   while (idx >= 0) {

//     // check if option exists
//     // edge case for cycle?
//     if (options[idx].size() == this->bounded_rational) {
//       this->add_result(options[idx]);
//       options.erase(options.begin() + idx);
//     }

//     for (auto &optj : other_options) {
//       uni.clear();
//       option.clear();
//       std::set_union(options[idx].begin(), options[idx].end(),
//       optj.begin(),
//                      optj.end(), std::inserter(uni, uni.begin()));

//       if (uni.size() > options[idx].size()) {
//         option = std::vector<EdgeColor>(uni.begin(), uni.end());

//       } else if (idx == start_idx) {

//         if (!this->in_options(optj, options)) {
//           option = optj;
//         }
//       }

//       if ((option.size() != 0) && (option.size() <=
//       this->bounded_rational))
//       {
//         options.push_back(option);
//         // idx++;
//       }
//     }
//     idx--;
//   }
// }

void Crawler::merge_options(std::vector<std::vector<EdgeColor>> &options) {
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

  uint8_t can_merge = true;
  bool merge_option = false;

  while (can_merge) {
    can_merge = false;
    // check all combinations
    for (int idx = options.size() - 1; idx >= 0; idx--) {
      // check if current option is valid
      if (options[idx].size() == this->bounded_rational) {
        this->add_result(options[idx]);
        options.erase(options.begin() + idx);
      } else {
        for (int jdx = idx - 1; jdx >= 0; jdx--) {
          // check if the current option itself may form a solution
          can_merge = this->merge_option(idx, jdx, options);
          // two options are removed
          if (can_merge == 2)
            break;
        }
      }
    }
  }
  if (this->path.size()) {
    for (int idx = options.size() - 1; idx >= 0; idx--) {
      options[idx].push_back(this->path.back().sort());
      if (options[idx].size() == this->bounded_rational) {
        this->add_result(options[idx]);
        options.erase(options.begin() + idx);
      }
    }
  }
}

void Crawler::print(std::vector<EdgeColor> path) {
  printf("Option\n");
  for (auto e : path) {
    printf("%d %d\n", e.current.name, e.other.name);
  }
}

void Crawler::print(std::vector<std::vector<EdgeColor>> options) {
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
  it = options.begin();
  while (it != options.end()) {
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

// void Crawler::check_options() {
//   /**
//    * @brief Removes options that are actual solutions
//    *
//    * @details Options  are pushed  as the  crawler discovers
//    * solutions. This  function removes  options that  are of
//    * target length and pushes them into the solution vector.
//    *
//    */
//   // erase in reverse order
//   for (int idx = this->options.size() - 1; idx >= 0; idx--) {
//     if (this->verbose) {
//       printf("Considering: \n");
//       this->print(this->options[idx]);
//     }

//     if (this->options[idx].size() == this->bounded_rational) {
//       if (this->verbose) {
//         printf("Removing %d", idx);
//       }
//       this->add_result(this->options[idx]);
//       this->options.erase(this->options.begin() + idx);
//     }
//   }
// }

// void Crawler::prune_options() {
//   /**
//    * @brief      Prune options that cannot be traversed anymore
//    *
//    * @details   Options need to be pruned that cannot be accessed anymore
//    from
//    * the last edge in the path
//    *
//    */

//   auto current_edge = this->path.back();
// }
