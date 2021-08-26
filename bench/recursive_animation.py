import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy
from plexsim.utils.rules import create_rule_full
warnings.simplefilter("ignore"); plt.style.use("fivethirtyeight spooky".split())
from imi.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.annealing import annealing
import time

def check_doubles(path, results):
    add = True
    if path:
        for r in results[0]:
            if all([i in r for i in path]) or all([i[::-1] in r for i in path]):
                add = False
                break
        if add and  path:
            results[0].append(path.copy())

def merge(results, n):
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
                J = True
                a = vpi
                b = vpj
                if len(vpi) > len(vpj):
                    a, b = b,a
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

def check_endpoint(s, vp_path) -> bool:
    # update paths
    fail = True
    for ss in  m.rules.neighbors(s):
        if m.rules[s][ss]['weight'] > 0:
            if [s, ss] not in vp_path:
                fail = False
    # print(f"Failing {fail} {s} {list(m.rules.neighbors(s))} {vp_path}")
    return fail

def check_df(queue, n, m, path = [], vp_path = [], results = [], all_paths = [[], []],
             verbose = True):
    # print("Returning")
    # for plotting ignore
    if queue:
        # get current node
        from_node, current = queue.pop()
        node = m.adj.rmapping[current]
        results[1] = []
        s = m.states[current]
        # check only if difference
        if current != from_node:
            path.append([current, from_node])
            vp_path.append([m.states[current], m.states[from_node]])
        if path:
            all_paths[0].append(path.copy())

        # logging
        if verbose:
            print(f"At {current}")
            print(f"Path : {path}")
            print(f"Vp_path : {vp_path}")
            print(f"Options: {results[1]}")
            print(f"Results: {results[0]}")

        
        # check if no options left in rule graph
        if check_endpoint(s, vp_path):
            if verbose:
                print("At an end point")
            option = [[[from_node, current]], [[m.states[from_node], m.states[current]]]]
            results[1].append(option)
            return results

        # check neighbors
        for neigh in m.graph.neighbors(node):
            other = m.adj.mapping[neigh]
            ss = m.states[other]
            # prevent going back
            if other == from_node:
                if verbose: print("found node already in path (cycle)")
                continue
            # check if branch is valid
            if m.rules[s][ss]['weight'] <= 0: 
                if verbose: print('negative weight')
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
                    o = check_df(queue, n, m, path.copy(), vp_path.copy(), results.copy(), all_paths, verbose) 
                    for r in o[1]:
                        results[1].append(r.copy())
                    print(f"branch results {o}")
                # move to next
                else:
                    continue
            # move to next
            else:
                continue
    # attempt merge
    merge(results, n)  
    # TODO self edges are ignore
    if from_node != current:
        this_option = [[from_node, current],
                    [m.states[from_node], m.states[current]]]
        for idx, merged in enumerate(results[1]):
            if verbose:
                print(f"merging {merged}")
            # they cannot be in the already present path
            if this_option[1] not in merged[1] and this_option[1][::-1] not in merged[1]: 
                print(f"This option {this_option} with merge {merged}")
                print(this_option[1] in merged[1])
                print(this_option[1][::-1] in merged[1])
                merged[0].append(this_option[0])
                merged[1].append(this_option[1])
            if len(merged[1]) == n:
                # remove from option list
                results[1].pop(idx)
                check_doubles(merged[0].copy(), results)
                check_doubles(merged[0].copy(), all_paths)
                print(f'adding results {merged[0]} {n} vp = {merged[1]}')
    # print(f"path {path} {vp_path}")
    # terminate if number of edges is reached
    if len(vp_path) == n:
        check_doubles(path.copy(), results)
        check_doubles(path.copy(), all_paths)
        if verbose: print('added path', results)
    return results

# setup graph
r = nx.Graph()
r.add_edge(0, 1)
r.add_edge(1, 2)
r.add_edge(2, 3)
r.add_edge(0, 3)


# r.add_edge(1, 2)
# r.add_edge(1, 3)
# r.add_edge(3, 5)

r = create_rule_full(r, self_weight=-1)

# edge target
target = 0
for k, v in nx.get_edge_attributes(r, 'weight').items():
    if v > 0:
        target += 1
print(f"TARGET {target}")

g = nx.krackhardt_kite_graph()
#g = nx.cycle_graph(3)
s = np.arange(len(r))

m = models.ValueNetwork(g, r, agentStates = s, bounded_rational = 3)
# anneal the state
print("annealing")
m.states = annealing(m, theta = 1e-5, rate = 1e-4, reset = True)


#m.states = [1, 2, 0, 1]
print("assignment",  m.states)
# setup all paths
all_paths = [[], []]
# get the results
start = [0]
start = [(0, 0)]
results, options = check_df(start, target, m,
                            path=[], vp_path=[], results=[[], []],
                            all_paths=all_paths, verbose = True)
print(len(results), len(all_paths[0]))
print("ALL_PATHS", len(all_paths[0]))
print("RESULTS", results)
print(len(results))
print('done')
print(all_paths)
from plexsim.utils.visualisation import GraphAnimation
tmp = GraphAnimation(g, m.states.reshape(-1, 1).T, len(r))
fig, ax = plt.subplots()
tmp.setup(ax = ax, rules = r, layout = nx.kamada_kawai_layout(g))
fig.show()
fig.savefig("/home/casper/test.png")


# init figure
cmap = cmr.pride
p_colors = np.linspace(0, 1, len(results), 0)
c_   = np.linspace(0, 1, s.size, 0)
c = cmap(c_[m.states.astype(int)])
fig, ax = plt.subplots(constrained_layout = 1, figsize = (10, 8))
pos = nx.kamada_kawai_layout(g)
nx.draw(g, pos,  ax = ax, node_color = c)
nx.draw_networkx_labels(g, pos, ax = ax,
                        font_color = 'white')
fig.show()

R = np.arange(len(results))
layout = np.zeros((len(results), 2), dtype = object)
layout[:] = -1
layout[:, -1] = R

fig = plt.figure(constrained_layout = 1, figsize = (10, 8))
axes = fig.subplot_mosaic(layout.T)
for axi in axes.values():
    axi.axis('off')
ax = axes[-1]

pos = nx.kamada_kawai_layout(g)
nx.draw(g, pos,  ax = ax, node_color = c)
nx.draw_networkx_labels(g, pos, ax = ax,
                        font_color = 'white')
inax = ax.inset_axes((0, .2, .3, .3))
inax.axis('equal')
inax.set_title("Target")
C = np.linspace(0, 1, len(r), 0)
C = cmap(C)
sg = [k for k, v in nx.get_edge_attributes(r, 'weight').items() if  v > 0]
sg = nx.from_edgelist(sg)

pos = nx.kamada_kawai_layout(sg)
nx.draw(sg, pos,  ax = inax, node_color = C) 
inax.margins(.5)


completed_colors = {} 
completed_c = 0
ignore = set()
for idx, r in enumerate(results):
    print(r)
def update(idx):
    cpath = all_paths[0][idx]
    ecs = []
    edges = ax.collections[1] 
    # reset all edges to black
    ECS = {k: 'lightgray' for k in g.edges()} 
    
    for e in cpath:
        e = tuple(e)
        if e in ECS:
            ECS[e] = 'red'
        else:
            ECS[e[::-1]] = 'red'
    edges.set_colors(ECS.values())  
    add = False
    if len(cpath) == target:
        if cpath in results:
            add = True
        
    # add only new paths in results
    if add:
        # make mapping and add color
        tmp = tuple((tuple(i) for i in cpath))
        completed_colors[tmp] = completed_colors.get(tmp, len(completed_colors))  
        cidx = completed_colors[tmp]
        # add new color
        if cidx not in ignore:
            ignore.add(cidx)
            axi = axes.get(cidx)
            jdx = []
            for e in cpath:
                for ei in e:
                    if ei not in jdx:
                        jdx.append(ei)
            sg = nx.from_edgelist(cpath)
            pos = nx.kamada_kawai_layout(sg)
            nx.draw(sg, pos, ax = axi, node_size = 80,
                    node_color = c[jdx])
            nx.draw_networkx_labels(sg, pos, ax = axi,
                                    font_color = 'white')
            axi.axis('equal')
            axi.margins(.1)
    ax.set_title(f"T = {idx}")
    # return ax.collections
        
ax.axis('equal')            
from matplotlib import animation
N = int(len(all_paths[0]) * 4)
print(f"using {N} frames")
#N = 4

f = np.linspace(0, len(all_paths[0]), N, 0).astype(int)
ani = animation.FuncAnimation(fig, update, frames = f)
ani.save("/home/casper/crawling.mp4",
         savefig_kwargs = dict(facecolor = 'gray'),
         )
fig.show()
