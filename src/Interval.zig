const Interval = @This();

min: f64,
max: f64,

pub const empty: Interval = .{
    .min = infinity,
    .max = -infinity,
};

pub const universe: Interval = .{
    .min = -infinity,
    .max = infinity,
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

pub fn padBy(self: *Interval, delta: f64) void {
    const padding = 0.5 * delta;
    self.min = self.min - padding;
    self.max = self.max + padding;
}

/// Returns the resulting interval of shifting the input interval's minimum and maximum by `offset`.
pub fn fromOffset(self: Interval, offset: f64) Interval {
    return .{ .min = self.min + offset, .max = self.max + offset };
}

const infinity = @import("vec.zig").infinity;
