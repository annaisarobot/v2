<?php
	require_once("applicationTop.php");
	
	// Check access rights
	if (!$fbapi->checkAccessRights("Sales Order", "View")) {
		$_SESSION['msg'] = 'You do not have access to use that function.';
		header("Location: /login.php");
	}

	// Get sales order list
	$fbapi->getSOList();
	
	// Check for error messages
	if ($fbapi->statusCode != 1000) {
		// Display error messages if it's not blank
		if (!empty($fbapi->statusMsg)) {
			echo $fbapi->statusMsg;
		}
	}

	print_r($fbapi->result);
	
	echo "\n\n<br/><br/>------------------------<br/><br/>\n\n";
	
	// Get specific sales order
	$fbapi->getSO("50032");
	
	// Check for error messages
	if ($fbapi->statusCode != 1000) {
		// Display error messages if it's not blank
		if (!empty($fbapi->statusMsg)) {
			echo $fbapi->statusMsg;
		}
	}

	print_r($fbapi->result);
?>