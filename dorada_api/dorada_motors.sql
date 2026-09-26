CREATE DATABASE IF NOT EXISTS dorada_motors
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE dorada_motors;

SET FOREIGN_KEY_CHECKS=0;

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
  INDEX idx_direccion_usuario (id_usuario),
  CONSTRAINT fk_direccion_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
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
  INDEX idx_producto_marca (id_marca),
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
    REFERENCES categoria(id_categoria) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_producto_marca FOREIGN KEY (id_marca)
    REFERENCES marca(id_marca) ON DELETE RESTRICT ON UPDATE CASCADE
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
  INDEX idx_pedido_direccion (id_direccion),
  INDEX idx_pedido_fecha (fecha_pedido),
  CONSTRAINT fk_pedido_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pedido_direccion FOREIGN KEY (id_direccion)
    REFERENCES direccion(id_direccion) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_pedido (
  id_detalle INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_detalle_pedido (id_pedido),
  INDEX idx_detalle_producto (id_producto),
  CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido(id_pedido) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pago (
  id_pago INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  metodo_pago VARCHAR(50) NOT NULL,
  monto DECIMAL(10,2) NOT NULL DEFAULT 0,
  fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado_pago VARCHAR(30) NOT NULL DEFAULT 'Pendiente',
  INDEX idx_pago_pedido (id_pedido),
  CONSTRAINT fk_pago_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido(id_pedido) ON DELETE CASCADE ON UPDATE CASCADE
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
  INDEX idx_compra_fecha (fecha_compra),
  CONSTRAINT fk_compra_proveedor FOREIGN KEY (id_proveedor)
    REFERENCES proveedor(id_proveedor) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_compra (
  id_detalle_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_compra INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_compra DECIMAL(10,2) NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_detalle_compra_compra (id_compra),
  INDEX idx_detalle_compra_producto (id_producto),
  CONSTRAINT fk_detalle_compra FOREIGN KEY (id_compra)
    REFERENCES compra(id_compra) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_detalle_compra_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE RESTRICT ON UPDATE CASCADE
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
  INDEX idx_movimiento_fecha (fecha_movimiento),
  CONSTRAINT fk_movimiento_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS comprobante (
  id_comprobante INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  tipo_comprobante VARCHAR(20) NOT NULL DEFAULT 'Boleta',
  numero_comprobante VARCHAR(40) NOT NULL UNIQUE,
  fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  igv DECIMAL(10,2) NOT NULL DEFAULT 0,
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_comprobante_pedido (id_pedido),
  CONSTRAINT fk_comprobante_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido(id_pedido) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

SET FOREIGN_KEY_CHECKS=1;
