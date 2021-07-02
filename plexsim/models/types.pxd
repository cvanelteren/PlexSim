import numpy as np, cython
cimport numpy as np
from libcpp.vector cimport vector
from libcpp.pair cimport pair
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map
from libcpp.unordered_set cimport unordered_set

# cdef extern class plexsim.PyObjectHolder as PyObjectHolder
from plexsim.models.pyobjectholder cimport PyObjectHolder

cdef extern from "math.h":
    float INFINITY

# PARALLEL DEFINITION
from cpython cimport PyObject

# TYPE DEFINITIONS
ctypedef size_t node_id_t
ctypedef double weight_t
ctypedef double nudge_t
ctypedef double state_t
ctypedef pair[bint, pair[state_t, double]] rule_t

# # TODO: move to structs?
# ctypedef vector[state_t] Neighbors
# ctypedef vector[weight_t] Weights

# nudges hash map
ctypedef unordered_map[node_id_t, state_t] Nudges

cdef struct NodeBackup:
    state_t state
    weight_t weight

# nudge temporaries
ctypedef unordered_map[node_id_t, NodeBackup] NudgesBackup



ctypedef vector[PyObjectHolder] SpawnVec


ctypedef unordered_map[node_id_t, weight_t] Neighbors
cdef struct Connection:
    # unordered_map[node_id_t, weight_t] neighbors
    Neighbors neighbors
    # Weights  weights

ctypedef unordered_map[node_id_t, Connection] Connections



# ctypedef unordered_set[state_t] MemoizeUnit
ctypedef pair[state_t, state_t] MemoizeUnit
# ctypedef unordered_map[MemoizeUnit, double, pair_hash]  MemoizeMap


# cdef extern from "<map>" namespace "std" nogil:
#     cdef cppclass multimap[T, U]:
#         cppclass iterator:
#             pair[T, U]& operator*()
#             iterator operator++()
#             iterator operator--()
#             bint operator==(iterator)
#             bint operator!=(iterator)

#         multimap() except +
#         U& operator[](T&)
#         iterator begin()
#         iterator end()
#         pair[iterator, bint] insert(pair[T, U])# XXX pair[T,U]&
#         iterator find(T&)




