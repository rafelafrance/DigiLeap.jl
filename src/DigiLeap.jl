module DigiLeap


using JSON


export iou, bbox_nms, bbox_nms_groups, overlapping_bboxes,
       PixelCoords, NormedCoords, CenterNormed,
       clamp_pixels, empty_pixel_coords, json2coords, bbox2json,
       simple_box


include("box_calc.jl")
include("bounding_box.jl")
include("simple_draw.jl")

end
