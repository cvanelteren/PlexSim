import networkx as nx, numpy as np


def create_rule_full(
    rule, connection_weight_other=-1, connection_weight=1, self_weight=-1
) -> nx.Graph:
    """
    Create a full rule graph

    Multiplies weight * @connection_weight if the edge is non-zero
    Sets the weight to be @connection_weight_other if no edge is found.
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
        g.add_edge(u, v, weight=w * connection_weight)

    # add self love
    for node in g.nodes():
        g.add_edge(node, node, weight=self_weight)
    return g


def check_doubles(path, results) -> None:
    """
    Don't allow for double edges
    Adds path inplace if it does not occur in results
    """
    add = True
    if path:
        for r in results[0]:
            if all([i in r for i in path]) or all([i[::-1] in r for i in path]):
                add = False
                break

        if add and path:
            results[0].append(path.copy())


def merge(results, n) -> None:
    """
    Merge paths from branches inplace
    """
    # attempt to merge branches
    merged = []
    # go through all the combinations in the options
    for idx, opti in enumerate(results[1]):
        for jdx, optj in enumerate(results[1]):
            # prevent self-comparison and double comparison
            if idx < jdx:
                # compare matched edges
                idxs, vpi = opti
                jdxs, vpj = optj
                # if the overlap is zero then the branches are valid
                # and should be merged
                # (not sure if this is necessary)
                J = True
                a = vpi
                b = vpj
                if len(vpi) > len(vpj):
                    a, b = b, a
                for i in a:
                    # if the rule edge already exists
                    # ignore the option
                    if i in b or i[::-1] in b:
                        J = False
                # add if no overlap is found
                if J:
                    # merging
                    print(f"Merging {vpi} with {vpj}")
                    proposal = [idxs.copy(), vpi.copy()]
                    for x, y in zip(jdxs, vpj):
                        proposal[0].append(x)
                        proposal[1].append(y)
                # copy
                else:
                    # print('copying')
                    proposal = [idxs.copy(), vpi.copy()]
                # check if its done
                if len(proposal) == n:
                    # prevent double results
                    check_doubles(proposal, results)
                # keep original branch
                else:
                    merged.append(proposal)
    # print(f"in merge and adding {merged} {results[1]}")
    if merged:
        results[1] = merged


def check_endpoint(s, m, vp_path) -> bool:
    """
    Check if an end point is reached
    """
    # update paths
    fail = True
    for ss in m.rules.neighbors(s):
        if m.rules[s][ss]["weight"] > 0:
            if [s, ss] not in vp_path:
                fail = False
    # print(f"Failing {fail} {s} {list(m.rules.neighbors(s))} {vp_path}")
    return fail


def check_df(queue, n, m, path=[], vp_path=[], results=[], verbose=False) -> list:
    """
    :param queue: edge queue, start with (node, node)
    :param n: number of edges in the rule graph
    :param m: model
    :param path: monitors edges visited in social network
    :param vp_path: monitors edges visited in value network
    :param results: output. List of 2. First index contained completed value networks, second index contains branch options
    :param verbose: print intermediate step for heavy debugging!
    """
    if queue:
        # get current node
        from_node, current = queue.pop()
        node = m.adj.rmapping[current]
        # empty local options
        results[1] = []
        s = m.states[current]
        # check only if difference
        if current != from_node:
            path.append([current, from_node])
            vp_path.append([m.states[current], m.states[from_node]])

        # logging
        if verbose:
            print(f"At {current}")
            print(f"Path : {path}")
            print(f"Vp_path : {vp_path}")
            print(f"Options: {results[1]}")
            print(f"Results: {results[0]}")

        # check if no options left in rule graph
        if check_endpoint(s, m, vp_path):
            if verbose:
                print("At an end point")
            option = [
                [[from_node, current]],
                [[m.states[from_node], m.states[current]]],
            ]
            results[1].append(option)
            return results

        # check neighbors
        for neigh in m.graph.neighbors(node):
            other = m.adj.mapping[neigh]
            ss = m.states[other]
            # prevent going back
            if other == from_node:
                if verbose:
                    print("found node already in path (cycle)")
                continue
            # check if branch is valid
            if m.rules[s][ss]["weight"] <= 0:
                if verbose:
                    print("negative weight")
                continue
            # construct proposals
            e = [current, other]
            ev = [s, ss]

            # step into branch
            if e not in path and e[::-1] not in path:
                if ev not in vp_path and ev[::-1] not in vp_path:
                    if verbose:
                        print(f"checking {e} at {current} with {other} at path {path}")
                    queue.append(e)
                    # get branch options
                    for option in check_df(
                        queue,
                        n,
                        m,
                        path.copy(),
                        vp_path.copy(),
                        results.copy(),
                        verbose,
                    )[1]:
                        results[1].append(option.copy())
                    print(f"branch results {o}")
                # move to next
                else:
                    continue
            # move to next
            else:
                continue
    # attempt merge
    merge(results, n)
    # TODO self edges are ignored --> add check for negativity
    if from_node != current:
        this_option = [[from_node, current], [m.states[from_node], m.states[current]]]
        for idx, merged in enumerate(results[1]):
            # they cannot be in the already present path
            if (
                this_option[1] not in merged[1]
                and this_option[1][::-1] not in merged[1]
            ):
                merged[0].append(this_option[0])
                merged[1].append(this_option[1])
            if len(merged[1]) == n:
                # remove from option list
                results[1].pop(idx)
                check_doubles(merged[0].copy(), results)
                check_doubles(merged[0].copy(), all_paths)
                if verbose:
                    print(f"adding results {merged[0]} {n} vp = {merged[1]}")

    # check if the solution is correct
    if len(vp_path) == n:
        check_doubles(path.copy(), results)
        check_doubles(path.copy(), all_paths)
        if verbose:
            print("added path", results)
    return results
