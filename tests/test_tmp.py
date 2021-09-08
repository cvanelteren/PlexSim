from plexsim.models.value_network_edges import VNE
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())

from plexsim.utils.rules import *
from plexsim.utils.visualisation import *


g = nx.path_graph(3)
g.add_edge(1, 3)
g.add_edge(3, 0)
r = create_rule_full(
    nx.cycle_graph(3),
    self_weight=-1,
)

s = np.arange(len(r))
m = VNE(graph=g, rules=r, agentStates=s)


m.states = [
    0,
    0,
    0,
    0,
]
print(m.siteEnergy(m.states))
print(m.adj.mapping)
