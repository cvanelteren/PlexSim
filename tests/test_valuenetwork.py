import unittest as ut
import subprocess, numpy as np

from plexsim.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.rules import create_rule_full
from plexsim.models import ValueNetwork

import matplotlib.pyplot as plt, networkx as nx
from plexsim.utils.visualisation import GraphAnimation

import time, logging

# Set log level


class TestRecursionCrawl(ut.TestCase):
    model = ValueNetwork

    def setUp(self):
        self.graphs = []
        for k, v in ConnectedSimpleGraphs().generate(4).items():
            [self.graphs.append(vi) for vi in v]
        self.verbose = False

    @ut.skip
    def test_crawls_true_positive(self):
        for graph in self.graphs:
            r = create_rule_full(graph, self_weight=-1)
            S = np.arange(len(r))
            m = self.model(graph, rules=r, agentStates=S)

            # set state -> social network matches the value network
            for node in range(m.nNodes):
                m.states[node] = node

            self.__test_crawl_single(m, target=1, verbose=self.verbose)

    # @ut.skip
    def test_crawls_true_negative(self):
        for graph in self.graphs:
            r = create_rule_full(graph, self_weight=-1)
            S = np.arange(len(r))
            m = self.model(graph, rules=r, agentStates=S)

            # set state -> social network matches the value network
            m.states = S[0]
            self.__test_crawl_single(m, target=0, verbose=self.verbose)

    # @ut.skip
    def test_y_dual_branch(self):
        r = nx.path_graph(3)
        S = np.arange(len(r))
        graph = nx.path_graph(3)
        # graph.add_edge(1, 3)
        m = self.model(graph, rules=r, agentStates=S)
        # SS = np.array([*np.arange(2), *[1, 1]])
        assert S.size == m.nNodes
        for idx in range(m.nNodes):
            m.states[idx] = S[idx]
        self.__test_crawl_single(m, target=0, verbose=True)

    def __test_crawl_single(self, m, target, verbose=False):

        if verbose:
            print("-" * 32)
            print(f"Testing graph of size {len(m.graph)}")
            print("-" * 32)

        # time.sleep(1)
        crawls = []
        tmp = []

        if verbose:
            fig, ax = plt.subplots()
            nx.draw(m.graph, ax=ax, with_labels=1)
            fig.show()
            # plt.show(block=True)

        for node_label, node in m.adj.mapping.items():
            crawl = m.check_df(node, verbose=verbose)
            # crawl = m.check_df(node)

            if verbose:
                print(f"solution: {crawl} {len(crawl)}")
            assignment = len(crawl) == target
            if verbose:
                print(f"Results ok? {assignment} for node {node}")
                print(f"{m.adj.mapping=}")
            # print(m.states)

            self.assertTrue(
                assignment,
                f"assignment was {assignment} with {crawl}",
            )

            crawls.append(assignment)
            # tmp.append((crawl, options))
        if verbose:
            plt.show()


if __name__ == "__main__":
    ut.main()
