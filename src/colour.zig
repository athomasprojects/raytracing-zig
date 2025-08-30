const std = @import("std");
const Colour = @import("vec.zig").Colour;
const Interval = @import("Interval.zig");

pub fn writeColour(writer: *std.Io.Writer, pixel_colour: Colour) !void {
    // Translate the [0,1] component values to the byte range [0,255].
    const intensity: Interval = .init(0, 0.999);
    const r_byte: u8 = @intFromFloat(256 * intensity.clamp(pixel_colour[0]));
    const g_byte: u8 = @intFromFloat(256 * intensity.clamp(pixel_colour[1]));
    const b_byte: u8 = @intFromFloat(256 * intensity.clamp(pixel_colour[2]));

    // Write out pixel colour components.
    try writer.print("{d} {d} {d}\n", .{ r_byte, g_byte, b_byte });
}
