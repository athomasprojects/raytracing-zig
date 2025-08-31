const std = @import("std");
const vec = @import("vec.zig");
const hittable = @import("hittable.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const HitRecord = hittable.HitRecord;
const Hittable = hittable.Hittable;
const HittableList = hittable.HittableList;
const Ray = @import("Ray.zig");

pub const Material = union(enum) {
    lambertian: Colour,
    metal: Metal,

    pub fn scatter(self: Material, ray_in: *Ray, rec: *HitRecord, scattered: *Ray) bool {
        return switch (self) {
            .lambertian => |_| lambertianScatter(ray_in, rec, scattered),
            .metal => |metal| metal.metalScatter(ray_in, rec, scattered),
        };
    }

    pub fn lambertianScatter(ray_in: *Ray, rec: *HitRecord, scattered_ray: *Ray) bool {
        _ = ray_in;
        var scatter_dir: Vec3 = rec.normal + vec.randomUnitVec();
        // Catch degenerate scatter direction.
        if (vec.nearZero(scatter_dir))
            scatter_dir = rec.normal;

        scattered_ray.* = .init(rec.p, scatter_dir);
        return true;
    }

    pub const Metal = struct {
        albedo: Colour,
        fuzz: f64,

        pub fn init(albedo: Colour, fuzz: f64) Metal {
            return .{
                .albedo = albedo,
                .fuzz = if (fuzz < 1) fuzz else 1,
            };
        }

        pub fn metalScatter(self: Metal, ray_in: *Ray, rec: *HitRecord, scattered_ray: *Ray) bool {
            var reflected: Vec3 = vec.reflect(ray_in.dir, rec.normal);
            reflected = vec.unitVec(reflected) + vec.scale(vec.randomUnitVec(), self.fuzz);
            scattered_ray.* = .init(rec.p, reflected);
            return vec.dot(scattered_ray.dir, rec.normal) > 0;
        }
    };
};
