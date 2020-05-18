import sys
sys.path.insert(0, '../')

from plexsim import models
from plexsim import example as cppModels
import networkx as nx, numpy as np
# from plexsim import example_old as cppModels



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

N = [100]
steps = int(10**8)
loops = 100
tests = 'testArray'.split()
T = tmp()
for ni in N:
    print(f"Testing size {ni}, {ni}\n")
    g = nx.grid_graph([ni, ni])
    M = models.Potts(g, sampleSize = ni*ni)
    cm = cppModels.Potts(g)

    [timeit(T, steps, loops, i) for i in tests]
    [timeit(M, steps, loops, i) for i in tests]
    print('-'*32)
    # [timeit(cm, steps, loops, i) for i in tests]
