#!/bin/sh

winepath=$1
glibcpath="/data/data/com.winlator/files/rootfs"

# 定义替换函数
replace_in_file() {
    file_path=$1
    search_str=$2
    replace_str=$3

    if [ ! -f "$file_path" ]; then
        echo "替换失败 - 文件不存在: $file_path"
        return 1
    fi

    # 计算匹配行数
    match_count=$(grep -c "$search_str" "$file_path")
    if [ "$match_count" -eq 0 ]; then
        echo "替换失败 - 未找到匹配内容: $file_path"
        return 1
    fi

    # 执行替换
    sed -i "s|$search_str|$replace_str|g" "$file_path"
    if [ $? -eq 0 ]; then
        echo "替换成功，共替换了 $match_count 处"
        return 0
    else
        echo "替换失败 - 写入错误: $file_path"
        return 1
    fi
}

# 执行所有替换任务
replace_in_file "./$winepath/dlls/crypt32/unixlib.c" \
    '"/etc/security/cacerts"' \
    '"/etc/security/cacerts,"\n"'$glibcpath'/etc/ca-certificates/cacert.pem"'

replace_in_file "./$winepath/programs/winemenubuilder/winemenubuilder.c" \
    'dirs = xwcsdup( L"/usr/local/share/:/usr/share/" )' \
    'dirs = xwcsdup( L"'$glibcpath'/usr/local/share/:'$glibcpath'/usr/share/" )'

replace_in_file "./$winepath/server/request.c" \
    '/tmp/' \
    "$glibcpath/tmp/"

replace_in_file "./$winepath/dlls/ntdll/unix/server.c" \
    '/tmp/' \
    "$glibcpath/tmp/"

replace_in_file "./$winepath/dlls/ntdll/unix/server.c" \
    'symlink( "/", "dosdevices/z:" );' \
    'symlink( "'$glibcpath'", "dosdevices/z:" );'

replace_in_file "./$winepath/dlls/ntdll/unix/virtual.c" \
    '*)0x7fffffff0000;' \
    '*)0x7fffff0000;'

replace_in_file "./$winepath/programs/winebrowser/main.c" \
    '/usr/' \
    "$glibcpath/usr/"

replace_in_file "./$winepath/server/unicode.c" \
    '/usr/' \
    "$glibcpath/usr/"

replace_in_file "./$winepath/dlls/ntdll/unix/esync.c" \
    '/wine-' \
    "$glibcpath/usr/wine-"

replace_in_file "./$winepath/server/esync.c" \
    '/wine-' \
    "$glibcpath/usr/wine-"
