from plexsim.models.value_network import ValueNetwork
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())
from test_valuenetwork import TestCrawl, visualize_graph
from plexsim.utils.rules import create_rule_full


def test_crawl_single(m, target, verbose=False, nodes=None):
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

    if nodes:
        to_check = ((m.adj.rmapping[node], node) for node in nodes)
    else:
        to_check = m.adj.mapping.items()
    for node_label, node in to_check:
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


def test_specific(graph: nx.Graph, nodes: list = None):
    r = create_rule_full(graph, self_weight=-1)
    S = np.arange(len(r))
    m = ValueNetwork(graph, rules=r, agentStates=S)
    print(f"{m.bounded_rational=}")
    m.states = S
    test_crawl_single(m, target=1, verbose=1, nodes=nodes)


g = nx.complete_graph(4)

# g = nx.path_graph(3)
# g = nx.star_graph(3)
# # g.add_edge(1, 2)

# g = nx.cycle_graph(3)
# g = nx.path_graph(2)


from plexsim.utils.graph import ConnectedSimpleGraphs

csg = ConnectedSimpleGraphs()

# g = nx.complete_graph(4)
# g = nx.cycle_graph(3)
# test_specific(g)
# double_y()
# g = csg.rvs(7)

# g = nx.path_graph(4)
# g.add_edge(1, 10)
# g.add_edge(10, 11)
#
g = nx.star_graph(10)
r = nx.path_graph(3)
A = np.arange(len(r))
r = create_rule_full(r)
# print(A.shape)
m = ValueNetwork(g, rules=r, agentStates=A)

# m.states = np.array([*A, *A])
print(m.states)
fig, ax = plt.subplots()
ax.imshow(m.simulate(100))
fig.show()
plt.show(block=1)

# s = {0: 0, 1: 1, 2: 2, 3: 3, 4: 2, 5: 3}
# for k, v in s.items():
#     m.states[k] = v

# print(m.states.shape)
# print(m.nNodes, m.states)
# visualize_graph(m)

# # m.reset()
# # print(m.states)

# plt.show(block=1)
# test_crawl_single(m, target=1, verbose=1)

# # m.simulate(100)

# # test_specific(g, nodes=[1])
# print("-" * 32)
# print(f"{g.number_of_nodes()=}")
# print(f"{g.number_of_edges()=}")
# print("-" * 32)

# print()
# # double_y()
