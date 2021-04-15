from example import PD, Potts
import networkx as nx
g = nx.path_graph(3)
print(Potts(graph =g ))
m = PD(graph = g)
print(m.graph)
m.return_adj()
m.step(1)
