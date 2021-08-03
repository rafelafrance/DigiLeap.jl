module DigiLeap


using JSON
using Logging


export iou, bbox_nms, bbox_nms_groups, overlapping_bboxes,
    PixelCoords, NormedCoords, CenterNormed,
    json2coords, bbox2json, pixel_coords, clamp_pixels, orient_pixels, merge_boxes,
    reconcile
    # scale_label, orient_label


include("box_calc.jl")
include("bounding_box.jl")
include("reconcile.jl")
# include("pipelines.jl")

end
