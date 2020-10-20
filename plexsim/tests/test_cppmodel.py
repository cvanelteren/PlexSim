import sys
from plexsim import models
import networkx as nx, numpy as np
sys.path.insert(0, '../plexsim')
import example as cppModels 

import time

def timeit(m, N, loops, func):
    # print(f"Testing {m.__class__.__name__} with {func}", end = ' ')
    start = time.time()
    for i in range(loops):
        a = getattr(m, func)(N)
    stop = time.time() - start
    return stop


N = [64]
# N = [10]
steps = int(1e2)
loops = int(100)
tests = 'simulate sampleNodes'.split()

timings = []
from tabulate import tabulate

def gen_prototypes(g):
    s = dict(sampleSize = 1)
    s = {}
    return [
        models.Potts(g        , **s),
        # cppModels.Potts(g     , **s),
        # cppModels.PottsFast(g , **s),
        cppModels.Potts(g        , **s)]

for ni in N:
    # g = nx.complete_graph(ni)
    # g = nx.barabasi_albert_graph(ni, np.random.randint(1, ni))
    # g = nx.path_graph(ni)
    # g = nx.balanced_tree(4, 5)
    g = nx.grid_graph((ni, ni))
    print(f"Testing size {g.number_of_nodes()}\n")
    # define models
    for m in gen_prototypes(g):
        l = []
        for test in tests:
            try:
                r = timeit(m, steps, loops, test)
            except Exception as e:
                print(e)
                r = -1
            l.append(r)
        timings.append((m.__class__.__name__, *l))
    timings.append(())
print('\n')
headers = "Models"
for test in tests:
    headers += " " + test
tab = tabulate(timings, headers = headers.split())

print(tab)
