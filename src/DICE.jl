module DICE

using JuMP;
#Ipopt is distributed under the EPL.
#We don't package it here though, and assume you have this set up on your system already.
using Ipopt;

include("Abstractions.jl")

#DICE Versions
abstract type Version end

#Configuration options & parameters, model settings and output
include("BaseTypes.jl")

#Scenarios
abstract type Scenario end
include("Scenarios.jl")

struct DICENarrative
    constants::Options
    parameters::Parameters
    model::JuMP.Model
    scenario::Scenario
    version::Version
    variables::Variables
    equations::Equations
    results::Results
end

function Base.show(io::IO, ::MIME"text/plain", dice::DICENarrative)
    println(io, "$(dice.scenario) scenario using $(dice.version).")
    show(io, dice.model)
end

function solve end
function options end

export solve, options

# Test if system has HSL MA97 installed, fall back to MUMPS if not.
function linearSolver(solver_name::String = "ma97")
    prob = Ipopt.createProblem(1,[1.],[1.],1,[1.],[1.],1,1,sum,sum,sum,sum);
    Ipopt.addOption(prob, "sb", "yes");
    Ipopt.addOption(prob, "print_level", 0);
    # Initially, we must check that coinhsl is installed at all if we want a HSL solver.
    # If not, Ipopt will default to try and find any dynamically linked libhsl. If it
    # cannot find one it will hard panic and we can't capture that failure.
    if occursin("ma", solver_name)
        Ipopt.addOption(prob, "linear_solver", "ma27");
        try
            # No HSL was found on the system, we return with fallback.
            return runLinearSolverCheck(prob, solver_name)
        catch
            #Continue, we have access to at least some version of HSL
        end
    end
    try
        # Outer try will fail if solver string is not in the list of
        # possible Ipopt solvers.
        # For now that's ma27, ma57, ma77, ma86, ma97, pardiso, wsmp, mumps, custom
        Ipopt.addOption(prob, "linear_solver", solver_name);
        try
            # Inner try attempts to run the dummy program and will crash because
            # the dummy is malformed.
            # No error code will be returned if the solver is extant, and an Invalid_Option
            # if the library is not found.
            runLinearSolverCheck(prob, solver_name)
        catch
            # We can use the requested solver.
            solver_name
        end
    catch
        "mumps"
    end
end

function runLinearSolverCheck(prob::IpoptProblem, solver_name::String)
    result_code = Ipopt.solveProblem(prob);
    if Ipopt.ApplicationReturnStatus[result_code] == :Invalid_Option
        @info "Unable to set linear_solver = $(solver_name), defaulting to MUMPS."
        return "mumps"
    else
        error("Attempts to identify linear solvers on system returned unexpected results.");
    end
end

# Include all version implementations
include("2013R.jl")
include("2016.jl")

end
