const std = @import("std");
const sqrt = std.math.sqrt;

const Vec3 = @import("vec3.zig").Vec3;
const Colour = @import("vec3.zig").Colour;

pub fn writeColour(writer: anytype, pixel_colour: Colour) !void {
    const r, const g, const b = pixel_colour;

    const c: f64 = 255.999;
    // Translate the [0,1] component values to the byte range [0,255].
    const r_byte: u8 = @intFromFloat(c * r);
    const g_byte: u8 = @intFromFloat(c * g);
    const b_byte: u8 = @intFromFloat(c * b);

    try writer.print("{d} {d} {d}\n", .{ r_byte, g_byte, b_byte });
}
