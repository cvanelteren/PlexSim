import numpy as np
def annealing(m, theta = 0.1, rate = .01, reset = True,
              verbose = False):
    if reset:
        m.reset()
    m.t = 1000000
    current = m.states.copy()
    best = np.sum(m.siteEnergy(current))
    if verbose:
        print(f"Starting with {best}")
    # counter for cooling
    k = 0
    while m.t > theta:
        # reset state to current
        m.states = current.copy()
        # generate proposal
        node = m.sampleNodes(1)
        m.updateState(node[0])
        proposal = np.sum(m.siteEnergy(m.states))
        # test if solution is better 
        if proposal < best:
            current = m.states.copy()
            best = proposal
            if verbose:
                print(f"Best is now {best}")
        # anneal
        t = (1 + (proposal - best) / (proposal + 1))
        t *=  cooling(m.t, k, rate) 
        m.t = abs(t) 
        k += 1
        if not k % 100 :
            if k > 1e5:
                print("Too much annealing!")
                break
    return current        
cooling = lambda x, k, rate: x/(1 + rate * k**2)
