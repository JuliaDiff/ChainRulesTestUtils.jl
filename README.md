# ChainRulesTestUtils.jl

[![Travis](https://travis-ci.org/JuliaDiff/ChainRulesTestUtils.jl.svg?branch=master)](https://travis-ci.org/JuliaDiff/ChainRulesTestUtils.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

> Utilities for testing forward- and reverse-mode AD sensitivities.

`ChainRulesTestUtils.jl` is designed to help you test `ChainRulesCore.frule` and `ChainRulesCore.rrule` methods.
Currently this is done via testing the rules against numerical differentiation (using [`FiniteDifferences.jl`](https://github.com/JuliaDiff/FiniteDifferences.jl)).

`ChainRulesTestUtils.jl` is separate from [`ChainRulesCore.jl`](https://github.com/JuliaDiff/ChainRulesCore.jl) so that it can be a test-only dependency, allowing it to have potentially heavy dependencies, while keeping `ChainRulesCore.jl` as light-weight as possible.
