# Does Inequality Harm the Climate? An Agent-Based Model with Endogenous Climate Policy

Version: Jan 2026

This agent-based model examines how income inequality shapes environmental outcomes through household consumption patterns and political support for climate policy.

## Getting Started

These instructions will allow you to run the model on your system.

### System Requirements and Installation

To run the code, you need to install **[Julia](https://julialang.org/)** (v1.10.0). Additionally, the following packages need to be installed:


* [Agents](https://juliadynamics.github.io/Agents.jl/stable/) - Version 6.2.10
* [ArgParse](https://argparsejl.readthedocs.io/en/latest/argparse.html) - Version 1.2.0
* [CSV] https://csv.juliadata.org/stable/ - Version 0.10.15
* [DataFrames](https://juliadata.github.io/) - Version 1.8.1
* [DataStructures](https://juliacollections.github.io/DataStructures.jl/latest/) - Version 0.18.22
* [Distributions](https://github.com/JuliaStats/Distributions.jl) - Version 0.25.122
* [OrderedCollections](https://github.com/JuliaCollections/OrderedCollections.jl) - Version 1.8.1
* [Plots](http://docs.juliaplots.org/) - Version 1.41.1
* [StatsBase](https://juliastats.org/StatsBase.jl/stable/) - Version 0.34.7
* [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) - Version 0.15.8


In order to install a package, start *julia* and execute the following command:

```
using Pkg; Pkg.add("<package name>")
```

### Running The Model

The model implementation is located in the *model/* folder. In order to run the model, the initial state has to be set up. Our baseline initialization is specified in the *experiments/init_baseline.jl* file. By default, the subset of data stored during a simulation run is defined in the *experiments/data_collection.jl* file.

To conduct an experiment and execute several runs of the model (batches) in parallel, execute *run_exp.jl*. This requires to set-up the experiment(s) in a configuration file, see *experiments/baseline.jl* as an example. In order to execute an experiment, use the following command:

```
julia -p <no_cpus> run_exp.jl <config-file> [--chunk <i>] [--no_chunks <n>]
```

The julia parameter *-p <no_cpus>* specifies how many CPU cores will be used in parallel. The *--chunk* and *--no_chunk* parameters are optional and can be used to break up the experiment into several chunks, e.g., to distribute execution among different machines.

Plots from experiments can be created by using the following command:

```
julia plot_exp.jl <config-file>
```

By default, data and plots will be stored in the *data/* folder.

### Quick Test Runs with main.jl

For quick tests and exploration of single mechanisms, you can run the simplified script *main.jl*. It executes a single run of the baseline model and provides a convenient way to check model behavior or inspect generated data without setting up a full experiment. To execute it, run:

```
julia main.jl
```
Note: *main.jl* is not intended for systematic experiments or batch execution. For proper experiments, please use *run_exp.jl* with the respective configuration files as described above.

## Authors

Fiona Borsetzky, Dirk Kohlweyer

## Further Links

* [ETACE](https://www.uni-bielefeld.de/fakultaeten/wirtschaftswissenschaften/lehrbereiche/etace/) - Economic Theory and Computational Economics, Bielefeld University
