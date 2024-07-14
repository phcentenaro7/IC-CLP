"""
Safe version of Julia's `first` function. Returns `nothing` if the passed argument is empty.
"""
noerror_first(R) = isempty(R) ? nothing : first(R)

"""
Safe version of Julia's `last` function. Returns `nothing` if the passed argument is empty.
"""
noerror_last(R) = isempty(R) ? nothing : last(R)