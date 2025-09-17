const std = @import("std");
const vec = @import("vec.zig");

min: f64,
max: f64,
const Self = @This();

pub const empty: Self = .{
    .min = vec.infinity,
    .max = -vec.infinity,
};

pub const universe: Self = .{
    .min = -vec.infinity,
    .max = vec.infinity,
};

/// Creates the interval tightly enclosing the two input intervals.
pub fn expandToInclude(a: Self, b: Self) Self {
    return .{
        .min = @min(a.min, b.min), // if (a.min <= b.min) a.min else b.min,
        .max = @max(a.max, b.max), // if (a.max >= b.max) a.max else b.max,
    };
}

pub fn size(self: Self) f64 {
    return self.max - self.min;
}

pub fn contains(self: Self, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Self, x: f64) bool {
    return self.min < x and x < self.max;
}

pub fn clamp(self: Self, x: f64) f64 {
    return std.math.clamp(x, self.min, self.max);
}

pub fn expand(self: Self, delta: f64) Self {
    const padding = 0.5 * delta;
    return .{
        .min = self.min - padding,
        .max = self.max + padding,
    };
}
