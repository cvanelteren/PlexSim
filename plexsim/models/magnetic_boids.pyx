#distutils: language=c++
import networkx as nx, numpy as np
cimport numpy as np, cython
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, preincrement, postincrement as post
from libc.math cimport exp, fmod, fabs, sqrt

cdef class MagneticBoids(ValueNetwork):
    """
    Magnetic boids. Combines the ideas from the value network without requirement
    of a social network. The model is inspired by the boids model. Each agent/boid/
    node has a color state. The colors bind together in a network dubbed the "value network".
    In the normal boids simulation, each boid want to fly close to other boids.
    From this, flocking behavior appears. In this implementation the boids attempt to flock
    according the coloring network.

    Parameters
    ----------
    coordinates: np.ndarray, initial position of the boids.

    velocities: np.ndarray, initial velocities of the boids.

    rules: nx.Graph or nx.DiGraph, color networks indicating how colors want to interact

    agentStates: np.ndarray, colors that each boid can take

    bounded_rational, unsigned int, edges to consider for measuring the completion
    of the value network

    boid_radius: unsigned int, radius of the boid.

    max_speed: unsigned int, maximum speed the boids can fly at. Note that negative speeds are compared to this value!

    radius: unsigned int: radius that the boids can see.

    bounds: np.ndarray, bounding box of the area can fly in.

    exploration: float, amount of noise to add to the update position of the boids.

    dt: float, simulation update parameter (extrapolation)

    kwargs: dict, base model values (see base model)
    """
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
                 exploration = np.inf,
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
        self.explore = exploration

        #FIXME: add setters
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
    @property
    def explore(self):
        """
        The explore parameter controls how much noise is added to the
        particle's position
        """
        return self._explore
    @explore.setter
    def explore(self, value):
        self._explore = 1 / value if value != 0 else np.inf

    cdef void _update_adjacency(self, node_id_t node) nogil:
        """
        Adds or removes edges depending on how close the boids are

        Parameters
        ----------
        node: size_t, node to update
        """
        cdef:
            double distance
            size_t other
            size_t idx
            Neighbors new_neighbors
            double weight
            double x1, x2

        # remove the current node from all other nodes
        # compute the distance from this node to all other nodes
        self.adj._adj[node].neighbors.clear()
        for other in range(self.adj._nNodes):
            # empty node from adj
            self.adj._remove_edge(other, node)
            # skip self
            if other != node:
                distance = 0
                for idx in range(2):
                    # distance += (x1 - x2 self._coordinates[node, idx])**2
                    #distance += fmod((self._coordinates[other, idx] - self._coordinates[node, idx]), self._bounds[idx])**2
                    x1 = self._wrap(self._coordinates[node, idx], self._bounds[1])
                    x2 = self._wrap(self._coordinates[other, idx], self._bounds[1])
                    distance += (x1 - x2)**2
                # append if within sight
                distance = sqrt(distance)
                if distance < self._radius:
                    # add current node back
                    self.adj._add_edge(node, other, 1/distance)
        return

    cdef double _wrap(self, double x1, double x2) nogil:
        """
        Wrap around the bounding box the boids can move in
        """
        return fmod(fmod(x1, x2) + x2, x2)

    cdef void _move_boid(self, node_id_t node) nogil:
        """
        Updates boids position and velocity. It performs
        1. Centering, moves boid's towards its flock with a satisfied value network
        2. Separation, ensures boid's position is appropriately spaced from other boids.
        3. Alignment, matches boid's velocity with its flock.

        Parameters
        ----------
        node: size_t, node to update
        """
        cdef:
            size_t neighbor
            double weight
            double n = <double>(self.adj._adj[node].neighbors.size())
            double z = 0
            size_t idx
            rule_t rule
            double update
            double distance_weight
            double energy = 0
            vector[double] coordinate = vector[double](2)
            vector[double] velocity = vector[double](2)

        # rule 1: boids fly to the center of mass to the neighbors
        # rule 2: boids attempt to keep a small distance away from other boids
        # rule 3: boids attempt to match velocity with nearby boids

        # with gil:
        #     print(self._coordinates.base[node])
        #     print(self.adj._adj[node].neighbors.size())

        z = n

        # if n != 0:
            # z = 1/n

        for idx in range(2):
           self._coordinates[node, idx] += self._explore * (self._rng._rand() * 2 - 1) * exp(-z) * self._dt
           self._velocities[node, idx] += self._explore *(self._rng._rand() * 2 - 1) * exp(-z) * self._dt

        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            # unpack neighbor
            neighbor = deref(it).first
            weight = deref(it).second
            # update positions
            update = self._rules._adj[self._states[node]][self._states[neighbor]]
            # update = 1
            distance_weight = 0
            for idx in range(2):
                # compute alignment
                coordinate[idx] +=  update * (self._coordinates[neighbor, idx] - self._coordinates[node, idx])
                velocity[idx]   +=  update * (self._velocities[neighbor, idx]  - self._velocities[node, idx])
            post(it)

        #compute average position
        for idx in range(2):
           # allow random exploration if numer of neighbors is low
           # TODO: perhaps add a float here to scale the exploration
           coordinate[idx] *= z
           velocity[idx] *= z

        # update velocity
        self._velocities[node, 0] += self._dt * coordinate[0]
        self._velocities[node, 1] += self._dt * coordinate[1]

        # match velocities
        self._velocities[node, 0] += self._dt * velocity[0]
        self._velocities[node, 1] += self._dt * velocity[1]

        # correct max speed
        for idx in range(2):
            # self._wrap(self._velocities[node, idx], self._max_speed)
            if fabs(self._velocities[node, idx]) > self._max_speed:
                 if self._velocities[node,idx] < 0:
                     self._velocities[node, idx] = -self._max_speed
                 else:
                     self._velocities[node, idx] = self._max_speed
            # if fabs(self._velocities[node, idx]) < .1:
                # self._velocities[node, idx] = .1

        # move to average position of neighborhood
        self._coordinates[node, 0] += (self._velocities[node, 0]) * self._dt  #% self._bounds[0]
        self._coordinates[node, 1] += (self._velocities[node, 1]) * self._dt #% self._bounds[1]
        # check for collision
        self._check_collision(node)
        # check bounds
        self._check_boundary(node)
        return

    cdef void _check_collision(self, node_id_t node) nogil:
        """
        Checks collision of the boid. Ensures the coordinates remain in the
        bounding box

        Parameters
        ----------
        node: size_t, boid to update
        """
        cdef double distance
        cdef node_id_t other
        cdef size_t idx
        cdef double weight
        cdef double x1, x2
        cdef vector[double] velocity = vector[double](2)
        it = self.adj._adj[node].neighbors.begin()

        # cdef double counter = 0
        while it != self.adj._adj[node].neighbors.end():
            other = deref(it).first
            distance = 0
            for idx in range(2):
                x1 = self._wrap(self._coordinates[node, idx], self._bounds[1])
                x2 = self._wrap(self._coordinates[other, idx], self._bounds[1])
                distance += (x1 - x2)**2
            distance = sqrt(distance)
            if distance <= self._boid_radius:
                for idx in range(2):
                    self._coordinates[node, idx] -= self._velocities[node, idx] * self._dt
                    # self._velocities[node, idx]  += .1
            post(it)
        return

    cdef void _check_boundary(self, node_id_t node) nogil:
        cdef size_t idx
        # check bounds
        for idx in range(len(self._coordinates[node])):
            # # inside box
            # if self._coordinates[node, idx] <= self._bounds[1]:
            #     if self._coordinates[node, idx] >= self._bounds[0]:
            #         return
            # # outside lower bound
            if self._coordinates[node,idx] <= self._bounds[0]:
                self._coordinates[node, idx] = self._wrap(self._coordinates[node, idx], self._bounds[1])
            #     self._coordinates[node, idx]  = self._bounds[1] + self._coordinates[node, idx]
            # # outside upper bound
            if self._coordinates[node, idx]  >= self._bounds[1]:
                self._coordinates[node, idx] = self._wrap(self._coordinates[node, idx], self._bounds[1])
                # self._coordinates[node, idx] = fmod(self._coordinates[node, idx], self._bounds[1])
        return


    @property
    def boid_radius(self):
        return self._boid_radius

    @boid_radius.setter
    def boid_radius(self, value):
        self._boid_radius = value
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
