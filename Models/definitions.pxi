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
from pyprind import ProgBar

# ___CythonImports___
cimport cython
import cython
from cython cimport numeric
from cython.parallel cimport prange, parallel, threadid

# cpp import 
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map

from libc.math cimport exp, lround, abs as c_abs
from cython.operator cimport dereference, preincrement, postincrement

# struct for adjacency matrix
cdef struct Connection:
    vector[int] neighbors
    vector[double] weights

from PlexSim.Models.Models cimport Model
from PlexSim.Models.parallel cimport * 
