"""Enlarge the label if needed."""
function scale_label(image; threshold=512, factor=2.0)
    h, w = size(image)

    if h < threshold || w < threshold
        image = imresize(image, size(image) .* factor)
    end

    image
end


"""Orient the label to 90°, 180°, or 270°."""
function orient_label(image; conf_low=15.0, conf_high=100.0)
end
