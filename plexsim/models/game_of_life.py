from plexsim.models.types cimport *
from plexsim.models.base cimport *


class Conway(Model):
    def __init__(self, graph):
        super().__init__(self, graph = graph)
