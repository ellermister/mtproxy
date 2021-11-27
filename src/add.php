<?php
/**
 * Created by PhpStorm.
 * User: ellermister
 * Date: 2021/11/24
 * Time: 11:44
 */
$ip = trim($_SERVER['REMOTE_ADDR']);
$ip = long2ip(ip2long($ip) >> 8 << 8)."/24"; //增加IP段

$file_path = '/etc/nginx/ip_white.conf';
$raw = file_get_contents($file_path);
$arr = explode("\n", $raw);
foreach ($arr as $seg) {
    $buffer = explode(' ', $seg);
    if (trim($buffer[0]) == $ip) {
        echo "already added";
        die;
    }
}
$arr[] = "$ip 1;";
if (file_put_contents($file_path, implode("\n", $arr))) {
    echo "Added successfully";
    system("nginx -s reload");
} else {
    echo "Added fail";
}
