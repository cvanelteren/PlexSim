#distutils : language = c++


"""
Contains default definitions shared among all models
"""



# default model archetype
# numpy
import numpy  as np
cimport numpy as np

from scipy.stats import linregress
import networkx as nx, multiprocessing as mp, \
                scipy,  functools, copy, time
from tqdm import tqdm


# ___CythonImports___
cimport cython
import cython
from cython cimport numeric
from cython.parallel cimport prange, parallel, threadid

# cpp import 
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map

from libc.math cimport exp
from libc.math cimport lround 
from cython.operator cimport dereference, preincrement

# struct for adjacency matrix
cdef struct Connection:
    vector[int] neighbors
    vector[double] weights

from PlexSim.Models.Models cimport Model
