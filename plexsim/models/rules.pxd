#distutils: language=c++
from plexsim.models.types cimport *
from libcpp.unordered_map cimport unordered_map
# from plexsim.models.adjacency cimport Adjacency
cdef class Rules:
    """
    Special type of overriding dynamics in a model.
    Creates a layered-structure where part of the model is
    updated according to fixed rules.
    """
    #properties
    # cdef multimap[state_t, pair[state_t, double]] _rules
    cdef unordered_map[state_t, unordered_map[state_t, double]] _adj

    # functions
    # cdef rule_t _check_rules(self, state_t x, state_t y) nogil
    cdef dict __dict__
