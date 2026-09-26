CREATE DATABASE IF NOT EXISTS dorada_motors
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE dorada_motors;

CREATE TABLE IF NOT EXISTS usuario (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nombres VARCHAR(120) NOT NULL,
  apellidos VARCHAR(120) NOT NULL DEFAULT '',
  correo VARCHAR(160) NOT NULL UNIQUE,
  contrasena VARCHAR(255) NOT NULL,
  telefono VARCHAR(30) NOT NULL DEFAULT '',
  estado VARCHAR(20) NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS direccion (
  id_direccion INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  departamento VARCHAR(100) NOT NULL,
  provincia VARCHAR(100) NOT NULL,
  distrito VARCHAR(100) NOT NULL,
  direccion_detalle VARCHAR(255) NOT NULL,
  referencia VARCHAR(255) NOT NULL DEFAULT '',
  INDEX idx_direccion_usuario (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS categoria (
  id_categoria INT AUTO_INCREMENT PRIMARY KEY,
  nombre_categoria VARCHAR(120) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS marca (
  id_marca INT AUTO_INCREMENT PRIMARY KEY,
  nombre_marca VARCHAR(120) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS producto (
  id_producto INT AUTO_INCREMENT PRIMARY KEY,
  id_categoria INT NOT NULL,
  id_marca INT NOT NULL,
  nombre_producto VARCHAR(180) NOT NULL,
  descripcion TEXT NULL,
  precio DECIMAL(10,2) NOT NULL DEFAULT 0,
  stock INT NOT NULL DEFAULT 0,
  stock_minimo INT NOT NULL DEFAULT 5,
  imagen_url VARCHAR(255) NOT NULL DEFAULT '',
  INDEX idx_producto_categoria (id_categoria),
  INDEX idx_producto_marca (id_marca)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pedido (
  id_pedido INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado_pedido VARCHAR(30) NOT NULL DEFAULT 'Pendiente',
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  id_direccion INT NULL,
  tipo_entrega VARCHAR(30) NOT NULL DEFAULT 'Recojo en tienda',
  INDEX idx_pedido_usuario (id_usuario),
  INDEX idx_pedido_fecha (fecha_pedido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_pedido (
  id_detalle INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_detalle_pedido (id_pedido),
  INDEX idx_detalle_producto (id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pago (
  id_pago INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  metodo_pago VARCHAR(50) NOT NULL,
  monto DECIMAL(10,2) NOT NULL DEFAULT 0,
  fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado_pago VARCHAR(30) NOT NULL DEFAULT 'Pendiente',
  INDEX idx_pago_pedido (id_pedido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS carrito_favorito (
  id_carrito_favorito INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  id_producto INT NOT NULL,
  tipo_registro VARCHAR(30) NOT NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS proveedor (
  id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
  razon_social VARCHAR(180) NOT NULL,
  ruc VARCHAR(20) NULL,
  telefono VARCHAR(30) NULL,
  correo VARCHAR(160) NULL,
  direccion VARCHAR(255) NULL,
  estado VARCHAR(20) NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS compra (
  id_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_proveedor INT NOT NULL,
  fecha_compra DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  estado VARCHAR(30) NOT NULL DEFAULT 'Registrado',
  INDEX idx_compra_proveedor (id_proveedor),
  INDEX idx_compra_fecha (fecha_compra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_compra (
  id_detalle_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_compra INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_compra DECIMAL(10,2) NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_detalle_compra_compra (id_compra),
  INDEX idx_detalle_compra_producto (id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS movimiento_stock (
  id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
  id_producto INT NOT NULL,
  tipo_movimiento VARCHAR(20) NOT NULL,
  cantidad INT NOT NULL,
  motivo VARCHAR(255) NULL,
  fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  stock_anterior INT NULL,
  stock_nuevo INT NULL,
  INDEX idx_movimiento_producto (id_producto),
  INDEX idx_movimiento_fecha (fecha_movimiento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS comprobante (
  id_comprobante INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  tipo_comprobante VARCHAR(20) NOT NULL,
  numero_comprobante VARCHAR(40) NOT NULL UNIQUE,
  fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  igv DECIMAL(10,2) NOT NULL DEFAULT 0,
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_comprobante_pedido (id_pedido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS favorito (
  id_favorito INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  id_producto INT NOT NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_favorito_usuario_producto (id_usuario,id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS carrito (
  id_carrito INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_carrito_usuario (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_carrito (
  id_detalle_carrito INT AUTO_INCREMENT PRIMARY KEY,
  id_carrito INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL DEFAULT 1,
  UNIQUE KEY uq_carrito_producto (id_carrito,id_producto),
  INDEX idx_detalle_carrito_producto (id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_usuario (
  id_admin INT AUTO_INCREMENT PRIMARY KEY,
  nombres VARCHAR(120) NOT NULL,
  correo VARCHAR(160) NOT NULL UNIQUE,
  contrasena VARCHAR(255) NOT NULL,
  rol VARCHAR(30) NOT NULL DEFAULT 'Administrador',
  estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
  ultimo_acceso DATETIME NULL,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS devolucion (
  id_devolucion INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  motivo VARCHAR(255) NOT NULL,
  monto_reembolso DECIMAL(10,2) NOT NULL DEFAULT 0,
  estado VARCHAR(20) NOT NULL DEFAULT 'Aprobada',
  fecha_devolucion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_admin INT NULL,
  INDEX idx_devolucion_pedido (id_pedido),
  INDEX idx_devolucion_producto (id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO configuracion_empresa
(id_configuracion,nombre_comercial,razon_social,moneda,igv,logo)
VALUES
(1,'Dorada Motors','ADN Import''s','S/',18.00,'logo_adn_imports.png');

INSERT IGNORE INTO categoria (nombre_categoria) VALUES
('Transmisión'),
('Frenos'),
('Motor'),
('Eléctrico'),
('Accesorios');

INSERT IGNORE INTO marca (nombre_marca) VALUES
('DTIEX'),
('GDM'),
('BJR'),
('KIGKOL');
