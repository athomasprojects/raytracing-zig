const std = @import("std");
const vec = @import("vec.zig");
const hittable = @import("hittable.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const HitRecord = hittable.HitRecord;
const HittableList = hittable.HittableList;
const Ray = @import("Ray.zig");

pub const Material = union(enum) {
    lambertian: struct {
        albedo: Colour,

        pub fn scatter(_: @This(), _: *Ray, rec: *HitRecord, scattered_ray: *Ray) bool {
            var scatter_dir: Vec3 = rec.normal + vec.randomUnitVec();
            // Catch degenerate scatter direction.
            if (vec.nearZero(scatter_dir))
                scatter_dir = rec.normal;

            scattered_ray.* = .init(rec.p, scatter_dir);
            return true;
        }
    },
    metal: struct {
        albedo: Colour,
        fuzz: f64,

        pub fn init(albedo: Colour, fuzz: f64) @This() {
            return .{
                .albedo = albedo,
                .fuzz = if (fuzz < 1) fuzz else 1,
            };
        }

        pub fn scatter(self: @This(), ray_in: *Ray, rec: *HitRecord, scattered_ray: *Ray) bool {
            var reflected: Vec3 = vec.reflect(ray_in.dir, rec.normal);
            reflected = vec.unit(reflected) + vec.scale(vec.randomUnitVec(), self.fuzz);
            scattered_ray.* = .init(rec.p, reflected);
            return vec.dot(scattered_ray.dir, rec.normal) > 0;
        }
    },
    dielectric: struct {
        // zig fmt: off
        refraction_index: f64, // Refractive index in vacuum or air, or the
                               // ratio of the material's refractive index over
                               // the refractive index of the enclosing media.
        albedo: Colour,

        // zig fmt: on
        pub fn scatter(self: @This(), ray_in: *Ray, rec: *HitRecord, scattered_ray: *Ray) bool {
            const ri = if (rec.front_face)
                1 / self.refraction_index
            else
                self.refraction_index;

            const unit_direction = vec.unit(ray_in.dir);
            const cos_theta = @min(vec.dot(-unit_direction, rec.normal), 1);
            const sin_theta = @sqrt(@abs(1 - cos_theta * cos_theta));

            const cannot_refract = ri * sin_theta > 1;

            const direction = if (cannot_refract)
                vec.reflect(unit_direction, rec.normal)
            else
                vec.refract(unit_direction, rec.normal, ri);

            scattered_ray.* = .init(rec.p, direction);
            return true;
        }
    },

    pub fn scatter(self: Material, ray_in: *Ray, rec: *HitRecord, scattered: *Ray) bool {
        return switch (self) {
            inline else => |m| m.scatter(ray_in, rec, scattered),
        };
    }
};
