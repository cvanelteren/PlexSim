import unittest as ut
from PlexSim.plexsim.models import *
import subprocess, numpy as np

class TestBaseModel(ut.TestCase):
    model = Model
    agentStates = [0]
    #g = nx.path_graph()
    g  = nx.path_graph(3)
    def setUp(self):
        self.updateTypes = "async sync".split()
        self.nudgeTypes  = "constant pulse".split()
        self.m = self.__class__.model(self.__class__.g)
        self.agentStates =  self.__class__.agentStates

    def sampling(self):
        """
        helper function
        """
        samples = self.m.sampleNodes(1)
        for sample in samples.base.flat:
            self.assertTrue(0 <= sample <= self.m.nNodes)
        return samples

    def test_init(self):
        # testin update types
        for updateType, nudgeType in zip(self.updateTypes, self.nudgeTypes):
            m = self.m.__class__(graph = nx.path_graph(1), updateType = updateType,\
                                 nudgeType = nudgeType, sampleSize = 1)
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
                self.assertEqual(samples.shape[-1],  1)
            else:
                self.assertEqual(samples.shape[-1], self.m.nNodes)
        #with self.assertRaises(ValueError):
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
        self.m.nudgeType  = "pulse"
        self.m.kNudges    = 2
        self.m.sampleSize = 1
        newModel = pickle.loads(pickle.dumps(self.m))
        import copy
        newModel = copy.deepcopy(self.m)
        for prop in "updateType nudgeType sampleSize last_written seed kNudges".split():
            self.assertEqual(getattr(newModel, prop), getattr(self.m, prop))
    def test_nudges(self):
        nudge = 1 
        node = next(iter(self.m.mapping))
        self.m.nudges = {node : nudge}
        self.assertEqual(self.m.nudges[0], nudge)

    def test_sampleSize(self):
        with self.assertRaises(AssertionError):
            self.m.sampleSize = self.m.nNodes +1
        self.m.sampleSize = .25
        self.assertEqual(self.m.sampleSize, int(.25 * self.m.nNodes)
        )

    def test_seed(self):
        with self.assertRaises(ValueError):
            self.m.seed = -1
        self.m.seed = 1
        self.assertEqual(self.m.seed, 1)
    #@ut.skip("Cython not used")
    def test_apply_nudge(self):
        print("testing nudges")
        nudges = {"1" : 1}
        self.m.nudges = nudges 
        print(self.m.nudges)
        print(self.m.adj)
        nodes = np.ones(10, dtype = int) * self.m.mapping[next(iter(nudges))]
        self.m.updateState(memoryview(nodes))
        ## fill buffer
        #self.m._apply_nudges(self, backup)
        #self.assertEqual(backup[0], 1)

        ## check if empty
        #self.m._remove_nudge(self, backup)
        #self.assertEqual(backup.size(), 0)
    


class TestPotts(TestBaseModel):
    model = Potts
    agentStates = [0, 1]
    g = nx.path_graph(2)
    def test_updateState(self):
        # force update to be independent
        # update all the nodes
        self.m.updateType = 'sync'
        temps = np.asarray([0, np.inf])
        targs = [1, 0]
        mag, sus = self.m.magnetize(temps = temps,\
                                             n = 10000)
        for (magi, target) in zip(mag, targs):
            self.assertAlmostEqual(magi, target, places = 1)

class TestIsing(TestPotts):
    model = Ising
    agentStates = [-1, 1]

from PlexSim.plexsim import cy_tests 

if __name__ == '__main__':
    ut.main()
