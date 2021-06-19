module DigiLeap

export iou, bbox_nms, bbox_nms_groups,
       simple_box


using JSON


include("box_calc.jl")
include("simple_draw.jl")

end
