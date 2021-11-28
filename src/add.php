<?php
/**
 * Created by PhpStorm.
 * User: ellermister
 * Date: 2021/11/24
 * Time: 11:44
 */
$ip = trim($_SERVER['REMOTE_ADDR']);

$ip_white_list = trim(file_get_contents('/var/ip_white_list'));
if($ip_white_list == 'IPSEG'){
	$ip = long2ip(ip2long($ip) >> 8 << 8)."/24"; //增加IP段	
}else if($ip_white_list == 'OFF'){
	die ("No need to add white list");
}

$file_path = '/etc/nginx/ip_white.conf';
$raw = file_get_contents($file_path);
$arr = explode("\n", $raw);
foreach ($arr as $seg) {
    $buffer = explode(' ', $seg);
    if (trim($buffer[0]) == $ip) {
        die ("already added");
    }
}
$arr[] = "$ip 1;";
if (file_put_contents($file_path, implode("\n", $arr), LOCK_EX)) {
    echo "Added successfully";
    system("nginx -s reload");
} else {
    echo "Added fail";
}
