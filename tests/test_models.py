import unittest as ut
from plexsim.models import *
from plexsim.models.base import Model
import subprocess, numpy as np, networkx as nx


# TODO: add cython tests
class TestBaseModel(ut.TestCase):
    model = Model
    agentStates = np.array([0])
    g = nx.path_graph(3)

    def setUp(self):
        self.updateTypes = "async sync".split()
        self.nudgeTypes = "constant pulse".split()
        self.m = self.__class__.model(self.__class__.g)
        self.agentStates = self.__class__.agentStates

    def sampling(self):
        """
        helper function
        """
        samples = self.m.sampleNodes(1)
        for sample in samples.base.flat:
            self.assertTrue(0 <= sample <= self.m.nNodes)
        return samples

    def test_sampling(self):
        self.m.sampleNodes(100)

    def test_init(self):
        # testin update types
        for updateType, nudgeType in zip(self.updateTypes, self.nudgeTypes):
            m = self.m.__class__(
                graph=nx.path_graph(1),
                updateType=updateType,
                nudgeType=nudgeType,
                sampleSize=1,
            )
            self.assertEqual(m.updateType, updateType)
            self.assertEqual(m.nudgeType, nudgeType)
            self.assertEqual(m.sampleSize, 1)

    def test_updateTypes_sampling(self):
        """
        Test all the sampling methods
        It should generate idx from node ids
        """
        for updateType in self.updateTypes:
            self.m.updateType = updateType
            samples = self.sampling()
            # check the number of nodes being sampled
            if updateType == "single":
                self.assertEqual(samples.shape[-1], 1)
            else:
                self.assertEqual(samples.shape[-1], self.m.nNodes)
        # with self.assertRaises(ValueError):
        #    self.m.updateType = "NOT_POSSIBLE"

    def test_updateTypes_updateState(self):
        """
        Check whether the updateState function operates
        """
        for updateType in self.updateTypes:
            self.m.updateType = updateType
            update = self.m.simulate(1)[0]
            for u in update:
                self.assertIn(u, self.m.agentStates)

    def test_reduce(self):
        """
        Used for pickling
        """
        import pickle, copy

        before = self.m.states
        # dumping to binary
        # tmp
        self.m.updateType = "sync"
        self.m.nudgeType = "pulse"
        self.m.kNudges = 2
        self.m.sampleSize = 1
        newModel = pickle.loads(pickle.dumps(self.m))
        other = copy.deepcopy(self.m)
        self.assertEqual(newModel, self.m)

    def test_nudges(self):
        nudge = 1
        node = next(iter(self.m.adj.mapping))
        self.m.nudges = {node: nudge}
        self.assertEqual(self.m.nudges[0], nudge)

    def test_sampleSize(self):
        with self.assertRaises(AssertionError):
            self.m.sampleSize = self.m.nNodes + 1
        self.m.sampleSize = 0.25
        self.assertEqual(self.m.sampleSize, int(0.25 * self.m.nNodes))

    def test_seed(self):
        with self.assertRaises(ValueError):
            self.m.rng.seed = -1
        self.m.rng.seed = 1
        self.assertEqual(self.m.rng.seed, 1)

    # @ut.skip("Cython not used")
    def test_apply_nudge(self):
        nudges = {1: 1}
        self.m.kNudges = 10
        self.m.nudges = nudges
        nodes = np.ones(10, dtype=np.uintp) * self.m.adj.mapping[next(iter(nudges))]
        self.m.updateState(memoryview(nodes))
        ## fill buffer
        # self.m._apply_nudges(self, backup)
        # self.assertEqual(backup[0], 1)

        ## check if empty
        # self.m._remove_nudge(self, backup)
        # self.assertEqual(backup.size(), 0)

    # def test_spawn(self):
    #     self.m.nudges = {0: 1}
    #     d = self.m.__deepcopy__({})
    #     self.assertEqual(self.m.nudges, d.nudges)

    def test_spawn(self):
        models = self.m.spawn()
        for model in models:
            self.assertTrue(isinstance(model, type(self.m)))


class TestPotts(TestBaseModel):
    model = Potts
    agentStates = np.array([0, 1])
    g = nx.path_graph(2)

    def test_updateState(self):
        # force update to be independent
        # update all the nodes
        self.m.updateType = "async"
        temps = np.asarray([0, np.inf])
        targs = [1, 0]

        mag, sus = self.m.magnetize(temps=temps, n=1000)
        for magi, target in zip(mag, targs):
            self.assertAlmostEqual(magi, target, places=1)

    def test_nudgeShift(self):
        nudge = {0: 0.25}
        self.m.nudges = nudge

        self.m.simulate(10)


class TestIsing(TestPotts):
    model = Ising
    # agentStates = np.array([-1, 1], dtype = int)
    agentStates = np.array([0, 1])
    g = nx.path_graph(3)


class TestBornholdt(TestPotts):
    model = Bornholdt
    agentStates = np.array([0, 1])
    g = nx.path_graph(3)


from plexsim.utils.rules import create_rule_full


class TestValueNetwork(TestBaseModel):
    """
    Slightly edited base class. Value network are tested
    which has as an input a rule graph.

    FIXME: add setup dict to base class to prevent this doubling
    This was a temporary edit
    """

    model = ValueNetwork
    rule = create_rule_full(nx.path_graph(3))

    def setUp(self):
        rules = create_rule_full(nx.cycle_graph(3))
        g = self.__class__.g

        self.updateTypes = "async sync".split()
        self.nudgeTypes = "constant pulse".split()
        self.m = ValueNetwork(graph=g, rules=rules)
        self.agentStates = self.__class__.agentStates

    def test_init(self):
        # testin update types
        for updateType, nudgeType in zip(self.updateTypes, self.nudgeTypes):
            m = self.m.__class__(
                graph=nx.path_graph(1),
                rules=self.rule,
                updateType=updateType,
                nudgeType=nudgeType,
                sampleSize=1,
            )
            self.assertEqual(m.updateType, updateType)
            self.assertEqual(m.nudgeType, nudgeType)
            self.assertEqual(m.sampleSize, 1)

    def test_dump_rules(self):
        """
        Dump rules returns a networkx graph that removes all the negative edges
        """
        rules = self.m.dump_rules()
        self.assertEqual(rules.number_of_edges(), 3)
        self.assertEqual(self.__class__.rule.number_of_edges(), 6)


# from plexsim import cy_tests
# from plexsim.tests import test_pickle
if __name__ == "__main__":
    ut.main()
