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
    for k, v in ConnectedSimpleGraphs().generate(4).items():
        for vi in v:
            graphs.append(vi)

    timings = np.zeros((2, len(graphs)))
    for idx, graph in enumerate(graphs):
        print("setting up vncpp")
        m = setup(graph, VNCPP)
        start = time.time()
        run(m)
        timings[0, idx] = time.time() - start

        print("setting up vncpy")
        m = setup(graph, VNCY)

        start = time.time()
        run(m)
        timings[1, idx] = time.time() - start

    print(timings[1] / (timings[0]))
    print(timings[0] / timings[1])
    print(timings)
    xr = np.array([len(i) for i in graphs])
    fig, ax = plt.subplots(2, 1, figsize=(5, 5))
    for t, l in zip(timings, "CPP CYTHON".split()):
        ax[0].scatter(xr, t, label=l, s=5)

    ax[1].scatter(xr, timings[1] / timings[0], label="Cython/CPP speed")
    ax[1].scatter(xr, timings[0] / timings[1], label="CPP/Cython speed")
    ax[0].scatter(xr, t, label=l, s=5)

    ax[1].scatter(xr, timings[1] / timings[0], label="Cython/CPP speed")
    # ax[1].scatter(xr, timings[0] / timings[1], label="CPP/Cython speed")

    ax[0].legend()
    ax[1].legend()

    ax[0].set_xlabel("Value network size |V|")
    ax[1].set_xlabel("Value network size |V|")

    ax[0].set_ylabel("Timings")
    ax[1].set_ylabel("Ratio timing")
    ax[0].set_yscale("log")
    ax[1].set_yscale("log")
    fig.show()
    plt.show()
