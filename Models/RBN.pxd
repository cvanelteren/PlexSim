# cython: infer_types=True
# distutils: language=c++
from PlexSim.Models.Models cimport Model
from libcpp.vector cimport vector

import numpy as np
cimport numpy as np

from libcpp.unordered_map cimport unordered_map
from libcpp.string cimport string
from libcpp.vector cimport vector
cdef class RBN(Model):
    """Random boolean network"""
    cdef:
        double _delta # memory retention variable

        unordered_map[long, vector[int]] _rules

    # overload the parent functions
    cdef void _step(self, long node) nogil
    
