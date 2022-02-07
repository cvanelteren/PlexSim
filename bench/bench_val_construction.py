from plexsim.models.value_network import ValueNetwork as VNCPP
from plexsim.models.value_network2 import ValueNetwork as VNCY
from plexsim.utils.graph import ConnectedSimpleGraphs, connected_random
from plexsim.utils.rules import create_rule_full

import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
import timeit

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())


def setup(graph: nx.Graph, model_t: object) -> object:
    r = create_rule_full(graph, self_weight=-1)
    S = np.arange(len(r))
    # br = min([1, r.number_of_edges()])
    m = model_t(graph, rules=r, agentStates=S, heuristic=1)
    # bounded_rational=br)
    print(f"{m.bounded_rational=}")
    number_of_triangles = sum(nx.triangles(m.graph).values()) / 3
    print(number_of_triangles)
    m.states = S
    return m


def run(m: object) -> None:
    # m.check_df(m.nNodes // 2, verbose=0)
    # m.check_df(10, verbose=1)
    for node in range(m.nNodes):
        m.check_df(node, verbose=False)


import time

if __name__ == "__main__":
    graphs = []

    # graphs = [ConnectedSimpleGraphs().rvs(7) for i in range(10)]

    from functools import partial

    p = lambda x, s, q: np.exp(-s * x) * x
    p = partial(p, s=1, q=0.5)
    for i in range(5, 20):
        g = nx.random_tree(20)

        # for _ in range(5):
        #     i, j = np.random.choice(g.nodes(), size=2)
        #     while i != j:
        #         i, j = np.random.choice(g.nodes(), size=2)
        #     g.add_edge(i, j)
        # # g = connected_random(nx.empty_graph(i), k=int(1e4), p=p)

        plt.show(block=1)
        graphs.append(g)

    # graphs = [nx.path_graph(20)]
    timings = np.zeros((2, len(graphs)))
    for idx, graph in enumerate(graphs):
        print("-" * 32)
        print(f"{graph.number_of_nodes()=}")
        print(f"{graph.number_of_edges()=}")
        n = graph.number_of_edges()
        m = graph.number_of_nodes()

        print("-" * 32)
        print("setting up vncpp")
        m = setup(graph, VNCPP)
        start = time.time()
        run(m)
        timings[0, idx] = time.time() - start

        print("setting up vncpy")
        m = setup(graph, VNCY)

        start = time.time()
        # run(m)
        timings[1, idx] = time.time() - start

    print(timings[1] / (timings[0]))
    xr = np.array([i.number_of_edges() for i in graphs])
    fig, ax = plt.subplots(2, 1, figsize=(5, 5))
    for t, l in zip(timings, "CPP CYTHON".split()):
        ax[0].scatter(xr, t, label=l, s=5)

    ax[1].scatter(xr, timings[1] / timings[0], label="Cython/CPP speed")
    # ax[1].scatter(xr, timings[0] / timings[1], label="CPP/Cython speed")

    ax[0].legend()
    ax[1].legend()

    ax[0].set_xlabel("Value network size |E|")
    ax[1].set_xlabel("Value network size |E|")

    ax[0].set_ylabel("Timings")
    ax[1].set_ylabel("Ratio timing")
    # ax[0].set_yscale("log")
    # ax[1].set_yscale("log")
    fig.show()
    plt.show(block=True)
