using DrWatson
@quickactivate "Social Agent Based Modelling"
using Agents, Random, DataFrames, Graphs
using Distributions: Poisson, DiscreteNonParametric
using LinearAlgebra: diagind
using GraphPlot
using SNAPDatasets
using DelimitedFiles
using CSV


include(srcdir("agentFunctions.jl"))
include(srcdir("modelling.jl"))

watts_networks = watts_strogatz(1000,10,0.8)
bara_albert = barabasi_albert(1000,10,5)

watts_space = Agents.GraphSpace(watts_networks)
bara_space = Agents.GraphSpace(bara_albert)

function strip_isolates(g)
    isolates=findall(x->x==0, degree(g))
    isolates = reverse(isolates)
    for i in isolates
        rem_vertex!(g,i)
    end
    return g
end

strip_isolates(bara_space)

using GraphIO, Graphs
bara_albert = barabasi_albert(1000,10,5)
savegraph(open(datadir("test.net");write=true),bara_albert,"test",NETFormat())

seeds = rand(0:5000,100)
wattsStrogatz = model_decision_agents_SIR(mixed_population;space=bara_space,seed = seeds[1],tauRational=1,tauSocial=1, switchingLimit=2,detectionTime = 7,
	initialInfected = 0.005,
	deathRate = 0.03,
	reinfectionProtection = 180,
	infectionPeriod=30,
	transmissionUndetected = 1.1,
	transmissionDetected = 0.05,
	detectionProbability = 0.03) #according to Gutenberg study of U Mainz, 42.4% undetected overall ==> since multiple days of possible detection, lower individual detection probability.
	#  0.963^23 approx 0.42
	#TODO calibrate parameters properly


watts_agent_df, model_df = run!(wattsStrogatz, agent_step_SIR_latent!,model_step!, 100; adata = [:affinity,:SIR_status],parallel=true)
CSV.write(datadir("watts_strogatz_test_latent.csv"),watts_agent_df)

barabasiAlbert = model_decision_agents_SIR(mixed_population;space=bara_space,seed = seeds[1],tauRational=1,tauSocial=1, switchingLimit=2,detectionTime = 7,
	initialInfected = 0.01,
	deathRate = 0.03,
	reinfectionProtection = 180,
	infectionPeriod=30,
	transmissionUndetected = 0.5,
	transmissionDetected = 0.03,
	detectionProbability = 0.037) #according to Gutenberg study of U Mainz, 42.4% undetected overall ==> since multiple days of possible detection, lower individual detection probability.
	#  0.963^23 approx 0.42
	#TODO calibrate parameters properly

barabasiAlbert_agent_df, model_df = run!(barabasiAlbert, agent_step_SIR!,model_step!, 500; adata = [:affinity,:SIR_status],parallel=true)

CSV.write(datadir("barabasi_albert_test.csv"),barabasiAlbert_agent_df)


natural_spread = 0.35/0.97

# functions to calculate some network measures
#details see http://networksciencebook.com/chapter/10#network-epidemic table 10.3

"epidemic threshold for SIR modell on given graph"
function SIR_epidemic_threshold(graph)
    degrees = indegree(graph)
    mean_degree = mean(degrees)
    second_moment = mean(degrees.^2)
    return 1/(second_moment/mean_degree-1)
end

"epidemic threshold for SIS modell on given graph"
function SIS_epidemic_threshold(graph)
    degrees = indegree(graph)
    mean_degree = mean(degrees)
    second_moment = mean(degrees.^2)
    return mean_degree/second_moment
end

SIR_epidemic_threshold(watts_networks)
SIS_epidemic_threshold(watts_networks)
SIR_epidemic_threshold(bara_albert)
SIS_epidemic_threshold(bara_albert)