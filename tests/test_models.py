import unittest as ut
from plexsim.models import *
from plexsim.models.base import Model
import subprocess, numpy as np, networkx as nx


# TODO: add cython tests
class TestBaseModel(ut.TestCase):
    model = Model
    agentStates = np.array([0])
    # g = nx.path_graph()
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
        import pickle

        before = self.m.states
        # dumping to binary
        # tmp
        self.m.updateType = "sync"
        self.m.nudgeType = "pulse"
        self.m.kNudges = 2
        self.m.sampleSize = 1
        newModel = pickle.loads(pickle.dumps(self.m))

        properties = {}
        for prop in dir(self.m):
            if not prop.startswith("_"):
                v = getattr(self.m, prop)
                properties[prop] = v
        import copy

        other = copy.deepcopy(self.m)
        self.assertEqual(newModel, self.m)

        # TODO: this below is now in base model
        # for name in dir(self.m):
        #     prop = getattr(self.m, name)
        #     oprop = getattr(other, name)
        #     if not name.startswith("_") and callable(prop) == False:
        #         print(f"checking {name=} {prop} {oprop}")
        #         if hasattr(prop, "__iter__"):
        #             for x, y in zip(prop, oprop):
        #                 self.assertEqual(x, y)
        #         else:
        #             self.assertEqual(prop, oprop)

        # for name, prop in properties.items():
        #     prop_copy = getattr(newModel, name)
        #     print(name, prop_copy, prop)
        #     if hasattr(prop, "__iter__"):
        #         for x, y in zip(prop_copy, prop):
        #             self.assertEqual(x, y)
        #     else:
        #         print(type(prop))
        #         self.assertEqual(prop_copy == prop, True)

        # for prop in "updateType nudgeType sampleSize last_written kNudges".split():
        #     self.assertEqual(getattr(newModel, prop), getattr(self.m, prop))

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
        nudges = {"1": 1}
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

    def test_spanw(self):
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


# from plexsim import cy_tests
# from plexsim.tests import test_pickle
if __name__ == "__main__":
    ut.main()
