const std = @import("std");
const vec = @import("vec.zig");

min: f64,
max: f64,
const Interval = @This();

pub const empty: Interval = .{
    .min = vec.infinity,
    .max = -vec.infinity,
};

pub const universe: Interval = .{
    .min = -vec.infinity,
    .max = vec.infinity,
};

/// Creates the interval tightly enclosing the two input intervals.
pub fn expandToInclude(a: Interval, b: Interval) Interval {
    return .{
        .min = @min(a.min, b.min), // if (a.min <= b.min) a.min else b.min,
        .max = @max(a.max, b.max), // if (a.max >= b.max) a.max else b.max,
    };
}

pub fn size(self: Interval) f64 {
    return self.max - self.min;
}

pub fn contains(self: Interval, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Interval, x: f64) bool {
    return self.min < x and x < self.max;
}

pub fn clamp(self: Interval, x: f64) f64 {
    return std.math.clamp(x, self.min, self.max);
}

pub fn expandBy(self: *Interval, delta: f64) void {
    const padding = 0.5 * delta;
    self.min = self.min - padding;
    self.max = self.max + padding;
}
