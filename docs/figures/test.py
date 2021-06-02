from plexsim.models import *
import networkx as nx, numpy as np

n = 64
g = nx.grid_graph([n, n])

nx.set_node_attributes(g, {node: 0 for node in g.nodes()}, "state")
idx = np.random.randint(len(list(g.nodes())))

node = list(g.nodes())[idx]
rule = nx.cycle_graph(3)
from plexsim.utils.rules import create_rule_full

rule = create_rule_full(rule, self_weight=-1)

settings = dict(
    graph=g,
    updateType="async",
)

import time

ti = time.time()

coordinates =  np.random.rand(len(g), 2)
velocities  = np.random.rand(len(g), 2)
S = np.arange(0, len(rule))
models = dict(
    Potts=Potts(t=0.8, agentStates=np.arange(0, 5), **settings),
    Bonabeau=Bonabeau(agentStates=np.arange(3), eta=0, **settings),
    AB=AB(**settings),
    Prisoner=Prisoner(**settings),
    Ising=Ising(t=2.2, **settings),
    Bornholdt=Bornholdt(t=2.2, alpha=4, **settings),
    RBN=RBN(**settings),
    SIRS=SIRS(mu=0.15, nu=0, kappa=0.01, beta=0.4, **settings),
    CCA=CCA(agentStates=np.arange(0, 4).tolist(), threshold=0.01, **settings),
    Percolation=Percolation(p=0.01, **settings),
    MagneticBoids(coordinates = coordinates,
                  velocities = velocities,
                  rules = rule, bounded_rational = 1, agentStates = S),
    # Cycledelic(g, predation = 2.0, competition = 1.5, difusion = .68)
)
print(f"Settup time was {time.time() - ti}")
# models.get("Bornholdt").sampleSize = 1
if m := models.get("SIRS"):
    m.states = 0
    m.states[m.sampleNodes(1)[0, 0]] = 1

if m := models.get("SIR"):
    m.states = 0
    m.states[m.sampleNodes(1)[0, 0]] = 1


if m := models.get("Percolation"):
    m.states = 0
    m.states[m.sampleNodes(1)[0, 0]] = 1
print("starting sims")

# mi = list(models.values())
# for i in mi:
#     print(i.memory.shape, i.memento)
# assert 0
T = 500
import time

start = time.time()

results = {}
for idx, (name, m) in enumerate(models.items()):
    #     m.states = m.agentStates[-1]
    # m.reset()
    results[name] = m.simulate(T).reshape(T, n, n)
print(f"Simulation took {time.time() - start}")
