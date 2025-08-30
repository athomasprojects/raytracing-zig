const std = @import("std");
const math = std.math;
const sqrt = math.sqrt;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub const Vec3 = @Vector(3, f64);
pub const Point3 = Vec3;
pub const Colour = Vec3;

pub const sqrt2: f64 = @as(f64, math.sqrt2);
pub const sqrt3: f64 = sqrt(@as(f64, 3));
pub const infinity = std.math.inf(f64);
pub const allowed_float_min: comptime_float = 1e-160;

pub const unit_vec_x = Vec3{ 1, 0, 0 };
pub const unit_vec_y = Vec3{ 0, 1, 0 };
pub const unit_vec_z = Vec3{ 0, 0, 1 };

pub const empty: Vec3 = @splat(0);

pub inline fn init(e0: f64, e1: f64, e2: f64) Vec3 {
    return .{ e0, e1, e2 };
}

pub inline fn fromScalar(value: f64) Vec3 {
    return @splat(value);
}

pub inline fn loadArr(arr: [3]f64) Vec3 {
    return arr;
}

pub inline fn x(v: Vec3) f64 {
    return v[0];
}

pub inline fn y(v: Vec3) f64 {
    return v[1];
}

pub inline fn z(v: Vec3) f64 {
    return v[2];
}

pub inline fn scale(v: Vec3, t: f64) Vec3 {
    return v * @as(Vec3, @splat(t));
}

pub inline fn divScalar(v: Vec3, t: f64) Vec3 {
    return v / @as(Vec3, @splat(t));
}

pub fn length(v: Vec3) f64 {
    if (isUnitAxis(v)) return 1;
    if (hasTwoOnes(v)) return sqrt2;
    if (isAllOnes(v)) return sqrt3;
    return sqrt(lengthSquared(v));
}

pub fn lengthSquared(v: Vec3) f64 {
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

    const yzx_mask = [_]i32{ 1, 2, 0 };
    const zxy_mask = [_]i32{ 2, 0, 1 };
    const u_yzx = @shuffle(f64, u, u, yzx_mask);
    const v_zxy = @shuffle(f64, v, v, zxy_mask);
    const u_zxy = @shuffle(f64, u, u, zxy_mask);
    const v_yzx = @shuffle(f64, v, v, yzx_mask);

    return u_yzx * v_zxy - u_zxy * v_yzx;
}

pub fn normalize(v: Vec3) Vec3 {
    const len = length(v);
    return divScalar(v, len);
}

pub fn hasTwoOnes(v: Vec3) bool {
    const abs_v: Vec3 = @abs(v);
    const comparison: @Vector(3, bool) = abs_v == fromScalar(1);
    return @reduce(.Add, @as(@Vector(3, u8), @intFromBool(comparison))) == 2;
}

pub fn isAllOnes(v: Vec3) bool {
    const abs_v: Vec3 = @abs(v);
    return abs_v[0] == 1 and abs_v[0] == abs_v[1] and abs_v[1] == abs_v[2];
}

pub fn isUnitAxis(v: Vec3) bool {
    const abs_v: Vec3 = @abs(v);
    return eql(abs_v, unit_vec_x) or eql(abs_v, unit_vec_y) or eql(abs_v, unit_vec_z);
}

pub inline fn isUnitVec(v: Vec3) bool {
    return lengthSquared(v) == 1;
}

pub inline fn eql(u: Vec3, v: Vec3) bool {
    return @reduce(.And, u == v);
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

pub fn unitVec(v: Vec3) Vec3 {
    return divScalar(v, length(v));
}

pub fn randomUnitVec() Vec3 {
    while (true) {
        const p = randomVecRange(-1, 1);
        const len_square: f64 = lengthSquared(p);
        if (allowed_float_min < len_square and len_square <= 1) {
            return divScalar(p, sqrt(len_square));
        }
    }
}

/// Returns random unit vector on the same hemisphere as the surface normal.
pub fn randomVecOnHemisphere(normal: Vec3) Vec3 {
    const on_unit_sphere: Vec3 = randomUnitVec();
    if (dot(on_unit_sphere, normal) > 0) {
        // The random vector is in the same hemisphere as the surface normal.
        return on_unit_sphere;
    }
    return -on_unit_sphere;
}

pub fn print(v: Vec3) void {
    std.debug.print("{{{d}, {d}, {d}}}\n", .{ v[0], v[1], v[2] });
}

test "init vector" {
    const v = init(1, 2, 3);
    try expectEqual(v, @Vector(3, f64){ 1, 2, 3 });
}

test "empty vector" {
    const v = empty;
    try expectEqual(v, [_]f64{0} ** 3);
    try expectEqual(v, @splat(0));
}

test "equality" {
    const v: Vec3 = .{ 6, 3, -5 };
    const u = [_]f64{ 6, 3, -5 };
    try expect(@TypeOf(v) == @TypeOf(u));
    try expectEqual(v, u);
    try expect(eql(v, u));
}

test "create a vector from a scalar" {
    const c: f64 = 5.018972;
    const v = fromScalar(c);
    const expected: @Vector(3, f64) = [_]f64{c} ** 3;
    try expectEqual(v, expected);
}

test "create a vector from an array" {
    const arr: [3]f64 = .{ 2, 5, -6.9 };
    try expectEqual(loadArr(arr), arr);
}

test "access vector components" {
    const v = init(1, 2, 3);
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
    try expectEqual(v, Vec3{ 2, 4, -7 });
}

test "scalar division" {
    const v = divScalar(Vec3{ 1, 2, 3 }, 2);
    try expectEqual(v, [_]f64{ 0.5, 1, 1.5 });
}

test "dot product" {
    const u = init(1, 0, 0);
    const v = init(0, 1, 0);

    const a = init(1, -1, 1);
    const b = init(0.5, 1, 1);
    try expect(dot(u, v) == 0);
    try expect(dot(a, b) == 0.5);
}

test "cross product" {
    const xx = init(1, 0, 0);
    const yy = init(0, 1, 0);
    const zz = init(0, 0, 1);
    const zero = empty;
    try expectEqual(cross(xx, yy), zz);
    try expectEqual(cross(yy, zz), xx);
    try expectEqual(cross(zz, xx), yy);
    try expectEqual(cross(xx, zz), -yy);
    try expectEqual(cross(xx, xx), zero);
    try expectEqual(cross(-xx, xx), zero);
}

test "length squared" {
    const u = init(1, 1, 0);
    const v = init(1, 1, 1);
    const w = init(-1, 1, 0);
    const u_l2 = lengthSquared(u);
    const v_l2 = lengthSquared(v);
    const w_l2 = lengthSquared(w);
    try expect(u_l2 == 2);
    try expect(v_l2 == 3);
    try expect(w_l2 == 2);
}

test "length" {
    const u = init(-1, 0, 0);
    const v = init(1, 0, 1);
    const w = init(1, 1, 1);
    try expect(length(u) == 1);
    try expect(length(v) == sqrt2);
    try expect(length(w) == sqrt3);
}

test "normalize" {
    const v = init(1, -1, -1);
    const v_norm = normalize(v);
    const norm_vlen = length(v_norm);
    try expect(norm_vlen == 1);
}

test "two elements are +/- 1" {
    const u = init(1, -1, 0);
    const v = init(1, 1, 0);
    const w = init(-1, -1, 1);

    try expect(hasTwoOnes(u));
    try expect(hasTwoOnes(v));
    try expect(!hasTwoOnes(w));
}

test "all +/- ones" {
    const u = init(1, -1, 1);
    const v = init(1, 1, -1);
    const w = init(-1, -1, -1);

    try expect(isAllOnes(u));
    try expect(isAllOnes(v));
    try expect(isAllOnes(w));
}

test "random float in [0,1)" {
    const val = randomFloat();
    try expect(@TypeOf(val) == f32);
    try expect(val >= 0 and val < 1);
}

test "random float in [min,max)" {
    const min: f64 = -100.5;
    const max: f64 = 426.8;
    const val = randomFloatRange(min, max);
    try expect(@TypeOf(val) == f32);
    try expect(val >= min and val < max);
}

test "random vec with all elements [0,1)" {
    const v = randomVec();
    try expect(@TypeOf(v) == Vec3);
    try expect(@reduce(.And, v >= @as(Vec3, @splat(0)) and v < @as(Vec3, @splat(1))), true);
}

test "random vec with all element in [min,max)" {
    const min: f64 = -100.5;
    const max: f64 = 426.8;
    const v = randomVecRange(min, max);
    try expect(@TypeOf(v) == Vec3);
    try expect(@reduce(.And, v >= @as(Vec3, @splat(min)) and v < @as(Vec3, @splat(max))), true);
}

test "is unit vector" {
    const v: Vec3 = .{ -2, 6, 4 };
    const unit = divScalar(v, length(v));
    try expect(isUnitVec(unit));
}

test "random unit vector" {
    const v = randomUnitVec();
    try expect(@TypeOf(v) == Vec3);
    try expect(isUnitVec(v));
}
