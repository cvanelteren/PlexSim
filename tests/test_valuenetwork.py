import unittest as ut
import subprocess, numpy as np

from plexsim.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.rules import create_rule_full
from plexsim.models import ValueNetwork

import matplotlib.pyplot as plt
from plexsim.utils.visualisation import GraphAnimation

import logging

# Set log level


class TestRecursionCrawl(ut.TestCase):
    model = ValueNetwork

    def setUp(self):
        self.graphs = []
        for k, v in ConnectedSimpleGraphs().generate(5).items():
            [self.graphs.append(vi) for vi in v]

    def test_crawls_true_positive(self):
        for graph in self.graphs:
            r = create_rule_full(graph, self_weight=-1)
            S = np.arange(len(r))
            m = self.model(graph, rules=r, agentStates=S)

            # set state -> social network matches the value network
            for node in range(m.nNodes):
                m.states[node] = node

            self.__test_crawl_single(m, target=1)

    @ut.skip
    def test_crawls_true_negative(self):
        for graph in self.graphs:
            r = create_rule_full(graph, self_weight=-1)
            S = np.arange(len(r))
            m = self.model(graph, rules=r, agentStates=S)

            # set state -> social network matches the value network
            m.states = S[0]
            self.__test_crawl_single(m, target=0)

    def __test_crawl_single(self, m, target):

        print("-" * 32)
        print(f"Testing graph of size {len(m.graph)}")
        print("-" * 32)
        crawls = []
        tmp = []
        for node_label, node in m.adj.mapping.items():
            queue = [[node, node]]
            crawl, options = m.check_df(
                queue, path=[], vp_path=[], results=[[], []], verbose=0
            )
            # if len(crawl) == 1:

            print(f"solution: {crawl} {len(crawl)}")
            assignment = len(crawl) == target
            print(f"Results ok? {assignment} for node {node}")
            print(m.states)

            # try:
            self.assertTrue(
                assignment,
                f"assignment was {assignment} with {crawl} and {options}",
            )

            # except:
            #     queue = [[node, node]]
            #     crawl, options = m.check_df(
            #         queue, path=[], vp_path=[], results=[[], []], verbose=1
            #     )

            # if len(crawl) == False:

            # crawl, options = m.check_df(
            #     queue, path=[], vp_path=[], results=[[], []], verbose=1
            # )

            crawls.append(assignment)
            tmp.append((crawl, options))

        # if not all(crawls):
        # print("-" * 32 + "\n")
        # print(f"Crawling results {crawls}")
        # print(m.adj.rmapping, m.bounded_rational)
        # for idx, crawl in enumerate(crawls):
        #     if crawl == False:
        #         r, o = tmp[idx]
        #         print(f"Node {idx}, found {len(r)} with options {len(o)}")
        #         print("Listing results")
        #         for ri in r:
        #             print(ri)
        #         print("Listing options")
        #         for opt in o:
        #             print(opt)

        #         queue = [[node, node]]
        #         crawl, options = m.check_df(
        #             queue, path=[], vp_path=[], results=[[], []], verbose=1
        #         )

        # fig, ax = plt.subplots(figsize=(2, 2), constrained_layout=1)
        # ga = GraphAnimation(m.graph, m.states.reshape(1, -1), m.nStates)
        # ga.setup(ax=ax, labels=dict(font_color="white"), rules=m.rules)
        # plt.show(block=1)
