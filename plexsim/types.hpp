#ifndef types_hpp
#define types_hpp

#include "model.hpp"
#include "xtensor-blas/xlinalg.hpp"
#include "xtensor-python/pyarray.hpp"
#include "xtensor/xarray.hpp"
#include "xtensor/xcomplex.hpp"
#include "xtensor/xindex_view.hpp"
#include "xtensor/xio.hpp"
#include "xtensor/xmath.hpp"
#include "xtensor/xrandom.hpp"
#include "xtensor/xstrided_view.hpp"

typedef double state__t;
typedef xt::xarray<state__t> state_t;
typedef std::string id_t;

// typedef xt::xarray xar;
typedef std::unordered_map<id_t, Node> Nodes;

typedef std::unordered_map<id_t, std::unordered_map<id_t, double>> adj_t;

#endif
