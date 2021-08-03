"""Draw a box with an option for thickness."""
function simple_box(image, coords; color=RGB(0, 0, 0), thickness=1)
	ll, tt, rr, bb = coords

	max_h, max_w = size(image)

	ll, rr = clamp(ll, 1, max_w), clamp(rr, 1, max_w)
	tt, bb = clamp(tt, 1, max_h), clamp(bb, 1, max_h)

	image[tt:clamp(tt+thickness, 1, max_h), ll:rr] .= color
	image[clamp(bb-thickness, 1, max_h):bb, ll:rr] .= color
	image[tt:bb, ll:clamp(ll+thickness, 1, max_w)] .= color
	image[tt:bb, clamp(rr-thickness, 1, max_w):rr] .= color
end


function imagesize(filename)
    wand = ImageMagick.MagickWand()
    success = ccall(
        (:MagickPingImage, ImageMagick.libwand),
        Bool,
        (Ptr{Cvoid}, Ptr{UInt8}),
        wand,
        filename
    )
    if !success
        throw(ParseError())
    end
    reverse(size(wand))
end
