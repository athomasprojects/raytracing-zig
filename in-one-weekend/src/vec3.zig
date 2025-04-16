const std = @import("std");
const math = std.math;
const sqrt = math.sqrt;

pub const Vec3Error = error{
    TooManyElements,
};

pub const F64x3 = @Vector(3, f64);
pub const sqrt2: f64 = sqrt(@as(f64, math.sqrt2));
pub const sqrt3: f64 = sqrt(@as(f64, 3));

pub const unit_vec_x = F64x3{ 1, 0, 0 };
pub const unit_vec_y = F64x3{ 0, 1, 0 };
pub const unit_vec_z = F64x3{ 0, 0, 1 };

pub const Point3 = F64x3;
pub const Colour = F64x3;

pub const Vec3 = struct {
    pub fn createEmpty() F64x3 {
        return @splat(0);
    }

    pub fn create(e0: f64, e1: f64, e2: f64) F64x3 {
        return .{ e0, e1, e2 };
    }

    pub fn fromScalar(value: f64) F64x3 {
        return @splat(value);
    }

    pub fn loadArr(arr: [3]f64) F64x3 {
        return .{ arr[0], arr[1], arr[2] };
    }

    pub fn x(v: F64x3) f64 {
        return v[0];
    }

    pub fn y(v: F64x3) f64 {
        return v[1];
    }

    pub fn z(v: F64x3) f64 {
        return v[2];
    }

    pub fn divByScalar(v: F64x3, t: f64) F64x3 {
        return v / @as(F64x3, @splat(t));
    }

    pub fn length(v: F64x3) f64 {
        const abs_v: F64x3 = @abs(v);
        if (isEql(abs_v, unit_vec_x) or isEql(abs_v, unit_vec_y) or isEql(abs_v, unit_vec_z)) {
            return 1;
        } else if (containsTwo(abs_v, 1.0)) {
            return sqrt2;
        } else if (containsThree(abs_v, 1.0)) {
            return sqrt3;
        }

        return sqrt(lengthSquared(v));
    }

    pub fn lengthSquared(v: F64x3) f64 {
        return @reduce(std.builtin.ReduceOp.Add, v * v);
    }

    pub fn dot(u: F64x3, v: F64x3) f64 {
        return @reduce(std.builtin.ReduceOp.Add, u * v);
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

    pub fn unitVector(v: F64x3) F64x3 {
        return divByScalar(v, length(v));
    }

    fn containsN(v: F64x3, value: f64, num: u8) bool {
        const comparison: @Vector(3, bool) = v == fromScalar(value);
        const count: u8 = @reduce(std.builtin.ReduceOp.Add, @as(@Vector(3, u8), @intFromBool(comparison)));
        return count == num;
    }

    pub fn containsTwo(v: F64x3, value: f64) bool {
        return containsN(v, value, 2);
    }

    pub fn containsThree(v: F64x3, value: f64) bool {
        return containsN(v, value, 3);
    }

    pub fn isEql(u: F64x3, v: F64x3) bool {
        return @reduce(std.builtin.ReduceOp.And, u == v);
    }

    pub fn print(v: F64x3) void {
        std.debug.print("{{{d}, {d}, {d}}}\n", .{ v[0], v[1], v[2] });
    }
};
