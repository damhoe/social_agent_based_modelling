# script to run huge ensemble simulations
using Distributed
using Random
using BenchmarkTools
addprocs(Sys.CPU_THREADS-1)
@everywhere begin
    include("../agentFunctions.jl")
    include("../modelling.jl")
    include("../populationCreation.jl")
end
# create initialize function for model creation, needed for paramscan methods:
@everywhere begin
    function initialize(;args ...)
        return model_car_owners(mixed_population;args ...)
    end
end
# generate multiple models with different seeds
@everywhere begin
    seeds = 1000:1002
    spaceDims = (100,100)
    @time ensemble =   [initialize(;seed=i_seed,space=Agents.GridSpace(spaceDims;periodic=true,metric = :euclidean)) for i_seed in seeds];
end
# defining data to be collected for agents
@everywhere adata = [(:state, mean),(:rationalOptimum, mean), (:carAge, mean),(:affinity, mean)]

# running enseble simulation
@btime adf, = ensemblerun!(ensemble, agent_step!, model_step!, 10; adata,parallel=false)
@btime adf, = ensemblerun!(ensemble, agent_step!, model_step!, 10; adata,parallel=true)