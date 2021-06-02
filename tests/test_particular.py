import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from plexsim.utils.rules import create_rule_full
from plexsim.models import ValueNetwork

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())

graph = nx.star_graph(4)
graph.add_edge(1, 2)
r = create_rule_full(graph, self_weight=-1)
S = np.arange(len(r))
m = ValueNetwork(graph, rules=r, agentStates=S)

for node in range(m.nNodes):
    m.states[node] = S[node]
print(m.states)
target = [[0, 0]]
paths, options = m.check_df(target, path=[], vp_path=[], results=[[], []], verbose=True)

opts = {}
for option in options:
    option = tuple((tuple(i) for i in option[0]))
    opts[option] = opts.get(option, 0) + 1
print(len(options))
for k, v in opts.items():
    if v > 1:
        print(k, v)
    # print(k, v)
