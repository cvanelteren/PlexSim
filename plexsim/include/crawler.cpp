#include "crawler.hpp"
#include <unistd.h>
// TODO: this file is a mess. Future me needs to clean this up.
// There are a bunch of deprecated functions and most of the functions need not
// be put in a proper class
unsigned int sec = 1000000;

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
  printf("(%ld, %ld) \t (%f, %f) \n", this->current.name, this->other.name,
         this->current.state, this->other.state);
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

bool compare_edge_name(const EdgeColor &current, const EdgeColor &other) {
  return (current.current.name != other.current.name) ||
         (current.other.name != other.other.name);
}

bool compare_edge_color(const EdgeColor &current, const EdgeColor &other) {
  // for set comparison
  return (current.current.state != other.current.state) ||
         (current.other.state != other.other.state);
}

Crawler::Crawler(size_t start, double state, size_t bounded_rational,
                 size_t heuristic, size_t path_size, bool verbose) {
  this->bounded_rational = bounded_rational;
  this->queue.push_back(
      EdgeColor(ColorNode(start, state), ColorNode(start, state)));

  // default
  this->verbose = verbose;
  this->heuristic = heuristic;
  this->path_size = path_size;
}

// Crawler::Crawler(size_t start, double state, size_t bounded_rational,
//                  bool verbose)
//     : Crawler(start, state, bounded_rational) {

//   // override default
//   this->verbose = verbose;
// }

// bool check_overlap(std::vector<EdgeColor> option,
// std::vector<std::vector> > others) {}
// TODO make results sets so that unique paths are only in there

void Crawler::add_result(std::vector<EdgeColor> option) {

  std::vector<EdgeColor> overlap;

  std::set<EdgeColor> u_option =
      std::set<EdgeColor>(option.begin(), option.end());

  std::set<std::pair<double, double>> tmp;
  for (auto &elem : u_option) {
    tmp.insert(std::make_pair(elem.current.state, elem.other.state));
  }
  if (tmp.size() != this->bounded_rational) {
    return;
  }

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

  // exit early on heuristic
  if ((add == true) && (u_option.size() == this->bounded_rational) &&
      (check_size(u_option))) {
    if (this->heuristic > 0) {
      if (this->results.size() < this->heuristic) {
        this->results.push_back(
            std::vector<EdgeColor>(u_option.begin(), u_option.end()));
      } else {
        return;
      }
    }
    // add result and continue
    else {
      this->results.push_back(
          std::vector<EdgeColor>(u_option.begin(), u_option.end()));
    }

    // this->results.insert(tmp);
  }
}

bool Crawler::in_options(std::vector<EdgeColor> &option,
                         std::vector<std::vector<EdgeColor>> &options,
                         size_t target = 0) {
  std::vector<EdgeColor> overlap;

  for (auto opt : options) {
    overlap.clear();
    std::set_intersection(opt.begin(), opt.end(), option.begin(), option.end(),
                          std::inserter(overlap, overlap.begin()));

    if (overlap.size() == target) {
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
  std::vector<EdgeColor> vopt = {option.sort()};
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

bool Crawler::in_vpath(EdgeColor option, std::vector<EdgeColor> path) {
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

  std::set<EdgeColor> overlap;
  std::vector<EdgeColor> tmp = {option};
  std::set_union(path.begin(), path.end(), tmp.begin(), tmp.end(),
                 std::inserter(overlap, overlap.begin()), compare_edge_color);
  // printf("path size %d", path.size());
  // printf("overlap %d\n", overlap.size());
  bool a = (overlap.size() == path.size());

  std::swap(option.current, option.other);

  tmp.clear();
  tmp = {option};
  overlap.clear();
  std::set_union(path.begin(), path.end(), tmp.begin(), tmp.end(),
                 std::inserter(overlap, overlap.begin()), compare_edge_color);
  bool b = (overlap.size() == path.size());
  // printf("overlap %d\n", overlap.size());
  std::swap(option.current, option.other);
  // usleep(sec);
  return a || b;
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

  std::set<EdgeColor> overlap;
  std::vector<EdgeColor> tmp = {option};
  std::set_union(path.begin(), path.end(), tmp.begin(), tmp.end(),
                 std::inserter(overlap, overlap.begin()));

  printf("overlap %d\n", overlap.size());
  bool a = (overlap.size() == path.size());
  std::swap(option.current, option.other);

  tmp.clear();
  tmp = {option};
  std::set_union(path.begin(), path.end(), tmp.begin(), tmp.end(),
                 std::inserter(overlap, overlap.begin()));
  bool b = (overlap.size() == path.size());
  printf("overlap %d\n", overlap.size());
  std::swap(option.current, option.other);
  return a || b;
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
  size_t n = options.size() + other_options.size();

  int counter;
  bool can_merge = true;
  bool in_options = false;
  int start_idx;
  int end_idx = 0;

  // printf("Printing merging lj;asdkf;jadf options \n");
  // this->print(options);

  // remember the tried combinations
  // std::unordered_map<size_t, std::unordered_map<size_t, bool>> memoize;
  while (can_merge) {
    // reset search
    can_merge = false;
    start_idx = end_idx;
    end_idx = options.size() - 1;

    // printf("IDX=%d \t end_idx %d \n", start_idx, end_idx);

    // search for possible mergers
    for (int idx = end_idx; idx >= start_idx; idx--) {

      if (options[idx].size() == bounded_rational) {
        this->add_result(options[idx]);
        options.erase(options.begin() + idx);
        continue;
      }

      for (int jdx = other_options.size() - 1; jdx >= 0; jdx--) {
        // early exit for heuristic approach
        if (this->heuristic) {
          if (this->results.size() == this->heuristic) {
            return;
          }
        }
        option.clear();
        uni.clear();

        std::set_union(options[idx].begin(), options[idx].end(),
                       other_options[jdx].begin(), other_options[jdx].end(),
                       std::inserter(uni, uni.begin()), compare_edge_color);

        // printf("overlap size %d option size %d\n", uni.size(),
        // options[idx].size());
        //

        if ((uni.size() > options[idx].size()) &&
            (uni.size() <= bounded_rational)) {
          option = std::vector<EdgeColor>(uni.begin(), uni.end());

          // check for solution

          in_options = false;
          for (auto &elem : options) {
            if (elem == option) {
              in_options = true;
              // memoize[idx][jdx] = true;
              break;
            }
          }
          if (!in_options) {
            options.push_back(option);
            can_merge = true;
          }
        }
        // filter out cases if the labels are the same
        else if ((uni.size() == options[idx].size()) &&
                 (uni.size() == options[jdx].size())) {
          std::set_union(options[idx].begin(), options[idx].end(),
                         options[jdx].begin(), options[jdx].end(),
                         std::inserter(uni, uni.begin()), compare_edge_name);

          if (uni.size() == options[idx].size()) {
            other_options.erase(other_options.begin() + jdx);
            continue;
          }
        }
      }
    }
  } // end merge

// add current path
#pragma openmp simd for
  for (int idx = options.size() - 1; idx >= 0; idx--) {
    if (this->path.size()) {
      if (!this->in_vpath(this->path.back(), options[idx])) {
        // printf("Adding option\n");
        options[idx].push_back(this->path.back().sort());
      }
    }
    if (options[idx].size() == this->bounded_rational) {
      this->add_result(options[idx]);
      options.erase(options.begin() + idx);
    }
  }
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

void Crawler::print_results() {
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
  printf("\n");
}

void Crawler::print_path() {
  printf("Printing path");
  for (auto ec : this->path) {
    printf("\n Edge %ld %ld \t %f %f \n", ec.current.name, ec.other.name,
           ec.current.state, ec.other.state);
  }
  printf("\n");
}

void Crawler::print_options(std::vector<std::vector<EdgeColor>> options) {
  printf("Printing options\n");

  auto it = options.begin();
  std::vector<EdgeColor>::iterator jt;

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
  printf("\n");
}

void Crawler::print(std::vector<std::vector<EdgeColor>> options) {
  this->print_results();
  this->print_options(options);
  this->print_path();
}

template <typename C> bool Crawler::check_size(C &path) {
  auto it = path.begin();
  // store nodes
  std::set<size_t> uniques;
  while (it != path.end()) {
    uniques.insert((*it).current.name);
    uniques.insert((*it).other.name);
    it++;
  }
  return uniques.size() <= path_size;
};

size_t get_path_size(std::vector<EdgeColor> path) {
  std::set<size_t> uniques;
  for (size_t idx = 0; idx < path.size(); idx++) {
    uniques.insert(path[idx].current.name);
    uniques.insert(path[idx].other.name);
  }
  return uniques.size();
}
