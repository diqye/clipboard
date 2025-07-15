const std = @import("std");

const A = packed struct {
    a: u32,
    b: u64
};

const B = packed struct {
    a: [4+8] u8,
};
fn testfn(a:[*c] const u8) void {
    _ = a;
}
pub fn main() !void {
    const str : [:0] const u8 = "hello";
    testfn(str);
}

fn myfn(comptime T: type,a:T) ?T {
    const type1 = @typeInfo(T);
    if(std.meta.eql(type1,  u8)) {
        return a;
    }
    std.debug.print("{}", .{type1});
    return null;
}
test "tranlsate" {
    _ = myfn(i32,10);
}
