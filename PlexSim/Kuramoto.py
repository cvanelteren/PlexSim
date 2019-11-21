from models import Model
from numpy import *
'''
the state is now the natural frequency of the node
'''
class Kuramoto(Model):
    def __init__(self, graph, agentStates = [1, 2], updateType= 'sync'):
        # need to keep track of inherent phase
        super(Kuramoto, self).__init__(graph = graph, agentStates = agentStates, updateType= mode)

        # tmp hack
        self.states = random.rand(self.nNodes) * 2 * pi #  phase
        self.freq = random.randn(self.nNodes) # frequency
        self.dt = 1e-3

    def func(self, freq, weights, delta):
        return freq +  weights.dot(sin(delta))

    def nearest_neighbor(self):
        # TODO: compute neareast neighbor
        self
    def updateState(self, nodesToUpdate):
        states = self.states.copy() if self.updateType== 'sync' else self.states
        for node in nodesToUpdate:
            # get neighbor phase and update
            weights        = self.interaction[node]
            neighborStates = states[self.edgeData[node]]

            phase = states[node]
            freq  = self.freq[node]
            delta = neighborStates - phase
            # runge-kutta 4
            k1 = self.func(freq, weights, delta)
            k2 = self.func(freq, weights, delta + .5  * k1)
            k3 = self.func(freq, weights, delta + .5  * k2)
            k4 = self.func(freq, weights, delta  * k3)

            self.states[node] += self.dt / 6  * (k1 + 2 * k2 + 2 * k3 + k4)
            # euler update
            # self.states[node] = phase + self.dt * ( freq + weights.dot(sin(delta)))

        self.states = mod(self.states, 2*pi)
        return self.states
