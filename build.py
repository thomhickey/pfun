from Cython.Build import cythonize


def build(setup_kwargs):
    setup_kwargs.update(
        {
            'ext_modules': cythonize(
                [
                    'pfun/trampoline.pyx',
                    'pfun/list.pyx',
                    'pfun/reader.pyx'
                ],
                language_level='1'
            )
        }
    )