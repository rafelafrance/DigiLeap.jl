module DigiLeap


using JSON


export iou, bbox_nms, bbox_nms_groups, overlapping_bboxes,
       PixelCoords, NormedCoords, CenterNormed,
       json2coords, bbox2json, pixel_coords, clamp_pixels!, orient_pixels,
       simple_box


include("box_calc.jl")
include("bounding_box.jl")
include("simple_draw.jl")

end
