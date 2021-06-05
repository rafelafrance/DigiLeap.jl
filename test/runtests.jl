using Test
using DigiLeap

for t in ["box_calc"]
  include("$(t).jl")
end
