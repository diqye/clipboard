const std = @import("std");
const c = @cImport({
    @cInclude("stdio.h"); // 引入 libc 中的头文件
});

const myerror = error {
    myerror,
};
pub fn main() !void {
    std.debug.print("start\n", .{});
    try throwerr();
    defer {
        std.debug.print("defer print\n", .{});
    }
}

fn throwerr() myerror!void {
    return myerror.myerror;
}
