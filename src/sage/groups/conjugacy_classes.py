﻿# -*- coding: utf-8 -*-
r"""
Conjugacy classes of groups

This module implements a wrapper of GAP's ``ConjugacyClass`` function.

There are two main classes, :class:`ConjugacyClass` and
:class:`ConjugacyClassGAP`. All generic methods should go into
:class:`ConjugacyClass`, whereas :class:`ConjugacyClassGAP` should only
contain wrappers for GAP functions. :class:`ConjugacyClass` contains some
fallback methods in case some group cannot be defined as a GAP object.

.. TODO::

    - Implement a non-naive fallback method for computing all the elements of
      the conjugacy class when the group is not defined in GAP, as the one in
      Butler's paper.
    - Define a sage method for gap matrices so that groups of matrices can
      use the quicker GAP algorithm rather than the naive one.

EXAMPLES:

Conjugacy classes for groups of permutations::

    sage: G = SymmetricGroup(4)
    sage: g = G((1,2,3,4))
    sage: G.conjugacy_class(g)
    Conjugacy class of (1,2,3,4) in Symmetric group of order 4! as a permutation group

Conjugacy classes for groups of matrices::

    sage: F = GF(5)
    sage: gens = [matrix(F,2,[1,2, -1, 1]), matrix(F,2, [1,1, 0,1])]
    sage: H = MatrixGroup(gens)
    sage: h = H(matrix(F,2,[1,2, -1, 1]))
    sage: H.conjugacy_class(h)
    Conjugacy class of [1 2]
    [4 1] in Matrix group over Finite Field of size 5 with 2 generators:
    [[[1, 2], [4, 1]], [[1, 1], [0, 1]]]

TESTS::

    sage: G = SymmetricGroup(3)
    sage: g = G((1,2,3))
    sage: C = ConjugacyClass(G,g)
    sage: TestSuite(C).run()
"""

#****************************************************************************
#       Copyright (C) 2011 Javier López Peña <jlopez@ende.cc>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#                  http://www.gnu.org/licenses/
#****************************************************************************

from sage.structure.parent import Parent
from sage.misc.cachefunc import cached_method
from sage.categories.enumerated_sets import EnumeratedSets
from sage.categories.finite_enumerated_sets import FiniteEnumeratedSets

class ConjugacyClass(Parent):
    r"""
    Generic conjugacy classes for elements in a group.

    This is the default fall-back implementation to be used whenever
    GAP cannot handle the group.

    EXAMPLES::

        sage: G = SymmetricGroup(4)
        sage: g = G((1,2,3,4))
        sage: ConjugacyClass(G,g)
        Conjugacy class of (1,2,3,4) in Symmetric group of order 4! as a
        permutation group
    """
    def __init__(self, group, element):
        r"""
        Generic conjugacy classes for elements in a group.
        This is the default fall-back implementation to be used whenever
        GAP cannot handle the group.

        EXAMPLES::

            sage: G = SymmetricGroup(4)
            sage: g = G((1,2,3,4))
            sage: ConjugacyClass(G,g)
            Conjugacy class of (1,2,3,4) in Symmetric group of order 4! as a
            permutation group
            sage: TestSuite(G).run()
        """
        self._parent = group
        self._representative = element
        if group.is_finite():
            Parent.__init__(self, category = FiniteEnumeratedSets())
        else: # If the group is not finite, then we do not know if we are finite or not
            Parent.__init__(self, category = EnumeratedSets())

    def __repr__(self):
        r"""
        EXAMPLES::

            sage: G = SymmetricGroup(4)
            sage: g = G((1,2,3,4))
            sage: C = ConjugacyClass(G,g)
            sage: C
            Conjugacy class of (1,2,3,4) in Symmetric group of order 4! as a
            permutation group

        """
        return "Conjugacy class of %s in %s"%(self._representative,self._parent)

    def __cmp__(self, other):
        r"""
        Comparison of conjugacy classes is done by comparing the
        underlying sets.

        EXAMPLES::

            sage: F = GF(5)
            sage: gens = [matrix(F,2,[1,2, -1, 1]), matrix(F,2, [1,1, 0,1])]
            sage: H = MatrixGroup(gens)
            sage: h = H(matrix(F,2,[1,2, -1, 1]))
            sage: h2 = H(matrix(F,2,[1,1, 0, 1]))
            sage: g = h2*h*h2^(-1)
            sage: C = ConjugacyClass(H,h)
            sage: D = ConjugacyClass(H,g)
            sage: C == D
            True
        """
        c = cmp(type(self),type(other))
        if c:
             return c
        return cmp(self.set(), other.set())

    def __contains__(self, element):
        r"""
        Checks if ``element`` belongs to the conjugacy class ``self``.

        EXAMPLES::

            sage: G = SymmetricGroup(4)
            sage: g = G((1,2,3,4))
            sage: C = ConjugacyClass(G,g)
            sage: g in C
            True
        """
        return element in self.set()

    @cached_method
    def set(self):
        r"""
        Naive algorithm to give a set with all the elements of the conjugacy
        class.

        .. TODO::

            Implement a non-naive algorithm, cf. for instance
            G. Butler: "An Inductive Schema for Computing Conjugacy Classes
            in Permutation Groups", Math. of Comp. Vol. 62, No. 205 (1994)

        EXAMPLES:

        Groups of permutations::

            sage: G = SymmetricGroup(3)
            sage: g = G((1,2))
            sage: C = ConjugacyClass(G,g)
            sage: S = [(2,3), (1,2), (1,3)]
            sage: C.set() == Set(G(x) for x in S)
            True

        Groups of matrices over finite fields::

            sage: F = GF(5)
            sage: gens = [matrix(F,2,[1,2, -1, 1]), matrix(F,2, [1,1, 0,1])]
            sage: H = MatrixGroup(gens)
            sage: h = H(matrix(F,2,[1,2, -1, 1]))
            sage: C = ConjugacyClass(H,h)
            sage: S = [[[3, 2], [2, 4]], [[0, 1], [2, 2]], [[3, 4], [1, 4]],\
                  [[0, 3], [4, 2]], [[1, 2], [4, 1]], [[2, 1], [2, 0]],\
                  [[4, 1], [4, 3]], [[4, 4], [1, 3]], [[2, 4], [3, 0]],\
                  [[1, 4], [2, 1]], [[3, 3], [3, 4]], [[2, 3], [4, 0]],\
                  [[0, 2], [1, 2]], [[1, 3], [1, 1]], [[4, 3], [3, 3]],\
                  [[4, 2], [2, 3]], [[0, 4], [3, 2]], [[1, 1], [3, 1]],\
                  [[2, 2], [1, 0]], [[3, 1], [4, 4]]]
            sage: C.set() == Set(H(x) for x in S)
            True
        """
        from sage.sets.set import Set
        from sage.combinat.backtrack import TransitiveIdeal
        if self._parent.is_finite():
            g = self._representative
            G = self._parent
            gens = G.gens()
            return Set(x for x in TransitiveIdeal(lambda y: [c*y*c**-1 for c in gens], [g]))
        else:
            raise NotImplementedError("Listing the elements of conjugacy classes is not implemented for infinite groups!")

    @cached_method
    def list(self):
        r"""
        Return a list with all the elements of ``self``.

        EXAMPLES:

        Groups of permutations::

            sage: G = SymmetricGroup(3)
            sage: g = G((1,2,3))
            sage: c = ConjugacyClass(G,g)
            sage: L = c.list()
            sage: Set(L) == Set([G((1,3,2)), G((1,2,3))])
            True
        """
        return list(self.set())

    def is_real(self):
        """
        Checks if ``self`` is real (closed for inverses).

        EXAMPLES::

            sage: G = SymmetricGroup(4)
            sage: g = G((1,2,3,4))
            sage: c = ConjugacyClass(G,g)
            sage: c.is_real()
            True

        """
        return self._representative**(-1) in self

    def is_rational(self):
        """
        Checks if ``self`` is rational (closed for powers).

        EXAMPLES::

            sage: G = SymmetricGroup(4)
            sage: g = G((1,2,3,4))
            sage: c = ConjugacyClass(G,g)
            sage: c.is_rational()
            False
        """
        g = self._representative
        return all(g**k in self.set() for k in range(1,g.order()))

    def representative(self):
        """
        Return a representative of ``self``.

        EXAMPLES::

            sage: G = SymmetricGroup(3)
            sage: g = G((1,2,3))
            sage: C = ConjugacyClass(G,g)
            sage: C.representative()
            (1,2,3)
        """
        return self._representative


class ConjugacyClassGAP(ConjugacyClass):
    r"""
    Class for a conjugacy class for groups defined over GAP.
    Intended for wrapping GAP methods on conjugacy classes.

    INPUT:

    - ``group`` -- the group in which the conjugacy class is taken

    - ``element`` -- the element generating the conjugacy class

    EXAMPLES::

        sage: G = SymmetricGroup(4)
        sage: g = G((1,2,3,4))
        sage: ConjugacyClassGAP(G,g)
        Conjugacy class of (1,2,3,4) in Symmetric group of order 4! as a
        permutation group
    """

    def __init__(self, group, element):
        r"""
        Constructor for the class.

        EXAMPLES:

        Conjugacy classes for groups of permutations::

            sage: G = SymmetricGroup(4)
            sage: g = G((1,2,3,4))
            sage: ConjugacyClassGAP(G,g)
            Conjugacy class of (1,2,3,4) in Symmetric group of order 4! as a permutation group

        Conjugacy classes for groups of matrices::

            sage: F = GF(5)
            sage: gens = [matrix(F,2,[1,2, -1, 1]), matrix(F,2, [1,1, 0,1])]
            sage: H = MatrixGroup(gens)
            sage: h = H(matrix(F,2,[1,2, -1, 1]))
            sage: ConjugacyClassGAP(H,h)
            Conjugacy class of [1 2]
            [4 1] in Matrix group over Finite Field of size 5 with 2 generators:
            [[[1, 2], [4, 1]], [[1, 1], [0, 1]]]

        """
        try:
            self._gap_group = group._gap_()
            self._gap_representative = element._gap_()
            self._gap_conjugacy_class = self._gap_group.ConjugacyClass(self._gap_representative)
            ConjugacyClass.__init__(self, group, element)
        except TypeError:
            raise TypeError("The group %s cannot be defined as a GAP group"%group)

    def _gap_(self):
        r"""
        Return the gap object corresponding to ``self``.

        EXAMPLES::

            sage: G = SymmetricGroup(3)
            sage: g = G((1,2,3))
            sage: C = ConjugacyClassGAP(G,g)
            sage: C._gap_()
            ConjugacyClass( SymmetricGroup( [ 1 .. 3 ] ), (1,2,3) )
        """
        return self._gap_conjugacy_class

    @cached_method
    def set(self):
        r"""
        Return a Sage ``Set`` with all the elements of the conjugacy class.

        By default attempts to use GAP construction of the conjugacy class.
        If GAP method is not implemented for the given group, and the group
        is finite, falls back to a naive algorithm.

        .. WARNING::

            The naive algorithm can be really slow and memory intensive.

        EXAMPLES:

        Groups of permutations::

            sage: G = SymmetricGroup(4)
            sage: g = G((1,2,3,4))
            sage: C = ConjugacyClassGAP(G,g)
            sage: S = [(1,3,2,4), (1,4,3,2), (1,3,4,2), (1,2,3,4), (1,4,2,3), (1,2,4,3)]
            sage: C.set() == Set(G(x) for x in S)
            True

        """
        from sage.sets.set import Set
        try:
            cc = self._gap_conjugacy_class.AsList().sage()
            return Set([self._parent(x) for x in cc])
        except NotImplementedError:    # If GAP doesn't work, fall back to naive method
            return ConjugacyClass.set.f(self) # Need the f because the base-class mehod is also cached

