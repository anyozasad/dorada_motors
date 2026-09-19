<?php

if (!isset($conexion) || !($conexion instanceof mysqli)) {
    require_once __DIR__ . "/conexion.php";
}

$conexion->query("
    CREATE TABLE IF NOT EXISTS admin_usuario (
        id_admin INT AUTO_INCREMENT PRIMARY KEY,
        nombres VARCHAR(120) NOT NULL,
        correo VARCHAR(160) NOT NULL UNIQUE,
        contrasena VARCHAR(255) NOT NULL,
        rol ENUM('Administrador','Vendedor','Almacen') NOT NULL DEFAULT 'Administrador',
        estado ENUM('Activo','Bloqueado') NOT NULL DEFAULT 'Activo',
        ultimo_acceso DATETIME NULL,
        creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$conexion->query("
    CREATE TABLE IF NOT EXISTS bitacora (
        id_bitacora BIGINT AUTO_INCREMENT PRIMARY KEY,
        id_admin INT NULL,
        usuario VARCHAR(160) NOT NULL,
        rol VARCHAR(40) NOT NULL,
        modulo VARCHAR(60) NOT NULL,
        accion VARCHAR(120) NOT NULL,
        detalle TEXT NULL,
        ip VARCHAR(64) NULL,
        fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_bitacora_fecha (fecha),
        INDEX idx_bitacora_modulo (modulo)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$conexion->query("
    CREATE TABLE IF NOT EXISTS configuracion_empresa (
        id_configuracion TINYINT PRIMARY KEY,
        nombre_comercial VARCHAR(160) NOT NULL DEFAULT 'Dorada Motors',
        razon_social VARCHAR(180) NOT NULL DEFAULT 'ADN Import''s',
        ruc VARCHAR(20) NULL,
        direccion VARCHAR(255) NULL,
        telefono VARCHAR(30) NULL,
        correo VARCHAR(160) NULL,
        moneda VARCHAR(8) NOT NULL DEFAULT 'S/',
        igv DECIMAL(5,2) NOT NULL DEFAULT 18.00,
        logo VARCHAR(255) NOT NULL DEFAULT 'logo_adn_imports.png',
        actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$conexion->query("
    INSERT IGNORE INTO configuracion_empresa
    (id_configuracion,nombre_comercial,razon_social,moneda,igv,logo)
    VALUES (1,'Dorada Motors','ADN Import''s','S/',18.00,'logo_adn_imports.png')
");

$conexion->query("
    CREATE TABLE IF NOT EXISTS devolucion (
        id_devolucion INT AUTO_INCREMENT PRIMARY KEY,
        id_pedido INT NOT NULL,
        id_producto INT NOT NULL,
        cantidad INT NOT NULL,
        motivo VARCHAR(255) NOT NULL,
        monto_reembolso DECIMAL(10,2) NOT NULL DEFAULT 0,
        estado ENUM('Aprobada','Rechazada') NOT NULL DEFAULT 'Aprobada',
        fecha_devolucion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        id_admin INT NULL,
        INDEX idx_devolucion_pedido (id_pedido),
        INDEX idx_devolucion_producto (id_producto)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$conexion->query("
    ALTER TABLE producto
    ADD COLUMN IF NOT EXISTS stock_minimo INT NOT NULL DEFAULT 5
");

$conexion->query("
    ALTER TABLE usuario
    ADD COLUMN IF NOT EXISTS estado VARCHAR(20) NOT NULL DEFAULT 'Activo'
");

$conexion->query("
    ALTER TABLE movimiento_stock
    ADD COLUMN IF NOT EXISTS stock_anterior INT NULL
");

$conexion->query("
    ALTER TABLE movimiento_stock
    ADD COLUMN IF NOT EXISTS stock_nuevo INT NULL
");
