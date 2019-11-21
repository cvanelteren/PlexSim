class SIR(Model):
    def __init__(self, graph, gamma, agentStates = [0, 1, 2]):
        super(SIR, self).__init__(graph, agentStates)
        self.gamma = gamma # infection rate
