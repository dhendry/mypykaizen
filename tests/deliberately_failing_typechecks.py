def bad_assignment() -> None:
    v: int = 1
    v = None
    v = 2.3
    v = "asdf"


def no_return_type():
    return "What goes in must come out"
