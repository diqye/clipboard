const std = @import("std");

const A = packed struct {
    a: u32,
    b: u64
};

const B = packed struct {
    a: [4+8] u8,
};
pub fn main() !void {
    const b  = A{ .a = 1, .b = 2 };
    const a : B = @bitCast(b);
    std.debug.print("{},{}", .{a,b});
}

test "tranlsate" {
}
