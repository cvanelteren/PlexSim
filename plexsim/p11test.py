#!/home/casper/miniconda3/bin/python
import example
import networkx as nx
from models import Model as cModel
n = 5
settings = dict(
    graph = nx.grid_graph([n, n]),
    agentStates = [0, 1],
)
import time
def timeit(model, loops, n):
    print(f"Testing {model}")
    start = time.time()
    for i in range(loops):
        model.sampleNodes(n)
    return time.time() - start


if __name__ == '__main__':

    # m = example.Model(**settings)

    # mm = cModel(**settings)
    # loops = 100
    # N = 10000000

    # cpp =timeit(m, loops, N)
    # cyt = timeit(mm, loops, N)
    # print(f"Cython took: {cyt}\nCPP took {cpp}\nCPP is {cyt/cpp} faster")

    # tmp = set(m.sampleNodes(1))
    # assert l
    # en(tmp) == settings["graph"].number_of_nodes(), len(tmp)

    import numpy as np
    
    n_a_rows = 4000
    n_a_cols = 3000
    n_b_rows = n_a_cols
    n_b_cols = 2000

    # a = np.arange(n_a_rows * n_a_cols).reshape(n_a_rows, n_a_cols)
    # b = np.arange(n_b_rows * n_b_cols).reshape(n_b_rows, n_b_cols)
    a = np.ones((n_a_rows, n_a_cols), dtype = float)
    b = np.ones((n_b_rows, n_b_cols), dtype = float)
    start = time.time()
    N = 100
    for loop in range(N):
        d = a.dot(b) 
    end = time.time()
    
    print ("time taken : {}".format(end - start))
# print(example.fun(2.))
