module DigiLeap

export iou, bbox_nms, bbox_nms_groups,
       simple_box


using JSON


for i in ["box_calc", "simple_draw"]
    include("$(i).jl")
end

end
