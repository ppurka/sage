#
# Declare C library functions used in Sage
#

include "python.pxi"

from libc.stdio cimport *
from libc.string cimport strlen, strcpy, memset, memcpy

from libc.math cimport sqrt, frexp, ldexp

from sage.libs.gmp.all cimport *
