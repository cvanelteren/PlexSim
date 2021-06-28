#include "edges.hpp"
// bool color_node::operator<(const color_node &this, color_node &other) {
//   return (this->name < other->name) && (this->state < other->state);
// }

bool edge_vn::operator<(const edge_vn &other) {
  return (this->current.name < other.current.name) &&
         (this->current.state < other.current.state);
}

// bool edge_vn::operator<(const edge_vn &current, const edge_vn &other) {
//   return (current.current.name < other.current.name) &&
//          (current.current.state < other.current.state);
// }

bool edge_vn::operator<=(const edge_vn &other) {
  return (this->current.name <= other.current.name) &&
         (this->current.state <= other.current.state);
}

bool operator<(const edge_vn &current, const edge_vn &other) {
  return (current.current.name < other.current.name) &&
         (current.current.state < other.current.state);
}
