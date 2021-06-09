import os


# this function is inspired by numpy
def get_include():
    """
    Return the directory that contains the plexim \\*.h header files.
    Extension modules that need to compile against plexsim should use this
    function to locate the appropriate include directory.
    Notes
    -----
    When using ``distutils``, for example in ``setup.py``.
    ::
        import plexsim
        ...
        Extension('extension_name', ...
                include_dirs=[plexsim.get_include()])
        ...
    """
    import plexsim

    d = os.path.join(os.path.dirname(__file__), "../")
    return d
