from plexsim.models.value_network import ValueNetwork
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())
from test_valuenetwork import TestCrawl
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


def unrolled_y():
    g = nx.path_graph(4)
    g.add_edge(1, 10)
    # g.add_edge(10, 11)
    nx.draw(g, with_labels=1)
    plt.show()
    r = create_rule_full(nx.path_graph(3))
    S = np.arange(4)
    s = np.array([*S, 2])
    m = ValueNetwork(g, rules=r, agentStates=S)
    m.states = s
    test_crawl_single(m, target=1, verbose=1)

    assert s.size == m.nNodes

    x = np.linspace(0, 1, m.nStates, 0)
    colors = cmr.guppy(x)
    c = []
    for node in range(m.nNodes):
        s = int(m.states[node])
        ci = colors[s]
        c.append(ci)

    print(m.states)
    nx.draw(g, with_labels=1, node_color=c)
    plt.show()


def double_y():
    g = nx.path_graph(4)
    g.add_edge(1, 10)
    # g.add_edge(10, 11)
    nx.draw(g, with_labels=1)
    plt.show()
    r = create_rule_full(nx.path_graph(3))
    S = np.arange(4)
    s = np.array([*S, 2])
    m = ValueNetwork(g, rules=r, agentStates=S)
    m.states = s
    test_crawl_single(m, target=1, verbose=1)

    assert s.size == m.nNodes

    x = np.linspace(0, 1, m.nStates, 0)
    colors = cmr.guppy(x)
    c = []
    for node in range(m.nNodes):
        s = int(m.states[node])
        ci = colors[s]
        c.append(ci)

    print(m.states)
    nx.draw(g, with_labels=1, node_color=c)
    plt.show()


g = nx.complete_graph(4)

# g = nx.path_graph(3)
# g = nx.star_graph(3)
# # g.add_edge(1, 2)

# g = nx.cycle_graph(3)
# g = nx.path_graph(2)


from plexsim.utils.graph import ConnectedSimpleGraphs

csg = ConnectedSimpleGraphs()

# g = nx.complete_graph(5)
# g = nx.path_graph(2)
g = nx.path_graph(3)
# test = TestRecursionCrawl()
# test_specific(g)
# double_y()
# g = csg.rvs(7)
r = nx.path_graph(3)
r = create_rule_full(r)
m = ValueNetwork(graph=g, rules=r)
print(m.simulate(10))

# test_specific(g, nodes=[1])
print("-" * 32)
print(f"{g.number_of_nodes()=}")
print(f"{g.number_of_edges()=}")
print("-" * 32)

print()
# double_y()
