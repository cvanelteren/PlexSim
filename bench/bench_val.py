from plexsim.models.value_network import ValueNetwork as VNCPP
from plexsim.models.value_network_gradient import VNG
from plexsim.models.value_network_edges import VNE
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
    # m.simulate(2)
    if type(m) is type(VNG):
        d = m.check_gradient()
    else:
        d = m.siteEnergy(m.states)
    # print(m, d)


import time


def main():
    graphs = []
    # graphs = [ConnectedSimpleGraphs().rvs(6) for i in range(5)]

    # graphs = [
    #     j
    #     for i in ConnectedSimpleGraphs().generate(6).values()
    #     for j in i
    #     if j.number_of_edges() < 5
    # ]

    print(len(graphs))
    from functools import partial

    experiments = dict(
        triangular_lattice=[nx.triangular_lattice_graph(i, 1) for i in range(2, 8)],
        connected_simple=[ConnectedSimpleGraphs().rvs(5) for i in range(5)],
    )

    # experiments = dict(
    #     connected_simple=[ConnectedSimpleGraphs().rvs(6) for i in range(5)],
    # )

    import copy

    # graphs = [nx.path_graph(20)]
    models = [VNCPP, VNG]
    ntrials = 10
    output = []
    for name, graphs in experiments.items():
        for idx, graph in enumerate(graphs):
            graph = nx.convert_node_labels_to_integers(graph)
            print("-" * 32)
            print(f"{graph.number_of_nodes()=}")
            print(f"{graph.number_of_edges()=}")
            n = graph.number_of_edges()
            m = graph.number_of_nodes()
            for midx, model in enumerate(models):
                print(32 * "-")
                print(f"Setting up {model}")
                m = setup(graph, model)
                for trial in range(ntrials):
                    start = time.time()
                    run(m)
                    data = dict(
                        trial=trial,
                        m=copy.copy(m),
                        model=m.__class__.__name__,
                        timing=time.time() - start,
                        experiment=name,
                    )
                    output.append(data)

    import pandas as pd

    output = pd.DataFrame(output)
    output.to_pickle("./bench_val.pkl")


if __name__ == "__main__":
    import cProfile as cp, pstats

    profiler = cp.Profile()
    profiler.enable()
    main()
    profiler.disable()
    stats = pstats.Stats(profiler).sort_stats("cumtime")
    report = "./bench_val.prof.stats.txt"
    stats.dump_stats(report)
