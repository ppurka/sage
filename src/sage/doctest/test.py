"""
Test the doctesting framework

Many tests (with expected failures or crashes) are run in a
subprocess, those tests can be found in the ``tests/`` subdirectory.

EXAMPLES::

    sage: import signal
    sage: import subprocess
    sage: import time
    sage: from sage.env import SAGE_SRC
    sage: tests_dir = os.path.join(SAGE_SRC, 'sage', 'doctest', 'tests')
    sage: tests_env = dict(os.environ)

Unset :envvar:`TERM` when running doctests, see :trac:`14370`::

    sage: try:
    ....:     del tests_env['TERM']
    ....: except KeyError:
    ....:     pass
    sage: kwds = {'cwd': tests_dir, 'env':tests_env}

Check that :trac:`2235` has been fixed::

    sage: subprocess.call(["sage", "-t", "longtime.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t longtime.rst
    [0 tests, ...s]
    ----------------------------------------------------------------------
    All tests passed!
    ----------------------------------------------------------------------
    ...
    0
    sage: subprocess.call(["sage", "-t", "-l", "longtime.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t --long longtime.rst
    [1 test, ...s]
    ----------------------------------------------------------------------
    All tests passed!
    ----------------------------------------------------------------------
    ...
    0

Test the ``--initial`` option::

    sage: subprocess.call(["sage", "-t", "-i", "initial.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t initial.rst
    **********************************************************************
    File "initial.rst", line 4, in sage.doctest.tests.initial
    Failed example:
        a = binomiak(10,5)  # random to test that we still get the exception
    Exception raised:
        Traceback (most recent call last):
        ...
        NameError: name 'binomiak' is not defined
    **********************************************************************
    File "initial.rst", line 14, in sage.doctest.tests.initial
    Failed example:
        binomial(10,5)
    Expected:
        255
    Got:
        252
    **********************************************************************
    ...
    ----------------------------------------------------------------------
    sage -t initial.rst  # 5 doctests failed
    ----------------------------------------------------------------------
    ...
    1

Test a timeout using the ``SAGE_TIMEOUT`` environment variable::

    sage: from copy import deepcopy
    sage: kwds2 = deepcopy(kwds)
    sage: kwds2['env']['SAGE_TIMEOUT'] = "3"
    sage: subprocess.call(["sage", "-t", "99seconds.rst"], **kwds2)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t 99seconds.rst
        Time out
    **********************************************************************
    Tests run before process (pid=...) timed out:
    ...
    ----------------------------------------------------------------------
    sage -t 99seconds.rst  # Time out
    ----------------------------------------------------------------------
    ...
    4

Test handling of ``KeyboardInterrupt`` in doctests::

    sage: subprocess.call(["sage", "-t", "keyboardinterrupt.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t keyboardinterrupt.rst
    **********************************************************************
    File "keyboardinterrupt.rst", line 11, in sage.doctest.tests.keyboardinterrupt
    Failed example:
        raise KeyboardInterrupt
    Exception raised:
        Traceback (most recent call last):
        ...
        KeyboardInterrupt
    **********************************************************************
    ...
    ----------------------------------------------------------------------
    sage -t keyboardinterrupt.rst  # 1 doctest failed
    ----------------------------------------------------------------------
    ...
    1

Interrupt the doctester::

    sage: subprocess.call(["sage", "-t", "interrupt.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t interrupt.rst
    Killing test interrupt.rst
    ----------------------------------------------------------------------
    Doctests interrupted: 0/1 files tested
    ----------------------------------------------------------------------
    ...
    128

Interrupt the doctester (while parallel testing) when a doctest cannot
be interrupted. We also test that passing a ridiculous number of threads
doesn't hurt::

    sage: F = tmp_filename()
    sage: from copy import deepcopy
    sage: kwds2 = deepcopy(kwds)
    sage: kwds2['env']['DOCTEST_TEST_PID_FILE'] = F  # Doctester will write its PID in this file
    sage: subprocess.call(["sage", "-tp", "1000000", "--timeout=120",  # long time
    ....:     "99seconds.rst", "interrupt_diehard.rst"], **kwds2)
    Running doctests...
    Doctesting 2 files using 1000000 threads.
    Killing test 99seconds.rst
    Killing test interrupt_diehard.rst
    ----------------------------------------------------------------------
    Doctests interrupted: 0/2 files tested
    ----------------------------------------------------------------------
    ...
    128

Even though the doctester master process has exited, the child process
is still alive, but it should be killed automatically
in max(20, 120 * 0.05) = 20 seconds::

    sage: pid = int(open(F).read())    # long time
    sage: time.sleep(2)                # long time
    sage: os.kill(pid, signal.SIGHUP)  # long time; 2 seconds passed => still alive
    sage: time.sleep(23)               # long time
    sage: os.kill(pid, signal.SIGHUP)  # long time; 25 seconds passed => dead
    Traceback (most recent call last):
    ...
    OSError: ...

Test a doctest failing with ``abort()``::

    sage: subprocess.call(["sage", "-t", "abort.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t abort.rst
        Killed due to abort
    **********************************************************************
    Tests run before process (pid=...) failed:
    ...
    ------------------------------------------------------------------------
    Unhandled SIGABRT: An abort() occurred in Sage.
    This probably occurred because a *compiled* component of Sage has a bug
    in it and is not properly wrapped with sig_on(), sig_off(). You might
    want to run Sage under gdb with 'sage -gdb' to debug this.
    Sage will now terminate.
    ------------------------------------------------------------------------
    ...
    ----------------------------------------------------------------------
    sage -t abort.rst  # Killed due to abort
    ----------------------------------------------------------------------
    ...
    16

A different kind of crash::

    sage: subprocess.call(["sage", "-t", "fail_and_die.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t fail_and_die.rst
    **********************************************************************
    File "fail_and_die.rst", line 5, in sage.doctest.tests.fail_and_die
    Failed example:
        this_gives_a_NameError
    Exception raised:
        Traceback (most recent call last):
        ...
        NameError: name 'this_gives_a_NameError' is not defined
        Killed due to kill signal
    **********************************************************************
    Tests run before process (pid=...) failed:
    ...
    ----------------------------------------------------------------------
    sage -t fail_and_die.rst  # Killed due to kill signal
    ----------------------------------------------------------------------
    ...
    16

Test that ``sig_on_count`` is checked correctly::

    sage: subprocess.call(["sage", "-t", "sig_on.rst"], **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t sig_on.rst
    **********************************************************************
    File "sig_on.rst", line 5, in sage.doctest.tests.sig_on
    Failed example:
        sig_on_count()
    Expected:
        0
    Got:
        1
    **********************************************************************
    1 item had failures:
       1 of   4 in sage.doctest.tests.sig_on
        [2 tests, 1 failure, ...]
    ----------------------------------------------------------------------
    sage -t sig_on.rst  # 1 doctest failed
    ----------------------------------------------------------------------
    ...
    1

Test the ``--debug`` option::

    sage: subprocess.call(["sage", "-t", "--debug", "simple_failure.rst"], stdin=open(os.devnull), **kwds)  # long time
    Running doctests...
    Doctesting 1 file.
    sage -t simple_failure.rst
    **********************************************************************
    File "simple_failure.rst", line 7, in sage.doctest.tests.simple_failure
    Failed example:
        a * b
    Expected:
        20
    Got:
        15
    **********************************************************************
    Previously executed commands:
        s...: a = 3
        s...: b = 5
        s...: a + b
        8
    debug:
    <BLANKLINE>
    Returning to doctests...
    **********************************************************************
    1 item had failures:
       1 of   5 in sage.doctest.tests.simple_failure
        [4 tests, 1 failure, ...]
    ----------------------------------------------------------------------
    sage -t simple_failure.rst  # 1 doctest failed
    ----------------------------------------------------------------------
    ...
    1

Test running under gdb, without and with a timeout::

    sage: subprocess.call(["sage", "-t", "--gdb", "1second.rst"], stdin=open(os.devnull), **kwds)  # long time, optional: gdb
    exec gdb ...
    Running doctests...
    Doctesting 1 file.
    sage -t 1second.rst
        [2 tests, 1.0 s]
    ----------------------------------------------------------------------
    All tests passed!
    ----------------------------------------------------------------------
    ...
    0
    sage: subprocess.call(["sage", "-t", "--gdb", "-T" "5", "99seconds.rst"], stdin=open(os.devnull), **kwds)  # long time, optional: gdb
    exec gdb ...
    Running doctests...
    Doctesting 1 file.
        Time out
    4

Test the ``--show-skipped`` option::

    sage: subprocess.call(["sage", "-t", "--show-skipped", "show_skipped.rst"], **kwds)  # long time
    Running doctests ...
    Doctesting 1 file.
    sage -t show_skipped.rst
        1 unlabeled test not run
        2 tests not run due to known bugs
        1 gap test not run
        1 long test not run
        1 other test skipped
        [1 test, ... s]
    ----------------------------------------------------------------------
    All tests passed!
    ----------------------------------------------------------------------
    ...
    0

Optional tests are run correctly::

    sage: subprocess.call(["sage", "-t", "--long", "--show-skipped", "--optional=sage,gap", "show_skipped.rst"], **kwds)  # long time
    Running doctests ...
    Doctesting 1 file.
    sage -t --long show_skipped.rst
        1 unlabeled test not run
        2 tests not run due to known bugs
        1 other test skipped
        [3 tests, ... s]
    ----------------------------------------------------------------------
    All tests passed!
    ----------------------------------------------------------------------
    ...
    0
"""
