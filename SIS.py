from models import Model
from scipy.stats import beta, bernoulli
import numpy as np
class SIS(Model):
    def __init__(self, graph, params, agentStates = [0, 1]):
        super(SIS, self).__init__(\
        graph = graph, agentStates = agentStates)
        a, b, aa, bb, aaa, bbb = params

        # sample parameters
        self.alpha = beta.rvs(a,b) # prob outside person infecting person in the graph
        self.beta  = beta.rvs(aa, bb)  # prob infectious person within the network infecting other
        self.gamma = beta.rvs(aaa, bbb)


        self.states.fill(0) # start with zero infected
        self.symptoms = np.zeros(self.states.shape)

    def infectOutside(self):
        return bernoulli.rvs(self.alpha)
    def infectInside(self, node):
        # proportional to interaction
        return bernoulli.rvs(self.beta)

    def updateState(self, nodesToUpdate):
        states = self.states.copy() if self.updateType== 'sync' else self.states
        for node in nodesToUpdate:
            # if infected; check if cured
            if states[node]:
                if bernoulli.rvs(self.gamma):
                    self.states[node] = 0
            else:
                # check infection outside network
                # check infecting within network
                a = [self.infectInside(node) for i in self.edgeData[node]]
                

                if any(a) or self.infectOutside():
                    self.states[node] = 1
            # update symptoms
            # symptomps[node] = self.checkSymtomps(states[node])

        return self.states
