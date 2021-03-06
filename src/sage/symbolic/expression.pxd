from sage.libs.ginac cimport *

from sage.structure.element cimport CommutativeRingElement


cdef class Expression(CommutativeRingElement):
    cdef GEx _gobj
    cdef Expression coerce_in(self, z)
    cpdef object _eval_self(self, R)
    cpdef object _convert(self, R)
    cpdef bint is_polynomial(self, var)
    cpdef bint is_relational(self)
    cpdef bint is_infinity(self)
    cpdef object pyobject(self)
    cpdef Expression _subs_expr(self, expr)

cpdef bint is_Expression(x)
cdef Expression new_Expression_from_GEx(parent, GEx juice)
cdef Expression new_Expression_from_pyobject(parent, x)
