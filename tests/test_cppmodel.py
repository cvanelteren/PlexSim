import sys
sys.path.insert(0, '../')

from plexsim import models
from plexsim import example as cppModels
# from plexsim import example_old as cppModels


import networkx as nx
import numpy as np


import time


def timeit(m, N, loops, func):
    print(f"Testing {m.__class__.__name__} with {func}")
    start = time.time()
    for i in range(loops):
        a = getattr(m, func)(N)

    stop = time.time() - start
    print("Time taken ", stop)

N = [100]
steps = 1000
loops = 100
for ni in N:
    print(f"Testing size {ni}, {ni}\n")
    g = nx.grid_graph([ni, ni])
    M = models.Potts(g, sampleSize = ni*ni)
    cm = cppModels.Potts(g)

    timeit(M, steps, loops, 'sampleNodes')
    # timeit(M, steps, loops, "checkRand")
    # timeit(M, steps, loops, 'simulate')

    timeit(cm, steps, loops, 'sampleNodes')
    # timeit(cm, steps, loops, "checkRand")
    # timeit(cm, steps, loops, 'simulate')
