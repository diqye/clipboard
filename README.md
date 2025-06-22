## Clipboard

macOS Terminal上读取、写入粘贴板快捷操作。

## 安装

```shell
git clone xxx.git
cd xxx
zig build
mv zig-out/bin/clipboard /user/loal/
```
## 使用

```shell
clipboard:
 --print  [-p]        打印当前剪切板文本
 --write  [-W] text   写入内容到剪切板
 --key    [-K] key    读取已经存储的内容到剪切板
 --value  [-V] text   存储到本地和--key同时使用
 --delete [-D]        删除key和--key同时使用
 ```
