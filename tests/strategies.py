from pfun import (
    maybe, reader, state, Dict, cont, writer, trampoline, free, io
)
from pfun import list as list_
from hypothesis.strategies import (
    integers,
    booleans,
    text,
    one_of,
    floats,
    builds,
    just,
    lists as lists_,
    dictionaries,
    tuples,
    none,
    composite,
    binary
)

from pfun.either import Left, Right


def _everything(allow_nan=False):
    return integers(), booleans(), text(), floats(allow_nan=allow_nan)


def anything(allow_nan=False):
    return one_of(*_everything(allow_nan))


def unaries(return_strategy=anything()):
    def _(a):
        return lambda _: a

    return builds(_, return_strategy)


def maybes(value_strategy=anything()):
    justs = builds(maybe.Just, value_strategy)
    nothings = just(maybe.Nothing())
    return one_of(justs, nothings)


def eithers(value_strategy=anything()):
    lefts = builds(Left, value_strategy)
    rights = builds(Right, value_strategy)
    return one_of(lefts, rights)


def frees(value_strategy=anything()):
    dones = builds(free.Done, value_strategy)

    @composite
    def mores(draw):
        f = draw(frees(value_strategy))
        return free.More(free.Done(f))

    return one_of(dones, mores())


def nullaries(value_strategy=anything()):
    def f(v):
        return lambda: v

    return builds(f, value_strategy)


def trampolines(value_strategy=anything()):
    dones = builds(trampoline.Done, value_strategy)

    @composite
    def call(draw):
        t = draw(trampolines(value_strategy))
        return trampoline.Call(lambda: t)

    @composite
    def and_then(draw):
        t = draw(trampolines(value_strategy))
        cont = lambda _: t
        return trampoline.AndThen(draw(trampolines(value_strategy)), cont)

    return one_of(dones, call(), and_then())


def lists(element_strategies=_everything(allow_nan=False), min_size=0):
    return builds(
        list_.list_,
        one_of(
            *(
                lists_(strategy, min_size=min_size)
                for strategy in element_strategies
            )
        )
    )


def readers(value_strategy=anything()):
    return builds(reader.wrap, value_strategy)


def states(value_strategy=anything()):
    return builds(state.wrap, value_strategy)


def dicts(keys=text(), values=anything(), min_size=0, max_size=None):
    return builds(
        Dict, dictionaries(keys, values, min_size=min_size, max_size=max_size)
    )


def conts(value_strategy=anything()):
    return builds(cont.wrap, value_strategy)


def monoids():
    return one_of(lists_(anything()), lists(), tuples(), integers(), text())


def writers(value_strategy=anything(), monoid=lists()):
    return builds(writer.Writer, value_strategy, monoid)


def io_primitives(value_strategy=anything()):
    return builds(io.wrap, value_strategy)


def puts():
    return builds(io.put_line, text())


def gets():
    return builds(io.get_line, text())


def read_files():
    read_files = builds(io.read_str, text())
    read_bytess = builds(io.read_bytes, text())
    return one_of(read_files, read_bytess)


def write_files():
    write_strs = builds(io.write_str, text(), text())
    write_bytess = builds(io.write_bytes, text(), binary())
    return one_of(write_bytess, write_strs)


def ios(value_strategy=anything()):
    return one_of(
        io_primitives(value_strategy),
        write_files(),
        read_files(),
        gets(),
        puts()
    )
