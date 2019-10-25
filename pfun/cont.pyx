from typing import Generator
from functools import wraps

from .monad cimport (
    Monad, 
    _sequence, 
    _map_m, 
    _filter_m, 
    wrap_t, 
    _with_effect
)
from .trampoline cimport Trampoline, Call, Done
from .util import identity
from .curry import curry


cdef class Cont(Monad):
    """
    Type that represents a function in continuation passing style.
    """
    cdef object run_c

    def __cinit__(self, object run_c):
        self.run_c = run_c

    def and_then(self, f):
        """
        Chain together functions in continuation passing style

        :example:
        >>> value(1).and_then(lambda i: value(i + 1)).run(identity)
        2

        :param f: Function in continuation passing style to chain with
        the result of this function
        :return:
        """
        return self._and_then(f)
    
    cdef Cont _and_then(self, object f):
        return Cont(
            lambda c: Call(
                lambda: self.run_c(
                    lambda b: Call(lambda: (<Cont>f(b)).run_c(c))
                )
            ).and_then(identity)
        )

    def run(self, f):
        """
        Run the wrapped function in continuation passing style by passing the
        result to ``f``

        :example:
        >>> from pfun import identity
        >>> value(1).run(identity)
        1

        :param f: The function to pass the result of the wrapped function to
        :return: the result of passing the return value
        of the wrapped function to ``f``
        """
        return self._run(f)
    
    cdef object _run(self, object f):
        return (<Trampoline>self.run_c(f))._run()

    def map(self, f):
        """
        Map the  ``f`` over this continuation

        :example:
        >>> from pfun import identity
        >>> value(1).map(lambda v: v + 1).run(identity)
        2

        :param f: The function to map over this continuation
        :return: Continuation mapped with ``f``
        """
        return self._map(f)
    
    cdef Cont _map(self, object f):
        return Cont(lambda c: Call(lambda: (<Trampoline>self.run_c(c))._map(f)))


@curry
def map_m(f,
          iterable):
    """
    Apply ``f`` to each element in ``iterable`` and collect the results

    :example:
    >>> from pfun import identity
    >>> map_m(value, range(3)).run(identity)
    (0, 1, 2)

    :param f: The function to map over ``iterable``
    :param iterable: The iterable to map over
    :return: ``iterable`` mapped with ``f`` inside Cont
    """
    return _map_m(<wrap_t>_wrap, f, iterable)


def sequence(iterable):
    """
    Gather an iterable of continuation results into one iterable

    :example:
    >>> from pfun import identity
    >>> sequence([value(v) for v in range(3)]).run(identity)
    (0, 1, 2)

    :param iterable: An iterable of continuation results
    :return: Continuation results
    """
    return _sequence(<wrap_t>_wrap, iterable)


@curry
def filter_m(f, iterable):
    """
    Filter elements by in ``iterable`` by ``f`` and combine results into
    an iterable as a continuation

    :example:
    >>> from pfun import identity
    >>> filter_m(lambda v: value(v % 2 == 0), range(3)).run(identity)
    (0, 2)

    :param f: Function to filter by
    :param iterable: Iterable to filter
    :return: Elements in ``iterable`` filtered by ``f`` as a continuation
    """
    return _filter_m(<wrap_t>_wrap, f, iterable)


def wrap(a):
    """
    Wrap a constant value in a :class:`Cont` context

    :example:
    >>> from pfun import identity
    >>> value(1).run(identity)
    1

    :param a: Constant value to wrap
    :return: :class:`Cont` wrapping the value
    """
    return _wrap(a)

cdef Cont _wrap(a):
    return Cont(lambda cont: Done(cont(a)))


Conts = Generator


def with_effect(f):
    """
    Decorator for functions that
    return a generator of maybes and a final result.
    Iterates over the yielded maybes and sends back the
    unwrapped values using "and_then"

    :example:
    >>> @with_effect
    ... def f() -> Conts[Any, int, int]:
    ...     a = yield value(2)
    ...     b = yield value(2)
    ...     return a + b
    >>> from pfun import identity
    >>> f().run(identity)
    Just(4)

    :param f: generator function to decorate
    :return: `f` decorated such that generated :class:`Cont` \
        will be chained together with `and_then`
    """
    @wraps(f)
    def decorator(*args, **kwargs):
        g = f(*args, **kwargs)
        return _with_effect(<wrap_t>_wrap, g)
    
    return decorator
