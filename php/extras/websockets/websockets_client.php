<?php
$progpath=dirname(__FILE__);
$confpath=realpath("{$progpath}/../../");
//load the config.xml file
include_once("$confpath/common.php");
global $ConfigXml;
global $allhost;
global $dbh;
global $sel;
global $CONFIG;
$_SERVER['HTTP_HOST']='localhost';
$_SERVER['UNIQUE_HOST']='localhost';
$_SERVER['SERVER_NAME']='localhost';
include_once("$confpath/config.php");
$progpath=dirname(__FILE__);
require_once("{$progpath}/websockets_functions.php");
//get command line arguments, removing the first one since it is the filename
array_shift($argv);
//if the first arg is a file assume they want to tail the file
if(is_file($argv[0])){
	wsTailFile($argv[0]);
}
elseif($argv[0]=='-test'){
	$messages=array(
		'hello',
		'{"love":"this is a love test","big":"http://www.disney.com"}'
	);
	foreach($messages as $message){
		$ok=wsSendMessage($message);
		sleep(1);
	}

}
else{
	//send the args as a string to the websocket
	$ok=wsSendMessage(implode(' ',$argv));
}
?>