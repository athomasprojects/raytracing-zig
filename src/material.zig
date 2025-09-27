const std = @import("std");
const vec = @import("vec.zig");

const Colour = vec.Colour;
const Point3 = vec.Vec3;
const Vec3 = vec.Vec3;
const Ray = @import("Ray.zig");
const Texture = @import("texture.zig").Texture;
const HitRecord = @import("hittable.zig").HitRecord;

pub const Material = union(enum) {
    lambertian: struct {
        tex: Texture,

        pub fn fromAlbedo(albedo: Colour) @This() {
            return .{
                .tex = .{ .solid_colour = .{ .albedo = albedo } },
            };
        }

        fn scatter(_: @This(), ray_in: Ray, hit: HitRecord) ?Ray {
            var scatter_dir: Vec3 = hit.normal + vec.randomUnitVec();

            // Catch degenerate scatter direction.
            if (vec.nearZero(scatter_dir)) scatter_dir = hit.normal;

            return .initMoving(hit.p, scatter_dir, ray_in.time);
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

        fn scatter(self: @This(), ray_in: Ray, hit: HitRecord) ?Ray {
            const reflected: Vec3 = vec.unit(vec.reflect(ray_in.direction, hit.normal)) + vec.scale(vec.randomUnitVec(), self.fuzz);
            return if (vec.dot(reflected, hit.normal) > 0) .initMoving(hit.p, reflected, ray_in.time) else null;
        }
    },

    dielectric: struct {
        // zig fmt: off
        albedo: Colour,
        refraction_index: f64, // Refractive index in vacuum or air, or the
                               // ratio of the material's refractive index over
                               // the refractive index of the enclosing media.

        // zig fmt: on
        fn scatter(self: @This(), ray_in: Ray, hit: HitRecord) ?Ray {
            const ri = if (hit.front_face)
                1 / self.refraction_index
            else
                self.refraction_index;

            const unit_direction = vec.unit(ray_in.direction);
            const cos_theta = @min(vec.dot(-unit_direction, hit.normal), 1);
            const sin_theta = @sqrt(@abs(1 - cos_theta * cos_theta));

            const cannot_refract = ri * sin_theta > 1;
            const reflectance = reflectanceSchlick(cos_theta, ri);

            const direction = if (cannot_refract or reflectance > vec.randomFloat())
                vec.reflect(unit_direction, hit.normal) // reflect
            else
                vec.refract(unit_direction, hit.normal, ri); // refract

            return .initMoving(hit.p, direction, ray_in.time);
        }

        fn reflectanceSchlick(cosine: f64, refraction_index: f64) f64 {
            var r0 = (1 - refraction_index) / (1 + refraction_index);
            r0 = r0 * r0;
            return r0 + (1 - r0) * std.math.pow(f64, (1 - cosine), 5);
        }
    },

    diffuse_light: struct {
        tex: Texture,

        pub fn fromEmittedColour(colour: Colour) @This() {
            return .{ .tex = .{ .solid_colour = .init(colour) } };
        }

        // fn emitted(self: @This(), u: f64, v: f64, p: Point3, tex_buf: []const Texture) Colour {
        //     return self.tex.value(u, v, p, tex_buf);
        // }

        fn scatter(_: @This(), _: Ray, _: HitRecord) ?Ray {
            return null;
        }
    },

    isotropic: struct {
        tex: Texture,

        pub fn fromAlbedo(colour: Colour) @This() {
            return .{ .tex = .{ .solid_colour = .init(colour) } };
        }

        fn scatter(_: @This(), ray_in: Ray, hit: HitRecord) ?Ray {
            return .initMoving(hit.p, vec.randomUnitVec(), ray_in.time);
        }
    },

    pub fn scatter(self: Material, ray_in: Ray, hit: HitRecord) ?Ray {
        return switch (self) {
            inline else => |m| m.scatter(ray_in, hit),
        };
    }

    pub fn emittedColour(self: Material, u: f64, v: f64, p: Point3, tex_buf: []const Texture) Colour {
        return switch (self) {
            .diffuse_light => |m| m.tex.value(u, v, p, tex_buf),
            else => vec.zero,
        };
    }

    pub fn attenuation(self: Material, hit: HitRecord, tex_buf: []const Texture) Colour {
        return switch (self) {
            .lambertian => |m| m.tex.value(hit.u, hit.v, hit.p, tex_buf),
            .diffuse_light => |m| m.tex.value(hit.u, hit.v, hit.p, tex_buf),
            .isotropic => |m| m.tex.value(hit.u, hit.v, hit.p, tex_buf),
            inline else => |m| m.albedo,
        };
    }
};
