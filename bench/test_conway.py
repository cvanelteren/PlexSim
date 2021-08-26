from plexsim.models import Conway
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())

n = 65

g = nx.grid_graph((n, n), periodic=True)

# for node in g.nodes():
#     for i in range(-1, 2):
#         for j in range(-1, 2):
#             x, y = node
#             new = ((x + i) % n, (y + j) % n)
#             if g.has_node(new):
#                 if not g.has_edge(node, new):
#                     g.add_edge(new, node)

m = Conway(g)
# m.states = 0
# m.states[:4] = 1
# S = np.arange(10)
# m = models.Potts(g, agentStates=S)
fig, ax = plt.subplots()
from plexsim.utils.visualisation import GraphAnimation

s = {0: {"states": m.states.reshape(1, -1)}}

s = m.states.reshape(1, -1)
ga = GraphAnimation(m.graph, s, m.nStates + 1)
pos = {i: eval(i) for i in m.graph.nodes()}
ga.setup(ax, layout=pos, node_kwargs=dict(node_size=64))
h = ax.collections[0]
print(h.set_color)

# m.states = 0
# m.states[:4] = 1

while True:
    # s = m.updateState(m.sampleNodes(1)[0]).base
    m.simulate(2)
    c = ga.colors(m.states.astype(int))
    h.set_color(c)
    plt.pause(1e-16)
