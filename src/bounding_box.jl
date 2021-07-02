"""Bounding box types and functions."""

"""Bounding boxes in various formats format.

There will be N rows of 4 columns.
"""
PixelCoords = Matrix{Int}       # 4 columns [min_x min_y max_x max_y]
NormedCoords = Matrix{Float64}  # 4 columns [min_x min_y max_x max_y] normed to [0, 1]
CenterNormed = Matrix{Float64}  # [center_x center_y height width] normed to [0, 1]


"""An empty PixelCoords struct."""
empty_pixel_coords() = Matrix{Int}(undef, 0, 4)


"""Clamp the pixel coordinates to the image size before creation."""
function clamp_pixels(boxes::Matrix{Int}, image_size::Tuple{Int, Int})
    height, width = image_size
    boxes[:, 1] = clamp.(boxes[:, 1], 1, width)
    boxes[:, 2] = clamp.(boxes[:, 2], 1, height)
    boxes[:, 3] = clamp.(boxes[:, 3], 1, width)
    boxes[:, 4] = clamp.(boxes[:, 4], 1, height)
    PixelCoords(boxes)
end


"""Convert JSON bounding box to an array."""
function json2coords(coords::String)
    box = JSON.parse(coords)
    convert(Matrix{Int}, [box["left"] box["top"] box["right"] box["bottom"]])
end


"""Convert bounding box coordinates to JSON."""
bbox2json(bbox) = JSON.json(Dict(
    :left => bbox[1],
    :top => bbox[2],
    :right => bbox[3],
    :bottom => bbox[4],
))
