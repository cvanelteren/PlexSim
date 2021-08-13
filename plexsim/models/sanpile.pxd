from plexsim.models.base cimport Model
from cython.operator cimport dereference as deref, postincrement as post
cdef class Sandpile(Model):
    cdef void _step(self, node_id_t):
        """
        Add a grain and recursively check for avalanches
        """
        cdef size_t counter = 0
        cdef vector[node_id_t] queue
        self._states[node] += 1
        if self._states[node] > self._threshold:
            queue.push_back(node)
            counter = self._check_avalanches(queue, counter)

    cdef size_t _check_avalanche(vector[node_id_t] queue, size_t counter) nogil:
        """
        Pop queue
        Add to its neighbors one grain
        Check their threshold
        """

        cdef node_id_t node, neighbor
        if queue.size():
            counter += 1
            node = queue.back()
            queue.pop_back()

            it = self.adj._adj[node].neighbors.begin()
            while it < self.adj._adj[node].neighbors.end():
                neighbor = deref(it).first
                self._states[neighbor] =+ 1
                if self._states[neighbor] > self._threshold:
                    queue.push_back(neighbor)
                post(it)
            self._check_avalanche(queue, counter)
        return counter
