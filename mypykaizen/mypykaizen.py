"""
Wrapper around mypy which prevents the number of typecheck errors from increasing
but which does not force you to fix them all.

Developed against mypy 0.770
"""
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import List, Optional

import mypy.version
from dataclasses_json import dataclass_json  # type:ignore

ALLOWABLE_ERRORS_FILE_NAME = ".mypykaizen.json"


@dataclass_json
@dataclass
class AllowableErrors:
    """Class to keep track of the allowable errors"""

    file_version: str = "v1"
    mypy_version: Optional[str] = None

    # TODO: Consider updating this to be aware of the -p parameter (what mypy is
    #  checking) and possibly other arguments as well

    total_errors: Optional[int] = None
    files_in_error: Optional[int] = None
    last_full_output: Optional[List[str]] = None

    @classmethod
    def load(cls) -> "AllowableErrors":
        if os.path.isfile(ALLOWABLE_ERRORS_FILE_NAME):
            try:
                with open(ALLOWABLE_ERRORS_FILE_NAME, "rt") as f:
                    return AllowableErrors.from_json(f.read())
            except json.decoder.JSONDecodeError:
                print("mypykaizen: Failed to decode errors file! Continuing any way")
        return AllowableErrors()

    def save(self) -> None:
        with open(ALLOWABLE_ERRORS_FILE_NAME, "wt") as f:
            f.write(self.to_json(indent=4))


def main() -> None:
    # Run mypy:
    result = subprocess.run(
        ["mypy"] + sys.argv[1:],
        text=True,
        # Redirect input/out streams
        stdin=sys.stdin,
        stderr=sys.stderr,
        stdout=subprocess.PIPE,
    )

    # Note that stderr should be redirected so we dont have to worry about that - a cleaner
    # approach would be to create a "capturing output stream" or something so sys.stdout
    # is updated in real time
    if result.stdout:
        sys.stdout.write(result.stdout)

    if result.returncode not in {0, 1} or not result.stdout:
        # Ex: return code 2 seems to be used for when bad args are provided:
        print("mypykaizen: Not active")
        exit(result.returncode)

    print()
    allowable_errors = AllowableErrors.load()
    needs_save = False

    if mypy.version.__version__ != allowable_errors.mypy_version:
        print()
        print(f"mypykaizen: mypy version change - saved data from {allowable_errors.mypy_version}")
        print(f"            current version is {mypy.version.__version__}")
        print()
        allowable_errors.mypy_version = mypy.version.__version__
        needs_save = True

    output_lines = result.stdout.splitlines()
    last_line = output_lines[-1]
    output_lines = output_lines[:-1]  # Remove the last line which is just the summary
    output_lines.sort()  # Sort them as it does not look like mypy is deterministic

    if re.match(r"^Success: .*", last_line):
        assert result.returncode == 0, result.returncode
        print("mypykaizen: No errors!")

        # No longer allow any errors:
        allowable_errors.total_errors = 0
        allowable_errors.files_in_error = 0
        allowable_errors.last_full_output = output_lines
        allowable_errors.save()

        exit(result.returncode)

    fail_match = re.match(r"^Found (?P<total>\d+) errors? in (?P<files>\d+) files? .*", last_line)

    if not fail_match:
        print("mypykaizen: Neither success nor failure for last line:")
        print(last_line)

        exit(10)  # Arbitrary but not 0, 1, or 2 (the codes I have seen used by mypy

    total_errors = int(fail_match.group("total"))
    files_in_error = int(fail_match.group("files"))

    # Now check and do a comparison:
    errors_increased = False

    # Check total errors:
    if allowable_errors.total_errors is None:
        print(f"mypykaizen: Initializing total_errors to {total_errors}")
        allowable_errors.total_errors = total_errors
        needs_save = True
    elif total_errors > allowable_errors.total_errors:
        # Errors have increased
        errors_increased = True
        print(
            f"mypykaizen: ERROR - Number of total errors has increased from\n"
            f"            {allowable_errors.total_errors} to {total_errors}"
        )
    elif total_errors < allowable_errors.total_errors:
        print(
            f"mypykaizen: YAY - Number of total errors has DECREASED from\n"
            f"            {allowable_errors.total_errors} to {total_errors}!!\n"
            f"            GOOD JOB - have a 🍪!"
        )
        allowable_errors.total_errors = total_errors
        needs_save = True
    else:
        print(f"mypykaizen: total_errors unchanged at {total_errors}")

    # Check files in error counts
    if allowable_errors.files_in_error is None:
        # init
        print(f"mypykaizen: Initializing files_in_error to {files_in_error}")
        allowable_errors.files_in_error = files_in_error
        needs_save = True
    elif files_in_error > allowable_errors.files_in_error:
        # Errors have increased
        errors_increased = True
        print(
            f"mypykaizen: ERROR - Number of total files_in_error has increased from\n"
            f"            {allowable_errors.files_in_error} to {files_in_error}"
        )
    elif files_in_error < allowable_errors.files_in_error:
        # Decreased
        print(
            f"mypykaizen: YAY - Number of files_in_error errors has DECREASED from\n"
            f"            {allowable_errors.files_in_error} to {files_in_error}!!\n"
            f"            GOOD JOB - have a 🍪!"
        )
        allowable_errors.files_in_error = files_in_error
        needs_save = True
    else:
        # No change
        print(f"mypykaizen: files_in_error unchanged at {files_in_error}")

    # Display a simplified diff for new type checking errors which have been introduced
    if errors_increased and allowable_errors.last_full_output:
        import difflib

        print(f"mypykaizen: Differences")
        for l in difflib.unified_diff(allowable_errors.last_full_output, output_lines, n=0):
            if not l:
                continue

            # Only looking at the lines which start with + for new addition
            if l.startswith("+++"):
                continue
            if not l.startswith("+"):
                continue
            print(" " * 3, l[1:])  # Print adds an extra space

    # Note as coded, that this technically allows you to introduce new type errors if you
    # fix an equal number. This is largely unintentional but does make it super easy to
    # support refactoring usecases where a bunch of line numbers change
    if not errors_increased:
        allowable_errors.last_full_output = output_lines
        needs_save = True

    if needs_save:
        allowable_errors.save()

    if errors_increased:
        exit(11)  # Arbitrary but not 0, 1, or 2

    print("mypykaizen: DONE, but try and clean some of these problems up :)")
    assert total_errors + files_in_error > 0  # Exit on success earlier
    exit(0)


if __name__ == "__main__":
    main()
