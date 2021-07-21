"""Bounding box types and functions."""


PixelCoords = Matrix{Int}
NormedCoords = Matrix{Float64}
CenterNormed = Matrix{Float64}


pixel_coords()::Matrix{Int} = Matrix{Int}(undef, 0, 4)


"""Convert JSON bounding box to an array."""
function json2coords(coords)::Matrix{Int}
    box = JSON.parse(coords)
    convert(Matrix{Int}, [box["left"] box["top"] box["right"] box["bottom"]])
end


"""Convert bounding box coordinates to JSON."""
bbox2json(bbox)::String = JSON.json(Dict(
    :left => bbox[1],
    :top => bbox[2],
    :right => bbox[3],
    :bottom => bbox[4],
))


"""Clamp pixels to image size."""
function clamp_pixels(coords::Matrix{Int}, image_size::Tuple{Int,Int})::Matrix{Int}
    height, width = image_size
    boxes = zeros(Int, size(coords))
    boxes[:, 1] = clamp.(coords[:, 1], 1, width)
    boxes[:, 2] = clamp.(coords[:, 2], 1, height)
    boxes[:, 3] = clamp.(coords[:, 3], 1, width)
    boxes[:, 4] = clamp.(coords[:, 4], 1, height)
    boxes
end


"""Orient pixels so left is <= right and top is <= bottom."""
function orient_pixels(coords::Matrix{Int})::Matrix{Int}
    boxes = zeros(Int, size(coords))
    boxes[:, 1] = min.(coords[:, 1],  coords[:, 3])
    boxes[:, 2] = min.(coords[:, 2],  coords[:, 4])
    boxes[:, 3] = max.(coords[:, 1],  coords[:, 3])
    boxes[:, 4] = max.(coords[:, 2],  coords[:, 4])
    boxes
end


"""Merge a group of boxes into a single "best" box."""
function merge_boxes(boxes::Matrix{Int})::Matrix{Int}
    min_x = minimum(boxes[:, 1])
    min_y = minimum(boxes[:, 2])
    max_x = maximum(boxes[:, 3])
    max_y = maximum(boxes[:, 4])
    box = convert(Matrix{Int}, [min_x min_y max_x max_y])
    box
end


# ######################################################################################
# """Pixel coordinates of bounding boxes.

# In [left top right bottom] = [min_x min_y max_x max_y] order.
# """

# struct PixelCoords
#     boxes::Matrix{Int}
#     image_size::Union{Missing, Tuple{Int,Int}}

#     function PixelCoords(coords::Matrix{Int}, image_size::Tuple{Int,Int})
#         boxes = orient_pixels(coords)
#         boxes = clamp_pixels(boxes, image_size)
#         new(boxes, image_size)
#     end

#     function PixelCoords(coords::Matrix{Int}, image_size::Missing)
#         boxes = orient_pixels(coords)
#         new(boxes, image_size)
#     end
# end

# PixelCoords(boxes::Matrix{Int}) = PixelCoords(boxes, missing)
# PixelCoords() = PixelCoords(empty_pixels(), missing)


# ######################################################################################
# """Normed bounding box coordinates.

# In [left top right bottom] = [min_x min_y max_x max_y] order. All coordinates are
# normed to [0.0, 1.0] of the image size.
# """

# struct NormedCoords
#     boxes::Matrix{Float64}
#     image_size::Union{Missing, Tuple{Int,Int}}
# end

# NormedCoords(boxes::Matrix{Float64}) = NormedCoords(copy(boxes), missing)
# NormedCoords() = NormedCoords(Matrix{Float64}(undef, 0, 4), missing)


# """Convert bounding boxes to normed bounding boxes."""
# function NormedCoords(coords::Matrix{Int}, image_size::Tuple{Int,Int})
#     normed = convert(Matrix{Float64}, coords)
#     normed .-= 1.0

#     image_size = image_size .- 1
#     height, width = convert(Tuple{Float64,Float64}, image_size)

#     normed[:, 1] ./= width
#     normed[:, 2] ./= height
#     normed[:, 3] ./= width
#     normed[:, 4] ./= height

#     NormedCoords(normed, pixels.image_size)
# end


# """Convert pixel bounding boxes to normed bounding boxes."""
# function NormedCoords(pixels::PixelCoords)
#     if ismissing(pixels.image_size)
#         error("PixelCoords.image_size is missing.")
#     end
#     NormedCoords(pixels.boxes, pixels.image_size)
# end


# ######################################################################################
# """Center normed bounding box coordinates.

# In [center_x center_y height width] order. All coordinates are normed to [0.0, 1.0]
# of the image size. the center is the midpoint of the x & y box coordinates. The height
# and width are the box diameters of the x & y coordinates.
# """

# struct CenterNormed
#     boxes::Matrix{Float64}
#     image_size::Union{Missing, Tuple{Int,Int}}
# end

# CenterNormed(boxes) = CenterNormed(boxes, missing)
# CenterNormed() = CenterNormed(Matrix{Float64}(undef, 0, 4), missing)


# """Convert pixel bounding boxes to center normed bounding boxes."""
# function CenterNormed(pixels::PixelCoords)
#     if ismissing(pixels.image_size)
#         error("PixelCoords.image_size is missing.")
#     end
#     centered = convert(Matrix{Float64}, pixels.boxes)
#     centered .-= 1.0  # Shift to 0-based offset

#     pixels = clamp_pixels(pixels, image_size)
#     centered = zeros(CenterNormed, size(pixels))
#     centered
# end


# """Convert normed bounding boxes to normed & centered boxes."""
# function CenterNormed(normed::NormedCoords)::CenterNormed
#     centered = zeros(CenterNormed, size(normed))

#     centered[:, center_x] = (normed[:, left] .+ normed[:, right])  ./ 2.0
#     centered[:, center_y] = (normed[:, top]  .+ normed[:, bottom]) ./ 2.0

#     centered[:, box_h] = normed[:, bottom] .- normed[:, top]
#     centered[:, box_w] = normed[:, right]  .- normed[:, left]

#     centered
# end
