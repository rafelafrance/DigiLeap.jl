module DigiLeap


using JSON


export iou, bbox_nms, bbox_nms_groups, overlapping_bboxes,
    PixelCoords, NormedCoords, CenterNormed,
    json2coords, bbox2json, pixel_coords, clamp_pixels, orient_pixels, merge_boxes,
    scale_label, orient_label


include("box_calc.jl")
include("bounding_box.jl")
include("pipelines.jl")

end
