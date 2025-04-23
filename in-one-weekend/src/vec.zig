const std = @import("std");
const math = std.math;
const sqrt = math.sqrt;

pub const F64x3 = @Vector(3, f64);
pub const Point3 = F64x3;
pub const Colour = F64x3;

pub const sqrt2: f64 = @as(f64, math.sqrt2);
pub const sqrt3: f64 = sqrt(@as(f64, 3));

pub const unit_vec_x = F64x3{ 1, 0, 0 };
pub const unit_vec_y = F64x3{ 0, 1, 0 };
pub const unit_vec_z = F64x3{ 0, 0, 1 };

pub const Vec3 = struct {
    pub inline fn createEmpty() F64x3 {
        return @splat(0);
    }

    pub inline fn create(e0: f64, e1: f64, e2: f64) F64x3 {
        return .{ e0, e1, e2 };
    }

    pub inline fn fromScalar(value: f64) F64x3 {
        return @splat(value);
    }

    pub inline fn loadArr(arr: [3]f64) F64x3 {
        return .{ arr[0], arr[1], arr[2] };
    }

    pub inline fn x(v: F64x3) f64 {
        return v[0];
    }

    pub inline fn y(v: F64x3) f64 {
        return v[1];
    }

    pub inline fn z(v: F64x3) f64 {
        return v[2];
    }

    pub inline fn scale(v: F64x3, t: f64) F64x3 {
        return v * @as(F64x3, @splat(t));
    }

    pub inline fn divScalar(v: F64x3, t: f64) F64x3 {
        return v / @as(F64x3, @splat(t));
    }

    pub fn length(v: F64x3) f64 {
        if (isUnitAxis(v)) {
            return 1;
        } else if (hasTwoOnes(v)) {
            return sqrt2;
        } else if (isAllOnes(v)) {
            return sqrt3;
        }

        return sqrt(lengthSquared(v));
    }

    pub fn lengthSquared(v: F64x3) f64 {
        return @reduce(.Add, v * v);
    }

    pub fn dot(u: F64x3, v: F64x3) f64 {
        return @reduce(.Add, u * v);
    }

    pub fn cross(u: F64x3, v: F64x3) F64x3 {
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

    pub fn normalize(v: F64x3) F64x3 {
        const len = length(v);
        return divScalar(v, len);
    }

    pub fn hasTwoOnes(v: F64x3) bool {
        const abs_v: F64x3 = @abs(v);
        const comparison: @Vector(3, bool) = abs_v == fromScalar(1);
        return @reduce(.Add, @as(@Vector(3, u8), @intFromBool(comparison))) == 2;
    }

    pub fn isAllOnes(v: F64x3) bool {
        const abs_v: F64x3 = @abs(v);
        return abs_v[0] == 1 and abs_v[0] == abs_v[1] and abs_v[1] == abs_v[2];
    }

    pub fn isUnitAxis(v: F64x3) bool {
        const abs_v: F64x3 = @abs(v);
        return isEql(abs_v, unit_vec_x) or isEql(abs_v, unit_vec_y) or isEql(abs_v, unit_vec_z);
    }

    pub inline fn isEql(u: F64x3, v: F64x3) bool {
        return @reduce(.And, u == v);
    }

    pub fn print(v: F64x3) void {
        std.debug.print("{{{d}, {d}, {d}}}\n", .{ v[0], v[1], v[2] });
    }
};
