from setuptools import find_packages, setup

setup(
    name="mypykaizen",
    version="0.11.0",
    license="MIT",
    packages=find_packages(exclude=["tests"]),
    author="Dan Hendry",
    description=(
        "Wrapper around mypy which prevents the number of typecheck errors from increasing "
        "but which does not force you to fix them all up front."
    ),
    keywords="mypy typecheck typechecking",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    platforms="any",
    zip_safe=True,
    install_requires=["mypy>=0.761", "dataclasses-json>=0.4.1",],
    python_requires=">=3.7.4",
    classifiers=[
        "Development Status :: 2 - Pre-Alpha",
        "Intended Audience :: Developers",
        "Operating System :: OS Independent",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
    ],
    entry_points={"console_scripts": ["mypykaizen=mypykaizen.mypykaizen:main"],},
    url="https://github.com/dhendry/mypykaizen/",
    project_urls={
        "Bug Tracker": "https://github.com/dhendry/mypykaizen/",
        "Documentation": "https://github.com/dhendry/mypykaizen/",
        "Source Code": "https://github.com/dhendry/mypykaizen/",
    },
)
