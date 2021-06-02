import networkx as nx, numpy as np
from example import PD

a = np.arange(3, dtype = np.float64)
g = nx.grid_graph((3,3))
m = PD(g, t = 1.5,
       sampleSize = 3)
b = m.simulate(10)
print(b)
