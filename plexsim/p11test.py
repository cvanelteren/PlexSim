from example import * 




import networkx as nx
g = nx.DiGraph()
[g.add_node(i) for i in "a b c".split()]
g.add_edge('a', 'b')
g.add_edge('b', 'a')
print("from python")
for k, v in nx.node_link_data(g).items():
    print(k, v)
print("from c++")
lg(g)
