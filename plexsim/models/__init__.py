# base model; shouldn't be run

# energy modesl
from plexsim.models.potts import Potts
from plexsim.models.ising import Ising
from plexsim.models.bornholdt import Bornholdt
from plexsim.models.value_network import ValueNetwork
from plexsim.models.pottsis import Pottsis
from plexsim.models.prisoner import Prisoner
from plexsim.models.magnetic_boids import MagneticBoids

# voter models
from plexsim.models.ab import AB
from plexsim.models.bonabeau import Bonabeau

# logistic map
from plexsim.models.logmap import Logmap

# Elementary celullary automata
from plexsim.models.rbn import RBN
from plexsim.models.cca import CCA
from plexsim.models.game_of_life import Conway

# Percolation
from plexsim.models.percolation import Percolation

# misc
from plexsim.models.cyclic import Cycledelic, CycledelicAgent

# disease
from plexsim.models.sirs import SIRS
