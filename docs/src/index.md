# Introduction

**UniversalMonteCarlo** is a high-performance library designed to achieve fast and advanced quantitative finance calculus using simple, well-designed, and syntactically-sweetened inputs. However, even though the library has a *simple input* philosophy, complex and general problems can be described and solved. In this context, the user can focus on what humans perform best: expert judgment and reaching conclusions.

You should really use this library if you fall into one of the following categories:

* You are new to finance and/or programming and want to test and analyze examples without having to learn the nuances of complex programming languages or inputs.
* You are an experienced Quant Analyst that wants to test complex financial derivatives without having to deploy a huge infrastructure, i.e. you just want to write and test what you have already derived in a piece of paper.
* You are an experienced Quant Developer with a fair amount of quantitative finance background. You will be able to expand and add functionalities to the library since UniversalMonteCarlo input file is processed by Julia itself.
* You are both experienced in Quantitative Finance as well as programming: you can go full hacker mode and apply the best of both worlds.

Briefly speaking, on the technical ground, UniversalMonteCarlo provides:

* Simulation of Stochastic Differential Equations (SDEs) through many different algorithms, removing the commonly imposed barrier in other libraries where SDE solvers are limited to the EulerMaruyama scheme or, in the best-case scenario, Milstein or Predictor-Corrector schemes.
* Simple definition of financial instruments and objects, which can be used in a comprehensive manner across the platform.
* Many valuation algorithms.

## Installation
The package can be installed with the Julia package manager. From the Julia REPL, type `]` to enter the Pkg REPL mode and run:
```julia
pkg> add https://github.com/SciQuant/UniversalMonteCarlo.jl.git
```

Or, equivalently, via the `Pkg` API:
```julia
julia> import Pkg; Pkg.add(PackageSpec(url = "https://github.com/SciQuant/UniversalMonteCarlo.jl.git"))
```

## Authors
UniversalMonteCarlo is being developed by [SciQuant](https://github.com/SciQuant), an organization dedicated to creating high-quality scientific software for the financial industry.
