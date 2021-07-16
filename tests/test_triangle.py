from plexsim.models import ValueNetwork
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())
from test_valuenetwork import TestRecursionCrawl
from plexsim.utils.rules import create_rule_full


def test_crawl_single(m, target, verbose=False):
    if verbose:
        print("-" * 32)
        print(f"Testing graph of size {len(m.graph)}")
        print("-" * 32)

    # time.sleep(1)
    crawls = []
    tmp = []

    # fig, ax = plt.subplots()
    # nx.draw(m.graph, ax=ax, with_labels=1)
    # fig.show()
    # plt.show()

    for node_label, node in m.adj.mapping.items():
        # node = 4
        # node_label = "4"
        print(f"Checking {node=}")
        crawl = m.check_df(node, verbose=verbose)
        if verbose:
            print(f"Solution: {crawl} {len(crawl)}")
        assignment = len(crawl) == target

        if verbose:
            print(f"Results ok? {assignment} for node {node} {node_label=}")
            for a in crawl:
                print(a)
            print()
        # print(m.states)
        # break


def test_specific(graph: nx.Graph):
    r = create_rule_full(graph, self_weight=-1)
    S = np.arange(len(r))
    m = ValueNetwork(graph, rules=r, agentStates=S)
    print(f"{m.bounded_rational=}")
    m.states = S
<<<<<<< Updated upstream
    test_crawl_single(m, target=1, verbose=1)

=======
    test_crawl_single(m, target=1, verbose=1, nodes=nodes)


g = nx.path_graph(5)

# g = nx.path_graph(3)
# g = nx.star_graph(4)
# g.add_edge(1, 2)
# g.add_edge(1, 2)

g = nx.cycle_graph(3)
# g = nx.path_graph(2)
>>>>>>> Stashed changes

# g = nx.path_graph(2)
g = nx.path_graph(3)
# g = nx.cycle_graph(3)

#
# g = nx.cycle_graph(3)
# g = nx.path_graph(2)
# g = nx.path_graph(3)
# test = TestRecursionCrawl()
# test.test_specific(g)
<<<<<<< Updated upstream
=======

test_specific(g)

>>>>>>> Stashed changes
nx.draw(g, with_labels=1)
plt.show()

test_specific(g)
