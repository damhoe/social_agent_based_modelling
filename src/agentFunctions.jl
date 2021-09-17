using DrWatson
@quickactivate "Social Agent Based Modelling"
using Agents

"define an agent for 2d grid space"
mutable struct DecisionAgentGrid <:AbstractAgent
    id::Int
    pos::Tuple{Int64,Int64}
    internalRationalInfluence::Float64
    state::Int
    state_old::Int
    affinity::Float64
    affinity_old::Float64
end

"define an agent for 2d grid space"
mutable struct DecisionAgentGraph <:AbstractAgent
    id::Int
    pos::Int
    internalRationalInfluence::Float64
    state::Int
    state_old::Int
    affinity::Float64
    affinity_old::Float64
end


"get random personal opinion on decision, skewed by inverted beta dist"
function randomInternalRational(model,distribution=Beta(2,5))
    return 1-rand(model.rng,distribution)
end
"get random affinity on decision, skewed by inverted beta dist"
function randomAffinity(model,distribution=Beta(2,5))
    return 1-rand(model.rng,distribution)
end

"function to add an agent to a space based on position"
function create_agent(model,position;initializeInternalRational=randomInternalRational,initializeAffinity=randomAffinity)
    initialInternalRational=initializeInternalRational(model)
    initialAffinity = initializeAffinity(model)
    initialState = 0
    add_agent!(position,
        model,
        #general parameters
        initialInternalRational,
        initialState,
        initialState,
        initialAffinity,
        initialAffinity
    )
end

function set_state!(state::Int,agent::AbstractAgent)
    agent.state = state
end

"computes rational decision for 0=no or 1=yes"
function rational_influence(agent,model)
    rationalAffinity = internalRational(agent,model) # no external rational component implemented yet
    return rationalAffinity-agent.affinity
end

"computes contribuition for rational decision from external sources"
function externalRational(agent,model)
    return model.externalRationalInfluence # first very simple case: model parameter controls external "forcing"
end
"computes contribuition for rational decision from internal sources"
function internalRational(agent,model)
    return agent.internalRationalInfluence # first very simple case: agent parameter controls internal "forcing"
end

"return distance of neighbour depending on space type of model"
function neigbourDistance(agent,neighbour,model)
    if typeof(model.space)<:Agents.GridSpace
        return edistance(agent,neighbour,model)
    else
        if typeof(model.space)<:Agents.GraphSpace
            if model.neighbourhoodExtent==1
                return 1 #shortcut to save expensive astar algorithm
            else
                return length(a_star(model.space.graph,agent.pos,neighbour.pos)) # get shortest path between a and neighbour
            end
        else
        error("distance for this space type not yet implemented")
        end
    end
end

"returns social influence based on neighbours state"
function state_social_influence(agent, model::AgentBasedModel)
    stateSocialInfluence::Real = 0
    sumNeighbourWeights = 0
    neighbours = nearby_agents(agent,model,model.neighbourhoodExtent)
    @inbounds for n in neighbours
        neighbourDistance=neigbourDistance(agent,n,model)
        stateSocialInfluence += (n.state_old-agent.state)/neighbourDistance
        sumNeighbourWeights +=1/neighbourDistance
    end
    if sumNeighbourWeights>0
        stateSocialInfluence /= sumNeighbourWeights #such that the maximum social influence is 1
    end
    return stateSocialInfluence * model.socialInfluenceFactor
end

"returns social influence based on neighbours affinity"
function affinity_social_influence(agent, model::AgentBasedModel)
    #calculate neighbours maximum distance based on
    affinitySocialInfluence = 0.0
    sumNeighbourWeights = 0
    neighbours = nearby_agents(agent,model,model.neighbourhoodExtent)
    @inbounds for n in neighbours
        neighbourDistance=neigbourDistance(agent,n,model)
        affinitySocialInfluence += (n.affinity_old-agent.affinity)/neighbourDistance
        sumNeighbourWeights +=1/neighbourDistance
    end
    if sumNeighbourWeights>0
        affinitySocialInfluence /= sumNeighbourWeights #such that the maximum social influence is 1
    end
    return affinitySocialInfluence * model.socialInfluenceFactor
end

"returns social influence based on neighbours state"
function combined_social_influence(agent, model::AgentBasedModel)
    combinedSocialInfluence = 0.0
    sumNeighbourWeights = 0
    neighbours = nearby_agents(agent,model,model.neighbourhoodExtent)
    @inbounds for n in neighbours
        neighbourDistance=neigbourDistance(agent,n,model)
        combinedSocialInfluence += ((n.affinity_old-agent.affinity)+(n.state_old-agent.state))/neighbourDistance
        sumNeighbourWeights +=1/neighbourDistance
    end
    if sumNeighbourWeights>0
        combinedSocialInfluence /= sumNeighbourWeights #such that the maximum social influence is 1
    end
    return combinedSocialInfluence * model.socialInfluenceFactor
end

"step function for agents"
function agent_step!(agent, model)
    if agent.state===0 # one way decision, no change for already "yes" decision, Q: should affinity still change?
        #compute new affinity
        agent.affinity = min(
        model.upperAffinityBound,
          max(
              model.lowerAffinityBound,
              agent.affinity
              +rational_influence(agent,model)
              +state_social_influence(agent,model)
          )
        )
        #change state if affinity large enough & switching still possible
        if model.numberSwitched<model.switchingLimit
            if (agent.affinity>=model.switchingBoundary)
                set_state!(1,agent)
                model.numberSwitched+=1
            end
        end
    end
    #store affinity and state for next timestep
    agent.affinity_old = agent.affinity
    agent.state_old = agent.state
end
