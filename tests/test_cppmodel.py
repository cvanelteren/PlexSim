import sys
from plexsim import models
import networkx as nx, numpy as np
sys.path.insert(0, '../plexsim')
import example as cppModels 

import time

class tmp:
    def __init__(self):
        pass
    def testArray(self, n):
        tmp = np.ones(n)
        d = tmp.sum()
        return None
def timeit(m, N, loops, func):
    print(f"Testing {m.__class__.__name__} with {func}")
    start = time.time()
    for i in range(loops):
        a = getattr(m, func)(N)

    stop = time.time() - start
    print("Time taken ", stop)

N = [300]
steps = int(10)
loops = int(1)
tests = 'sampleNodes simulate'.split()
# tests = 'testArray'.split()
T = tmp()
for ni in N:
    g = nx.complete_graph(ni)
    print(f"Testing size {g.number_of_nodes()}\n")
    M = models.Potts(g)
    cm = cppModels.Potts(g)

    [timeit(M, steps, loops, i) for i in tests]
    print('-'*32)
    [timeit(cm, steps, loops, i) for i in tests]
