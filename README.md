# mypykaizen

Wrapper around mypy which prevents the number of typecheck errors from increasing
but which does not force you to fix them all.

Start using and enforcing mypy type checking without first having to fix ALL the errors up front.
This tool enforces that the total number of errors is only allowed to go down or stay the same.

Currently experimental.

## Is this you?

* You want to add mypy type checking to your project 
* You set it up but you get `Found 3319 errors in 126 files (checked 163 source files)` - "Pffffttttt, yea, not going
to fix all that right now"
  * "The teams on board with this type checking thing, lets "

# How it works

* `mypykaizen` is a a wrapper around the `mypy` comand

# Limitations and cavetes


