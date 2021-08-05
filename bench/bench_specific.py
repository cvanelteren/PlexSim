from plexsim.models.value_network import ValueNetwork as VNCPP
from plexsim.models.value_network2 import ValueNetwork as VNCY
from plexsim.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.rules import create_rule_full
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())


rules = nx.path_graph(4)
rules.add_edge(2, 10)
rules = create_rule_full(rules)

size = 1000
p = 1 / size
# p = 1 / 3
graph = nx.erdos_renyi_graph(size, p)

S = np.arange(len(rules))
import time

m = VNCPP(graph, rules, agentStates=S)
m.reset()
start = time.time()
for node in graph.nodes():
    m.check_df(node)
elapsed = time.time() - start

print(f"{elapsed=}")
