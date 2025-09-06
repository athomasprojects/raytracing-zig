const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const sqrt = math.sqrt;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub const Vec3 = @Vector(3, f64);
pub const Point3 = Vec3;
pub const Colour = Vec3;

pub const sqrt2: f64 = @as(f64, math.sqrt2);
pub const sqrt3: f64 = sqrt(@as(f64, 3));
pub const infinity = std.math.inf(f64);
pub const tolerance = 1e-8;
pub const tolerance_vec: Vec3 = @splat(1e-8);

pub const zero: Vec3 = @splat(0);
pub const one: Vec3 = @splat(1);
pub const unit_vec_x: Vec3 = .{ 1, 0, 0 };
pub const unit_vec_y: Vec3 = .{ 0, 1, 0 };
pub const unit_vec_z: Vec3 = .{ 0, 0, 1 };

pub inline fn x(v: Vec3) f64 {
    return v[0];
}

pub inline fn y(v: Vec3) f64 {
    return v[1];
}

pub inline fn z(v: Vec3) f64 {
    return v[2];
}

pub fn splat(n: anytype) Vec3 {
    return switch (@TypeOf(n)) {
        comptime_int, usize => @splat(@floatFromInt(n)),
        comptime_float, f64 => @splat(n),
        else => unreachable,
    };
}

pub inline fn scale(v: Vec3, t: f64) Vec3 {
    return v * splat(t);
}

pub inline fn divScalar(v: Vec3, t: f64) Vec3 {
    return v / splat(t);
}

pub fn magnitude(v: Vec3) f64 {
    return @sqrt(magnitude2(v));
}

pub fn magnitude2(v: Vec3) f64 {
    return @reduce(.Add, v * v);
}

pub fn dot(u: Vec3, v: Vec3) f64 {
    return @reduce(.Add, u * v);
}

pub fn cross(u: Vec3, v: Vec3) Vec3 {
    // Shuffle index sets for cross product.
    // x = u.y*v.z - u.z*v.y
    // y = u.z*v.x - u.x*v.z
    // z = u.x*v.y - u.y*v.x

    const yzx_mask = [3]i32{ 1, 2, 0 };
    const zxy_mask = [3]i32{ 2, 0, 1 };
    const u_yzx: Vec3 = @shuffle(f64, u, undefined, yzx_mask);
    const v_zxy: Vec3 = @shuffle(f64, v, undefined, zxy_mask);
    const u_zxy: Vec3 = @shuffle(f64, u, undefined, zxy_mask);
    const v_yzx: Vec3 = @shuffle(f64, v, undefined, yzx_mask);
    return u_yzx * v_zxy - u_zxy * v_yzx;
}

pub fn normalize(v: Vec3) Vec3 {
    return divScalar(v, magnitude(v));
}

pub fn unit(v: Vec3) Vec3 {
    const mag = magnitude(v);
    if (mag == 0)
        return zero;

    return divScalar(v, mag);
}

/// Returns the reflected vector from an incident vector `v` on a surface with normal vector `n`.
pub fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v - scale(n, 2 * dot(v, n));
}

/// Returns the refracetd vector resulting from the incident vector `v` passing
/// through two media (whose ratio of refractive indices is given by `eta_i/eta_t`),
/// separated by a surface with normal vector `n`.
///
/// The result is calculated using Snell's law.
pub fn refract(v: Vec3, n: Vec3, refractive_index_ratio: f64) Vec3 {
    const cos_theta = @min(dot(-v, n), 1);
    const r_out_perp = scale(@mulAdd(Vec3, @splat(cos_theta), n, v), refractive_index_ratio);
    const r_out_parallel = scale(n, -@sqrt(@abs(1 - magnitude2(r_out_perp))));
    return r_out_perp + r_out_parallel;
}

pub inline fn eql(u: Vec3, v: Vec3) bool {
    return @reduce(.And, @abs(u - v) <= tolerance_vec);
}

pub inline fn nearZero(v: Vec3) bool {
    return @reduce(.And, @abs(v) < tolerance_vec);
}

pub fn isUnit(v: Vec3) bool {
    return std.math.approxEqAbs(f64, magnitude2(v), 1, std.math.floatEpsAt(f64, 1));
}

/// Returns random real in [0, 1).
pub inline fn randomFloat() f64 {
    return std.crypto.random.float(f64);
}

/// Returns a random real in [min,max).
pub fn randomFloatRange(min: f64, max: f64) f64 {
    return min + (max - min) * randomFloat();
}

/// Returns random vector whose elements are all in [0, 1).
pub fn randomVec() Vec3 {
    return .{
        randomFloat(),
        randomFloat(),
        randomFloat(),
    };
}

/// Returns random vector whose elements are all in [min, max).
pub fn randomVecRange(min: f64, max: f64) Vec3 {
    return .{
        randomFloatRange(min, max),
        randomFloatRange(min, max),
        randomFloatRange(min, max),
    };
}

pub fn randomUnitVec() Vec3 {
    while (true) {
        const v = randomVecRange(-1, 1);
        const mag_sq = magnitude2(v);
        if (std.math.floatEpsAt(f64, 0) < mag_sq and mag_sq <= 1) {
            return divScalar(v, sqrt(mag_sq));
        }
    }
}

/// Returns a random vector within the unit disk defined by x^2 + y^2 = 1.
pub fn randomVecInUnitDisk() Vec3 {
    while (true) {
        const v: Vec3 = .{
            randomFloatRange(-1, 1),
            randomFloatRange(-1, 1),
            0,
        };

        if (magnitude2(v) < 1)
            return v;
    }
}

/// Returns random unit vector on the same hemisphere as the surface normal.
pub fn randomVecOnHemisphere(normal: Vec3) Vec3 {
    const v: Vec3 = randomUnitVec();
    return if (dot(v, normal) > 0) v else -v;
}

pub fn hasTwoOnes(v: Vec3) bool {
    const abs_v: Vec3 = @abs(v);
    const comparison: @Vector(3, bool) = @abs(abs_v - one) <= tolerance_vec;
    return @reduce(.Add, @as(@Vector(3, u8), @intFromBool(comparison))) == 2;
}

pub fn isAllOnes(v: Vec3) bool {
    return eql(@abs(v), one);
}

pub fn isBasisVec(v: Vec3) bool {
    const abs_v: Vec3 = @abs(v);
    if (eql(abs_v, unit_vec_x)) return true;
    if (eql(abs_v, unit_vec_y)) return true;
    if (eql(abs_v, unit_vec_z)) return true;
}

pub fn print(v: Vec3) void {
    std.debug.print("{{{d}, {d}, {d}}}\n", .{ v[0], v[1], v[2] });
}

test "init vector" {
    const v: Vec3 = .{ 1, 2, 3 };
    try expectEqual(v, @Vector(3, f64){ 1, 2, 3 });
}

test "equality" {
    const v: Vec3 = .{ 6, 3, -5 };
    const u = [_]f64{ 6, 3, -5 };
    try expectEqual(v, u);
    try expect(eql(v, u));
}

test "create a vector from a scalar" {
    const c: f64 = 5.018972;
    const v = splat(c);
    const expected: @Vector(3, f64) = [_]f64{c} ** 3;
    try expectEqual(expected, v);
}

test "access vector components" {
    const v: Vec3 = .{ 1, 2, 3 };
    const vx = x(v);
    const vy = y(v);
    const vz = z(v);
    try expect(vx == 1);
    try expect(vy == 2);
    try expect(vz == 3);
}

test "scale" {
    const v = scale(Vec3{ 1, 2, -3.5 }, 2);
    try expect(@TypeOf(v) == Vec3);
    try expectEqual(v, .{ 2, 4, -7 });
}

test "scalar division" {
    const v = divScalar(Vec3{ 1, 2, 3 }, 2);
    try expectEqual(v, [_]f64{ 0.5, 1, 1.5 });
}

test "dot product" {
    const u: Vec3 = .{ 1, 0, 0 };
    const v: Vec3 = .{ 0, 1, 0 };
    const a: Vec3 = .{ 1, -1, 1 };
    const b: Vec3 = .{ 0.5, 1, 1 };
    try expect(dot(u, v) == 0);
    try expect(dot(a, b) == 0.5);
}

test "cross product" {
    const xx: Vec3 = .{ 1, 0, 0 };
    const yy: Vec3 = .{ 0, 1, 0 };
    const zz: Vec3 = .{ 0, 0, 1 };
    try expectEqual(cross(xx, yy), zz);
    try expectEqual(cross(yy, zz), xx);
    try expectEqual(cross(zz, xx), yy);
    try expectEqual(cross(xx, zz), -yy);
    try expectEqual(cross(xx, xx), zero);
    try expectEqual(cross(-xx, xx), zero);
}

test "length squared" {
    const u: Vec3 = .{ 1, 1, 0 };
    const v: Vec3 = .{ 1, 1, 1 };
    const w: Vec3 = .{ -1, 1, 0 };
    const u_l2 = magnitude2(u);
    const v_l2 = magnitude2(v);
    const w_l2 = magnitude2(w);
    try expect(u_l2 == 2);
    try expect(v_l2 == 3);
    try expect(w_l2 == 2);
}

test "length" {
    const u: Vec3 = .{ -1, 0, 0 };
    const v: Vec3 = .{ 1, 0, 1 };
    const w: Vec3 = .{ 1, 1, 1 };
    try expect(magnitude(u) == 1);
    try expect(magnitude(v) == sqrt2);
    try expect(magnitude(w) == sqrt3);
}

test "normalize" {
    const v: Vec3 = .{ 1, -1, -1 };
    const v_norm = normalize(v);
    const norm_vlen = magnitude(v_norm);
    try expect(norm_vlen == 1);
}

test "two elements are +/- 1" {
    const u: Vec3 = .{ 1, -1, 0 };
    const v: Vec3 = .{ 1, 1, 0 };
    const w: Vec3 = .{ -1, -1, 1 };
    try expect(hasTwoOnes(u));
    try expect(hasTwoOnes(v));
    try expect(!hasTwoOnes(w));
}

test "all +/- ones" {
    const u: Vec3 = .{ 1, -1, 1 };
    const v: Vec3 = .{ 1, 1, -1 };
    const w: Vec3 = .{ -1, -1, -1 };
    try expect(isAllOnes(u));
    try expect(isAllOnes(v));
    try expect(isAllOnes(w));
}

test "random float in [0,1)" {
    const val = randomFloat();
    try expect(@TypeOf(val) == f64);
    try expect(val >= 0 and val < 1);
}

test "random float in [min,max)" {
    const min: f64 = -100.5;
    const max: f64 = 426.8;
    const val = randomFloatRange(min, max);
    try expect(@TypeOf(val) == f64);
    try expect(val >= min and val < max);
}

test "random vec with all elements [0,1)" {
    const v = randomVec();
    try expect(@TypeOf(v) == Vec3);
    try expect(@reduce(.And, v >= splat(0)));
    try expect(@reduce(.And, v < splat(1)));
}

test "random vec with all element in [min,max)" {
    const min: f64 = -100.5;
    const max: f64 = 426.8;
    const v = randomVecRange(min, max);
    try expect(@TypeOf(v) == Vec3);
    try expect(@reduce(.And, v >= splat(min)));
    try expect(@reduce(.And, v < splat(max)));
}

test "unit vector" {
    const v: Vec3 = unit(.{ -2, 6, 4 });
    try expect(isUnit(v));
}

test "random unit vector" {
    const v = randomUnitVec();
    try expect(isUnit(v));
    try expect(@reduce(.And, v >= splat(-1)));
    try expect(@reduce(.And, v < splat(1)));
}

test "near zero" {
    try expect(!nearZero(tolerance_vec));
    try expect(nearZero(.{ 1e-13, -1e-13, 0 }));
}
