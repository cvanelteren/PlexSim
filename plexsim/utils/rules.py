import networkx as nx, numpy as np

def create_rule_full(rule, connection_weight_other = -1,
                     connection_weight = 1,
                     self_weight = 0):
    """
    Create a full rule graph
    """
    # connection between nodes
    # self weight
    A = nx.adjacency_matrix(rule).todense() 
    g = nx.Graph()
    for idx, w in enumerate(A.flat):
        u, v = np.unravel_index(idx, A.shape)
        if w > 0:
            w *= connection_weight
        else:
            w = connection_weight_other
        g.add_edge(u, v, weight = w * connection_weight)

    # add self love
    for node in g.nodes():
        g.add_edge(node, node, weight = self_weight)
    return g

def check_df(queue, n, m, path = [], vp_path = [], results = []):
    # print(">", path)
    if queue:
        # get current node
        current = queue.pop()
        # print(f"At {current}")
        # print(f"vp_path : {vp_path}")
        node = m.adj.rmapping[current]
        s = m.states[current]
        # update paths 
        for neigh in m.graph.neighbors(node):
            other = m.adj.mapping[neigh]
            ss = m.states[other]
            # sort results to prevent symmetry effects 
            e = sorted((current, other))
            if e not in path: 
                queue.append(other)
            ev = sorted((s, ss))
            if path:
                if e == path[-1]:
                    # print("reversal found")
                    continue
            if m.rules[s][ss]['weight'] <= 0: 
                # print('negative weight')
                continue
            # other not already checked
            if ev not in vp_path and e not in path:
                # advance path
                path.append(e)
                vp_path.append(ev)
                # results are either just the solution space or nothing
                check_df(queue, n, m, path.copy(), vp_path.copy(), results) 
                path.remove(e)
                vp_path.remove(ev)
    # terminate if number of edges is reached
    if len(path) == n:
        # print("Terminating")
        b = set(tuple([tuple(i) for i in path]))
        add = True
        if len(results):
            add = False
            for r in results:
                a = set(tuple([tuple(i) for i in r]))
                J = len(a.intersection(b))/ len((a.union(b)))
                if J != 1:
                    add = True
                    break
        if add:
            results.append(path.copy())
    # print("Returning")
    return results
