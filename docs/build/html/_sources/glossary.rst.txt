    :Author: Casper van Elteren



Background of models
--------------------

Under construction |:construction:|.

Ising model
~~~~~~~~~~~

Named  after  Ernst   Ising,  the  Ising  model  is  a   mathematical  model  of
ferromagnetism.  It consists  of  a  set of  binary  distributed variables  that
follows the Gibbs  distribution. Each variable updates  through nearest neighbor
interactions where for ferromagnetic systems the lowest energy state is achieved
by aligning the spin state with its neighbors.

One of the major properties of the Ising model is the phase transition in two or
more dimensions, i.e.  as a function of noise (temperature)  the model goes from
an ordered phase, to an unordered phase.

It has bee shown  that the Ising model falls within  the same universality class
as  (directed) diffusion,  and it  has been  extended it  many different  fields
including studying neural behavior, voter dynamics and so on.

Potts model
~~~~~~~~~~~

The q-Potts model generalizes the Ising model.  In the Potts model the spins are
not binary but can take on arbitrary spin directions i.e.



.. math::

    \theta = \frac{q_i 2 \pi}{q}

:math:`q_i \in n = \{0, \dots, q -  1\}`. In the limit :math:`q \rightarrow \infty` this model
reduces to the  XY model. One particular interesting extensions  is the cellular
Potts  model  used   to  model  static  and  kinetic   phenomena  in  biological
morphogenesis.

Bornholdt model
~~~~~~~~~~~~~~~

Is an  extensions of the  traditional Ising  model used for  modeling financial
systems. It adds a  global cost term such that each  variable “feels” the effect
of the entire  system. This causes “shocks”  in the system similar  to an abrupt
financial crisis. Each  variable can be given a strategy  that either aligns, or
skews it states  according to this general magnetization. This  causes a dynamic
between traders (variables) that either want to  be apart of the minority or the
majority state.

AB voter model
~~~~~~~~~~~~~~

todo

SIRS
~~~~

Susceptible Infected Recovered (Susceptible) or SIRS model inspired by Youssef &
Scolio (2011) The article describes an individual approach to SIR modeling which
canonically uses a mean-field  approximation. In mean-field approximations nodes
are  assumed to  have  ’homogeneous mixing’,  i.e.  a node  is  able to  receive
information  from the  entire network.  The individual  approach emphasizes  the
importance of local connectivity motifs in spreading dynamics of any process.

Cycledelic
~~~~~~~~~~

A  model  for studying  species  dynamics.  It is  based  on
Reichenbach et al. 2007.The model was designed to understand
the  co-existance  of  interacting species  in  a  spatially
extended ecosystem.  Each vertex point represents  the locus
of  three   species.  The  color  (red,   green,  blue)  are
proportional to  the density  of the  three species  at each
pixel (vertex point).

The model produces a wide  range of different patterns based
on three input parameters

- Diffusion (:math:`D`): mobility of species.

- Predation (:math:`P`): competition  between the tree different
  species.

- Competition (:math:`C`): Competition among different specifies.

Each  vertex  in  the  system :math:`\sigma_i`  :math:`\in`  :math:`\sigma  :=\{
\sigma_0, \dots,  \sigma_n\}` contains a  vector with the
density  of the  three “species”,  i.e. rock (:math:`r`),  paper
(:math:`g`),  or  scissor  (:math:`b`). The  concentration  of  each
specie at vertex :math:`i` is updated according to



.. math::

    \frac{d \sigma_i}{dt} = \scriptstyle \begin{cases}
      \frac{dr_i}{dt}& = ((\underbrace{P  (g_i - b_i)  + r_i}_{\textrm{predation}} - \underbrace{C  (g_i + b_i) - r_i^2}_{\textrm{Competition}})r_i - \underbrace{D(\sum_{<i,j>} r_j r_i)}_{\textrm{mobility}}) \delta t \\\\\\
      \frac{dg_i}{dt}& = ((P  (b_i - r_i)  + g_i - C  (r_i + b_i) - g_i^2)g_i - D(\sum_{<i,j>} g_j g_i)) \delta t \\\\\\
      \frac{db_i}{dt}& = ((P  (r_i - g_i)  + b_i - C  (r_i + g_i) - b_i^2)b_i - D(\sum_{<i,j>} b_j b_i)) \delta t, \end{cases}

where :math:`<i,j>` indicates the nearest neighbors of variable :math:`i`.
