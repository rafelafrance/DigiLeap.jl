@testset "box_calc" begin

    @testset "iou" begin
        # =====================================================================
        # It handles disjoint boxes
        box1 = [10 10 20 20]
        box2 = [30 30 40 40]
        @test  iou(box1, box2) == 0.0

        box1 = [30 30 40 40]
        box2 = [10 10 20 20]
        @test  iou(box1, box2) == 0.0

        # =====================================================================
        # It handles one box inside of another box.
        box1 = [0 0 10 10]
        box2 = [0 0  5  5]
        area1 = 11.0 * 11.0
        area2 = 6.0 * 6.0
        @test iou(box1, box2) == area2 / (area1 + area2 - area2)
    end

    @testset "nms" begin
        # =====================================================================
        # It handles non-overlapping boxes
        boxes = [
            10 10 20 20;
            30 30 40 40;
            50 50 60 60
        ]
        @test nms(boxes) == boxes

        # =====================================================================
        # It handles one box inside another
        boxes = [
            100 100 400 400;
            110 110 390 390
        ]
        @test nms(boxes) == reshape(boxes[1, :], 1, 4)

        # =====================================================================
        # It handles overlap above the threshold
        boxes = [
            100 100 400 400;
            120 120 410 410
        ]
        @test nms(boxes) == reshape(boxes[1, :], 1, 4)

        # =====================================================================
        # It handles overlap below the threshold
        boxes = [
            100 100 400 400;
            395 395 500 500
        ]
        @test nms(boxes) == boxes[[2, 1], :]  # Boxes are sorted by area descending

        # =====================================================================
        # It handles an empty array
        boxes = Array{Int64}(undef, 0, 4)
        @test nms(boxes) == Array{Int64}(undef, 0, 4)
   end

end
