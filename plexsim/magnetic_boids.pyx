#distutils: language=c++
import networkx as nx, numpy as np
cimport numpy as np, cython
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, preincrement, postincrement as post
from libc.math cimport exp, fmod, fabs
cdef class MagneticBoids(ValueNetwork):
    def __init__(self,
                 coordinates,
                 velocities,
                 rules = nx.Graph(),
                 graph = nx.Graph(),
                 agentStates = np.arange(0, 1, dtype = np.double),
                 size_t bounded_rational = 1,
                 boid_radius = .1,
                 max_speed = .1,
                 radius = .1,
                 bounds = np.array([0, 20], dtype = np.double),
                 dt = .01,
                 **kwargs):
        # init empty graph with n nodes
        if len(graph) == 0 or len(graph) != len(coordinates):
            graph = nx.empty_graph(len(coordinates))

        super(MagneticBoids, self).__init__(graph = graph,
                                            agentStates = agentStates,
                                            bounded_rational = bounded_rational,
                                            rules = rules,
                                            **kwargs)

        self.coordinates = coordinates
        self.velocities  = velocities
        self._bounds = bounds
        self._radius = radius

        self.dt = dt

        #TODO move this into input
        self._boid_radius = boid_radius
        self._max_speed = max_speed

    cdef void _step(self, node_id_t node) nogil:
        # sample updates
        cdef:
            state_t proposal = self._sample_proposal()
            state_t cur_state = self._states[node]
        # update movement boids
        self._move_boid(node)
        # recompute adjacency boids
        self._update_adjacency(node)
        # stochastic update energy
        cdef double p = self.probability(proposal, node)/self.probability(cur_state, node)
        if self._rng._rand () < p:
            self._newstates[node] = proposal
        return

    cdef void _update_adjacency(self, node_id_t node) nogil:
        cdef:
            double distance
            size_t other
            size_t idx
            Neighbors new_neighbors
            double weight
        # remove the current node from all other nodes
        # compute the distance from this node to all other nodes
        self.adj._adj[node].neighbors.clear()
        for other in range(self.adj._nNodes):
            # empty node from adj
            self.adj._adj[other].neighbors.erase(node)
            # skip self
            if other != node:
                distance = 0
                for idx in range(2):
                    distance += (self._coordinates[other, idx] - self._coordinates[node, idx])**2
                # append if within sight
                if distance < self._radius**2:
                    # add current node back
                    self.adj._adj[node].neighbors[other] = 1/distance
                    self.adj._adj[other].neighbors[node] = 1/distance
        return

    cdef void _move_boid(self, node_id_t node) nogil:
        cdef:
            size_t neighbor
            double weight
            double n = <double>(self.adj._adj[node].neighbors.size())
            double z = 1
            size_t idx
            rule_t rule
            double update
            double energy = 0
            vector[double] coordinate = vector[double](2)
            vector[double] velocity = vector[double](2)

        # rule 1: boids fly to the center of mass to the neighbors
        # rule 2: boids attempt to keep a small distance away from other boids
        # rule 3: boids attempt to match velocity with nearby boids

        if n != 0:
            z = 1/n
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            # unpack neighbor
            neighbor = deref(it).first
            weight = deref(it).second
            # check magnetism (rules)
            rule = self._rules._check_rules(self._states[node],
                                           self._states[neighbor])
            if rule.first:
                update = rule.second.second
            else:
                update = self._hamiltonian(self._states[node],
                                           self._states[neighbor])
            # update positions
            # update = 1
            for idx in range(2):
                # compute alignment
                coordinate[idx] +=  (self._coordinates[neighbor, idx])
                velocity[idx] += update * (self._velocities[neighbor, idx])
            post(it)

        # compute average position
        for idx in range(2):
           coordinate[idx] *= z
           velocity[idx] *= z
        # update velocity
        self._velocities[node, 0] += self._dt * (coordinate[0] - self._coordinates[node, 0])
        self._velocities[node, 1] += self._dt * (coordinate[1] - self._coordinates[node, 1])

        # match velocities
        self._velocities[node, 0] += self._dt * (velocity[0] - self._velocities[node, 0])
        self._velocities[node, 1] += self._dt * (velocity[1] - self._velocities[node, 1])

        for idx in range(2):
            if fabs(self._velocities[node, idx]) > self._max_speed:
                if self._velocities[node,idx] < 0:
                    self._velocities[node, idx] = -self._max_speed
                else:
                    self._velocities[node, idx] = self._max_speed

        # self._velocities[node, 0] = fmod(self._velocities[node, 0], self._max_speed)
        # self._velocities[node, 1] = fmod(self._velocities[node, 1], self._max_speed)

        # move to average position of neighborhood
        self._coordinates[node, 0] += self._velocities[node, 0] * self._dt  #% self._bounds[0]
        self._coordinates[node, 1] += self._velocities[node, 1] * self._dt #% self._bounds[1]
        # check for collision
        self._check_collision(node)
        # check bounds
        self._check_boundary(node)
        return

    cdef void _check_collision(self, node_id_t node) nogil:
        cdef double distance
        cdef node_id_t other
        cdef double weight
        cdef vector[double] velocity = vector[double](2)
        it = self.adj._adj[node].neighbors.begin()

        # cdef double counter = 0
        while it != self.adj._adj[node].neighbors.end():
            other = deref(it).first
            distance = 0
            for idx in range(2):
                distance += (self._coordinates[node, idx] - self._coordinates[other, idx])**2

            if distance < self._boid_radius:
                # velocity[0] += self._coordinates[node, 0] - self._coordinates[other, 0]
                # velocity[1] += self._coordinates[node, 1] - self._coordinates[other, 1]
                if other != node:
                    self._coordinates[node, 0] += self._coordinates[node, 0] - self._coordinates[other, 0]
                    self._coordinates[node, 1] += self._coordinates[node, 1] - self._coordinates[other, 1]
                # counter += 1
            post(it)

        # if counter == 0:
            # counter = 1
        #self._coordinates[node, 0] -= 2 * self._dt * velocity[0] * 1/counter
        #self._coordinates[node, 1] -= 2 * self._dt * velocity[1] * 1/counter
        return

    cdef void _check_boundary(self, node_id_t node) nogil:
        cdef size_t idx
        # check bounds
        for idx in range(len(self._coordinates[node])):
            # inside box
            if self._coordinates[node, idx] <= self._bounds[1] and self._coordinates[node, idx] >= self._bounds[0]:
                return
            # outside lower bound
            if self._coordinates[node,idx] < self._bounds[0]:
                self._coordinates[node, idx]  = self._coordinates[node, idx] + self._bounds[1]
            # outside upper bound
            if self._coordinates[node, idx]  >= self._bounds[1]:
                self._coordinates[node, idx] = fmod(self._coordinates[node, idx], self._bounds[1])
        return


    @property
    def coordinates(self):
        return self._coordinates.base
    @coordinates.setter
    def coordinates(self, value):
        self._coordinates = value
    @property
    def velocities(self):
        return self._velocities.base

    @velocities.setter
    def velocities(self, value):
        self._velocities = value
    @property
    def bounds(self):
        return self._bounds.base
    @property
    def radius(self):
        return self._radius
    @radius.setter
    def radius(self, value):
        self._radius = value
    @property
    def dt(self):
        return self._dt
    @dt.setter
    def dt(self, value):
        self._dt = value
