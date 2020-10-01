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
    print(f"Testing {m.__class__.__name__} with {func}", end = ' ')
    start = time.time()
    for i in range(loops):
        a = getattr(m, func)(N)

    stop = time.time() - start
    return stop


N = [100]
# N = [10]
steps = int(1e4)
loops = int(1)
tests = 'simulate sampleNodes '.split()
# tests = 'testArray'.split()
T = tmp()
# import cProfile as cp
# p = cp.Profile()

timings = []
from tabulate import tabulate
for ni in N:
    g = nx.complete_graph(ni)
    g = nx.barabasi_albert_graph(ni, np.random.randint(1, ni))
    # g = nx.path_graph(ni)
    # g = nx.grid_graph((ni, ni))
    print(f"Testing size {g.number_of_nodes()}\n")

    # define models
    M = models.Potts(g)
    cPF = cppModels.PottsFast(g)
    cP = cppModels.Potts(g)
    cPD  = cppModels.PD(g)


    timings.append((M.__class__.__name__ + str(ni), \
                    *[timeit(M, steps, loops,  test) for test in tests]))

    timings.append((" Flat_class", \
                    *[timeit(cPF, steps, loops,  test) for test in tests]))

    timings.append((" Virtual_class",\
                    *[timeit(cP, steps, loops,  test) for test in tests]))

    timings.append((" CRTP_class", \
                    *[timeit(cPD, steps, loops,  test) for test in tests]))

    timings.append(())


print('\n')
headers = "Models"
for test in tests:
    headers += " " + test

    print(headers)
print(headers, tests)
tab = tabulate(timings, headers = headers.split())

print(tab)
