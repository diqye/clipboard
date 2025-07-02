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
 --write  [-w] text   写入内容到剪切板
 --key    [-k] key    读取已经存储到本地的内容到剪切板
 --value  [-v] text   存储到本地和--key同时使用
 --paste              将剪切板的内容存储到本地,和 --key 一起使用
 --delete [-d]        删除key和--key同时使用
 --list   [-l]        列出所有的key
 --help   [-h]        打印帮助信息
 --push               将数据文件推送到gitee上,需要环境变量:
                      $gitee_clipboard_token=私有令牌
                      $gitee_store_path=https://gitee.com/api/v5/repos/diqye/store/contents/{path}
                      其中 {path} 为占位符，程序会自动生成名字替换它。
 --write_pipe         通过管道进来的内容写入剪切板
 ```

### 1. 打印剪切板的内容到屏幕
```shell
clipboard -p
```
### 2. 将一个文件内容复制
```shell
cat test.zig  | clipboard --write_pipe
```
### 3. 指定key将一段文本存储到本地
```shell
clipboard --key mykey --value text
```
### 4. 将存储到本地key的内容复制
```shell
clipboard --key mykey
```
### 5. 列出所有的key
```shell
clipboard --list
```
### 6. 备份到gitee上
1. 需要环境变量 `gitee_clipboard_token`
1. 需要环境变量 `gitee_store_path==https://gitee.com/api/v5/repos/diqye/store/contents/{path}`
    - `{path}` 是一个占位符，程序会自动替换
```shell
clipboard --push
```