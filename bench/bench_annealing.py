import matplotlib.pyplot as plt, cmasher as cmr, time
import numpy as np, os, sys, networkx as nx, warnings, pyprind as pr
from plexsim import models
from imi import infcy

from plexsim.utils import annealing, graph
from plexsim.utils.rules import create_rule_full
from itertools import product

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())


csg = graph.ConnectedSimpleGraphs()

graphs = [graph for graphs in csg.generate(6).values() for graph in graphs]


combs = product(graphs, graphs)
timings = np.zeros(len(graphs) ** 2)
edges = np.zeros(timings.size)
pb = pr.ProgBar(len(graphs) ** 2)
for idx, (graph, rule) in enumerate(combs):
    create_rule_full(rule)
    s = np.arange(len(rule))
    m = models.ValueNetwork(graph, rules=rule, agentStates=s)
    start = time.time()
    annealing.annealing(m)
    timings[idx] = time.time() - start
    edges[idx] = rule.number_of_edges()
    pb.update()

fig, ax = plt.subplots()

ax.scatter(edges, timings)
ax.set_title(f"{timings.sum(): .2f}")
fig.show()
plt.show(block=1)
