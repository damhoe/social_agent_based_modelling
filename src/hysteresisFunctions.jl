using DrWatson
@quickactivate "Social Agent Based Modelling"
using Random
using Serialization
using DataFrames,DataFramesMeta
using CSV
using Glob
using Plots
using Distributions
using ProgressMeter

#plots a histogram of the combustion share distribution
# the path needs to be specified with .png at the end
function plot_combustion_share_histogram(p_combustion, path)
    Plots.histogram(p_combustion_range,xlabel="p_CombustionShare",ylabel="Count" )
    png(path)
end

#determine whether or not the grid already converged
#input is a vector of mean states of a model as collected in agents_df
function check_conversion(state_vec)
        diff_vec=diff(state_vec)
        if sum(diff_vec)==0
                return true
        else
                return false
        end
end

#conversion checker which can account for oscillating behaviour up to a period, pmax. setting pmax=1 gives same as above
function check_conversion_osc(state_vec,pmax=5)
        conv=false
        p=1
        while (conv==false) && (p<=pmax)
                diff_vec=diff(state_vec[1:p:end])
                if sum(diff_vec)==0
                        conv=true
                end
                p+=1
        end
        if conv==true
                return true
        else
                return false
        end
end

#generates an ensemble of starting models
#p_combustion: set of probabilities specifying the likelihood for a combustion car
#summary_results_directory: specifies where the summaries of the ensemble runs should be stored
#step_length: determines how many steps each model should take before checking conversion
#gridsize: size of the considered grid, number of agents is gridsize squared
#models_per_p: specifies how many different models should be considered per p in p_combustion
#seeds: set of seeds to generate models_per_p different grid population -> reused for each p
# To always get the same seeds insert them manually and specify Random.seed!(XXXX)
#store_model: specifies if the models should be stored (serialized) to be used as a starting ensemble later
#model_directory: specifies the directory for the storage of the models. If store_model is true and no path is specified there will be an error

function generate_ensemble(p_combustion,summary_results_directory;step_length=50,gridsize = 30, models_per_p = 100,seeds = rand(1234:9999,100),store_model = true, model_directory = "")
        if store_model==true && model_directory == ""
                return("Error: Please specify a model storage path!")
        end
        @showprogress 1 "P Variation..." for p_combustion in p_combustion_range
                ensemble_results = DataFrame(Seed = seeds, P_Combustion = p_combustion, Final_State_Average = -9999.0 , Final_Affinity_Average = -9999.0)
                @showprogress 1 "Seed Variation..." for i = 1:models_per_p
                        space = Agents.GridSpace((gridsize, gridsize); periodic = true, metric = :euclidean)
                        mixedHugeGaia = model_car_owners(mixed_population;kwargsPlacement=(combustionShare=p_combustion,),seed = seeds[i],space=space,tauSocial=3,tauRational=6,fuelCostKM=0,powerCostKM=0,priceCombustionCar=5000,priceElectricCar=5000)
                        converged = false
                        while converged == false
                                agent_df, model_df = run!(mixedHugeGaia, agent_step!,model_step!, step_length; adata = [(:state, mean),(:affinity,mean)])
                                converged= check_conversion_osc(agent_df[end-step_length:end,"mean_affinity"])
                        end

                        #add final values to dataframe
                        ensemble_results[ensemble_results.Seed .== seeds[i],:Final_State_Average].= agent_df[end,"mean_state"]
                        ensemble_results[ensemble_results.Seed .== seeds[i],:Final_Affinity_Average].= agent_df[end,"mean_affinity"]
                        #store model
                        if store_model == true
                                parameters = (p_combustion=p_combustion,seed=seeds[i])
                                filename = savename("model",parameters,".bin")
                                storage_path=joinpath(model_directory,filename)
                                mkpath(storage_path)
                                serialize(storage_path, mixedHugeGaia)
                        end
                end
        end
        filename = savename("ensemble_overview",(p_combustion=p_combustion),".csv")
        storage_path=joinpath(summary_results_directory,filename)
        mkpath(storage_path)
        CSV.write(storage_path, ensemble_results)
end
