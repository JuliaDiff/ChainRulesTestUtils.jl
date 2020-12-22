# ChainRulesTestUtils.jl

[![CI](https://github.com/JuliaDiff/ChainRulesTestUtils.jl/workflows/CI/badge.svg?branch=master)](https://github.com/JuliaDiff/ChainRulesTestUtils.jl/actions?query=workflow%3ACI)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)


[![](https://img.shields.io/badge/docs-master-blue.svg)](https://JuliaDiff.github.io/ChainRulesTestUtils.jl/dev)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaDiff.github.io/ChainRulesTestUtils.jl/stable)

> Collection of utilities for testing forward- and reverse-mode AD sensitivities.

`ChainRulesTestUtils.jl` is designed to help you test `ChainRulesCore.frule` and `ChainRulesCore.rrule` methods.
The main entry points are `ChainRulesTestUtils.frule_test`, `ChainRulesTestUtils.rrule_test`, and `ChainRulesTestUtils.test_scalar`
Currently this is done via testing the rules against numerical differentiation (using [`FiniteDifferences.jl`](https://github.com/JuliaDiff/FiniteDifferences.jl)).

`ChainRulesTestUtils.jl` is separate from [`ChainRulesCore.jl`](https://github.com/JuliaDiff/ChainRulesCore.jl) so that it can be a test-only dependency, allowing it to have potentially heavy dependencies, while keeping `ChainRulesCore.jl` as light-weight as possible.
