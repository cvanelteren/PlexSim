from plexsim.models.value_network import ValueNetwork as VNCPP
from plexsim.models.value_network2 import ValueNetwork as VNCY
from plexsim.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.rules import create_rule_full

import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
import timeit

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())


def setup(graph: nx.Graph, model_t: object) -> object:
    r = create_rule_full(graph, self_weight=-1)
    S = np.arange(len(r))
    m = model_t(graph, rules=r, agentStates=S)
    print(f"{m.bounded_rational=}")
    m.states = S
    return m


def run(m: object) -> None:
    for node in range(m.nNodes):
        m.check_df(node)


import time

if __name__ == "__main__":
    graphs = []
    for k, v in ConnectedSimpleGraphs().generate(3).items():
        for vi in v:
            graphs.append(vi)

    for graph in graphs:
        print("setting up vncpp")
        m = setup(graph, VNCPP)
        start = time.time()
        run(m)
        print(time.time() - start)

        print("setting up vncpy")
        m = setup(graph, VNCY)

        start = time.time()
        run(m)
        print(time.time() - start)
