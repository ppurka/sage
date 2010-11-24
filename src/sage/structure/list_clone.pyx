"""
Elements, Array and Lists With Clone Protocol

This module defines several class which are subclasses of
:class:`Element<sage.structure.element.Element>` and which roughly implement
the "prototype" design pattern (see [Pro]_, [GOF]_). Those classes are
intended to be used to model *mathematical* objects, which are by essence
immutable. However, in many occasions, one wants to construct the
data-structure encoding of a new mathematical object by small modifications of
the data structure encoding some already built object. For the resulting
data-structure to correctly encode the mathematical object, some structural
invariants must hold. One problem is that, in many cases, during the
modification process, there is no possibility but to break the invariants.

For example, in a list modeling a permutation of `\{1,\dots,n\}`, the integers
must be distinct. A very common operation is to take a permutation to make a
copy with some small modifications, like exchanging two consecutive values in
the list or cycling some values. Though the result is clearly a permutations
there's no way to avoid breaking the permutations invariants at some point
during the modifications.

The main purpose of this module is two define the class
:class:`ClonableElement` and its subclasses:

- :class:`ClonableArray` for arrays (lists of fixed length) of objects;
- :class:`ClonableList` for (resizable) lists of objects;
- :class:`ClonableIntArray` for arrays of int.

The following parents demonstrate how to use them:

- ``IncreasingArrays()`` (see :class:`IncreasingArray` and the parent class
  :class:`IncreasingArrays`)
- ``IncreasingLists()`` (see :class:`IncreasingList` and the parent class
  :class:`IncreasingLists`)
- ``IncreasingIntArrays()`` (see :class:`IncreasingIntArray` and the parent class
  :class:`IncreasingIntArrays`)

EXAMPLES:

We now demonstrate how :class:`IncreasingArray` works, creating an instance
``el`` through its parent ``IncreasingArrays()``::

    sage: from sage.structure.list_clone import IncreasingArrays
    sage: el = IncreasingArrays()([1, 4 ,8]); el
    [1, 4, 8]

If one tries to create this way a list which in not increasing, an error is
raised::

    sage: IncreasingArrays()([5, 4 ,8])
    Traceback (most recent call last):
    ...
    AssertionError: array is not increasing

Once created modifying ``el`` is forbidden::

    sage: el[1] = 3
    Traceback (most recent call last):
    ...
    ValueError: object is immutable; please change a copy instead.

However, you can modify a temporarily mutable clone::

    sage: with el.clone() as elc:
    ...       elc[1] = 3
    sage: [el, elc]
    [[1, 4, 8], [1, 3, 8]]

We check that the original and the modified copy now are in a proper immutable
state::

    sage: el.is_immutable(), elc.is_immutable()
    (True, True)
    sage: elc[1] = 5
    Traceback (most recent call last):
    ...
    ValueError: object is immutable; please change a copy instead.

You can break the property that the lists is increasing during the
modification::

    sage: with el.clone() as el2:
    ...      el2[1] = 12
    ...      print el2
    ...      el2[2] = 25
    [1, 12, 8]
    sage: el2
    [1, 12, 25]

But it must be restored at the end of the ``with`` block, otherwise an error
is raised::

    sage: with el2.clone() as el3:
    ...      el3[1] = 100
    Traceback (most recent call last):
    ...
    AssertionError: array is not increasing

Finally, let us mention that same feature is achievable by hands::

    sage: el4 = copy(el2)
    sage: el4[1] = 10
    sage: el4.set_immutable()
    sage: el4.check()

REFERENCES:

    .. [Pro] Prototype pattern
       http://en.wikipedia.org/wiki/Prototype_pattern

    .. [GOF] Design Patterns: Elements of Reusable Object-Oriented
       Software. E. Gamma; R. Helm; R. Johnson; J. Vlissides (1994).
       Addison-Wesley. ISBN 0-201-63361-2.

AUTHORS:

- Florent Hivert (2010-03): initial revision
"""
#*****************************************************************************
#  Copyright (C) 2009-2010 Florent Hivert <Florent.Hivert@univ-rouen.fr>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#                  http://www.gnu.org/licenses/
#*****************************************************************************


include "../ext/stdsage.pxi"

import sage
from sage.structure.element cimport Element
from sage.structure.element import Element
from sage.structure.parent cimport Parent

############################################################################
###                         Basic clone elements                         ###
############################################################################
cdef class ClonableElement(Element):
    """
    Abstract class for elements with clone protocol

    This class is a subclasse of
    :class:`Element<sage.structure.element.Element>` and implement the
    "prototype" design pattern (see [Pro]_, [GOF]_). The role of this class
    is:

    - to manage copy and mutability and hashing of elements
    - to ensure that at the end of a piece of code an object is restored in a
      meaningful mathematical state.

    A class ``C`` inheriting from :class:`ClonableElement` must implement
    the following two methods

    - ``obj.__copy__()`` -- returns a fresh copy of obj
    - ``obj.check()`` -- returns nothing, raise an exception if ``obj``
      doesn't satisfies the data structure invariants

    and ensure to call ``obj._require_mutable()`` at the beginning of any
    modifying method.

    Additionally, one can also implement

    - ``obj._hash_()`` -- return the hash value of ``obj``.

    Then, given an instance ``obj`` of ``C``, the following sequences of
    instructions ensures that the invariants of ``new_obj`` are properly
    restored at the end::

       with obj.clone() as new_obj:
           ...
           # lot of invariant breaking modifications on new_obj
           ...
       # invariants are ensured to be fulfilled

    The following equivalent sequence of instructions can be used if speed is
    needed, in particular in Cython code::

       new_obj = obj.__copy__()
       ...
       # lot of invariant breaking modifications on new_obj
       ...
       new_obj.set_immutable()
       new_obj.check()
       # invariants are ensured to be fulfilled

    Finally, is the class implement the ``_hash_`` method then
    :class:`ClonableElement` ensure that hash value is only computed on immutable
    object and cache it so that it is only computed once.

    .. warning:: for the hashing mechanism to work correctly, the hash value
       cannot be 0.

    EXAMPLES:

    The following code shows a minimal example of usage of
    :class:`ClonableElement`. We implement a class or pairs `(x,y)`
    such that `x < y`::

        sage: class IntPair(ClonableElement):
        ...       def __init__(self, parent, x, y):
        ...           ClonableElement.__init__(self, parent=parent)
        ...           self._x = x
        ...           self._y = y
        ...           self.set_immutable()
        ...           self.check()
        ...       def _repr_(self):
        ...           return "(x=%s, y=%s)"%(self._x, self._y)
        ...       def check(self):
        ...           assert self._x < self._y, "Bad ordered pair"
        ...       def get_x(self): return self._x
        ...       def get_y(self): return self._y
        ...       def set_x(self, v): self._require_mutable(); self._x = v
        ...       def set_y(self, v): self._require_mutable(); self._y = v

    .. note:: we don't need to define ``__copy__`` since it is properly
       inherited from :class:`Element<sage.structure.element.Element>`.

    We now demonstrate the behavior. Let's create an ``IntPair``::

        sage: myParent = Parent()
        sage: el = IntPair(myParent, 1, 3); el
        (x=1, y=3)
        sage: el.get_x()
        1

    Modifying it is forbidden::

        sage: el.set_x(4)
        Traceback (most recent call last):
        ...
        ValueError: object is immutable; please change a copy instead.

    However, you can modify a mutable copy::

        sage: with el.clone() as el1:
        ...       el1.set_x(2)
        sage: [el, el1]
        [(x=1, y=3), (x=2, y=3)]

    We check that the original and the modified copy are in a proper immutable
    state::

        sage: el.is_immutable(), el1.is_immutable()
        (True, True)
        sage: el1.set_x(4)
        Traceback (most recent call last):
        ...
        ValueError: object is immutable; please change a copy instead.

    A modification which doesn't restore the invariant `x < y` at the end is
    illegal and raise an exception::

        sage: with el.clone() as el2:
        ...       el2.set_x(5)
        Traceback (most recent call last):
        ...
        AssertionError: Bad ordered pair
    """
    def __cinit__(self):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3]) # indirect doctest
            sage: el.is_immutable()
            True
        """
        self._needs_check = True
        self._is_immutable = False
        self._hash = 0

    cpdef bint _require_mutable(self):
        """
        Check that ``self`` is mutable.

        Raise a ``ValueError`` if ``self`` is immutable.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el._require_mutable()
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
        """
        if self._is_immutable:
            raise ValueError, "object is immutable; please change a copy instead."

    cpdef inline bint is_mutable(self):
        """
        Returns ``True`` if ``self`` is mutable (can be changed) and ``False``
        if it is not.

        To make this object immutable use ``self.set_immutable()``.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el.is_mutable()
            False
            sage: copy(el).is_mutable()
            True
            sage: with el.clone() as el1:
            ...       print [el.is_mutable(), el1.is_mutable()]
            [False, True]
        """
        return not self._is_immutable

    cpdef inline bint is_immutable(self):
        """
        Returns ``True`` if ``self`` is immutable (can not be changed)
        and ``False`` if it is not.

        To make ``self`` immutable use ``self.set_immutable()``.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el.is_immutable()
            True
            sage: copy(el).is_immutable()
            False
            sage: with el.clone() as el1:
            ...       print [el.is_immutable(), el1.is_immutable()]
            [True, False]
        """
        return self._is_immutable

    cpdef inline set_immutable(self):
        """
        Makes ``self`` immutable, so it can never again be changed.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el1 = copy(el); el1.is_mutable()
            True
            sage: el1.set_immutable();  el1.is_mutable()
            False
            sage: el1[2] = 4
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
        """
        self._is_immutable = True

    cpdef inline _set_mutable(self):
        """
        Makes ``self`` mutable, so it can be changed.

        This function is for debugging only, you are not supposed to use it.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el._set_mutable(); el.is_mutable()
            True
        """
        self._is_immutable = False

    def __hash__(self):
        """
        Return the hash value of ``self``.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: hash(el)    # random
            -309690657
            sage: el1 = copy(el); hash(el1)
            Traceback (most recent call last):
            ...
            ValueError: cannot hash a mutable object.
        """
        if self._hash == 0:
            if not self._is_immutable:
                raise ValueError, "cannot hash a mutable object."
            else:
                self._hash = self._hash_()
        return self._hash

    cpdef inline ClonableElement clone(self, bint check=True):
        """
        Returns a clone that is mutable copy of ``self``.

        INPUT:

        - ``check`` -- a boolean indicating if ``self.check()`` must be called
          after modifications.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: with el.clone() as el1:
            ...       el1[2] = 5
            sage: el1
            [1, 2, 5]
        """
        cdef ClonableElement res
        res = self.__copy__()
        res._needs_check = check
        return res

    cpdef inline ClonableElement __enter__(self):
        """
        Implement the self guarding clone protocol.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el.clone().__enter__()
            [1, 2, 3]
        """
        self._require_mutable()
        return self

    cpdef bint __exit__(self, typ, value, tracback):
        """
        Implement the self guarding clone protocol.

        .. note:: The input argument are required by the ``with`` protocol but
           are ignored.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el1 = el.clone().__enter__()
            sage: el1.__exit__(None, None, None)
            False

        Lets try to make a broken list::

            sage: el2 = el.clone().__enter__()
            sage: el2[1] = 7
            sage: el2.__exit__(None, None, None)
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing
        """
        self.set_immutable()
        if __debug__ and self._needs_check:
            self.check()
        # is there a way if check() fails to replace self by a invalid object ?
        return False


############################################################################
###     The most common case of clone object : list with constraints     ###
############################################################################
cdef class ClonableArray(ClonableElement):
    """
    Array with clone protocol

    The class of objects which are
    :class:`Element<sage.structure.element.Element>` behave as arrays
    (i.e. lists of fixed length) and implement the clone protocol. See
    :class:`ClonableElement` for details about clone protocol.
    """
    def __init__(self, Parent parent, lst, check = True):
        """
        Initialize ``self``

        INPUT:

        - ``parent`` -- a :class:`Parent<sage.structure.parent.Parent>`
        - ``lst``    -- a list
        - ``check``  -- a boolean specifying if the invariant must be checked
          using method :meth:`check`.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()([1,2,3])
            [1, 2, 3]

            sage: el = IncreasingArrays()([3,2,1])
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing

            sage: IncreasingArrays()(None)
            Traceback (most recent call last):
            ...
            TypeError: 'NoneType' object is not iterable

        You are not suppose to do the following (giving a wrong list and
        desactivating checks)::

            sage: broken = IncreasingArrays()([3,2,1], False)
        """
        self._parent = parent
        self._list = list(lst)
        self._is_immutable = True
        if check:
            self.check()

    def _repr_(self):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()([1,2,3])
            [1, 2, 3]
        """
        return repr(self._list)

    def __nonzero__(self):
        """
        Tests if self is not Empty.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()([1,2,3]).__nonzero__()
            True
            sage: IncreasingArrays()([]).__nonzero__()
            False
        """
        return bool(self._list)

    cpdef inline list _get_list(self):
        """
        Returns the list embedded in ``self``.

        Don't use ! For internal purpose only.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el._get_list()
            [1, 2, 3]
        """
        return self._list

    cpdef inline _set_list(self, list lst):
        """
        Set the list embedded in ``self``.

        Don't use ! For internal purpose only.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el._set_list([1,4,5])
            sage: el
            [1, 4, 5]
        """
        self._list = lst

    def __len__(self):
        """
        Returns the len of ``self``

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: len(IncreasingArrays()([1,2,3]))
            3
        """
        return len(self._list)

    def __getitem__(self, key):
        """
        Returns the ``key``-th element of ``self``

        It also works with slice returning a python list in this case.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()([1,2,3])[1]
            2
            sage: IncreasingArrays()([1,2,3])[7]
            Traceback (most recent call last):
            ...
            IndexError: list index out of range
            sage: IncreasingArrays()([1,2,3])[-1]
            3
            sage: IncreasingArrays()([1,2,3])[-1:]
            [3]
            sage: IncreasingArrays()([1,2,3])[:]
            [1, 2, 3]
            sage: type(IncreasingArrays()([1,2,3])[:])
            <type 'list'>
        """
        if PY_TYPE_CHECK(key, slice):
            self._list[key.start:key.stop:key.step]
        return self._list[key]

    def __setitem__(self, int key, value):
        """
        Set the ``i``-th element of ``self``

        An exception is raised if ``self`` is immutable.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,4,10])
            sage: elc = copy(el)
            sage: elc[1] = 3; elc
            [1, 3, 4, 10]
            sage: el[1] = 3
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
            sage: elc[5] = 3
            Traceback (most recent call last):
            ...
            IndexError: list assignment index out of range
        """
        self._require_mutable()
        self._list[key] = value

    cpdef object _getitem(self, int key):
        """
        Same as :meth:`__getitem__`

        This is much faster when used with Cython and ``key`` is known to be
        an ``int``.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()([1,2,3])._getitem(1)
            2
            sage: IncreasingArrays()([1,2,3])._getitem(5)
            Traceback (most recent call last):
            ...
            IndexError: list index out of range
        """
        return self._list[key]

    cpdef _setitem(self, int key, value):
        """
        Same as :meth:`__setitem__`

        This is much faster when used with Cython and ``key`` is known to be
        an ``int``.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,4])
            sage: elc = copy(el)
            sage: elc._setitem(1, 3); elc
            [1, 3, 4]
            sage: el._setitem(1, 3)
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
            sage: elc._setitem(5, 5)
            Traceback (most recent call last):
            ...
            IndexError: list assignment index out of range
        """
        self._require_mutable()
        self._list[key] = value

    def __iter__(self):
        """
        Returns an iterator for ``self``::

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,4])
            sage: list(iter(el))
            [1, 2, 4]

        As a consequence ``min``, ``max`` behave properly::

            sage: el = IncreasingArrays()([1,4,8])
            sage: min(el), max(el)
            (1, 8)

        TESTS::

            sage: list(iter(IncreasingArrays()([])))
            []
        """
        return self._list.__iter__()

    def __contains__(self, item):
        """
        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: c = IncreasingArrays()([1,2,4])
            sage: 1 in c
            True
            sage: 5 in c
            False
        """
        return self._list.__contains__(item)

    cpdef int index(self, x, start=None, stop=None):
        """
        Returns the smallest ``k`` such that ``s[k] == x`` and ``i <= k < j``

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: c = IncreasingArrays()([1,2,4])
            sage: c.index(1)
            0
            sage: c.index(4)
            2
            sage: c.index(5)
            Traceback (most recent call last):
            ...
            ValueError: list.index(x): x not in list
        """
        if start is None:
            return self._list.index(x)
        elif stop is None:
            return self._list.index(x, start)
        else:
            return self._list.index(x, start, stop)

    cpdef int count(self, key):
        """
        Returns number of ``i``'s for which ``s[i] == key``

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: c = IncreasingArrays()([1,2,2,4])
            sage: c.count(1)
            1
            sage: c.count(2)
            2
            sage: c.count(3)
            0
        """
        return self._list.count(key)

    # __hash__ is not properly inherited if comparison is changed
    # see <http://groups.google.com/group/cython-users/t/e89a9bd2ff20fd5a>
    def __hash__(self):
        """
        Returns the hash value of ``self``.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: hash(el)    # random
            -309690657
            sage: el1 = copy(el); hash(el1)
            Traceback (most recent call last):
            ...
            ValueError: cannot hash a mutable object.
        """
        if self._hash == 0:
            if not self._is_immutable:
                raise ValueError, "cannot hash a mutable object."
            else:
                self._hash = self._hash_()
        return self._hash

    def __richcmp__(left, right, int op):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,4])
            sage: elc = copy(el)
            sage: elc == el             # indirect doctest
            True
        """
        return (<Element>left)._richcmp(right, op)

    # See protocol in comment in sage/structure/element.pyx
    cdef int _cmp_c_impl(left, Element right) except -2:
        """
        TEST::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el1 = IncreasingArrays()([1,2,4])
            sage: el2 = IncreasingArrays()([1,2,3])
            sage: el1 == el1, el2 == el2, el1 == el2    # indirect doctest
            (True, True, False)
            sage: el1 <= el2, el1 >= el2, el2 <= el1    # indirect doctest
            (False, True, True)
        """
        cdef ClonableArray rgt = <ClonableArray>right
        return cmp(left._list, rgt._list)

    cpdef inline ClonableArray __copy__(self):
        """
        Returns a copy of ``self``

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,4])
            sage: elc = copy(el)
            sage: el[:] == elc[:]
            True
            sage: el is elc
            False

        We check that empty lists are correctly copied::

            sage: el = IncreasingArrays()([])
            sage: elc = copy(el)
            sage: el is elc
            False
            sage: elc.__nonzero__()
            False
            sage: elc.is_mutable()
            True

        We check that element with a ``__dict__`` are correctly copied::

            sage: IL = IncreasingArrays()
            sage: class myClass(IL.element_class): pass
            sage: el = myClass(IL, [])
            sage: el.toto = 2
            sage: elc = copy(el)
            sage: elc.toto
            2
        """
        cdef ClonableArray res
        #res = type(self).__new__(type(self), self._parent)
        res = PY_NEW_SAME_TYPE(self)
        res._parent = self._parent
        res._list = self._list[:]
        if HAS_DICTIONARY(self):
            res.__dict__ = self.__dict__.copy()
        return res

    cpdef inline check(self):
        """
        Check that ``self`` fulfill the invariants

        This is an abstract method. Subclasses are supposed to overload
        ``check``.

        EXAMPLES::

            sage: ClonableArray(Parent(), [1,2,3]) # indirect doctest
            Traceback (most recent call last):
            ...
            AssertionError: This should never be called, please overload
            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,4]) # indirect doctest
        """
        assert False, "This should never be called, please overload"

    cpdef inline long _hash_(self):
        """
        Return the hash value of ``self``.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,3])
            sage: el._hash_()    # random
            -309711137
            sage: type(el._hash_()) == int
            True
        """
        cdef long hv
        hv = hash(tuple(self._list))
        return hash(self._parent) + hv

    def __reduce__(self):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: el = IncreasingArrays()([1,2,4])
            sage: loads(dumps(el))
            [1, 2, 4]
            sage: t = el.__reduce__(); t
            (<built-in function _make_array_clone>, (<type 'sage.structure.list_clone.IncreasingArray'>, <class 'sage.structure.list_clone.IncreasingArrays_with_category'>, [1, 2, 4], True, True, None))
            sage: t[0](*t[1])
            [1, 2, 4]
        """
        # Warning: don't pickle the hash value as it can change upon unpickling.
        if HAS_DICTIONARY(self):
            dic = self.__dict__
        else:
            dic = None
        return (sage.structure.list_clone._make_array_clone,
                (type(self), self._parent, self._list,
                 self._needs_check, self._is_immutable, dic))


##### Needed for unpikling #####
def _make_array_clone(clas, parent, list, needs_check, is_immutable, dic):
    """
    Helpler to unpikle :class:`list_clone` instances.

    TESTS::

        sage: from sage.structure.list_clone import _make_array_clone, IncreasingArrays
        sage: ILs = IncreasingArrays()
        sage: el = _make_array_clone(ILs.element_class, ILs, [1,2,3], True, True, None)
        sage: el
        [1, 2, 3]
        sage: el == ILs([1,2,3])
        True

    We check that element with a ``__dict__`` are correctly pickled::

        sage: IL = IncreasingArrays()
        sage: class myClass(IL.element_class): pass
        sage: import __main__
        sage: __main__.myClass = myClass
        sage: el = myClass(IL, [])
        sage: el.toto = 2
        sage: elc = loads(dumps(el))
        sage: elc.toto
        2
    """
    cdef ClonableArray res
    res = <ClonableArray> PY_NEW(clas)
    res._parent = parent
    res._list = list
    res._needs_check = needs_check
    res._is_immutable = is_immutable
    if dic is not None:
        res.__dict__ = dic
    return res



#####################################################################
######                      TESTS Classes                      ######
#####################################################################
##### Cython version #####
cdef class IncreasingArray(ClonableArray):
    """
    A small extension class for testing :class:`ClonableArray`.

    TESTS::

        sage: from sage.structure.list_clone import IncreasingArrays
        sage: TestSuite(IncreasingArrays()([1,2,3])).run()
        sage: TestSuite(IncreasingArrays()([])).run()
    """

    cpdef check(self):
        """
        Check that ``self`` is increasing.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()([1,2,3]) # indirect doctest
            [1, 2, 3]
            sage: IncreasingArrays()([3,2,1]) # indirect doctest
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing
        """
        cdef int i
        for i in range(len(self)-1):
            assert self._getitem(i) <= self._getitem(i+1), "array is not increasing"


##### Parents #####
from sage.categories.sets_cat import Sets
from sage.structure.unique_representation import UniqueRepresentation
class IncreasingArrays(UniqueRepresentation, Parent):
    """
    A small (incomplete) parent for testing :class:`ClonableArray`

    TESTS::

        sage: from sage.structure.list_clone import IncreasingArrays
        sage: IncreasingArrays().element_class
        <type 'sage.structure.list_clone.IncreasingArray'>
    """

    def __init__(self):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()
            <class 'sage.structure.list_clone.IncreasingArrays_with_category'>
            sage: IncreasingArrays() == IncreasingArrays()
            True
        """
        Parent.__init__(self, category = Sets())

    def _element_constructor_(self, *args, **keywords):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingArrays
            sage: IncreasingArrays()([1])     # indirect doctest
            [1]
        """
        return self.element_class(self, *args, **keywords)

    Element = IncreasingArray


############################################################################
###                      Clonable (Resizable) Lists                      ###
############################################################################
cdef class ClonableList(ClonableArray):
    """
    List with clone protocol

    The class of objects which are
    :class:`Element<sage.structure.element.Element>` behave as lists and
    implement the clone protocol. See :class:`ClonableElement` for details
    about clone protocol.
    """
    cpdef append(self, el):
        """
        Appends ``el`` to ``self``

        INPUT: ``el`` -- any object

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: el = IncreasingLists()([1])
            sage: el.append(3)
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
            sage: with el.clone() as elc:
            ...       elc.append(4)
            ...       elc.append(6)
            sage: elc
            [1, 4, 6]
            sage: with el.clone() as elc:
            ...       elc.append(4)
            ...       elc.append(2)
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing
        """
        self._require_mutable()
        self._list.append(el)

    cpdef extend(self, it):
        """
        Extends ``self`` by the content of the iterable ``it``

        INPUT: ``it`` -- any iterable

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: el = IncreasingLists()([1, 4, 5, 8, 9])
            sage: el.extend((10,11))
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.

            sage: with el.clone() as elc:
            ...       elc.extend((10,11))
            sage: elc
            [1, 4, 5, 8, 9, 10, 11]

            sage: el2 = IncreasingLists()([15, 16])
            sage: with el.clone() as elc:
            ...       elc.extend(el2)
            sage: elc
            [1, 4, 5, 8, 9, 15, 16]

            sage: with el.clone() as elc:
            ...       elc.extend((6,7))
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing
        """
        self._require_mutable()
        self._list.extend(it)

    cpdef insert(self, int index, el):
        """
        Inserts ``el`` in ``self`` at position ``index``

        INPUT:

         - ``el`` -- any object
         - ``index`` -- any int

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: el = IncreasingLists()([1, 4, 5, 8, 9])
            sage: el.insert(3, 6)
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
            sage: with el.clone() as elc:
            ...       elc.insert(3, 6)
            sage: elc
            [1, 4, 5, 6, 8, 9]
            sage: with el.clone() as elc:
            ...       elc.insert(2, 6)
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing
        """
        self._require_mutable()
        self._list.insert(index, el)

    cpdef pop(self, int index=-1):
        """
        Remove ``self[index]`` from ``self`` and returns it

        INPUT: ``index`` - any int, default to -1

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: el = IncreasingLists()([1, 4, 5, 8, 9])
            sage: el.pop()
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
            sage: with el.clone() as elc:
            ...       print elc.pop()
            9
            sage: elc
            [1, 4, 5, 8]
            sage: with el.clone() as elc:
            ...       print elc.pop(2)
            5
            sage: elc
            [1, 4, 8, 9]
        """
        self._require_mutable()
        return self._list.pop(index)

    cpdef remove(self, el):
        """
        Remove the fisrt occurence of el from ``self``

        INPUT: ``el`` - any object

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: el = IncreasingLists()([1, 4, 5, 8, 9])
            sage: el.remove(4)
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
            sage: with el.clone() as elc:
            ...       elc.remove(4)
            sage: elc
            [1, 5, 8, 9]
            sage: with el.clone() as elc:
            ...       elc.remove(10)
            Traceback (most recent call last):
            ...
            ValueError: list.remove(x): x not in list
        """
        self._require_mutable()
        return self._list.remove(el)

    def __setitem__(self, key, value):
        """
        Set the ith element of ``self``

        An exception is raised if ``self`` is immutable.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: el = IncreasingLists()([1,2,4,10,15,17])
            sage: el[1] = 3
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.

            sage: with el.clone() as elc:
            ...       elc[3] = 7
            sage: elc
            [1, 2, 4, 7, 15, 17]

            sage: with el.clone(check=False) as elc:
            ...       elc[1:3]  = [3,5,6,8]
            sage: elc
            [1, 3, 5, 6, 8, 10, 15, 17]
        """
        self._require_mutable()
        self._list[key] = value

    def __delitem__(self, key):
        """
        Remove the ith element of ``self``

        An exception is raised if ``self`` is immutable.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: el = IncreasingLists()([1, 4, 5, 8, 9])
            sage: del el[3]
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
            sage: with el.clone() as elc:
            ...       del elc[3]
            sage: elc
            [1, 4, 5, 9]
            sage: with el.clone() as elc:
            ...       del elc[1:3]
            sage: elc
            [1, 8, 9]
        """
        self._require_mutable()
        del self._list[key]


class IncreasingLists(IncreasingArrays):
    """
    A small (incomplete) parent for testing :class:`ClonableArray`

    TESTS::

        sage: from sage.structure.list_clone import IncreasingLists
        sage: IncreasingLists().element_class
        <type 'sage.structure.list_clone.IncreasingList'>
    """
    Element = IncreasingList

cdef class IncreasingList(ClonableList):
    """
    A small extension class for testing :class:`ClonableList`.

    TESTS::

        sage: from sage.structure.list_clone import IncreasingLists
        sage: TestSuite(IncreasingLists()([1,2,3])).run()
        sage: TestSuite(IncreasingLists()([])).run()
    """

    cpdef check(self):
        """
        Check that ``self`` is increasing.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingLists
            sage: IncreasingLists()([1,2,3]) # indirect doctest
            [1, 2, 3]
            sage: IncreasingLists()([3,2,1]) # indirect doctest
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing
        """
        cdef int i
        for i in range(len(self)-1):
            assert self._getitem(i) < self._getitem(i+1), "array is not increasing"




############################################################################
###                     Clonable Arrays of int                            ##
############################################################################
cdef class ClonableIntArray(ClonableElement):
    """
    Array of int with clone protocol

    The class of objects which are
    :class:`Element<sage.structure.element.Element>` behave as list of int and
    implement the clone protocol. See :class:`ClonableElement` for details
    about clone protocol.
    """
    def __cinit__(self):
        self._len = -1
        self._list = NULL

    def __init__(self, Parent parent, lst, check = True):
        """
        Initialize ``self``

        INPUT:

        - ``parent`` -- a :class:`Parent<sage.structure.parent.Parent>`
        - ``lst``      -- a list
        - ``check`` -- a boolean specifying if the invariant must be checked
          using method :meth:`check`.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: IncreasingIntArrays()([1,2,3])
            [1, 2, 3]
            sage: IncreasingIntArrays()((1,2,3))
            [1, 2, 3]

            sage: IncreasingIntArrays()(None)
            Traceback (most recent call last):
            ...
            TypeError: object of type 'NoneType' has no len()

            sage: el = IncreasingIntArrays()([3,2,1])
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing

            sage: el = IncreasingIntArrays()([1,2,4])
            sage: list(iter(el))
            [1, 2, 4]
            sage: list(iter(IncreasingIntArrays()([])))
            []


        You are not suppose to do the following (giving a wrong list and
        desactivating checks)::

            sage: broken = IncreasingIntArrays()([3,2,1], False)
        """
        cdef int i
        self._parent = parent

        if self._list is not NULL:
            raise ValueError, "resizing is forbidden"
        self._alloc_(len(lst))
        for i from 0 <= i < self._len:
            self._list[i] = lst[i]

        self._is_immutable = True
        if check:
            self.check()

    cpdef _alloc_(self, int size):
        """
        Allocate the array part of ``self`` for a given size

        This can be used to initialize ``self`` without passing a list

        INPUT: ``size`` - an int

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([], check=False)
            sage: el._alloc_(3)
            sage: el._setitem(0, 1); el._setitem(1, 5); el._setitem(2, 8)
            sage: el
            [1, 5, 8]
            sage: copy(el)
            [1, 5, 8]

        TESTS::

            sage: el._alloc_(-1)
            Traceback (most recent call last):
            ...
            AssertionError: Negative size is forbidden
        """
        assert size >= 0, "Negative size is forbidden"
        self._is_immutable = False
        if self._list is NULL:
            self._len = size
            self._list = <int *>sage_malloc(sizeof(int) * self._len)
        else:
            self._len = size
            self._list = <int *>sage_realloc(self._list, sizeof(int) * self._len)

    def __dealloc__(self):
        if self._list is not NULL:
            sage_free(self._list)
            self._len = -1
            self._list = NULL

    def _repr_(self):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: IncreasingIntArrays()([1,2,3])
            [1, 2, 3]
        """
        return '['+', '.join(["%i"%(self._list[i]) for i in range(self._len)])+']'

    def __nonzero__(self):
        """
        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: IncreasingIntArrays()([1,2,3]).__nonzero__()
            True
            sage: IncreasingIntArrays()([]).__nonzero__()
            False
        """
        return self._len != 0

    def __len__(self):
        """
        Returns the len of ``self``

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: len(IncreasingIntArrays()([1,2,3]))
            3
        """
        return self._len

    def __getitem__(self, key):
        """
        Returns the ith element of ``self``

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,3])
            sage: el[1]
            2
            sage: el[1:2]
            [2]
            sage: el[4]
            Traceback (most recent call last):
            ...
            IndexError: list index out of range
            sage: el[-1]
            3
            sage: el[-1:]
            [3]
            sage: el[:]
            [1, 2, 3]
            sage: el[1:3]
            [2, 3]
            sage: type(el[:])
            <type 'list'>
            sage: list(el)
            [1, 2, 3]
            sage: it = iter(el); it.next(), it.next()
            (1, 2)
        """
        cdef int start, stop, step, keyi
        cdef list res
        cdef slice keysl
        # print key
        if PY_TYPE_CHECK(key, slice):
            keysl = <slice> key
            start, stop, step = keysl.indices(self._len)
            res = []
            for i in range(start, stop, step):
                res.append(self._getitem(i))
            return res
        keyi = <int> key
        # print key, key, self._len, self._len+keyi
        if keyi < 0:
            keyi += self._len
        if 0 <= keyi < self._len:
            return self._list[keyi]
        else:
            raise IndexError, "list index out of range"

    def __setitem__(self, int key, value):
        """
        Set the ith element of ``self``

        An exception is raised if ``self`` is immutable.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,4])
            sage: elc = copy(el)
            sage: elc[1] = 3; elc
            [1, 3, 4]
            sage: el[1] = 3
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
        """
        if 0 <= key < self._len:
            self._require_mutable()
            self._list[key] = value
        else:
            raise IndexError, "list index out of range"

    cpdef object _getitem(self, int key):
        """
        Same as :meth:`__getitem__`

        This is much faster when used with Cython and the index is known to be
        an int.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: IncreasingIntArrays()([1,2,3])._getitem(1)
            2
        """
        if 0 <= key < self._len:
            return self._list[key]
        else:
            raise IndexError, "list index out of range"

    cpdef _setitem(self, int key, value):
        """
        Same as :meth:`__setitem__`

        This is much faster when used with Cython and the index is known to be
        an int.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,4])
            sage: elc = copy(el)
            sage: elc._setitem(1, 3); elc
            [1, 3, 4]
            sage: el._setitem(1, 3)
            Traceback (most recent call last):
            ...
            ValueError: object is immutable; please change a copy instead.
        """
        if 0 <= key < self._len:
            self._require_mutable()
            self._list[key] = value
        else:
            raise IndexError, "list index out of range"

    def __contains__(self, int item):
        """
        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: c = IncreasingIntArrays()([1,2,4])
            sage: 1 in c
            True
            sage: 5 in c
            False
        """
        cdef int i
        for i from 0 <= i < self._len:
            if item == self._list[i]:
                return True
        return False

    cpdef int index(self, int item):
        """
        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: c = IncreasingIntArrays()([1,2,4])
            sage: c.index(1)
            0
            sage: c.index(4)
            2
            sage: c.index(5)
            Traceback (most recent call last):
            ...
            ValueError: list.index(x): x not in list
        """
        cdef int i
        for i from 0 <= i < self._len:
            if item == self._list[i]:
                return i
        raise ValueError, "list.index(x): x not in list"


    # __hash__ is not properly inherited if comparison is changed
    # see <http://groups.google.com/group/cython-users/t/e89a9bd2ff20fd5a>
    def __hash__(self):
        """
        Return the hash value of ``self``.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,3])
            sage: hash(el)    # random
            -309690657
            sage: el1 = copy(el); hash(el1)
            Traceback (most recent call last):
            ...
            ValueError: cannot hash a mutable object.
        """
        if self._hash == 0:
            if not self._is_immutable:
                raise ValueError, "cannot hash a mutable object."
            else:
                self._hash = self._hash_()
        return self._hash

    def __richcmp__(left, right, int op):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,4])
            sage: elc = copy(el)
            sage: elc == el             # indirect doctest
            True
        """
        return (<Element>left)._richcmp(right, op)

    # See protocol in comment in sage/structure/element.pyx
    cdef int _cmp_c_impl(left, Element right) except -2:
        """
        TEST::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el1 = IncreasingIntArrays()([1,2,4])
            sage: el2 = IncreasingIntArrays()([1,2,3])
            sage: el1 == el1, el2 == el2, el1 == el2    # indirect doctest
            (True, True, False)
            sage: el1 <= el2, el1 >= el2, el2 <= el1    # indirect doctest
            (False, True, True)
        """
        cdef int i, minlen, reslen
        cdef ClonableIntArray rgt = <ClonableIntArray>right
        if left._list is NULL:
            if rgt._list is NULL:
                return 0
            else:
                return -1
        elif rgt._list is NULL:
            return 1
        if left._len < rgt._len:
            minlen = left._len
            reslen = -1
        elif left._len > rgt._len:
            minlen = rgt._len
            reslen = +1
        else:
            minlen = rgt._len
            reslen = 0
        for i from 0 <= i < minlen:
            if left._list[i] != rgt._list[i]:
                if left._list[i] < rgt._list[i]:
                    return -1
                else:
                    return 1
        return reslen

    cpdef inline ClonableIntArray __copy__(self):
        """
        Returns a copy of ``self``

        TESTS::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,4])
            sage: elc = copy(el)
            sage: el[:] == elc[:]
            True
            sage: el is elc
            False

        We check that void lists are correctly copied::

            sage: el = IncreasingIntArrays()([])
            sage: elc = copy(el)
            sage: el is elc
            False
            sage: elc.__nonzero__()
            True
            sage: elc.is_mutable()
            True

        We check that element with a ``__dict__`` are correctly copied::

            sage: IL = IncreasingIntArrays()
            sage: class myClass(IL.element_class): pass
            sage: el = myClass(IL, [])
            sage: el.toto = 2
            sage: elc = copy(el)
            sage: elc.toto
            2
        """
        cdef ClonableIntArray res
        res = PY_NEW_SAME_TYPE(self)
        res._parent = self._parent
        if self:
            res._alloc_(self._len)
            for i from 0 <= i < res._len:
                res._list[i] = self._list[i]
        if HAS_DICTIONARY(self):
            res.__dict__ = self.__dict__.copy()
        return res

    cpdef inline check(self):
        """
        Check that ``self`` fulfill the invariants

        This is an abstract method. Subclasses are supposed to overload
        ``check``.

        EXAMPLES::

            sage: ClonableArray(Parent(), [1,2,3]) # indirect doctest
            Traceback (most recent call last):
            ...
            AssertionError: This should never be called, please overload
            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,4]) # indirect doctest
        """
        assert False, "This should never be called, please overload"

    cpdef inline long _hash_(self):
        """
        Return the hash value of ``self``.

        TESTS::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,3])
            sage: el._hash_()    # random
            -309711137
            sage: type(el._hash_()) == int
            True
        """
        cdef long hv
        if self._list == NULL:
            hv = hash(None)
        else:
            hv = hash(tuple(self))
        return hash(self._parent) + hv

    def __reduce__(self):
        """
        TESTS::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: el = IncreasingIntArrays()([1,2,4])
            sage: loads(dumps(el))
            [1, 2, 4]
            sage: t = el.__reduce__(); t
            (<built-in function _make_int_array_clone>, (<type 'sage.structure.list_clone.IncreasingIntArray'>, <class 'sage.structure.list_clone.IncreasingIntArrays_with_category'>, [1, 2, 4], True, True, None))
            sage: t[0](*t[1])
            [1, 2, 4]
        """
        # Warning: don't pickle the hash value as it can change upon unpickling.
        if HAS_DICTIONARY(self):
            dic = self.__dict__
        else:
            dic = None
        return (sage.structure.list_clone._make_int_array_clone,
                (type(self), self._parent, self[:],
                 self._needs_check, self._is_immutable, dic))


##### Needed for unpikling #####
def _make_int_array_clone(clas, parent, lst, needs_check, is_immutable, dic):
    """
    Helpler to unpikle :class:`list_clone` instances.

    TESTS::

        sage: from sage.structure.list_clone import _make_int_array_clone, IncreasingIntArrays
        sage: ILs = IncreasingIntArrays()
        sage: el = _make_int_array_clone(ILs.element_class, ILs, [1,2,3], True, True, None)
        sage: el
        [1, 2, 3]
        sage: el == ILs([1,2,3])
        True

    We check that element with a ``__dict__`` are correctly pickled::

        sage: IL = IncreasingIntArrays()
        sage: class myClass(IL.element_class): pass
        sage: import __main__
        sage: __main__.myClass = myClass
        sage: el = myClass(IL, [])
        sage: el.toto = 2
        sage: elc = loads(dumps(el))
        sage: elc.toto
        2
    """
    cdef ClonableIntArray res
    res = <ClonableIntArray> PY_NEW(clas)
    ClonableIntArray.__init__(res, parent, lst, needs_check)
    res._is_immutable = is_immutable
    if dic is not None:
        res.__dict__ = dic
    return res


cdef class IncreasingIntArray(ClonableIntArray):
    """
    A small extension class for testing :class:`ClonableIntArray`.

    TESTS::

        sage: from sage.structure.list_clone import IncreasingIntArrays
        sage: TestSuite(IncreasingIntArrays()([1,2,3])).run()
        sage: TestSuite(IncreasingIntArrays()([])).run()
    """

    cpdef check(self):
        """
        Check that ``self`` is increasing.

        EXAMPLES::

            sage: from sage.structure.list_clone import IncreasingIntArrays
            sage: IncreasingIntArrays()([1,2,3]) # indirect doctest
            [1, 2, 3]
            sage: IncreasingIntArrays()([3,2,1]) # indirect doctest
            Traceback (most recent call last):
            ...
            AssertionError: array is not increasing
        """
        cdef int i
        if not self:
            return
        for i in range(len(self)-1):
            assert self._getitem(i) < self._getitem(i+1), "array is not increasing"

class IncreasingIntArrays(IncreasingArrays):
    """
    A small (incomplete) parent for testing :class:`ClonableIntArray`

    TESTS::

        sage: from sage.structure.list_clone import IncreasingIntArrays
        sage: IncreasingIntArrays().element_class
        <type 'sage.structure.list_clone.IncreasingIntArray'>
    """
    Element = IncreasingIntArray