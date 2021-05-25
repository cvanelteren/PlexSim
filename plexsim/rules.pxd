#distutils: language=c++
from plexsim.types cimport *
cdef class Rules:
    """
    Special type of overriding dynamics in a model.
    Creates a layered-structure where part of the model is
    updated according to fixed rules.
    """
    cdef dict __dict__
    #properties
    cdef multimap[state_t, pair[state_t, double]] _rules

    # functions
    cdef rule_t _check_rules(self, state_t x, state_t y) nogil

