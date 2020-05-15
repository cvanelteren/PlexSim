import sys
sys.path.insert(0, '../')

from plexsim import models
from plexsim import example as cppModels
# from plexsim import example_old as cppModels


import networkx as nx
import numpy as np


import time


def timeit(m, N, loops, func):
    start = time.time()
    for i in range(loops):
        a = getattr(m, func)(N)

    stop = time.time() - start
    print("Time taken ", stop)

N = [300]
steps = 1000
loops = 5
for ni in N:
    print(f"Testing size {ni}, {ni}\n")
    g = nx.grid_graph([ni, ni])
    M = models.Potts(g, sampleSize = ni*ni)
    cm = cppModels.Potts(g)

    print("cython")
    timeit(M, steps, loops, 'sampleNodes')

    print("cpp")
    timeit(cm, steps, loops, 'sampleNodes')

    #print("cython sim")
    #timeit(M, steps, loops, 'simulate')
    #print("cpp cim")
    #timeit(cm, steps, loops, 'simulate')
