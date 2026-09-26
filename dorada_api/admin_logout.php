<?php
require_once "conexion.php";
require_once "auth_admin.php";

$_SESSION = [];
session_destroy();

header("Location: dashboard.php");
exit;
