import sys
sys.path.insert(0, '../')

from plexsim import models
from plexsim import example as cppModels


import networkx as nx
import numpy as np


import time


def timeit(m, N, loops):
    start = time.time()
    for i in range(loops):
        res = np.asarray(m.sampleNodes(N))
    stop = time.time() - start
    print("Time taken ", stop)
    print(res.size, res.shape)

#N = [10, 100, 500]
#steps = 1000
#loops = 10
#for ni in N:
#    print(f"Testing size {ni}, {ni}\n")
#    g = nx.grid_graph([ni, ni])
#    m = models.Model(g)
#    cm = cppModels.Model(g)
#
#    print("cython")
#    timeit(m, steps, loops)
#    print("cpp")
#    timeit(cm, steps, loops)

if __name__ == "__main__":
    pass
