/// A thin wrapper around `std.ArrayListUnmanaged` for creating generic bounded array lists.
pub fn BoundedList(comptime T: type) type {
    return struct {
        buf: []T,
        list: std.ArrayList(T),

        const Self = @This();

        /// Initialize with externally-managed memory. The buffer determines
        /// the capacity, and the length is set to zero.
        ///
        /// When initialized this way, all functions that accept an Allocator
        /// argument cause illegal behavior
        pub fn init(buf: []T) Self {
            return .{ .buf = buf, .list = .initBuffer(buf) };
        }

        /// Initialize with externally-managed memory.
        /// `capacity` determines the allocated buffer size.
        pub fn initCapacity(gpa: std.mem.Allocator, capacity: usize) !Self {
            const buf = try gpa.alloc(T, capacity);
            return .{ .buf = buf, .list = .initBuffer(buf) };
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            gpa.free(self.buf);
            self.buf = &.{};
            self.list = undefined;
        }
    };
}

const std = @import("std");
