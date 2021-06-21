module DigiLeap

export iou, bbox_nms, bbox_nms_groups, overlapping_bboxes,
       simple_box


using JSON


include("box_calc.jl")
include("simple_draw.jl")

end
