const std = @import("std");
const ppm = @import("ppm.zig");

const ppm_fname = "image02.ppm";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const image_width: usize = 5 * 256;
    const image_height: usize = 5 * 256;
    const path = ppm.IMG_DIR ++ ppm_fname;
    try ppm.createFile(image_width, image_height, path, allocator);
}
